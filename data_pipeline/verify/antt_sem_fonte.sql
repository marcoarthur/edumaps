-- Verify edumaps:antt_sem_fonte on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
DECLARE
  n integer;
BEGIN
  -- 1) as três tabelas sem fonte não existem mais
  IF to_regclass('clean.antt_trecho_geodados') IS NOT NULL
     OR to_regclass('clean.antt_contagem_equipamento') IS NOT NULL
     OR to_regclass('clean.antt_od_municipio') IS NOT NULL THEN
    RAISE EXCEPTION 'antt_sem_fonte: alguma das tabelas sem fonte da ANTT ainda existe';
  END IF;

  -- 2) fachada sobre a matview, com índice único (REFRESH CONCURRENTLY)
  IF NOT EXISTS (SELECT 1 FROM pg_matviews
                  WHERE schemaname = 'analytics' AND matviewname = 'mv_mobilidade_escola') THEN
    RAISE EXCEPTION 'antt_sem_fonte: falta analytics.mv_mobilidade_escola';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_views
                  WHERE schemaname = 'analytics' AND viewname = 'mobilidade_escola'
                    AND definition LIKE '%mv_mobilidade_escola%') THEN
    RAISE EXCEPTION 'antt_sem_fonte: analytics.mobilidade_escola não é a fachada da matview';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_indexes
                  WHERE schemaname = 'analytics' AND tablename = 'mv_mobilidade_escola'
                    AND indexdef LIKE 'CREATE UNIQUE INDEX%') THEN
    RAISE EXCEPTION 'antt_sem_fonte: mv_mobilidade_escola sem índice único';
  END IF;

  -- 3) contrato de colunas: nomes e ordem (28 = 31 da versão anterior − 3 da OD)
  SELECT count(*) INTO n FROM (
    SELECT attname::text, attnum::int FROM pg_attribute
     WHERE attrelid = 'analytics.mobilidade_escola'::regclass AND attnum > 0 AND NOT attisdropped
    EXCEPT
    SELECT * FROM (VALUES
      ('co_entidade', 1), ('no_entidade', 2), ('codigo_ibge', 3),
      ('municipio_escola', 4), ('uf_escola', 5), ('tp_dependencia', 6),
      ('tp_localizacao', 7), ('latitude', 8), ('longitude', 9), ('geom', 10),
      ('isocronas_por_tempo', 11),
      ('renavam_total_frota', 12), ('renavam_automoveis', 13),
      ('renavam_moto', 14), ('renavam_onibus', 15),
      ('vmda_total_municipio', 16), ('vmda_leve_municipio', 17),
      ('vmda_pesado_municipio', 18),
      ('acidentes_12m', 19), ('acidentes_fatais_12m', 20),
      ('sinistros_12m', 21), ('sinistros_fatais_12m', 22),
      ('recife_vagas_transporte', 23), ('recife_turno', 24),
      ('pct_acidentes_fatais', 25), ('pct_onibus_frota', 26),
      ('status_isocrona', 27), ('computed_at', 28)
    ) AS v(attname, attnum)
  ) diff;
  SELECT n + abs(count(*) - 28) INTO n FROM pg_attribute
   WHERE attrelid = 'analytics.mobilidade_escola'::regclass AND attnum > 0 AND NOT attisdropped;
  IF n > 0 THEN
    RAISE EXCEPTION 'antt_sem_fonte: colunas de analytics.mobilidade_escola fora do contrato (nome, ordem ou número)';
  END IF;

  -- 4) #154: sem acidente localizado, acidentes_12m é NULL (nunca 0)
  IF NOT EXISTS (SELECT 1 FROM clean.antt_acidente_trecho WHERE codigo_ibge IS NOT NULL) THEN
    SELECT count(*) INTO n FROM analytics.mv_mobilidade_escola
     WHERE acidentes_12m IS NOT NULL OR acidentes_fatais_12m IS NOT NULL;
    IF n > 0 THEN
      RAISE EXCEPTION 'REGRESSÃO #154: % escola(s) com acidentes_12m preenchido sem nenhum acidente localizado', n;
    END IF;
  END IF;
END
$$;

ROLLBACK;
