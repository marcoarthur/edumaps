-- Verify edumaps:escola_entorno_socioeconomico_saneamento on pg
--
-- Gate estrutural (#160): o verify só falha com ERRO (RAISE); SELECT que devolve
-- 0 linhas/false conta como sucesso no Sqitch 1.6.1. Checa estrutura, nunca
-- volume — em base recém-deployada o censo/setores podem estar vazios.
BEGIN;

DO $$
DECLARE
  v_cols integer;
  v_def  text;
BEGIN
  IF to_regclass('clean.escola_entorno_socioeconomico') IS NULL THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_saneamento: tabela ausente';
  END IF;

  -- 1. colunas novas
  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.escola_entorno_socioeconomico'::regclass
    AND attname IN ('pct_analfabeto', 'pct_esgoto_inadequado', 'pct_agua_sem_rede',
                    'pct_lixo_inadequado', 'pct_sem_banheiro')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 5 THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_saneamento: colunas (esperadas 5, encontradas %)', v_cols;
  END IF;

  -- 2. função
  IF to_regprocedure('clean.refresh_escola_entorno_socioeconomico(integer[],bigint[])') IS NULL THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_saneamento: função ausente';
  END IF;

  -- 3. default da versão
  --    (a change escola_entorno_socioeconomico_renda, posterior no plano, sobe
  --    o default para ivet-v1.2; o verify roda contra o estado FINAL, por isso
  --    aqui se espera v1.2, o valor vigente com o bloco B completo.)
  SELECT pg_get_expr(d.adbin, d.adrelid) INTO v_def
  FROM pg_attrdef d
  JOIN pg_attribute a ON a.attrelid = d.adrelid AND a.attnum = d.adnum
  WHERE d.adrelid = 'clean.escola_entorno_socioeconomico'::regclass
    AND a.attname = 'versao';
  IF v_def IS NULL OR position('ivet-v1.2' in v_def) = 0 THEN
    RAISE EXCEPTION 'escola_entorno_socioeconomico_saneamento: versao default esperada ivet-v1.2 (v1.1 até a change da renda), encontrada %', v_def;
  END IF;
END;
$$;

COMMIT;
