-- Deploy edumaps:escolas_scores_versao to pg
-- requires: escolas_scores_diversidade_esp
--
-- #462 (RX-01): a versão citável dos seis índices vai no comentário da MV.
-- Só o COMMENT muda; a MV não é recriada nem recalculada.
--
-- REGRA: change nova que mude a fórmula de clean.mv_escolas_scores sobe a
-- versão (indices-vN) aqui, no COMMENT, e em $INDICES_VERSAO /
-- @INDICES_HISTORICO de EduMaps::Model::Rank::School. O teste
-- backend/t/02-models/indices_versao.t falha se os dois divergirem.

BEGIN;

  COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS 'ÍNDICE CANÔNICO do produto (#137): 6 scores 0-10 das escolas ativas, derivados do Censo Escolar (quanto maior, melhor). VERSÃO indices-v2 (2026-11-16; indices-v1 = fórmula original, 2026-06-04; v2 = inclusão da diversidade pela educação especial em classe comum, #459). Mudança de fórmula sobe a versão aqui e em EduMaps::Model::Rank::School ($INDICES_VERSAO), #462. Consumido por analytics.ranking_escola (bin/ranking.pl), EduMaps::Model::Rank::School, SchoolEmbedding e View::ClusterEscola. Fórmula em docs/analises/ivet.md §2.2 (insumo do bloco A do IVET). Atualizar com REFRESH MATERIALIZED VIEW + refresh do ranking.';

COMMIT;
