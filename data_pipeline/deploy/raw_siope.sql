-- Deploy edumaps:raw_siope to pg
-- requires: extensions

BEGIN;

  DROP TABLE IF EXISTS raw.remuneracao_siope_raw;
  CREATE TABLE raw.remuneracao_siope_raw (
      linha_original SERIAL PRIMARY KEY,
      dados JSONB NOT NULL
  );

  -- Importar dados do NDJSON usando COPY
  \copy raw.remuneracao_siope_raw (dados) FROM '/home/itaipu/Code/Data/siope/siope_validado.ndjson'

  -- Log da importação
  DO $$
  DECLARE
      total_registros INTEGER;
  BEGIN
      SELECT COUNT(*) INTO total_registros FROM raw.remuneracao_siope_raw;
      RAISE NOTICE 'Importados % registros do SIOPE', total_registros;
  END $$;

  -- Criar função para limpeza de valores numéricos
  CREATE OR REPLACE FUNCTION clean.to_numeric_safe(val TEXT)
  RETURNS NUMERIC
  LANGUAGE SQL
  IMMUTABLE
  AS $$
      SELECT 
          CASE 
              WHEN val IS NULL THEN NULL
              WHEN val = '' THEN NULL
              WHEN val = 'NA' THEN NULL
              WHEN val = 'ND' THEN NULL
              WHEN val = '-' THEN NULL
              WHEN TRIM(val) = '' THEN NULL
              ELSE NULLIF(REGEXP_REPLACE(REPLACE(val, ',', '.'), '[^0-9\.-]', '', 'g'), '')::NUMERIC
          END;
  $$;

  -- Criar função para limpeza de texto
  CREATE OR REPLACE FUNCTION clean.texto_limpo(val TEXT)
  RETURNS TEXT
  LANGUAGE SQL
  IMMUTABLE
  AS $$
      SELECT 
          CASE 
              WHEN val IS NULL THEN NULL
              WHEN TRIM(val) = '' THEN NULL
              WHEN val = 'NA' THEN NULL
              WHEN val = 'ND' THEN NULL
              WHEN val = '-' THEN NULL
              ELSE TRIM(val)
          END;
  $$;

  -- Criar tabela limpa
  DROP TABLE IF EXISTS clean.remuneracao_siope;
  CREATE TABLE clean.remuneracao_siope AS
  SELECT 
      linha_original,
      -- Dados básicos
      clean.texto_limpo(dados ->> 'TIPO') as tipo,
      clean.to_numeric_safe(dados ->> 'NU_PERIODO')::integer as nu_periodo,
      clean.texto_limpo(dados ->> 'SIG_UF') as sig_uf,
      clean.texto_limpo(dados ->> 'COD_MUNI') as cod_municipio,
      
      -- Dados do profissional
      clean.texto_limpo(dados ->> 'NO_PROFISSIONAL') as no_profissional,
      clean.texto_limpo(dados ->> 'CO_ESCOLA') as codigo_inep,
      clean.texto_limpo(dados ->> 'NO_RAZAO_SOCIAL') as no_razao_social,
      clean.texto_limpo(dados ->> 'DS_SITUACAO_PROFISSIONAL') as situacao_profissional,
      clean.texto_limpo(dados ->> 'TP_CATEGORIA') as tipo_categoria,
      
      -- Carga horária e valores
      clean.to_numeric_safe(dados ->> 'NU_CARGA_HORARIA')::integer as carga_horaria,
      clean.to_numeric_safe(dados ->> 'VL_SALARIO') as salario,
      clean.to_numeric_safe(dados ->> 'VL_MINIMO_FUNDEB') as valor_minimo_fundeb,
      clean.to_numeric_safe(dados ->> 'VL_MAXIMO_FUNDEB') as valor_maximo_fundeb,
      clean.to_numeric_safe(dados ->> 'VL_OUTROS') as valor_outros

  FROM raw.remuneracao_siope_raw;

  -- Remover registros com codigo_inep nulo ou inválido (chave primária)
  -- UPDATE clean.remuneracao_siope 
  -- SET codigo_inep = NULL
  -- WHERE TRIM(codigo_inep) = '' 
  --    OR codigo_inep = 'NA' 
  --    OR codigo_inep = 'ND';
  --
  ALTER TABLE clean.remuneracao_siope
      ALTER COLUMN codigo_inep TYPE bigint
      USING codigo_inep::bigint;

  -- Adicionar constraints
  ALTER TABLE clean.remuneracao_siope 
    ADD CONSTRAINT pk_remuneracao_siope PRIMARY KEY (linha_original);

  -- Criar índices para performance
  CREATE INDEX ix_siope_co_escola ON clean.remuneracao_siope (codigo_inep);
  CREATE INDEX ix_siope_cod_muni ON clean.remuneracao_siope (cod_municipio);
  CREATE INDEX ix_siope_tp_categoria ON clean.remuneracao_siope (tipo_categoria);

COMMIT;
