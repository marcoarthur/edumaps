-- Revert edumaps:ideb_analytics from pg

BEGIN;

  -- Remove funções analíticas do INEP na ordem inversa de dependência
  DROP FUNCTION IF EXISTS clean.inep_estatisticas_municipio(VARCHAR);
  DROP FUNCTION IF EXISTS clean.inep_series_historicas_municipio(VARCHAR, INTEGER);
  DROP FUNCTION IF EXISTS clean.inep_notas_evolucao(BIGINT);
  DROP FUNCTION IF EXISTS clean.inep_despivotar_series_historicas(BIGINT);

COMMIT;
