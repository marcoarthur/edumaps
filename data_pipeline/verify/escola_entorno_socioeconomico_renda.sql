-- Verify edumaps:escola_entorno_socioeconomico_renda on pg
--
-- Gate estrutural (#160): só falha com ERRO (RAISE). Checa estrutura, nunca
-- volume — em base recém-deployada o censo/setores podem estar vazios.
BEGIN;

DO $$
DECLARE
  v_cols integer;
  v_def  text;
BEGIN
  IF to_regclass('clean.escola_entorno_socioeconomico') IS NULL THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_renda: tabela ausente';
  END IF;

  -- 1. colunas de renda do responsável
  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.escola_entorno_socioeconomico'::regclass
    AND attname IN ('renda_resp_media', 'renda_resp_mediana')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 2 THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_renda: colunas (esperadas 2, encontradas %)', v_cols;
  END IF;

  -- 2. função
  IF to_regprocedure('clean.refresh_escola_entorno_socioeconomico(integer[],bigint[])') IS NULL THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_renda: função ausente';
  END IF;

  -- 3. default da versão
  SELECT pg_get_expr(d.adbin, d.adrelid) INTO v_def
  FROM pg_attrdef d
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid = 'clean.escola_entorno_socioeconomico'::regclass
    AND a.attname = 'versao';
  IF v_def IS NULL OR position('ivet-v1.2' in v_def) = 0 THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_renda: versao default esperada ivet-v1.2, encontrada %', v_def;
  END IF;
END;
$$;

COMMIT;
