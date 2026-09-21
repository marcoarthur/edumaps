-- Deploy edumaps:relacoes_gestao to pg
-- requires: relacoes_escolar
--
-- Gestão das relações institucionais (Etapa 4): histórico de interações
-- (timeline) e documentos/anexos de cada relação. Arquivo físico no upload_dir.
-- Interações e documentos pertencem a uma relação (ON DELETE CASCADE).

BEGIN;

  -- Interações: histórico do que aconteceu na relação (reunião, e-mail, ofício…).
  CREATE TABLE clean.relacoes_interacoes (
    id           bigserial   PRIMARY KEY,
    relacao_id   bigint      NOT NULL REFERENCES clean.relacoes (id) ON DELETE CASCADE,
    gestor_id    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    data         date,
    canal        text,
    participante text,
    assunto      text,
    descricao    text,
    resultado    text,
    created_at   timestamptz NOT NULL DEFAULT NOW(),
    updated_at   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes_interacoes IS
    'Histórico de interações de uma relação institucional (reunião, e-mail, telefone, ofício, visita). Timeline exibida no detalhe da relação.';
  COMMENT ON COLUMN clean.relacoes_interacoes.canal IS
    'Canal da interação em texto livre (reunião, e-mail, telefone, ofício, whatsapp, visita…).';
  COMMENT ON COLUMN clean.relacoes_interacoes.resultado IS
    'O que ficou decidido/encaminhado após a interação.';

  CREATE INDEX idx_relacoes_interacoes_relacao ON clean.relacoes_interacoes (relacao_id);

  -- Documentos/anexos da relação (ofícios, contratos, notas, fotos…).
  CREATE TABLE clean.relacoes_documentos (
    id            bigserial   PRIMARY KEY,
    relacao_id    bigint      NOT NULL REFERENCES clean.relacoes (id) ON DELETE CASCADE,
    gestor_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    tipo          text,
    data          date,
    referencia    text,
    nome_original text        NOT NULL,
    caminho       text        NOT NULL,
    mime          text,
    tamanho       bigint      NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes_documentos IS
    'Documentos anexados a uma relação institucional (ofício, contrato, nota, foto). O arquivo físico fica no dir de upload (upload_dir), não no banco.';
  COMMENT ON COLUMN clean.relacoes_documentos.referencia IS
    'Referência livre do documento (nº do ofício, protocolo…).';
  COMMENT ON COLUMN clean.relacoes_documentos.caminho IS
    'Caminho relativo ao upload_dir (ex.: <cod_inep>/relacoes/<relacao_id>/<uuid>.<ext>).';

  CREATE INDEX idx_relacoes_documentos_relacao ON clean.relacoes_documentos (relacao_id);

COMMIT;
