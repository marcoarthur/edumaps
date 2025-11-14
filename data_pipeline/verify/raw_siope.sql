-- Verify edumaps:raw_siope on pg

BEGIN;

  -- Verificar se as tabelas foram criadas
  SELECT 1/count(*) FROM information_schema.tables 
  WHERE table_schema = 'clean' AND table_name = 'remuneracao_municipal';

  -- Verificar colunas e nomes
  SELECT 
      COUNT(*) = 18 as colunas_semanticas_criadas,
      COUNT(*) FILTER (WHERE column_name = 'cod_municipio') = 1 as tem_codigo_municipio,
      COUNT(*) FILTER (WHERE column_name = 'nome_profissional') = 1 as tem_nome_prof,
      COUNT(*) FILTER (WHERE column_name = 'salario_base') = 1 as tem_salario_base
  FROM information_schema.columns 
  WHERE table_schema = 'clean' AND table_name = 'remuneracao_municipal';

ROLLBACK;
