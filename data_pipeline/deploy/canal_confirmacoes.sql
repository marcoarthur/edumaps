-- Deploy edumaps:canal_confirmacoes to pg
-- requires: gestor_reunioes
--
-- Confirmação de posse de um endereço de canal (e-mail, WhatsApp, Telegram):
-- guarda o pedido, o HASH do código (nunca o código em claro), a validade e o
-- número de tentativas. O endereço é PII — acesso restrito, como clean.contatos.
-- `contato_id`/`cod_inep` são opcionais: ligam o pedido à agenda da escola.

BEGIN;

  CREATE TABLE clean.canal_confirmacoes (
    id            bigserial   PRIMARY KEY,
    canal         text        NOT NULL
      CHECK (canal IN ('email', 'whatsapp', 'telegram')),
    endereco      text        NOT NULL,
    codigo_hash   text        NOT NULL,
    salt          text        NOT NULL,
    expira_em     timestamptz NOT NULL,
    confirmado_em timestamptz,
    tentativas    integer     NOT NULL DEFAULT 0,
    contato_id    bigint      REFERENCES clean.contatos (id) ON DELETE CASCADE,
    cod_inep      bigint,
    created_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_confirmacoes IS
    'Pedidos de confirmação de posse de um endereço de canal (e-mail/telefone/chat). Guarda apenas o hash do código + salt; o código em claro nunca é persistido. Endereço é PII — acesso restrito.';
  COMMENT ON COLUMN clean.canal_confirmacoes.canal IS
    'Canal do endereço: email, whatsapp ou telegram (espelha EduMaps::Channel).';
  COMMENT ON COLUMN clean.canal_confirmacoes.endereco IS
    'Endereço normalizado pelo canal (ex.: e-mail minúsculo; 55DDDNUMBER; chat_id).';
  COMMENT ON COLUMN clean.canal_confirmacoes.codigo_hash IS
    'SHA-256(código + salt) em hex. O código de 6 dígitos não é gravado em claro.';
  COMMENT ON COLUMN clean.canal_confirmacoes.expira_em IS
    'Validade do pedido. Pedidos pendentes vencidos deixam de ser aceitos e podem ser purgados.';
  COMMENT ON COLUMN clean.canal_confirmacoes.confirmado_em IS
    'Momento em que o código foi conferido com sucesso (NULL = pendente).';
  COMMENT ON COLUMN clean.canal_confirmacoes.tentativas IS
    'Nº de tentativas de verificação (limite em EduMaps::Channel::Confirmation->max_attempts).';

  CREATE INDEX idx_canal_confirmacoes_lookup
    ON clean.canal_confirmacoes (canal, endereco)
    WHERE confirmado_em IS NULL;
  CREATE INDEX idx_canal_confirmacoes_contato
    ON clean.canal_confirmacoes (contato_id);

COMMIT;
