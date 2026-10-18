-- Verify edumaps:mapbiomas_escola_risco on pg
--
-- Gate estrutural (#160): só falha com ERRO (RAISE).
BEGIN;

DO $$
DECLARE
  v_cols integer;
BEGIN
  IF to_regclass('clean.mapbiomas_escola_risco') IS NULL THEN
    RAISE EXCEPTION 'mapbiomas_escola_risco: tabela ausente';
  END IF;

  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.mapbiomas_escola_risco'::regclass
    AND attname IN ('co_entidade', 'nu_ano_censo', 'ano', 'raio_m',
                    'fogo_frequencia_media', 'fogo_frequencia_max',
                    'fogo_fracao_queimada', 'solo_carbono_medio', 'versao', 'computado_em')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 10 THEN
    RAISE EXCEPTION 'mapbiomas_escola_risco: colunas (esperadas 10, encontradas %)', v_cols;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_mapbiomas_escola_risco' AND contype = 'p'
      AND conrelid = 'clean.mapbiomas_escola_risco'::regclass
  ) THEN
    RAISE EXCEPTION 'mapbiomas_escola_risco: PK ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'mapbiomas_escola_risco_fracao_ck' AND contype = 'c'
      AND conrelid = 'clean.mapbiomas_escola_risco'::regclass
  ) THEN
    RAISE EXCEPTION 'mapbiomas_escola_risco: check de fração ausente (#154)';
  END IF;
END;
$$;

COMMIT;
