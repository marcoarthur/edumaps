-- Verify edumaps:censo2022_setor_instrucao_saneamento on pg
--
-- Gate estrutural (#160): o verify só falha com ERRO (RAISE); SELECT que devolve
-- 0 linhas/false conta como sucesso no Sqitch 1.6.1. Checa estrutura, nunca
-- volume — em base recém-deployada o censo pode estar vazio.
BEGIN;

DO $$
DECLARE
  v_cols integer;
BEGIN
  IF to_regclass('clean.censo2022_setor') IS NULL THEN
    RAISE EXCEPTION 'censo2022_setor_instrucao_saneamento: tabela ausente';
  END IF;

  SELECT count(*) INTO v_cols
  FROM pg_attribute
  WHERE attrelid = 'clean.censo2022_setor'::regclass
    AND attname IN ('alf_sabe_15mais', 'alf_nao_sabe_15mais',
                    'dom_agua_rede', 'dom_agua_poco_profundo', 'dom_agua_poco_raso',
                    'dom_agua_nascente', 'dom_agua_carro_pipa', 'dom_agua_chuva',
                    'dom_agua_rio', 'dom_agua_outra',
                    'dom_esgoto_rede', 'dom_esgoto_fossa_septica_rede',
                    'dom_esgoto_fossa_septica', 'dom_esgoto_fossa_rudimentar',
                    'dom_esgoto_vala', 'dom_esgoto_rio', 'dom_esgoto_outra',
                    'dom_esgoto_inexistente',
                    'dom_lixo_coletado', 'dom_lixo_cacamba', 'dom_lixo_queimado',
                    'dom_lixo_enterrado', 'dom_lixo_jogado', 'dom_lixo_outro',
                    'dom_banheiro_exclusivo', 'dom_sem_banheiro')
    AND attnum > 0 AND NOT attisdropped;
  IF v_cols <> 26 THEN
    RAISE EXCEPTION 'censo2022_setor_instrucao_saneamento: colunas (esperadas 26, encontradas %)', v_cols;
  END IF;
END;
$$;

COMMIT;
