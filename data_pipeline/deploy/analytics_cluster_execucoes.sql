-- Deploy edumaps:analytics_cluster_execucoes to pg
-- requires: idempotencia
--
-- #427 (AN-05, AN-09): cada execução do agrupamento de escolas fica guardada,
-- com o recorte, os parâmetros e o universo (quantas escolas havia, quantas
-- entraram e por que as outras ficaram de fora). Antes, o resultado vivia
-- numa coluna da tabela compartilhada clean.school_indicators e era apagado
-- pela execução seguinte: não havia link nem exportação.
--
-- * O backend cria a execução (estado 'processando') e passa o run_id ao
--   motor R, que grava as atribuições e completa o universo.
-- * Validade de 90 dias (expira_em); uma tarefa diária apaga as vencidas, e
--   as atribuições saem junto (ON DELETE CASCADE).
-- * Sem dado pessoal (escolas e indicadores públicos do Censo/IDEB): o
--   schema analytics já é legível pelo edumaps_leitor.

BEGIN;

  CREATE TABLE analytics.cluster_execucoes (
    run_id      text        PRIMARY KEY,
    job_id      bigint,
    estado      text        NOT NULL DEFAULT 'processando'
                            CHECK (estado IN ('processando', 'concluida', 'falhou')),
    recorte     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    parametros  jsonb       NOT NULL DEFAULT '{}'::jsonb,
    universo    jsonb       NOT NULL DEFAULT '{}'::jsonb,
    criado_em   timestamptz NOT NULL DEFAULT NOW(),
    expira_em   timestamptz NOT NULL DEFAULT NOW() + INTERVAL '90 days'
  );
  CREATE INDEX idx_cluster_execucoes_expira ON analytics.cluster_execucoes (expira_em);
  COMMENT ON TABLE analytics.cluster_execucoes IS
    'Execuções do agrupamento de escolas (#427): recorte, parâmetros (algoritmo, grupos, indicadores, ano IDEB) e universo (total, agrupadas, excluídas por motivo). Válidas por 90 dias.';

  CREATE TABLE analytics.cluster_atribuicoes (
    run_id        text    NOT NULL REFERENCES analytics.cluster_execucoes (run_id) ON DELETE CASCADE,
    co_entidade   bigint  NOT NULL,
    cluster_id    integer NOT NULL,
    cluster_label text,
    cluster_rank  integer,
    valores       jsonb   NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (run_id, co_entidade)
  );
  COMMENT ON TABLE analytics.cluster_atribuicoes IS
    'Grupo de cada escola em cada execução do agrupamento (#427), com os valores dos indicadores usados (para a exportação citável).';

COMMIT;
