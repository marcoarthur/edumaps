-- Verify edumaps:escola_entorno_socioeconomico to pg
--
-- Gate estrutural (#160): o verify só falha com ERRO (RAISE); SELECT que devolve
-- 0 linhas/false conta como sucesso no Sqitch 1.6.1. Checa estrutura, nunca
-- volume — em base recém-deployada o censo/setores podem estar vazios.
BEGIN;

DO $$
DECLARE
  v_cols integer;
BEGIN
  -- 1. tabela
  IF to_regclass('clean.escola_entorno_socioeconomico') IS NULL THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico: tabela ausente';
  END IF;

  -- 2. colunas esperadas
  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.escola_entorno_socioeconomico'::regclass
    AND attname IN ('co_entidade', 'nu_ano_censo', 'raio_m', 'n_setores',
                    'n_setores_suprimidos', 'area_influencia_km2',
                    'area_coberta_km2', 'cobertura_pct', 'pop_total',
                    'renda_per_capita', 'pct_sem_instrucao', 'pct_fund_incomp',
                    'pct_medio_mais', 'pct_preto_pardo', 'densidade_pop_km2',
                    'versao', 'computado_em')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 17 THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico: colunas (esperadas 17, encontradas %)', v_cols;
  END IF;

  -- 3. primary key
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_escola_entorno_socioeconomico' AND contype = 'p'
  ) THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico: PK ausente';
  END IF;

  -- 4. função de refresh
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'refresh_escola_entorno_socioeconomico'
      AND pronamespace = 'clean'::regnamespace
  ) THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico: função de refresh ausente';
  END IF;

  -- 5. guarda #154: a cobertura precisa existir como coluna (distinguir
  --    "sem extração" de "zero de vulnerabilidade").
  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'clean.escola_entorno_socioeconomico'::regclass
      AND attname = 'cobertura_pct' AND attnum > 0 AND NOT attisdropped
  ) THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico: coluna cobertura_pct ausente (#154)';
  END IF;
END;
$$;

COMMIT;
