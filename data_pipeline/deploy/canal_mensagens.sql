-- Deploy edumaps:canal_mensagens to pg
-- requires: canal_confirmacoes
--
-- Histórico de mensagens de canal (instrumentação): qual mensagem foi enviada,
-- por qual canal, a que OPERAÇÃO se refere (aviso/informação/pedido/...), para
-- qual destinatário e com que resultado. Destinatário e corpo são PII — acesso
-- restrito (a leitura exposta por API deve mascarar).

BEGIN;

  CREATE TABLE clean.canal_mensagens (
    id                  bigserial   PRIMARY KEY,
    canal               text        NOT NULL
      CHECK (canal IN ('email', 'whatsapp', 'telegram')),
    operacao            text        NOT NULL
      CHECK (operacao IN ('aviso','informacao','pedido','convite',
                          'confirmacao','lembrete','alerta')),
    destinatario        text        NOT NULL,
    assunto             text,
    corpo               text,
    referente_tipo      text,
    referente_id        bigint,
    status              text        NOT NULL DEFAULT 'queued'
      CHECK (status IN ('queued','sent','failed')),
    erro                text,
    provider_message_id text,
    tentativas          integer     NOT NULL DEFAULT 0,
    contato_id          bigint      REFERENCES clean.contatos (id) ON DELETE SET NULL,
    cod_inep            bigint,
    created_at          timestamptz NOT NULL DEFAULT NOW(),
    sent_at             timestamptz
  );

  COMMENT ON TABLE clean.canal_mensagens IS
    'Histórico de mensagens de canal (queued/sent/failed): canal, operação (motivo), destinatário, texto e referência à entidade. Instrumenta "qual mensagem foi enviada". PII — acesso restrito.';
  COMMENT ON COLUMN clean.canal_mensagens.canal IS
    'Canal de envio: email, whatsapp ou telegram (espelha EduMaps::Channel).';
  COMMENT ON COLUMN clean.canal_mensagens.operacao IS
    'Motivo/operação da mensagem. Espelha EduMaps::Channel::Operacoes (o CHECK é a fonte de verdade do banco).';
  COMMENT ON COLUMN clean.canal_mensagens.destinatario IS
    'Endereço normalizado do destino. PII — mascarar na leitura exposta por API.';
  COMMENT ON COLUMN clean.canal_mensagens.corpo IS
    'Texto enviado. PII — mascarar/truncar na leitura exposta por API.';
  COMMENT ON COLUMN clean.canal_mensagens.referente_tipo IS
    'Tipo da entidade a que a mensagem se refere (ex.: reuniao, confirmacao).';
  COMMENT ON COLUMN clean.canal_mensagens.referente_id IS
    'Id da entidade referida (ex.: reunioes.id).';
  COMMENT ON COLUMN clean.canal_mensagens.status IS
    'queued (enfileirada) -> sent (entregue ao provedor) | failed (falhou).';
  COMMENT ON COLUMN clean.canal_mensagens.provider_message_id IS
    'Identificador da mensagem no provedor, quando devolvido.';

  CREATE INDEX idx_canal_mensagens_canal_created
    ON clean.canal_mensagens (canal, created_at DESC);
  CREATE INDEX idx_canal_mensagens_contato
    ON clean.canal_mensagens (contato_id);
  CREATE INDEX idx_canal_mensagens_cod_inep
    ON clean.canal_mensagens (cod_inep);
  CREATE INDEX idx_canal_mensagens_status
    ON clean.canal_mensagens (status);

COMMIT;
