-- Revert edumaps:column_descriptions from pg

BEGIN;

  COMMENT ON COLUMN analytics.school_embedding.co_entidade IS NULL;
  COMMENT ON COLUMN analytics.school_embedding.embedding   IS NULL;

  COMMENT ON COLUMN clean.event_store.id          IS NULL;
  COMMENT ON COLUMN clean.event_store.event_id    IS NULL;
  COMMENT ON COLUMN clean.event_store.event_type  IS NULL;
  COMMENT ON COLUMN clean.event_store.codigo_ibge IS NULL;
  COMMENT ON COLUMN clean.event_store.source      IS NULL;
  COMMENT ON COLUMN clean.event_store.payload     IS NULL;
  COMMENT ON COLUMN clean.event_store.created_at  IS NULL;

  COMMENT ON COLUMN clean.mv_escolas_scores.nu_ano_censo     IS NULL;
  COMMENT ON COLUMN clean.mv_escolas_scores.co_entidade      IS NULL;
  COMMENT ON COLUMN clean.mv_escolas_scores.data_atualizacao IS NULL;

  COMMENT ON COLUMN clean.censo_escolas.geometry   IS NULL;
  COMMENT ON COLUMN clean.censo_escolas.nro_etapas IS NULL;

  COMMENT ON COLUMN clean.school_indicators.geometry   IS NULL;
  COMMENT ON COLUMN clean.school_indicators.nro_etapas IS NULL;

  COMMENT ON COLUMN analytics.mv_rede_escolas.no_municipio              IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.sg_uf                     IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.no_regiao                 IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.codigo_rede               IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_infantil       IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental    IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_ai IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_af IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_medio          IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_profissional   IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_eja            IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_especial       IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_integral       IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_superior         IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_concursados      IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_fund_i               IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_medio                IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_fund_ii        IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_matematica_fund_ii   IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_portugues_fund_ii    IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_medio          IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.ano_ideb                  IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_docente        IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_escola         IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_superior    IS NULL;
  COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_concursados IS NULL;

  -- cluster_*: idem deploy (colunas de runtime). Limpar so se existirem.
  DO $do$
  DECLARE
    r record;
  BEGIN
    FOR r IN
      SELECT * FROM (VALUES
        ('clean', 'censo_escolas',     'cluster_id'),
        ('clean', 'school_indicators', 'cluster_id'),
        ('clean', 'school_indicators', 'cluster_label'),
        ('clean', 'school_indicators', 'cluster_rank')
      ) AS t(esquema, tabela, coluna)
    LOOP
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = r.esquema
          AND table_name   = r.tabela
          AND column_name  = r.coluna
      ) THEN
        EXECUTE format(
          'COMMENT ON COLUMN %I.%I.%I IS NULL',
          r.esquema, r.tabela, r.coluna
        );
      END IF;
    END LOOP;
  END
  $do$;

COMMIT;
