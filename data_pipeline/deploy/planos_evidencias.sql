-- Deploy edumaps:planos_evidencias to pg
-- requires: planos_alertas
-- requires: gestor_reunioes
-- requires: gestor_documentos
--
-- #372 (épico #368, RF-006): evidência de uma ação ou meta do plano. Liga o que
-- a escola já registrou, sem reenviar arquivo:
--   * ata      -> uma reunião (clean.reunioes), com a ata em texto ou anexo;
--   * documento -> uma VERSÃO de documento (clean.escola_documentos_versoes);
--   * nota     -> texto livre.
-- Apagar a reunião ou o documento NÃO apaga a evidência (ON DELETE SET NULL):
-- ela fica como "origem removida", com o título guardado em `origem_titulo`.
-- Interna (sem GRANT ao edumaps_leitor; lista de sensíveis do leitor_grants.t).

BEGIN;

  CREATE TABLE clean.planos_evidencias (
    id                  bigserial   PRIMARY KEY,
    acao_id             bigint      REFERENCES clean.planos_acoes (id) ON DELETE CASCADE,
    meta_id             bigint      REFERENCES clean.planos_metas (id) ON DELETE CASCADE,
    tipo                text        NOT NULL CHECK (tipo IN ('ata', 'documento', 'nota')),
    reuniao_id          bigint      REFERENCES clean.reunioes (id) ON DELETE SET NULL,
    documento_versao_id bigint      REFERENCES clean.escola_documentos_versoes (id) ON DELETE SET NULL,
    texto               text        CHECK (texto IS NULL OR length(btrim(texto)) BETWEEN 1 AND 2000),
    origem_titulo       text,
    created_by          bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    created_at          timestamptz NOT NULL DEFAULT NOW(),
    -- pertence a uma ação OU a uma meta
    CONSTRAINT ck_planos_evidencias_dono CHECK ((acao_id IS NULL) <> (meta_id IS NULL)),
    -- cada tipo só usa a sua referência (a referência pode virar NULL depois)
    CONSTRAINT ck_planos_evidencias_tipo CHECK (
      CASE tipo
        WHEN 'nota'      THEN texto IS NOT NULL AND reuniao_id IS NULL AND documento_versao_id IS NULL
        WHEN 'ata'       THEN documento_versao_id IS NULL
        WHEN 'documento' THEN reuniao_id IS NULL
      END)
  );
  CREATE INDEX idx_planos_evidencias_acao ON clean.planos_evidencias (acao_id) WHERE acao_id IS NOT NULL;
  CREATE INDEX idx_planos_evidencias_meta ON clean.planos_evidencias (meta_id) WHERE meta_id IS NOT NULL;
  CREATE INDEX idx_planos_evidencias_reuniao ON clean.planos_evidencias (reuniao_id) WHERE reuniao_id IS NOT NULL;
  CREATE INDEX idx_planos_evidencias_versao ON clean.planos_evidencias (documento_versao_id) WHERE documento_versao_id IS NOT NULL;

  COMMENT ON TABLE clean.planos_evidencias IS
    'Evidências das ações e metas dos planos (#372): ata de reunião, versão de documento ou nota. Origem apagada vira NULL e a evidência fica ("origem removida").';
  COMMENT ON COLUMN clean.planos_evidencias.origem_titulo IS
    'Título da reunião ou "documento (vN)" no momento do vínculo — mostrado quando a origem é removida.';

  -- A auditoria dos planos passa a registrar evidências.
  ALTER TABLE clean.planos_auditoria DROP CONSTRAINT planos_auditoria_entidade_check;
  ALTER TABLE clean.planos_auditoria ADD CONSTRAINT planos_auditoria_entidade_check
    CHECK (entidade IN ('plano', 'objetivo', 'meta', 'acao', 'evidencia'));

COMMIT;
