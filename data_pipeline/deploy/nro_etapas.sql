-- Deploy edumaps:nro_etapas to pg
-- requires: censo_escolar_2025

BEGIN;

  -- Adiciona a coluna (caso ainda não exista)
  ALTER TABLE clean.censo_escolas ADD COLUMN IF NOT EXISTS nro_etapas integer;

  -- Atualiza com a contagem de etapas/modalidades oferecidas
  UPDATE clean.censo_escolas
  SET nro_etapas =
      -- Ensino regular (comum)
      (COALESCE(in_comum_creche, 0) = 1)::int
      + (COALESCE(in_comum_pre, 0) = 1)::int
      + (COALESCE(in_comum_fund_ai, 0) = 1)::int
      + (COALESCE(in_comum_fund_af, 0) = 1)::int
      + (COALESCE(in_comum_medio_medio, 0) = 1)::int
      + (COALESCE(in_comum_medio_integrado, 0) = 1)::int
      + (COALESCE(in_comum_medio_fic, 0) = 1)::int
      + (COALESCE(in_comum_medio_normal, 0) = 1)::int
      + (COALESCE(in_comum_eja_fund, 0) = 1)::int
      + (COALESCE(in_comum_eja_medio, 0) = 1)::int
      + (COALESCE(in_comum_eja_prof, 0) = 1)::int
      + (COALESCE(in_comum_prof, 0) = 1)::int
      -- Educação especial exclusiva
      + (COALESCE(in_esp_exclusiva_creche, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_pre, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_fund_ai, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_fund_af, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_medio_medio, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_medio_integr, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_medio_fic, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_medio_normal, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_eja_fund, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_eja_medio, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_eja_prof, 0) = 1)::int
      + (COALESCE(in_esp_exclusiva_prof, 0) = 1)::int;
COMMIT;
