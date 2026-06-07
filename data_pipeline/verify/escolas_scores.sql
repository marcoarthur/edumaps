-- Verify edumaps:escolas_scores on pg

BEGIN;

  -- 1. Verificar se a materialized view existe
  DO $$ 
  BEGIN
      ASSERT EXISTS (
          SELECT 1 FROM pg_matviews WHERE schemaname = 'clean' AND matviewname = 'mv_escolas_scores'
      ), 'ERRO: Materialized view clean.mv_escolas_scores não encontrada.';
  END $$;

  -- 2. Verificar colunas esperadas (presença e tipos)
  -- SELECT 
  --     column_name, 
  --     data_type 
  -- INTO TEMP tmp_columns
  -- FROM information_schema.columns 
  -- WHERE table_schema = 'clean' 
  --   AND table_name = 'mv_escolas_scores'
  -- ORDER BY ordinal_position;
  --
  -- -- Verificação: deve haver exatamente 9 colunas (ano, escola, 6 scores, atualização, mais? -> contagem)
  -- DO $$
  -- DECLARE
  --     col_count integer;
  -- BEGIN
  --     SELECT COUNT(*) INTO col_count FROM tmp_columns;
  --     -- Esperado: nu_ano_censo, co_entidade, score_capacidade_atendimento, score_infraestrutura,
  --     -- score_capacitacao_docente, score_diversidade_discente, score_capacidade_gestora,
  --     -- score_sustentabilidade, data_atualizacao → 9 colunas
  --     ASSERT col_count = 9, 'ERRO: Número de colunas inesperado (encontrado: ' || col_count || ', esperado: 9).';
  -- END $$;

  -- 3. Verificar se existem registros (pelo menos algum)
  DO $$
  DECLARE
      row_count integer;
  BEGIN
      SELECT COUNT(*) INTO row_count FROM clean.mv_escolas_scores;
      ASSERT row_count > 0, 'ERRO: A view materializada está vazia (nenhum registro).';
      RAISE NOTICE 'OK: % registros encontrados.', row_count;
  END $$;

  -- 4. Verificar se os scores estão no intervalo [0,10] (nenhum nulo, todos numéricos)
  -- DO $$
  -- DECLARE
  --     invalid_record record;
  -- BEGIN
  --     SELECT * INTO invalid_record
  --     FROM clean.mv_escolas_scores
  --     WHERE score_capacidade_atendimento < 0 OR score_capacidade_atendimento > 10
  --        OR score_infraestrutura < 0 OR score_infraestrutura > 10
  --        OR score_capacitacao_docente < 0 OR score_capacitacao_docente > 10
  --        OR score_diversidade_discente < 0 OR score_diversidade_discente > 10
  --        OR score_capacidade_gestora < 0 OR score_capacidade_gestora > 10
  --        OR score_sustentabilidade < 0 OR score_sustentabilidade > 10
  --     LIMIT 1;
  --
  --     IF FOUND THEN
  --         RAISE EXCEPTION 'ERRO: Score fora do intervalo [0,10] encontrado. Exemplo: (%)', invalid_record;
  --     END IF;
  -- END $$;

  -- 5. Verificar se não há valores nulos nos scores (devem ser 0 no pior caso)
  DO $$
  DECLARE
      null_count integer;
  BEGIN
      SELECT COUNT(*) INTO null_count
      FROM clean.mv_escolas_scores
      WHERE score_capacidade_atendimento IS NULL
         OR score_infraestrutura IS NULL
         OR score_capacitacao_docente IS NULL
         OR score_diversidade_discente IS NULL
         OR score_capacidade_gestora IS NULL
         OR score_sustentabilidade IS NULL;
      
      ASSERT null_count = 0, 'ERRO: Existem scores nulos (deveriam ser 0).';
  END $$;

  -- 6. Verificar consistência de chave primária (nu_ano_censo, co_entidade) – não deve haver duplicatas
  DO $$
  DECLARE
      duplicate_count integer;
  BEGIN
      SELECT COUNT(*) INTO duplicate_count
      FROM (
          SELECT nu_ano_censo, co_entidade, COUNT(*)
          FROM clean.mv_escolas_scores
          GROUP BY nu_ano_censo, co_entidade
          HAVING COUNT(*) > 1
      ) dup;
      ASSERT duplicate_count = 0, 'ERRO: Existem linhas duplicadas para o mesmo ano e escola.';
  END $$;

  -- 7. Verificar se todas as escolas existem na tabela clean.censo_escolas (escola ativa)
  DO $$
  DECLARE
      orphan_count integer;
  BEGIN
      SELECT COUNT(*) INTO orphan_count
      FROM clean.mv_escolas_scores s
      LEFT JOIN clean.censo_escolas e 
          ON s.co_entidade = e.co_entidade AND s.nu_ano_censo = e.nu_ano_censo
      WHERE e.co_entidade IS NULL;
      
      ASSERT orphan_count = 0, 'ERRO: Existem escolas nos scores que não estão em clean.censo_escolas (ou não ativas).';
  END $$;

  -- 8. (Opcional) Verificar se o campo data_atualizacao foi preenchido (não nulo)
  DO $$
  BEGIN
      IF EXISTS (SELECT 1 FROM clean.mv_escolas_scores WHERE data_atualizacao IS NULL) THEN
          RAISE EXCEPTION 'ERRO: data_atualizacao está nulo em alguns registros.';
      END IF;
  END $$;

  -- RAISE NOTICE 'Todas as verificações básicas foram bem-sucedidas.';

ROLLBACK;
