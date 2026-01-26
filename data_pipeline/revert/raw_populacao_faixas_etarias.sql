-- Revert edumaps:raw_populacao_faixas_etarias from pg

BEGIN;
  -- NOTA: Não removemos as colunas da tabela clean.populacao_municipal
  -- pois isso poderia quebrar dependências de outros sistemas.
  -- Em vez disso, apenas limpamos os dados temporários.
  
  -- Remover tabela temporária de importação
  DROP TABLE IF EXISTS raw.populacao_faixas_raw;
  
  -- Remover índices criados (opcional, se quiser limpar completamente)
  DROP INDEX IF EXISTS idx_populacao_faixa_0_4;
  DROP INDEX IF EXISTS idx_populacao_faixa_15_19;
  DROP INDEX IF EXISTS idx_populacao_faixa_60_64;
  DROP INDEX IF EXISTS idx_populacao_grupos;
  
  -- Log do revert
  RAISE NOTICE 'Revertido: raw_populacao_faixas_etarias. Tabela raw removida.';
  RAISE NOTICE 'NOTA: As colunas de faixa etária em clean.populacao_municipal NÃO foram removidas.';
  RAISE NOTICE 'Para removê-las manualmente, execute:';
  RAISE NOTICE 'ALTER TABLE clean.populacao_municipal DROP COLUMN faixa_0_4_anos, DROP COLUMN faixa_5_9_anos, ...';

COMMIT;
