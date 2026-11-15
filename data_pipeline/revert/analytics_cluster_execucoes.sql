-- Revert edumaps:analytics_cluster_execucoes from pg

BEGIN;
  DROP TABLE analytics.cluster_atribuicoes;
  DROP TABLE analytics.cluster_execucoes;
COMMIT;
