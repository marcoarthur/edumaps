-- Verify edumaps:mapbiomas_escola on pg
--
-- Gate estrutural (#160): o verify só falha com ERRO (RAISE); um SELECT que
-- devolve 0 linhas/false conta como sucesso no Sqitch 1.6.1. Checa estrutura,
-- nunca volume — num banco recém-deployado a arealização é legitimamente
-- VAZIA (quem a popula é o job MapBiomasEscola, #255).
BEGIN;

DO $$
DECLARE
  v_cols integer;
BEGIN
  IF to_regclass('clean.mapbiomas_escola') IS NULL THEN
    RAISE EXCEPTION 'mapbiomas_escola: tabela clean.mapbiomas_escola ausente';
  END IF;

  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.mapbiomas_escola'::regclass
    AND attname IN ('co_entidade', 'nu_ano_censo', 'ano', 'raio_m', 'classe',
                    'classe_desc', 'fracao', 'colecao', 'versao', 'computado_em')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 10 THEN
    RAISE EXCEPTION 'mapbiomas_escola: colunas (esperadas 10, encontradas %)', v_cols;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'pk_mapbiomas_escola' AND contype = 'p'
      AND conrelid = 'clean.mapbiomas_escola'::regclass
  ) THEN
    RAISE EXCEPTION 'mapbiomas_escola: PK pk_mapbiomas_escola ausente';
  END IF;

  -- Guarda #154: a fração precisa existir e ser restrita a [0,1] — é o que
  -- distingue "sem cobertura" (sem linha) de "zero de classe".
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'mapbiomas_escola_fracao_ck' AND contype = 'c'
      AND conrelid = 'clean.mapbiomas_escola'::regclass
  ) THEN
    RAISE EXCEPTION 'mapbiomas_escola: check de fração ausente (#154)';
  END IF;

  IF to_regclass('clean.v_mapbiomas_escola_grupos') IS NULL THEN
    RAISE EXCEPTION 'mapbiomas_escola: view clean.v_mapbiomas_escola_grupos ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'v_mapbiomas_escola_grupos'
      AND column_name = 'grupo'
  ) THEN
    RAISE EXCEPTION 'mapbiomas_escola: view de grupos sem a coluna grupo';
  END IF;
END;
$$;

COMMIT;
