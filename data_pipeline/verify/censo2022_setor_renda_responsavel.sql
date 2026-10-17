-- Verify edumaps:censo2022_setor_renda_responsavel on pg
--
-- Gate estrutural (#160): só falha com ERRO (RAISE). Checa estrutura, nunca
-- volume — em base recém-deployada o censo pode estar vazio.
BEGIN;

DO $$
DECLARE
  v_cols integer;
  v_com  text;
BEGIN
  IF to_regclass('clean.censo2022_setor') IS NULL THEN
    RAISE EXCEPTION 'censo2022_setor_renda_responsavel: tabela ausente';
  END IF;

  -- 1. colunas de renda presentes
  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.censo2022_setor'::regclass
    AND attname IN ('rend_media', 'rend_mediana', 'rend_resp_count')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 3 THEN
    RAISE EXCEPTION 'censo2022_setor_renda_responsavel: colunas de renda (esperadas 3, encontradas %)', v_cols;
  END IF;

  -- 2. rend_media/rend_mediana são NUMERIC (têm decimais)
  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.censo2022_setor'::regclass
    AND attname IN ('rend_media', 'rend_mediana')
    AND atttypid = 'numeric'::regtype
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 2 THEN
    RAISE EXCEPTION 'censo2022_setor_renda_responsavel: rend_media/rend_mediana deveriam ser NUMERIC (encontradas %)', v_cols;
  END IF;

  -- 3. rend_media deixa de dizer "sem fonte"
  SELECT col_description('clean.censo2022_setor'::regclass, a.attnum) INTO v_com
  FROM pg_attribute a
  WHERE a.attrelid = 'clean.censo2022_setor'::regclass AND a.attname = 'rend_media'
    AND a.attnum > 0 AND NOT a.attisdropped;
  IF v_com IS NULL OR position('V06004' in v_com) = 0 THEN
    RAISE EXCEPTION 'censo2022_setor_renda_responsavel: COMMENT de rend_media deveria citar V06004, encontrado: %', v_com;
  END IF;

  -- 4. rend_per_capita segue sem fonte (o produto é do responsável)
  SELECT col_description('clean.censo2022_setor'::regclass, a.attnum) INTO v_com
  FROM pg_attribute a
  WHERE a.attrelid = 'clean.censo2022_setor'::regclass AND a.attname = 'rend_per_capita'
    AND a.attnum > 0 AND NOT a.attisdropped;
  IF v_com IS NULL OR position('Sem fonte' in v_com) = 0 THEN
    RAISE EXCEPTION 'censo2022_setor_renda_responsavel: rend_per_capita deveria seguir sem fonte, encontrado: %', v_com;
  END IF;
END;
$$;

COMMIT;
