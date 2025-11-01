-- Deploy edumaps:raw_populacao to pg
-- requires: raw_municipios_sp

BEGIN;

  -- Criar tabela raw para importação do CSV
  DROP TABLE IF EXISTS raw.populacao_raw;
  CREATE TABLE raw.populacao_raw (
      linha_original        text,
      uf                    text,
      cod_uf                text,
      cod_mun               text,
      nome_municipio        text,
      populacao_estimada    text
  );

  -- Importar dados do CSV (caminho deve ser ajustado para o ambiente)
  COPY raw.populacao_raw
  FROM '/data/pop_2025_mun.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

  -- Log para debug: contar valores problemáticos
  DO $$
  DECLARE
    na_count integer;
    empty_count integer;
  BEGIN
    SELECT COUNT(*) INTO na_count FROM raw.populacao_raw WHERE populacao_estimada = 'NA';
    SELECT COUNT(*) INTO empty_count FROM raw.populacao_raw WHERE populacao_estimada = '' OR populacao_estimada IS NULL;
    
    RAISE NOTICE 'Encontrados % registros com valor "NA" em populacao_estimada', na_count;
    RAISE NOTICE 'Encontrados % registros com valor vazio/NULL em populacao_estimada', empty_count;
  END $$;

  -- Criar tabela limpa com dados tratados
  DROP TABLE IF EXISTS clean.populacao_municipal;
  CREATE TABLE clean.populacao_municipal AS
  SELECT
      linha_original::integer as linha_original,
      nome_municipio,
      -- Tratamento robusto para populacao_estimada
      CASE 
        WHEN populacao_estimada = 'NA' THEN NULL
        WHEN populacao_estimada = '' THEN NULL
        WHEN populacao_estimada IS NULL THEN NULL
        ELSE REPLACE(populacao_estimada, '.', '')::integer
      END as populacao_estimada,
      -- Criar código completo do município (UF + MUNIC) como varchar(7)
      (cod_uf || cod_mun)::varchar(7) as codigo_ibge
  FROM raw.populacao_raw;

  -- Log para debug: contar valores NULL resultantes
  DO $$
  DECLARE
    null_count integer;
    total_count integer;
  BEGIN
    SELECT COUNT(*) INTO null_count FROM clean.populacao_municipal WHERE populacao_estimada IS NULL;
    SELECT COUNT(*) INTO total_count FROM clean.populacao_municipal;
    
    RAISE NOTICE 'Total de registros processados: %, registros com população NULL: %', total_count, null_count;
  END $$;

  -- Adicionar constraints e índices
  ALTER TABLE clean.populacao_municipal 
      ADD CONSTRAINT pk_populacao_municipal PRIMARY KEY (codigo_ibge);

  CREATE INDEX ix_populacao_codigo_ibge ON clean.populacao_municipal (codigo_ibge);
  CREATE INDEX ix_populacao_nome ON clean.populacao_municipal (nome_municipio);

  -- Comentários para documentação
  COMMENT ON TABLE clean.populacao_municipal IS 'Dados limpos de população municipal estimada - Fonte: IBGE';
  COMMENT ON COLUMN clean.populacao_municipal.linha_original IS 'Número da linha original no CSV para auditoria';
  COMMENT ON COLUMN clean.populacao_municipal.codigo_ibge IS 'Código completo do município no padrão IBGE (UF + MUNIC) como varchar(7)';
  COMMENT ON COLUMN clean.populacao_municipal.nome_municipio IS 'Nome do município';
  COMMENT ON COLUMN clean.populacao_municipal.populacao_estimada IS 'População estimada do município (pode ser NULL para valores faltantes)';

COMMIT;
