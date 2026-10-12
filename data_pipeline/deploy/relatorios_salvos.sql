-- Deploy edumaps:relatorios_salvos to pg
-- requires: canal_envios
--
-- Assistente de Relatório (issue #219 — Fase 3): relatórios salvos pelo
-- gestor. Change NOVA, anexada ao fim do plano; nenhuma change já deployada é
-- editada. A dependência de canal_envios é só de ordem (fim do plano): a
-- tabela referencia apenas clean.gestores.
--
-- Cada linha é uma FOTOGRAFIA do ReportResult gerado por um job Minion
-- (relatorio_gerar). O conteúdo é copiado do resultado do job no servidor,
-- nunca do cliente. Retenção: até o gestor excluir, ou até a conta ser
-- removida (ON DELETE CASCADE).

BEGIN;

  CREATE TABLE clean.relatorios_salvos (
    id           bigserial PRIMARY KEY,
    gestor_id    bigint NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    cod_inep     bigint NOT NULL,
    job_id       bigint NOT NULL,                 -- job Minion de origem (dedupe)
    tema_id      text   NOT NULL,
    tema_titulo  text   NOT NULL,
    nivel        text   NOT NULL CHECK (nivel IN ('escola','municipio','uf','regiao')),
    codigo       text   NOT NULL,
    recorte_nome text,
    opcoes       jsonb  NOT NULL DEFAULT '{}'::jsonb,
    titulo       text   NOT NULL,
    conteudo     jsonb  NOT NULL,                 -- ReportResult (fotografia)
    gerado_em    timestamptz NOT NULL,            -- ReportResult.gerado_em
    created_at   timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (gestor_id, job_id)
  );

  CREATE INDEX idx_relatorios_salvos_gestor
    ON clean.relatorios_salvos (gestor_id, created_at DESC);

  COMMENT ON TABLE clean.relatorios_salvos IS
    'Assistente de Relatório (#219): relatórios salvos pelo gestor — fotografia do ReportResult de um job relatorio_gerar';
  COMMENT ON COLUMN clean.relatorios_salvos.gestor_id IS
    'Gestor que salvou (escopo: só ele vê); removido em cascata com a conta';
  COMMENT ON COLUMN clean.relatorios_salvos.cod_inep IS
    'Escola (INEP) da sessão em que o relatório foi gerado';
  COMMENT ON COLUMN clean.relatorios_salvos.job_id IS
    'Job Minion de origem; UNIQUE (gestor_id, job_id) torna o salvar idempotente';
  COMMENT ON COLUMN clean.relatorios_salvos.tema_id IS
    'Id do tema do catálogo do R (args do job)';
  COMMENT ON COLUMN clean.relatorios_salvos.tema_titulo IS
    'Título do tema no momento da geração (resultado do job)';
  COMMENT ON COLUMN clean.relatorios_salvos.nivel IS
    'Nível do recorte (geotag): escola, municipio, uf ou regiao';
  COMMENT ON COLUMN clean.relatorios_salvos.codigo IS
    'Código do recorte (geotag): INEP, IBGE de 7 dígitos, sigla da UF ou da região';
  COMMENT ON COLUMN clean.relatorios_salvos.recorte_nome IS
    'Nome do recorte no momento da geração (resultado do job)';
  COMMENT ON COLUMN clean.relatorios_salvos.opcoes IS
    'Opções do relatório (args do job), ex.: {"etapa": "fundamental_ii"}';
  COMMENT ON COLUMN clean.relatorios_salvos.titulo IS
    'Título do relatório (resultado do job)';
  COMMENT ON COLUMN clean.relatorios_salvos.conteudo IS
    'ReportResult gravado (fotografia), sem o cache_hit';
  COMMENT ON COLUMN clean.relatorios_salvos.gerado_em IS
    'Momento em que o relatório foi gerado (ReportResult.gerado_em)';
  COMMENT ON COLUMN clean.relatorios_salvos.created_at IS
    'Momento em que o gestor salvou o relatório';

COMMIT;
