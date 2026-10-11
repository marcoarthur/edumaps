-- Deploy edumaps:canal_confirmacao_listas to pg
-- requires: canal_listas_autoinscricao
--
-- Confirmação de posse do telefone nas listas com QR (issue #212 — Fase 1).
-- Change NOVA: só ALTER em tabelas existentes + duas tabelas novas; nenhuma
-- change já deployada é editada.
--
--   canal_listas.exige_confirmacao   exigência por lista (default false: a
--                                    Fase 0 continua intacta);
--   canal_lista_membros.confirmado_* estado da confirmação do membro (o
--                                    booleano `validado` passa a ser
--                                    preenchido pela confirmação);
--   canal_confirmacao_refs           referência pública opaca (128 bits) da
--                                    confirmação, guardada só como hash;
--   canal_telegram_estado            offset do getUpdates do bot público
--                                    (modo polling).
--
-- Modelo NÃO DESTRUTIVO, como na Fase 0: confirma/marca, nunca apaga.

BEGIN;

  -- ---------------------------------------------------------------------
  -- canal_listas: exigência de confirmação por lista (RF-101)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_listas
    ADD COLUMN exige_confirmacao boolean NOT NULL DEFAULT false;

  COMMENT ON COLUMN clean.canal_listas.exige_confirmacao IS
    'true = inscrições na lista ficam pendentes até o inscrito confirmar a posse do telefone (Telegram/WhatsApp). Default false (Fase 0 intacta). Mudar a opção não altera membros já existentes.';

  -- ---------------------------------------------------------------------
  -- canal_lista_membros: estado da confirmação (RF-102/RF-106)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_lista_membros
    ADD COLUMN confirmado_em    timestamptz,
    ADD COLUMN confirmado_via   text
      CONSTRAINT canal_lista_membros_confirmado_via_check
      CHECK (confirmado_via IN ('telegram', 'whatsapp')),
    ADD COLUMN telegram_chat_id bigint;

  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_em IS
    'Momento da confirmação de posse do telefone. NULL = não confirmado (pendente se a lista exige; "não exigida" caso contrário).';
  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_via IS
    'Canal pelo qual a posse foi confirmada: telegram ou whatsapp (CHECK é a fonte de verdade do banco).';
  COMMENT ON COLUMN clean.canal_lista_membros.telegram_chat_id IS
    'chat_id do Telegram do inscrito, gravado só quando confirmou via Telegram (endereço confirmado do canal — finalidade: comunicação da escola).';

  -- ---------------------------------------------------------------------
  -- canal_confirmacao_refs: referência pública da confirmação (RF-102..105)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_confirmacao_refs (
    id                     bigserial   PRIMARY KEY,
    inscricao_id           bigint      NOT NULL REFERENCES clean.canal_inscricoes (id) ON DELETE CASCADE,
    membro_id              bigint      NOT NULL REFERENCES clean.canal_lista_membros (id) ON DELETE CASCADE,
    ref_hash               text        NOT NULL UNIQUE,
    expira_em              timestamptz NOT NULL,
    usada_em               timestamptz,
    invalidada_em          timestamptz,
    envios_whatsapp        integer     NOT NULL DEFAULT 0,
    telegram_chat_pendente bigint,
    created_at             timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_confirmacao_refs IS
    'Referência pública (nonce de 128 bits) de uma confirmação de posse de telefone numa lista com QR. A ref em claro só vai ao inscrito; o banco guarda o SHA-256. Uso único, com validade; uma nova inscrição do mesmo membro invalida a anterior.';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.inscricao_id IS
    'Inscrição (submissão) que originou a ref — guarda o telefone_norm a comparar. DELETE CASCADE.';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.membro_id IS
    'Membro da lista a confirmar. DELETE CASCADE.';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.ref_hash IS
    'SHA-256 (hex) da ref de 32 hex. A ref em claro nunca é persistida.';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.expira_em IS
    'Validade da ref (default 24h). Vencida sem uso = não encontrada.';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.usada_em IS
    'Momento em que a ref concluiu a confirmação (uso único).';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.invalidada_em IS
    'Momento em que a ref foi substituída por outra (reinscrição do mesmo membro pendente).';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.envios_whatsapp IS
    'Quantos códigos de WhatsApp já foram enviados por esta ref (limite de reenvio).';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.telegram_chat_pendente IS
    'chat_id que abriu /start <ref> no bot e aguarda o compartilhamento do contato (persistido: sobrevive a reinício do worker).';

  CREATE INDEX idx_canal_confirmacao_refs_membro
    ON clean.canal_confirmacao_refs (membro_id);

  -- ---------------------------------------------------------------------
  -- canal_telegram_estado: offset do recebimento por polling (RF-107)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_telegram_estado (
    bot_username  text        PRIMARY KEY,
    update_offset bigint      NOT NULL DEFAULT 0,
    updated_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_telegram_estado IS
    'Estado do recebimento de updates do bot público do Telegram (modo polling): o offset persistido evita perda e reprocessamento ao reiniciar o worker.';
  COMMENT ON COLUMN clean.canal_telegram_estado.update_offset IS
    'Próximo offset do getUpdates (último update_id tratado + 1).';

COMMIT;
