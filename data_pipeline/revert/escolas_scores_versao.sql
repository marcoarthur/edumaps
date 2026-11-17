-- Revert edumaps:escolas_scores_versao from pg
--
-- Volta ao comentário da change escolas_scores_diversidade_esp.

BEGIN;

  COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS 'ÍNDICE CANÔNICO do produto (#137): 6 scores 0-10 das escolas ativas, derivados do Censo Escolar (quanto maior, melhor). Consumido por analytics.ranking_escola (bin/ranking.pl), EduMaps::Model::Rank::School, SchoolEmbedding e View::ClusterEscola. Fórmula, normalização e ordem em docs/analises/ivet.md (ivet-v1.0; insumo de diversidade corrigido em ivet-v1.4, #459). Atualizar com REFRESH MATERIALIZED VIEW + refresh do ranking.';

COMMIT;
