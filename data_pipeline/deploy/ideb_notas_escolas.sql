-- Deploy edumaps:ideb_notas_escolas to pg

BEGIN;

  -- Tabela normalizada para dados de IDEB/SAEB (anos finais - 2005 a 2023)
  CREATE TABLE clean.ideb_notas_escolas (
      id_escola BIGINT NOT NULL,
      sg_uf VARCHAR(2),
      co_municipio INTEGER,
      no_municipio VARCHAR(100),
      no_escola VARCHAR(200),
      rede VARCHAR(30),
      ano INTEGER NOT NULL,
      etapa VARCHAR(15),  -- 'fundamental_ii' ou 'ensino_medio'
      
      -- Indicadores de aprovação/rendimento
      aprovacao_si_4 NUMERIC(8,4),  -- Indicador de rendimento (0-1)
      aprovacao_1 NUMERIC(8,4),     -- 1ª série/ano
      aprovacao_2 NUMERIC(8,4),     -- 2ª série/ano
      aprovacao_3 NUMERIC(8,4),     -- 3ª série/ano
      aprovacao_4 NUMERIC(8,4),     -- 4ª série/ano (ensino médio)
      
      -- Notas de proficiência (escala SAEB)
      nota_matematica NUMERIC(8,2),
      nota_portugues NUMERIC(8,2),
      nota_media NUMERIC(8,2),
      
      -- IDEB (observado e projeção)
      ideb_observado NUMERIC(4,1),
      ideb_projecao NUMERIC(4,1),
      
      PRIMARY KEY (id_escola, etapa, ano)
  );

  -- Índices para otimização de consultas
  CREATE INDEX idx_ideb_id_escola ON clean.ideb_notas_escolas (id_escola);
  CREATE INDEX idx_ideb_ano ON clean.ideb_notas_escolas (ano);
  CREATE INDEX idx_ideb_uf ON clean.ideb_notas_escolas (sg_uf);
  CREATE INDEX idx_ideb_municipio ON clean.ideb_notas_escolas (co_municipio);
  CREATE INDEX idx_ideb_rede ON clean.ideb_notas_escolas (rede);

  -- ============================================================
  -- Importação dos dados (anos finais do fundamental II)
  -- ============================================================

  CREATE TEMP TABLE temp_ideb_fundamental_ii (
      sg_uf VARCHAR(2),
      co_municipio INTEGER,
      no_municipio VARCHAR(100),
      id_escola BIGINT,
      no_escola VARCHAR(200),
      rede VARCHAR(30),
      vl_aprovacao_2005_si_4 NUMERIC,
      vl_aprovacao_2005_1 NUMERIC,
      vl_aprovacao_2005_2 NUMERIC,
      vl_aprovacao_2005_3 NUMERIC,
      vl_aprovacao_2005_4 NUMERIC,
      vl_indicador_rend_2005 NUMERIC,
      vl_aprovacao_2007_si_4 NUMERIC,
      vl_aprovacao_2007_1 NUMERIC,
      vl_aprovacao_2007_2 NUMERIC,
      vl_aprovacao_2007_3 NUMERIC,
      vl_aprovacao_2007_4 NUMERIC,
      vl_indicador_rend_2007 NUMERIC,
      vl_aprovacao_2009_si_4 NUMERIC,
      vl_aprovacao_2009_1 NUMERIC,
      vl_aprovacao_2009_2 NUMERIC,
      vl_aprovacao_2009_3 NUMERIC,
      vl_aprovacao_2009_4 NUMERIC,
      vl_indicador_rend_2009 NUMERIC,
      vl_aprovacao_2011_si_4 NUMERIC,
      vl_aprovacao_2011_1 NUMERIC,
      vl_aprovacao_2011_2 NUMERIC,
      vl_aprovacao_2011_3 NUMERIC,
      vl_aprovacao_2011_4 NUMERIC,
      vl_indicador_rend_2011 NUMERIC,
      vl_aprovacao_2013_si_4 NUMERIC,
      vl_aprovacao_2013_1 NUMERIC,
      vl_aprovacao_2013_2 NUMERIC,
      vl_aprovacao_2013_3 NUMERIC,
      vl_aprovacao_2013_4 NUMERIC,
      vl_indicador_rend_2013 NUMERIC,
      vl_aprovacao_2015_si_4 NUMERIC,
      vl_aprovacao_2015_1 NUMERIC,
      vl_aprovacao_2015_2 NUMERIC,
      vl_aprovacao_2015_3 NUMERIC,
      vl_aprovacao_2015_4 NUMERIC,
      vl_indicador_rend_2015 NUMERIC,
      vl_aprovacao_2017_si_4 NUMERIC,
      vl_aprovacao_2017_1 NUMERIC,
      vl_aprovacao_2017_2 NUMERIC,
      vl_aprovacao_2017_3 NUMERIC,
      vl_aprovacao_2017_4 NUMERIC,
      vl_indicador_rend_2017 NUMERIC,
      vl_aprovacao_2019_si_4 NUMERIC,
      vl_aprovacao_2019_1 NUMERIC,
      vl_aprovacao_2019_2 NUMERIC,
      vl_aprovacao_2019_3 NUMERIC,
      vl_aprovacao_2019_4 NUMERIC,
      vl_indicador_rend_2019 NUMERIC,
      vl_aprovacao_2021_si_4 NUMERIC,
      vl_aprovacao_2021_1 NUMERIC,
      vl_aprovacao_2021_2 NUMERIC,
      vl_aprovacao_2021_3 NUMERIC,
      vl_aprovacao_2021_4 NUMERIC,
      vl_indicador_rend_2021 NUMERIC,
      vl_aprovacao_2023_si_4 NUMERIC,
      vl_aprovacao_2023_1 NUMERIC,
      vl_aprovacao_2023_2 NUMERIC,
      vl_aprovacao_2023_3 NUMERIC,
      vl_aprovacao_2023_4 NUMERIC,
      vl_indicador_rend_2023 NUMERIC,
      vl_nota_matematica_2005 NUMERIC,
      vl_nota_portugues_2005 NUMERIC,
      vl_nota_media_2005 NUMERIC,
      vl_nota_matematica_2007 NUMERIC,
      vl_nota_portugues_2007 NUMERIC,
      vl_nota_media_2007 NUMERIC,
      vl_nota_matematica_2009 NUMERIC,
      vl_nota_portugues_2009 NUMERIC,
      vl_nota_media_2009 NUMERIC,
      vl_nota_matematica_2011 NUMERIC,
      vl_nota_portugues_2011 NUMERIC,
      vl_nota_media_2011 NUMERIC,
      vl_nota_matematica_2013 NUMERIC,
      vl_nota_portugues_2013 NUMERIC,
      vl_nota_media_2013 NUMERIC,
      vl_nota_matematica_2015 NUMERIC,
      vl_nota_portugues_2015 NUMERIC,
      vl_nota_media_2015 NUMERIC,
      vl_nota_matematica_2017 NUMERIC,
      vl_nota_portugues_2017 NUMERIC,
      vl_nota_media_2017 NUMERIC,
      vl_nota_matematica_2019 NUMERIC,
      vl_nota_portugues_2019 NUMERIC,
      vl_nota_media_2019 NUMERIC,
      vl_nota_matematica_2021 NUMERIC,
      vl_nota_portugues_2021 NUMERIC,
      vl_nota_media_2021 NUMERIC,
      vl_nota_matematica_2023 NUMERIC,
      vl_nota_portugues_2023 NUMERIC,
      vl_nota_media_2023 NUMERIC,
      vl_observado_2005 NUMERIC,
      vl_observado_2007 NUMERIC,
      vl_observado_2009 NUMERIC,
      vl_observado_2011 NUMERIC,
      vl_observado_2013 NUMERIC,
      vl_observado_2015 NUMERIC,
      vl_observado_2017 NUMERIC,
      vl_observado_2019 NUMERIC,
      vl_observado_2021 NUMERIC,
      vl_observado_2023 NUMERIC,
      vl_projecao_2007 NUMERIC,
      vl_projecao_2009 NUMERIC,
      vl_projecao_2011 NUMERIC,
      vl_projecao_2013 NUMERIC,
      vl_projecao_2015 NUMERIC,
      vl_projecao_2017 NUMERIC,
      vl_projecao_2019 NUMERIC,
      vl_projecao_2021 NUMERIC
  );

  -- Importar CSV para tabela temporária
  COPY temp_ideb_fundamental_ii FROM '/data/divulgacao_anos_finais_escolas_2023.csv'
  CSV HEADER;

  -- Inserir dados normalizados (pivot)
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2005 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2005_si_4, vl_aprovacao_2005_1, vl_aprovacao_2005_2, vl_aprovacao_2005_3, vl_aprovacao_2005_4,
      vl_nota_matematica_2005, vl_nota_portugues_2005, vl_nota_media_2005,
      vl_observado_2005, NULL
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2005_si_4 IS NOT NULL 
     OR vl_nota_matematica_2005 IS NOT NULL 
     OR vl_observado_2005 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2007 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2007_si_4, vl_aprovacao_2007_1, vl_aprovacao_2007_2, vl_aprovacao_2007_3, vl_aprovacao_2007_4,
      vl_nota_matematica_2007, vl_nota_portugues_2007, vl_nota_media_2007,
      vl_observado_2007, vl_projecao_2007
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2007_si_4 IS NOT NULL 
     OR vl_nota_matematica_2007 IS NOT NULL 
     OR vl_observado_2007 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2009 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2009_si_4, vl_aprovacao_2009_1, vl_aprovacao_2009_2, vl_aprovacao_2009_3, vl_aprovacao_2009_4,
      vl_nota_matematica_2009, vl_nota_portugues_2009, vl_nota_media_2009,
      vl_observado_2009, vl_projecao_2009
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2009_si_4 IS NOT NULL 
     OR vl_nota_matematica_2009 IS NOT NULL 
     OR vl_observado_2009 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2011 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2011_si_4, vl_aprovacao_2011_1, vl_aprovacao_2011_2, vl_aprovacao_2011_3, vl_aprovacao_2011_4,
      vl_nota_matematica_2011, vl_nota_portugues_2011, vl_nota_media_2011,
      vl_observado_2011, vl_projecao_2011
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2011_si_4 IS NOT NULL 
     OR vl_nota_matematica_2011 IS NOT NULL 
     OR vl_observado_2011 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2013 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2013_si_4, vl_aprovacao_2013_1, vl_aprovacao_2013_2, vl_aprovacao_2013_3, vl_aprovacao_2013_4,
      vl_nota_matematica_2013, vl_nota_portugues_2013, vl_nota_media_2013,
      vl_observado_2013, vl_projecao_2013
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2013_si_4 IS NOT NULL 
     OR vl_nota_matematica_2013 IS NOT NULL 
     OR vl_observado_2013 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2015 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2015_si_4, vl_aprovacao_2015_1, vl_aprovacao_2015_2, vl_aprovacao_2015_3, vl_aprovacao_2015_4,
      vl_nota_matematica_2015, vl_nota_portugues_2015, vl_nota_media_2015,
      vl_observado_2015, vl_projecao_2015
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2015_si_4 IS NOT NULL 
     OR vl_nota_matematica_2015 IS NOT NULL 
     OR vl_observado_2015 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2017 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2017_si_4, vl_aprovacao_2017_1, vl_aprovacao_2017_2, vl_aprovacao_2017_3, vl_aprovacao_2017_4,
      vl_nota_matematica_2017, vl_nota_portugues_2017, vl_nota_media_2017,
      vl_observado_2017, vl_projecao_2017
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2017_si_4 IS NOT NULL 
     OR vl_nota_matematica_2017 IS NOT NULL 
     OR vl_observado_2017 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2019 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2019_si_4, vl_aprovacao_2019_1, vl_aprovacao_2019_2, vl_aprovacao_2019_3, vl_aprovacao_2019_4,
      vl_nota_matematica_2019, vl_nota_portugues_2019, vl_nota_media_2019,
      vl_observado_2019, vl_projecao_2019
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2019_si_4 IS NOT NULL 
     OR vl_nota_matematica_2019 IS NOT NULL 
     OR vl_observado_2019 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2021 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2021_si_4, vl_aprovacao_2021_1, vl_aprovacao_2021_2, vl_aprovacao_2021_3, vl_aprovacao_2021_4,
      vl_nota_matematica_2021, vl_nota_portugues_2021, vl_nota_media_2021,
      vl_observado_2021, vl_projecao_2021
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2021_si_4 IS NOT NULL 
     OR vl_nota_matematica_2021 IS NOT NULL 
     OR vl_observado_2021 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2023 AS ano,
      'fundamental_ii' AS etapa,
      vl_aprovacao_2023_si_4, vl_aprovacao_2023_1, vl_aprovacao_2023_2, vl_aprovacao_2023_3, vl_aprovacao_2023_4,
      vl_nota_matematica_2023, vl_nota_portugues_2023, vl_nota_media_2023,
      vl_observado_2023, NULL
  FROM temp_ideb_fundamental_ii
  WHERE vl_aprovacao_2023_si_4 IS NOT NULL 
     OR vl_nota_matematica_2023 IS NOT NULL 
     OR vl_observado_2023 IS NOT NULL;

  DROP TABLE temp_ideb_fundamental_ii;

  -- ============================================================
  -- Importação dos dados (ensino médio - apenas 2017 a 2023)
  -- ============================================================

  CREATE TEMP TABLE temp_ideb_ensino_medio (
      sg_uf VARCHAR(2),
      co_municipio INTEGER,
      no_municipio VARCHAR(100),
      id_escola BIGINT,
      no_escola VARCHAR(200),
      rede VARCHAR(30),
      vl_aprovacao_2017_si_4 NUMERIC,
      vl_aprovacao_2017_1 NUMERIC,
      vl_aprovacao_2017_2 NUMERIC,
      vl_aprovacao_2017_3 NUMERIC,
      vl_aprovacao_2017_4 NUMERIC,
      vl_indicador_rend_2017 NUMERIC,
      vl_aprovacao_2019_si_4 NUMERIC,
      vl_aprovacao_2019_1 NUMERIC,
      vl_aprovacao_2019_2 NUMERIC,
      vl_aprovacao_2019_3 NUMERIC,
      vl_aprovacao_2019_4 NUMERIC,
      vl_indicador_rend_2019 NUMERIC,
      vl_aprovacao_2021_si_4 NUMERIC,
      vl_aprovacao_2021_1 NUMERIC,
      vl_aprovacao_2021_2 NUMERIC,
      vl_aprovacao_2021_3 NUMERIC,
      vl_aprovacao_2021_4 NUMERIC,
      vl_indicador_rend_2021 NUMERIC,
      vl_aprovacao_2023_si_4 NUMERIC,
      vl_aprovacao_2023_1 NUMERIC,
      vl_aprovacao_2023_2 NUMERIC,
      vl_aprovacao_2023_3 NUMERIC,
      vl_aprovacao_2023_4 NUMERIC,
      vl_indicador_rend_2023 NUMERIC,
      vl_nota_matematica_2017 NUMERIC,
      vl_nota_portugues_2017 NUMERIC,
      vl_nota_media_2017 NUMERIC,
      vl_nota_matematica_2019 NUMERIC,
      vl_nota_portugues_2019 NUMERIC,
      vl_nota_media_2019 NUMERIC,
      vl_nota_matematica_2021 NUMERIC,
      vl_nota_portugues_2021 NUMERIC,
      vl_nota_media_2021 NUMERIC,
      vl_nota_matematica_2023 NUMERIC,
      vl_nota_portugues_2023 NUMERIC,
      vl_nota_media_2023 NUMERIC,
      vl_observado_2017 NUMERIC,
      vl_observado_2019 NUMERIC,
      vl_observado_2021 NUMERIC,
      vl_observado_2023 NUMERIC,
      vl_projecao_2019 NUMERIC,
      vl_projecao_2021 NUMERIC,
      extra VARCHAR(10)  -- Coluna "...49" (extra)
  );

  COPY temp_ideb_ensino_medio FROM '/data/divulgacao_ensino_medio_escolas_2023.csv'
  CSV HEADER;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2017 AS ano,
      'ensino_medio' AS etapa,
      vl_aprovacao_2017_si_4, vl_aprovacao_2017_1, vl_aprovacao_2017_2, vl_aprovacao_2017_3, vl_aprovacao_2017_4,
      vl_nota_matematica_2017, vl_nota_portugues_2017, vl_nota_media_2017,
      vl_observado_2017, NULL
  FROM temp_ideb_ensino_medio
  WHERE vl_aprovacao_2017_si_4 IS NOT NULL 
     OR vl_nota_matematica_2017 IS NOT NULL 
     OR vl_observado_2017 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2019 AS ano,
      'ensino_medio' AS etapa,
      vl_aprovacao_2019_si_4, vl_aprovacao_2019_1, vl_aprovacao_2019_2, vl_aprovacao_2019_3, vl_aprovacao_2019_4,
      vl_nota_matematica_2019, vl_nota_portugues_2019, vl_nota_media_2019,
      vl_observado_2019, vl_projecao_2019
  FROM temp_ideb_ensino_medio
  WHERE vl_aprovacao_2019_si_4 IS NOT NULL 
     OR vl_nota_matematica_2019 IS NOT NULL 
     OR vl_observado_2019 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2021 AS ano,
      'ensino_medio' AS etapa,
      vl_aprovacao_2021_si_4, vl_aprovacao_2021_1, vl_aprovacao_2021_2, vl_aprovacao_2021_3, vl_aprovacao_2021_4,
      vl_nota_matematica_2021, vl_nota_portugues_2021, vl_nota_media_2021,
      vl_observado_2021, vl_projecao_2021
  FROM temp_ideb_ensino_medio
  WHERE vl_aprovacao_2021_si_4 IS NOT NULL 
     OR vl_nota_matematica_2021 IS NOT NULL 
     OR vl_observado_2021 IS NOT NULL;

  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2023 AS ano,
      'ensino_medio' AS etapa,
      vl_aprovacao_2023_si_4, vl_aprovacao_2023_1, vl_aprovacao_2023_2, vl_aprovacao_2023_3, vl_aprovacao_2023_4,
      vl_nota_matematica_2023, vl_nota_portugues_2023, vl_nota_media_2023,
      vl_observado_2023, NULL
  FROM temp_ideb_ensino_medio
  WHERE vl_aprovacao_2023_si_4 IS NOT NULL 
     OR vl_nota_matematica_2023 IS NOT NULL 
     OR vl_observado_2023 IS NOT NULL;

  DROP TABLE temp_ideb_ensino_medio;

  -- ============================================================
  -- Comentários da tabela
  -- ============================================================

  COMMENT ON TABLE clean.ideb_notas_escolas IS 'Dados do IDEB/SAEB para escolas brasileiras (2005-2023), incluindo aprovações, notas de proficiência e indicadores de qualidade';

  COMMENT ON COLUMN clean.ideb_notas_escolas.id_escola IS 'Código único da escola (INEP) - corresponde ao co_entidade do censo escolar';
  COMMENT ON COLUMN clean.ideb_notas_escolas.sg_uf IS 'Sigla da Unidade da Federação';
  COMMENT ON COLUMN clean.ideb_notas_escolas.co_municipio IS 'Código do município (IBGE)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.no_municipio IS 'Nome do município';
  COMMENT ON COLUMN clean.ideb_notas_escolas.no_escola IS 'Nome da escola';
  COMMENT ON COLUMN clean.ideb_notas_escolas.rede IS 'Rede de ensino (Municipal, Estadual, Privada, Federal)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.ano IS 'Ano de referência dos dados';
  COMMENT ON COLUMN clean.ideb_notas_escolas.etapa IS 'Etapa de ensino (fundamental_ii ou ensino_medio)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.aprovacao_si_4 IS 'Indicador de rendimento (0-1) - Taxa de aprovação ajustada';
  COMMENT ON COLUMN clean.ideb_notas_escolas.aprovacao_1 IS 'Taxa de aprovação da 1ª série/ano (%)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.aprovacao_2 IS 'Taxa de aprovação da 2ª série/ano (%)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.aprovacao_3 IS 'Taxa de aprovação da 3ª série/ano (%)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.aprovacao_4 IS 'Taxa de aprovação da 4ª série/ano (%) - aplicável ao ensino médio';
  COMMENT ON COLUMN clean.ideb_notas_escolas.nota_matematica IS 'Proficiência média em Matemática (escala SAEB)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.nota_portugues IS 'Proficiência média em Língua Portuguesa (escala SAEB)';
  COMMENT ON COLUMN clean.ideb_notas_escolas.nota_media IS 'Média das proficiências em Matemática e Português';
  COMMENT ON COLUMN clean.ideb_notas_escolas.ideb_observado IS 'IDEB observado no ano';
  COMMENT ON COLUMN clean.ideb_notas_escolas.ideb_projecao IS 'Meta IDEB projetada para o ano';

COMMIT;
