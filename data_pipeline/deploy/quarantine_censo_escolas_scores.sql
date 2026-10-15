-- Deploy edumaps:quarantine_censo_escolas_scores to pg
-- requires: osm_mobilidade_completude
--
-- #137: quarentena dos índices escolares duplicados e declaração do canônico.
--
-- `clean.censo_escolas_scores` (view de `scores_view`) tem 11 scores e NENHUM
-- consumidor (só as classes DBIx) — nunca foi o índice do produto. O índice
-- canônico é `clean.mv_escolas_scores` (`escolas_scores`), consumido por
-- `analytics.ranking_escola`, `EduMaps::Model::Rank::School`,
-- `SchoolEmbedding` e `View::ClusterEscola`.
--
-- Fórmula, normalização e ordem: docs/analises/ivet.md (ivet-v1.0).

BEGIN;

COMMENT ON VIEW clean.censo_escolas_scores IS
'DEPRECATED (2026-10-15, #137): view de 11 scores SEM consumidor — nunca foi o índice do produto. NÃO usar em código novo. O índice canônico é clean.mv_escolas_scores (ver docs/analises/ivet.md, ivet-v1.0). Mantida como referência histórica até a remoção.';

COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS
'ÍNDICE CANÔNICO do produto (#137): 6 scores 0-10 das escolas ativas, derivados do Censo Escolar (quanto maior, melhor). Consumido por analytics.ranking_escola (bin/ranking.pl), EduMaps::Model::Rank::School, SchoolEmbedding e View::ClusterEscola. Fórmula, normalização e ordem em docs/analises/ivet.md (ivet-v1.0). Atualizar com REFRESH MATERIALIZED VIEW + refresh do ranking.';

COMMIT;
