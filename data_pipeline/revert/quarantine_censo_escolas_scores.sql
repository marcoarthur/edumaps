-- Revert edumaps:quarantine_censo_escolas_scores from pg
--
-- Restaura os comentários anteriores: a view não tinha comentário; a MV tinha
-- o texto definido em `escolas_scores.sql`.

BEGIN;

COMMENT ON VIEW clean.censo_escolas_scores IS NULL;

COMMENT ON MATERIALIZED VIEW clean.mv_escolas_scores IS
'Scores das escolas ativas calculados a partir do Censo Escolar. Escala 0-10, quanto maior melhor. Atualizar com REFRESH MATERIALIZED VIEW.';

COMMIT;
