-- Deploy edumaps:gestor_documentos to pg
-- requires: gestor_respostas
--
-- Documentos e planos escolares: pasta de documentos pedagógicos da escola
-- (PPP, projetos, planejamentos) com metáfora de sistema de arquivos
-- (pastas/subpastas + documentos), tags livres e versionamento auditado.
--
-- Regras de negócio (fase 1 — sem ACL; o escopo é a escola do gestor logado):
--   * toda linha traz cod_inep — escopo estrito da escola do token;
--   * o arquivo físico é imutável: cada versão é um uuid próprio em upload_dir
--     (<cod_inep>/documentos/<uuid>.<ext>) e nunca é reescrito;
--   * um documento é a identidade estável; re-upload com o MESMO nome na MESMA
--     pasta gera NOVA versão (sobrescrita auditada) — versões antigas seguem
--     disponíveis para download;
--   * pastas não podem ser excluídas com conteúdo (validado na aplicação);
--   * a auditoria não tem FK para a entidade: o histórico sobrevive à exclusão.

BEGIN;

  -- Pastas da escola (raiz = pasta_pai_id NULL).
  CREATE TABLE clean.pastas_escolares (
    id            bigserial   PRIMARY KEY,
    cod_inep      bigint      NOT NULL,
    gestor_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    pasta_pai_id  bigint      REFERENCES clean.pastas_escolares (id) ON DELETE CASCADE,
    nome          text        NOT NULL,
    created_at    timestamptz NOT NULL DEFAULT NOW(),
    updated_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.pastas_escolares IS
    'Pastas de documentos da escola (metáfora de sistema de arquivos). Raiz = pasta_pai_id NULL; subpastas apontam para o pai. A pasta pai é sempre da mesma escola (validado na aplicação).';
  COMMENT ON COLUMN clean.pastas_escolares.nome IS
    'Nome da pasta — único entre irmãos da mesma escola (índice COALESCE(pasta_pai_id, 0)).';
  COMMENT ON COLUMN clean.pastas_escolares.gestor_id IS
    'Gestor que criou a pasta (NULL após o gestor ser excluído).';

  CREATE INDEX idx_pastas_escolares_inep ON clean.pastas_escolares (cod_inep);
  CREATE INDEX idx_pastas_escolares_pai ON clean.pastas_escolares (cod_inep, pasta_pai_id);
  CREATE UNIQUE INDEX uq_pastas_escolares_inep_pai_nome
    ON clean.pastas_escolares (cod_inep, nome, COALESCE(pasta_pai_id, 0));

  -- Documentos (identidade estável). O conteúdo fica nas versões; aqui ficam
  -- pasta, nome (nome do arquivo exibido) e tags livres.
  CREATE TABLE clean.escola_documentos (
    id            bigserial   PRIMARY KEY,
    cod_inep      bigint      NOT NULL,
    pasta_id      bigint      REFERENCES clean.pastas_escolares (id) ON DELETE SET NULL,
    gestor_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    nome          text        NOT NULL,
    tags          text[]      NOT NULL DEFAULT '{}',
    created_at    timestamptz NOT NULL DEFAULT NOW(),
    updated_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.escola_documentos IS
    'Documento da escola (PPP, plano, projeto…). É a identidade estável que agrega as versões (escola_documentos_versoes) e as tags; a pasta NULL = raiz.';
  COMMENT ON COLUMN clean.escola_documentos.nome IS
    'Nome exibido do documento (único entre irmãos da mesma escola). Ser renomeado pelo gestor não muda o conteúdo.';
  COMMENT ON COLUMN clean.escola_documentos.tags IS
    'Tags livres criadas pelo gestor (ex.: PPP, 2026, Ensino Médio) — usadas para agrupar e filtrar.';
  COMMENT ON COLUMN clean.escola_documentos.pasta_id IS
    'Pasta que contém o documento (NULL = raiz). Mudar de pasta é a "movimentação" auditada.';

  CREATE INDEX idx_escola_documentos_inep ON clean.escola_documentos (cod_inep);
  CREATE INDEX idx_escola_documentos_pasta ON clean.escola_documentos (cod_inep, pasta_id);
  CREATE INDEX idx_escola_documentos_tags ON clean.escola_documentos USING GIN (tags);
  CREATE UNIQUE INDEX uq_escola_documentos_inep_pasta_nome
    ON clean.escola_documentos (cod_inep, nome, COALESCE(pasta_id, 0));

  -- Versões: cada upload vira uma linha imutável; o arquivo físico vive no
  -- upload_dir, fora do banco. Trocar o conteúdo = nova linha.
  CREATE TABLE clean.escola_documentos_versoes (
    id            bigserial   PRIMARY KEY,
    documento_id  bigint      NOT NULL REFERENCES clean.escola_documentos (id) ON DELETE CASCADE,
    versao        integer     NOT NULL,
    caminho       text        NOT NULL,
    nome_original text        NOT NULL,
    mime          text,
    tamanho       bigint      NOT NULL DEFAULT 0,
    sha1          char(40)    NOT NULL,
    gestor_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    criado_em     timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (documento_id, versao)
  );

  COMMENT ON TABLE clean.escola_documentos_versoes IS
    'Versão imutável de um documento da escola. O arquivo físico fica no upload_dir (<cod_inep>/documentos/<uuid>.<ext>) e nunca é sobrescrito no disco — substituir o conteúdo gera uma nova linha com versao + 1.';
  COMMENT ON COLUMN clean.escola_documentos_versoes.sha1 IS
    'SHA-1 do conteúdo, para conferência de integridade por versão.';
  COMMENT ON COLUMN clean.escola_documentos_versoes.nome_original IS
    'Nome original do arquivo enviado (usado no header de download da versão).';

  CREATE INDEX idx_escola_documentos_versoes_doc
    ON clean.escola_documentos_versoes (documento_id, versao);

  -- Auditoria de TODAS as mudanças (criações, uploads, sobrescritas,
  -- renomeações, movimentações, tags, exclusões). Sem FK para a entidade de
  -- propósito: o histórico permanece mesmo após excluir o documento/pasta.
  CREATE TABLE clean.escola_documentos_auditoria (
    id          bigserial   PRIMARY KEY,
    cod_inep    bigint      NOT NULL,
    gestor_id   bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    entidade    text        NOT NULL CHECK (entidade IN ('pasta', 'documento')),
    entidade_id bigint      NOT NULL,
    acao        text        NOT NULL CHECK (acao IN ('criado', 'renomeado', 'movido', 'sobrescrito', 'tags', 'excluido')),
    detalhes    jsonb       NOT NULL DEFAULT '{}',
    criado_em   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.escola_documentos_auditoria IS
    'Auditoria de mudanças em documentos/planos da escola: quem, o quê, quando e detalhes (JSONB). Base do histórico por documento e do feed de atividade da escola.';
  COMMENT ON COLUMN clean.escola_documentos_auditoria.entidade IS
    'Entidade afetada: pasta ou documento.';
  COMMENT ON COLUMN clean.escola_documentos_auditoria.acao IS
    'Ação: criado, renomeado, movido, sobrescrito (nova versão), tags (alteração de tags) ou excluido.';
  COMMENT ON COLUMN clean.escola_documentos_auditoria.detalhes IS
    'Detalhes em JSON: ex. {"de":"PPP.pdf","para":"PPP 2026.pdf"} ou {"versao":2,"tamanho":1234,"sha1":"abc…"}.';

  CREATE INDEX idx_escola_documentos_auditoria_inep
    ON clean.escola_documentos_auditoria (cod_inep, criado_em DESC);
  CREATE INDEX idx_escola_documentos_auditoria_ent
    ON clean.escola_documentos_auditoria (entidade, entidade_id);

COMMIT;