-- Verify edumaps:renaest_depara_declaracao on pg

BEGIN;

-- =================================================================
-- REGRESSÃO #155 — o de-para RENAEST declara o que é, e o que não
-- resolve tem destino.
--
-- NOTA SOBRE O MECANISMO: o `sqitch verify` só considera a verificação
-- FALHADA quando o script produz um ERRO. Um `SELECT 1 FROM ...` que
-- devolve `f` passa como "ok" (testado contra Sqitch 1.6.1; é o defeito
-- dos verify antigos deste repositório). Por isso as asserções abaixo
-- são blocos `DO ... RAISE EXCEPTION`.
--
-- O que se testa:
--   1. a tabela das não resolvidas existe com o grão e o vocabulário;
--   2. um código classificado `codigo_fora_da_malha` não pode existir na
--      malha — a classificação e o dado não podem divergir;
--   3. o COMMENT do de-para não pode voltar a prometer "fuzzy matching"
--      nem "validação humana", que nunca ocorreram;
--   4. `match_type = 'manual'` exige `validated_at` — validação humana
--      que não tem quando foi feita não é validação.
-- =================================================================

DO $$
DECLARE
    c text;
    n integer;
BEGIN
    -- 1) Estrutura da tabela das não resolvidas
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean'
      AND table_name = 'renaest_localidade_nao_resolvida'
      AND column_name IN ('localidade', 'uf', 'codigo_ibge_fonte', 'motivo', 'dt_carga', 'dt_snapshot');
    IF n <> 6 THEN
        RAISE EXCEPTION
            'REGRESSÃO #155: clean.renaest_localidade_nao_resolvida tem % das 6 colunas esperadas.', n;
    END IF;

    -- 2) Vocabulário fechado de motivos
    IF EXISTS (
        SELECT 1 FROM clean.renaest_localidade_nao_resolvida
        WHERE motivo NOT IN ('codigo_fora_da_malha', 'codigo_sentinela', 'sem_nome_ou_uf')
    ) THEN
        RAISE EXCEPTION
            'REGRESSÃO #155: motivo fora do vocabulário em clean.renaest_localidade_nao_resolvida.';
    END IF;

    -- 3) Contrato: `codigo_fora_da_malha` só pode existir se o código NÃO estiver na malha
    SELECT count(*) INTO n
    FROM clean.renaest_localidade_nao_resolvida nr
    WHERE nr.motivo = 'codigo_fora_da_malha'
      AND EXISTS (
          SELECT 1 FROM clean.malha_municipio m
          WHERE m.codigo_ibge = nr.codigo_ibge_fonte);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #155: % localidade(s) classificada(s) como codigo_fora_da_malha cujo código EXISTE na malha.', n;
    END IF;

    -- 4) O COMMENT do de-para não pode voltar a prometer o que não faz
    c := obj_description('clean.renaest_localidade_municipio'::regclass);
    IF c IS NULL THEN
        RAISE EXCEPTION 'REGRESSÃO #155: COMMENT ON TABLE de clean.renaest_localidade_municipio ausente.';
    END IF;
    IF c ILIKE '%fuzzy matching%' OR c ILIKE '%validação humana%' THEN
        RAISE EXCEPTION
            'REGRESSÃO #155: o COMMENT do de-para promete construção por fuzzy matching/validação humana: %', c;
    END IF;

    -- 5) Validação humana declarada tem de ter data
    SELECT count(*) INTO n
    FROM clean.renaest_localidade_municipio
    WHERE match_type = 'manual' AND validated_at IS NULL;
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #155: % linha(s) com match_type = manual sem validated_at.', n;
    END IF;
END $$;

ROLLBACK;
