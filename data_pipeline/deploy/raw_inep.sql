-- Deploy edumaps:raw_inep to pg
-- requires: raw_municipios_sp
-- requires: raw_escolas
BEGIN;
  -- Criar tabela raw para importação do CSV do INEP
  DROP TABLE IF EXISTS raw.inep_raw;
  CREATE TABLE raw.inep_raw (
      -- Estrutura mantida igual ao seu script
      linha_original        text,
      sg_uf                 text,
      co_municipio          text,
      no_municipio          text,
      id_escola             text,
      no_escola             text,
      rede                  text,
      -- Approval rates 2005-2023 (odd years)
      vl_aprovacao_2005_si_4 text,
      vl_aprovacao_2005_si   text,
      vl_aprovacao_2005_1    text,
      vl_aprovacao_2005_2    text,
      vl_aprovacao_2005_3    text,
      vl_aprovacao_2005_4    text,
      vl_indicador_rend_2005 text,
      -- 2007
      vl_aprovacao_2007_si_4 text,
      vl_aprovacao_2007_si   text,
      vl_aprovacao_2007_1    text,
      vl_aprovacao_2007_2    text,
      vl_aprovacao_2007_3    text,
      vl_aprovacao_2007_4    text,
      vl_indicador_rend_2007 text,
      -- 2009
      vl_aprovacao_2009_si_4 text,
      vl_aprovacao_2009_si   text,
      vl_aprovacao_2009_1    text,
      vl_aprovacao_2009_2    text,
      vl_aprovacao_2009_3    text,
      vl_aprovacao_2009_4    text,
      vl_indicador_rend_2009 text,
      -- 2011
      vl_aprovacao_2011_si_4 text,
      vl_aprovacao_2011_si   text,
      vl_aprovacao_2011_1    text,
      vl_aprovacao_2011_2    text,
      vl_aprovacao_2011_3    text,
      vl_aprovacao_2011_4    text,
      vl_indicador_rend_2011 text,
      -- 2013
      vl_aprovacao_2013_si_4 text,
      vl_aprovacao_2013_si   text,
      vl_aprovacao_2013_1    text,
      vl_aprovacao_2013_2    text,
      vl_aprovacao_2013_3    text,
      vl_aprovacao_2013_4    text,
      vl_indicador_rend_2013 text,
      -- 2015
      vl_aprovacao_2015_si_4 text,
      vl_aprovacao_2015_si   text,
      vl_aprovacao_2015_1    text,
      vl_aprovacao_2015_2    text,
      vl_aprovacao_2015_3    text,
      vl_aprovacao_2015_4    text,
      vl_indicador_rend_2015 text,
      -- 2017
      vl_aprovacao_2017_si_4 text,
      vl_aprovacao_2017_si   text,
      vl_aprovacao_2017_1    text,
      vl_aprovacao_2017_2    text,
      vl_aprovacao_2017_3    text,
      vl_aprovacao_2017_4    text,
      vl_indicador_rend_2017 text,
      -- 2019
      vl_aprovacao_2019_si_4 text,
      vl_aprovacao_2019_si   text,
      vl_aprovacao_2019_1    text,
      vl_aprovacao_2019_2    text,
      vl_aprovacao_2019_3    text,
      vl_aprovacao_2019_4    text,
      vl_indicador_rend_2019 text,
      -- 2021
      vl_aprovacao_2021_si_4 text,
      vl_aprovacao_2021_si   text,
      vl_aprovacao_2021_1    text,
      vl_aprovacao_2021_2    text,
      vl_aprovacao_2021_3    text,
      vl_aprovacao_2021_4    text,
      vl_indicador_rend_2021 text,
      -- 2023
      vl_aprovacao_2023_si_4 text,
      vl_aprovacao_2023_si   text,
      vl_aprovacao_2023_1    text,
      vl_aprovacao_2023_2    text,
      vl_aprovacao_2023_3    text,
      vl_aprovacao_2023_4    text,
      vl_indicador_rend_2023 text,
      -- Test scores 2005-2023
      vl_nota_matematica_2005 text,
      vl_nota_portugues_2005  text,
      vl_nota_media_2005      text,
      vl_nota_matematica_2007 text,
      vl_nota_portugues_2007  text,
      vl_nota_media_2007      text,
      vl_nota_matematica_2009 text,
      vl_nota_portugues_2009  text,
      vl_nota_media_2009      text,
      vl_nota_matematica_2011 text,
      vl_nota_portugues_2011  text,
      vl_nota_media_2011      text,
      vl_nota_matematica_2013 text,
      vl_nota_portugues_2013  text,
      vl_nota_media_2013      text,
      vl_nota_matematica_2015 text,
      vl_nota_portugues_2015  text,
      vl_nota_media_2015      text,
      vl_nota_matematica_2017 text,
      vl_nota_portugues_2017  text,
      vl_nota_media_2017      text,
      vl_nota_matematica_2019 text,
      vl_nota_portugues_2019  text,
      vl_nota_media_2019      text,
      vl_nota_matematica_2021 text,
      vl_nota_portugues_2021  text,
      vl_nota_media_2021      text,
      vl_nota_matematica_2023 text,
      vl_nota_portugues_2023  text,
      vl_nota_media_2023      text,
      -- Observado e projeção
      vl_observado_2005 text,
      vl_observado_2007 text,
      vl_observado_2009 text,
      vl_observado_2011 text,
      vl_observado_2013 text,
      vl_observado_2015 text,
      vl_observado_2017 text,
      vl_observado_2019 text,
      vl_observado_2021 text,
      vl_observado_2023 text,
      vl_projecao_2007  text,
      vl_projecao_2009  text,
      vl_projecao_2011  text,
      vl_projecao_2013  text,
      vl_projecao_2015  text,
      vl_projecao_2017  text,
      vl_projecao_2019  text,
      vl_projecao_2021  text
  );

  -- Importar dados do CSV
  COPY raw.inep_raw (
      sg_uf, co_municipio, no_municipio, id_escola, no_escola, rede,
      vl_aprovacao_2005_si_4, vl_aprovacao_2005_si, vl_aprovacao_2005_1, vl_aprovacao_2005_2, vl_aprovacao_2005_3, vl_aprovacao_2005_4, vl_indicador_rend_2005,
      vl_aprovacao_2007_si_4, vl_aprovacao_2007_si, vl_aprovacao_2007_1, vl_aprovacao_2007_2, vl_aprovacao_2007_3, vl_aprovacao_2007_4, vl_indicador_rend_2007,
      vl_aprovacao_2009_si_4, vl_aprovacao_2009_si, vl_aprovacao_2009_1, vl_aprovacao_2009_2, vl_aprovacao_2009_3, vl_aprovacao_2009_4, vl_indicador_rend_2009,
      vl_aprovacao_2011_si_4, vl_aprovacao_2011_si, vl_aprovacao_2011_1, vl_aprovacao_2011_2, vl_aprovacao_2011_3, vl_aprovacao_2011_4, vl_indicador_rend_2011,
      vl_aprovacao_2013_si_4, vl_aprovacao_2013_si, vl_aprovacao_2013_1, vl_aprovacao_2013_2, vl_aprovacao_2013_3, vl_aprovacao_2013_4, vl_indicador_rend_2013,
      vl_aprovacao_2015_si_4, vl_aprovacao_2015_si, vl_aprovacao_2015_1, vl_aprovacao_2015_2, vl_aprovacao_2015_3, vl_aprovacao_2015_4, vl_indicador_rend_2015,
      vl_aprovacao_2017_si_4, vl_aprovacao_2017_si, vl_aprovacao_2017_1, vl_aprovacao_2017_2, vl_aprovacao_2017_3, vl_aprovacao_2017_4, vl_indicador_rend_2017,
      vl_aprovacao_2019_si_4, vl_aprovacao_2019_si, vl_aprovacao_2019_1, vl_aprovacao_2019_2, vl_aprovacao_2019_3, vl_aprovacao_2019_4, vl_indicador_rend_2019,
      vl_aprovacao_2021_si_4, vl_aprovacao_2021_si, vl_aprovacao_2021_1, vl_aprovacao_2021_2, vl_aprovacao_2021_3, vl_aprovacao_2021_4, vl_indicador_rend_2021,
      vl_aprovacao_2023_si_4, vl_aprovacao_2023_si, vl_aprovacao_2023_1, vl_aprovacao_2023_2, vl_aprovacao_2023_3, vl_aprovacao_2023_4, vl_indicador_rend_2023,
      vl_nota_matematica_2005, vl_nota_portugues_2005, vl_nota_media_2005,
      vl_nota_matematica_2007, vl_nota_portugues_2007, vl_nota_media_2007,
      vl_nota_matematica_2009, vl_nota_portugues_2009, vl_nota_media_2009,
      vl_nota_matematica_2011, vl_nota_portugues_2011, vl_nota_media_2011,
      vl_nota_matematica_2013, vl_nota_portugues_2013, vl_nota_media_2013,
      vl_nota_matematica_2015, vl_nota_portugues_2015, vl_nota_media_2015,
      vl_nota_matematica_2017, vl_nota_portugues_2017, vl_nota_media_2017,
      vl_nota_matematica_2019, vl_nota_portugues_2019, vl_nota_media_2019,
      vl_nota_matematica_2021, vl_nota_portugues_2021, vl_nota_media_2021,
      vl_nota_matematica_2023, vl_nota_portugues_2023, vl_nota_media_2023,
      vl_observado_2005, vl_observado_2007, vl_observado_2009, vl_observado_2011, vl_observado_2013, vl_observado_2015, vl_observado_2017, vl_observado_2019, vl_observado_2021, vl_observado_2023,
      vl_projecao_2007, vl_projecao_2009, vl_projecao_2011, vl_projecao_2013, vl_projecao_2015, vl_projecao_2017, vl_projecao_2019, vl_projecao_2021
  )
  FROM '/data/inep.csv'
  WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

  -- Adicionar linha_original com número da linha
  WITH numbered AS (
    SELECT ctid, row_number() OVER () as linha
    FROM raw.inep_raw
  )
  UPDATE raw.inep_raw 
  SET linha_original = numbered.linha::text
  FROM numbered 
  WHERE raw.inep_raw.ctid = numbered.ctid;

  -- Log para debug da importação raw
  DO $$
  DECLARE
    total_count integer;
    null_count integer;
  BEGIN
    SELECT COUNT(*) INTO total_count FROM raw.inep_raw;
    SELECT COUNT(*) INTO null_count FROM raw.inep_raw WHERE vl_nota_media_2023 = '-' OR vl_nota_media_2023 = 'ND';
    
    RAISE NOTICE 'Importados % registros do INEP', total_count;
    RAISE NOTICE 'Registros com nota média 2023 faltante: %', null_count;
  END $$;

  -- ===========================================================================
  -- LIMPEZA DOS DADOS - Schema CLEAN
  -- ===========================================================================

  -- Criar função helper para tratamento de valores NULL
  CREATE OR REPLACE FUNCTION clean.null_if_invalid(val TEXT)
  RETURNS TEXT
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
        ELSE val
      END;
  $$;

  -- Criar função para converter para numeric com tratamento robusto
  CREATE OR REPLACE FUNCTION clean.to_numeric_safe(val TEXT)
  RETURNS NUMERIC
  LANGUAGE SQL
  IMMUTABLE
  AS $$
    SELECT 
      CASE 
        WHEN clean.null_if_invalid(val) IS NULL THEN NULL
        
        -- Aplica a limpeza regex e verifica se resultou em string vazia
        ELSE 
          CASE 
            -- Remove tudo que não é número, ponto decimal ou sinal negativo
            -- Converte vírgula para ponto antes da limpeza
            WHEN NULLIF(
                  REGEXP_REPLACE(
                    REPLACE(clean.null_if_invalid(val), ',', '.'),
                    '[^0-9\.]', '', 'g'
                  ),
                  ''
                ) IS NULL THEN NULL  -- Se resultou em string vazia, retorna NULL
            ELSE 
              REGEXP_REPLACE(
                REPLACE(clean.null_if_invalid(val), ',', '.'),
                '[^0-9\.]', '', 'g'
              )::NUMERIC
          END
      END;
  $$;

  -- Criar tabela limpa com dados tratados
  DROP TABLE IF EXISTS clean.inep;
  CREATE TABLE clean.inep AS
  SELECT
      linha_original::integer as linha_original,
      sg_uf,
      co_municipio::varchar(7) as codigo_ibge,
      no_municipio,
      id_escola,
      no_escola,
      rede,
      
      -- Aprovações 2005
      clean.to_numeric_safe(vl_aprovacao_2005_si_4) as vl_aprovacao_2005_si_4,
      clean.to_numeric_safe(vl_aprovacao_2005_si) as vl_aprovacao_2005_si,
      clean.to_numeric_safe(vl_aprovacao_2005_1) as vl_aprovacao_2005_1,
      clean.to_numeric_safe(vl_aprovacao_2005_2) as vl_aprovacao_2005_2,
      clean.to_numeric_safe(vl_aprovacao_2005_3) as vl_aprovacao_2005_3,
      clean.to_numeric_safe(vl_aprovacao_2005_4) as vl_aprovacao_2005_4,
      clean.to_numeric_safe(vl_indicador_rend_2005) as vl_indicador_rend_2005,

      -- Aprovações 2007
      clean.to_numeric_safe(vl_aprovacao_2007_si_4) as vl_aprovacao_2007_si_4,
      clean.to_numeric_safe(vl_aprovacao_2007_si) as vl_aprovacao_2007_si,
      clean.to_numeric_safe(vl_aprovacao_2007_1) as vl_aprovacao_2007_1,
      clean.to_numeric_safe(vl_aprovacao_2007_2) as vl_aprovacao_2007_2,
      clean.to_numeric_safe(vl_aprovacao_2007_3) as vl_aprovacao_2007_3,
      clean.to_numeric_safe(vl_aprovacao_2007_4) as vl_aprovacao_2007_4,
      clean.to_numeric_safe(vl_indicador_rend_2007) as vl_indicador_rend_2007,

      -- Aprovações 2009
      clean.to_numeric_safe(vl_aprovacao_2009_si_4) as vl_aprovacao_2009_si_4,
      clean.to_numeric_safe(vl_aprovacao_2009_si) as vl_aprovacao_2009_si,
      clean.to_numeric_safe(vl_aprovacao_2009_1) as vl_aprovacao_2009_1,
      clean.to_numeric_safe(vl_aprovacao_2009_2) as vl_aprovacao_2009_2,
      clean.to_numeric_safe(vl_aprovacao_2009_3) as vl_aprovacao_2009_3,
      clean.to_numeric_safe(vl_aprovacao_2009_4) as vl_aprovacao_2009_4,
      clean.to_numeric_safe(vl_indicador_rend_2009) as vl_indicador_rend_2009,

      -- Aprovações 2011
      clean.to_numeric_safe(vl_aprovacao_2011_si_4) as vl_aprovacao_2011_si_4,
      clean.to_numeric_safe(vl_aprovacao_2011_si) as vl_aprovacao_2011_si,
      clean.to_numeric_safe(vl_aprovacao_2011_1) as vl_aprovacao_2011_1,
      clean.to_numeric_safe(vl_aprovacao_2011_2) as vl_aprovacao_2011_2,
      clean.to_numeric_safe(vl_aprovacao_2011_3) as vl_aprovacao_2011_3,
      clean.to_numeric_safe(vl_aprovacao_2011_4) as vl_aprovacao_2011_4,
      clean.to_numeric_safe(vl_indicador_rend_2011) as vl_indicador_rend_2011,

      -- Aprovações 2013
      clean.to_numeric_safe(vl_aprovacao_2013_si_4) as vl_aprovacao_2013_si_4,
      clean.to_numeric_safe(vl_aprovacao_2013_si) as vl_aprovacao_2013_si,
      clean.to_numeric_safe(vl_aprovacao_2013_1) as vl_aprovacao_2013_1,
      clean.to_numeric_safe(vl_aprovacao_2013_2) as vl_aprovacao_2013_2,
      clean.to_numeric_safe(vl_aprovacao_2013_3) as vl_aprovacao_2013_3,
      clean.to_numeric_safe(vl_aprovacao_2013_4) as vl_aprovacao_2013_4,
      clean.to_numeric_safe(vl_indicador_rend_2013) as vl_indicador_rend_2013,

      -- Aprovações 2015
      clean.to_numeric_safe(vl_aprovacao_2015_si_4) as vl_aprovacao_2015_si_4,
      clean.to_numeric_safe(vl_aprovacao_2015_si) as vl_aprovacao_2015_si,
      clean.to_numeric_safe(vl_aprovacao_2015_1) as vl_aprovacao_2015_1,
      clean.to_numeric_safe(vl_aprovacao_2015_2) as vl_aprovacao_2015_2,
      clean.to_numeric_safe(vl_aprovacao_2015_3) as vl_aprovacao_2015_3,
      clean.to_numeric_safe(vl_aprovacao_2015_4) as vl_aprovacao_2015_4,
      clean.to_numeric_safe(vl_indicador_rend_2015) as vl_indicador_rend_2015,

      -- Aprovações 2017
      clean.to_numeric_safe(vl_aprovacao_2017_si_4) as vl_aprovacao_2017_si_4,
      clean.to_numeric_safe(vl_aprovacao_2017_si) as vl_aprovacao_2017_si,
      clean.to_numeric_safe(vl_aprovacao_2017_1) as vl_aprovacao_2017_1,
      clean.to_numeric_safe(vl_aprovacao_2017_2) as vl_aprovacao_2017_2,
      clean.to_numeric_safe(vl_aprovacao_2017_3) as vl_aprovacao_2017_3,
      clean.to_numeric_safe(vl_aprovacao_2017_4) as vl_aprovacao_2017_4,
      clean.to_numeric_safe(vl_indicador_rend_2017) as vl_indicador_rend_2017,

      -- Aprovações 2019
      clean.to_numeric_safe(vl_aprovacao_2019_si_4) as vl_aprovacao_2019_si_4,
      clean.to_numeric_safe(vl_aprovacao_2019_si) as vl_aprovacao_2019_si,
      clean.to_numeric_safe(vl_aprovacao_2019_1) as vl_aprovacao_2019_1,
      clean.to_numeric_safe(vl_aprovacao_2019_2) as vl_aprovacao_2019_2,
      clean.to_numeric_safe(vl_aprovacao_2019_3) as vl_aprovacao_2019_3,
      clean.to_numeric_safe(vl_aprovacao_2019_4) as vl_aprovacao_2019_4,
      clean.to_numeric_safe(vl_indicador_rend_2019) as vl_indicador_rend_2019,

      -- Aprovações 2021
      clean.to_numeric_safe(vl_aprovacao_2021_si_4) as vl_aprovacao_2021_si_4,
      clean.to_numeric_safe(vl_aprovacao_2021_si) as vl_aprovacao_2021_si,
      clean.to_numeric_safe(vl_aprovacao_2021_1) as vl_aprovacao_2021_1,
      clean.to_numeric_safe(vl_aprovacao_2021_2) as vl_aprovacao_2021_2,
      clean.to_numeric_safe(vl_aprovacao_2021_3) as vl_aprovacao_2021_3,
      clean.to_numeric_safe(vl_aprovacao_2021_4) as vl_aprovacao_2021_4,
      clean.to_numeric_safe(vl_indicador_rend_2021) as vl_indicador_rend_2021,

      -- Aprovações 2023
      clean.to_numeric_safe(vl_aprovacao_2023_si_4) as vl_aprovacao_2023_si_4,
      clean.to_numeric_safe(vl_aprovacao_2023_si) as vl_aprovacao_2023_si,
      clean.to_numeric_safe(vl_aprovacao_2023_1) as vl_aprovacao_2023_1,
      clean.to_numeric_safe(vl_aprovacao_2023_2) as vl_aprovacao_2023_2,
      clean.to_numeric_safe(vl_aprovacao_2023_3) as vl_aprovacao_2023_3,
      clean.to_numeric_safe(vl_aprovacao_2023_4) as vl_aprovacao_2023_4,
      clean.to_numeric_safe(vl_indicador_rend_2023) as vl_indicador_rend_2023,

      -- Notas 2005
      clean.to_numeric_safe(vl_nota_matematica_2005) as vl_nota_matematica_2005,
      clean.to_numeric_safe(vl_nota_portugues_2005) as vl_nota_portugues_2005,
      clean.to_numeric_safe(vl_nota_media_2005) as vl_nota_media_2005,

      -- Notas 2007
      clean.to_numeric_safe(vl_nota_matematica_2007) as vl_nota_matematica_2007,
      clean.to_numeric_safe(vl_nota_portugues_2007) as vl_nota_portugues_2007,
      clean.to_numeric_safe(vl_nota_media_2007) as vl_nota_media_2007,

      -- Notas 2009
      clean.to_numeric_safe(vl_nota_matematica_2009) as vl_nota_matematica_2009,
      clean.to_numeric_safe(vl_nota_portugues_2009) as vl_nota_portugues_2009,
      clean.to_numeric_safe(vl_nota_media_2009) as vl_nota_media_2009,

      -- Notas 2011
      clean.to_numeric_safe(vl_nota_matematica_2011) as vl_nota_matematica_2011,
      clean.to_numeric_safe(vl_nota_portugues_2011) as vl_nota_portugues_2011,
      clean.to_numeric_safe(vl_nota_media_2011) as vl_nota_media_2011,

      -- Notas 2013
      clean.to_numeric_safe(vl_nota_matematica_2013) as vl_nota_matematica_2013,
      clean.to_numeric_safe(vl_nota_portugues_2013) as vl_nota_portugues_2013,
      clean.to_numeric_safe(vl_nota_media_2013) as vl_nota_media_2013,

      -- Notas 2015
      clean.to_numeric_safe(vl_nota_matematica_2015) as vl_nota_matematica_2015,
      clean.to_numeric_safe(vl_nota_portugues_2015) as vl_nota_portugues_2015,
      clean.to_numeric_safe(vl_nota_media_2015) as vl_nota_media_2015,

      -- Notas 2017
      clean.to_numeric_safe(vl_nota_matematica_2017) as vl_nota_matematica_2017,
      clean.to_numeric_safe(vl_nota_portugues_2017) as vl_nota_portugues_2017,
      clean.to_numeric_safe(vl_nota_media_2017) as vl_nota_media_2017,

      -- Notas 2019
      clean.to_numeric_safe(vl_nota_matematica_2019) as vl_nota_matematica_2019,
      clean.to_numeric_safe(vl_nota_portugues_2019) as vl_nota_portugues_2019,
      clean.to_numeric_safe(vl_nota_media_2019) as vl_nota_media_2019,

      -- Notas 2021
      clean.to_numeric_safe(vl_nota_matematica_2021) as vl_nota_matematica_2021,
      clean.to_numeric_safe(vl_nota_portugues_2021) as vl_nota_portugues_2021,
      clean.to_numeric_safe(vl_nota_media_2021) as vl_nota_media_2021,

      -- Notas 2023
      clean.to_numeric_safe(vl_nota_matematica_2023) as vl_nota_matematica_2023,
      clean.to_numeric_safe(vl_nota_portugues_2023) as vl_nota_portugues_2023,
      clean.to_numeric_safe(vl_nota_media_2023) as vl_nota_media_2023,

      -- Observado
      clean.to_numeric_safe(vl_observado_2005) as vl_observado_2005,
      clean.to_numeric_safe(vl_observado_2007) as vl_observado_2007,
      clean.to_numeric_safe(vl_observado_2009) as vl_observado_2009,
      clean.to_numeric_safe(vl_observado_2011) as vl_observado_2011,
      clean.to_numeric_safe(vl_observado_2013) as vl_observado_2013,
      clean.to_numeric_safe(vl_observado_2015) as vl_observado_2015,
      clean.to_numeric_safe(vl_observado_2017) as vl_observado_2017,
      clean.to_numeric_safe(vl_observado_2019) as vl_observado_2019,
      clean.to_numeric_safe(vl_observado_2021) as vl_observado_2021,
      clean.to_numeric_safe(vl_observado_2023) as vl_observado_2023,

      -- Projeção
      clean.to_numeric_safe(vl_projecao_2007) as vl_projecao_2007,
      clean.to_numeric_safe(vl_projecao_2009) as vl_projecao_2009,
      clean.to_numeric_safe(vl_projecao_2011) as vl_projecao_2011,
      clean.to_numeric_safe(vl_projecao_2013) as vl_projecao_2013,
      clean.to_numeric_safe(vl_projecao_2015) as vl_projecao_2015,
      clean.to_numeric_safe(vl_projecao_2017) as vl_projecao_2017,
      clean.to_numeric_safe(vl_projecao_2019) as vl_projecao_2019,
      clean.to_numeric_safe(vl_projecao_2021) as vl_projecao_2021
      
  FROM raw.inep_raw;

  -- ===========================================================================
  -- CORREÇÃO: GARANTIR CHAVE PRIMÁRIA E REMOVER REGISTROS COM id_escola NULL
  -- ===========================================================================
  
  -- Log antes da correção
  DO $$
    DECLARE
      total_before integer;
      null_ids integer;
    BEGIN
      SELECT COUNT(*) INTO total_before FROM clean.inep;
      SELECT COUNT(*) INTO null_ids FROM clean.inep WHERE id_escola IS NULL OR TRIM(id_escola) = '';
      
      RAISE NOTICE 'Registros antes da correção: %', total_before;
      RAISE NOTICE 'Registros com id_escola NULL ou vazio: %', null_ids;
    END 
  $$;

  -- Remover registros onde id_escola é NULL, vazio ou inválido
  DELETE FROM clean.inep 
  WHERE id_escola IS NULL 
     OR TRIM(id_escola) = '' 
     OR id_escola = 'NA' 
     OR id_escola = 'ND' 
     OR id_escola = '-';

  -- Verificar se há duplicatas de id_escola
  DO $$
    DECLARE
      duplicate_count integer;
    BEGIN
      SELECT COUNT(*) INTO duplicate_count
      FROM (
        SELECT id_escola, COUNT(*)
        FROM clean.inep
        WHERE id_escola IS NOT NULL
        GROUP BY id_escola
        HAVING COUNT(*) > 1
      ) AS duplicates;
      
      IF duplicate_count > 0 THEN
        RAISE WARNING 'Encontrados % id_escola duplicados. Criando chave primária composta.', duplicate_count;
        
        -- Adicionar chave primária composta com linha_original para garantir unicidade
        ALTER TABLE clean.inep 
        ADD CONSTRAINT pk_inep PRIMARY KEY (id_escola, linha_original);
        
      ELSE
        RAISE NOTICE 'Nenhuma duplicata encontrada em id_escola. Adicionando chave primária simples.';
        
        -- Adicionar chave primária simples
        ALTER TABLE clean.inep 
        ADD CONSTRAINT pk_inep PRIMARY KEY (id_escola);
      END IF;
    END 
  $$;


  -- Log para debug da limpeza
  DO $$
    DECLARE
      clean_count integer;
      null_notes_count integer;
    BEGIN
      SELECT COUNT(*) INTO clean_count FROM clean.inep;
      SELECT COUNT(*) INTO null_notes_count FROM clean.inep WHERE vl_nota_media_2023 IS NULL;
      
      RAISE NOTICE 'Tabela clean.inep criada com % registros', clean_count;
      RAISE NOTICE 'Registros com nota média NULL após limpeza: %', null_notes_count;
    END 
  $$;

  -- Adicionar constraints e índices
  CREATE INDEX ix_inep_codigo_ibge ON clean.inep (codigo_ibge);
  CREATE INDEX ix_inep_id_escola ON clean.inep (id_escola);
  CREATE INDEX ix_inep_rede ON clean.inep (rede);

  -- Comentários para documentação
  COMMENT ON TABLE  clean.inep IS 'Dados limpos do INEP - Indicadores educacionais por escola e município';
  COMMENT ON COLUMN clean.inep.linha_original IS 'Número da linha original no CSV para auditoria';
  COMMENT ON COLUMN clean.inep.codigo_ibge IS 'Código completo do município no padrão IBGE (7 dígitos)';

COMMIT;
