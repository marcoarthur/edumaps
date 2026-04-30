-- Deploy edumaps:ideb_anos_iniciais to pg
-- requires: ideb_notas_escolas

BEGIN;

  -- ============================================================
  -- Importação dos dados (anos iniciais do fundamental I)
  -- ============================================================

  CREATE TEMP TABLE temp_ideb_anos_iniciais (
      sg_uf VARCHAR(2),
      co_municipio INTEGER,
      no_municipio VARCHAR(100),
      id_escola BIGINT,
      no_escola VARCHAR(200),
      rede VARCHAR(30),
      -- 2005
      vl_aprovacao_2005_si_4 NUMERIC,
      vl_aprovacao_2005_si NUMERIC,
      vl_aprovacao_2005_1 NUMERIC,
      vl_aprovacao_2005_2 NUMERIC,
      vl_aprovacao_2005_3 NUMERIC,
      vl_aprovacao_2005_4 NUMERIC,
      vl_indicador_rend_2005 NUMERIC,
      -- 2007
      vl_aprovacao_2007_si_4 NUMERIC,
      vl_aprovacao_2007_si NUMERIC,
      vl_aprovacao_2007_1 NUMERIC,
      vl_aprovacao_2007_2 NUMERIC,
      vl_aprovacao_2007_3 NUMERIC,
      vl_aprovacao_2007_4 NUMERIC,
      vl_indicador_rend_2007 NUMERIC,
      -- 2009
      vl_aprovacao_2009_si_4 NUMERIC,
      vl_aprovacao_2009_si NUMERIC,
      vl_aprovacao_2009_1 NUMERIC,
      vl_aprovacao_2009_2 NUMERIC,
      vl_aprovacao_2009_3 NUMERIC,
      vl_aprovacao_2009_4 NUMERIC,
      vl_indicador_rend_2009 NUMERIC,
      -- 2011
      vl_aprovacao_2011_si_4 NUMERIC,
      vl_aprovacao_2011_si NUMERIC,
      vl_aprovacao_2011_1 NUMERIC,
      vl_aprovacao_2011_2 NUMERIC,
      vl_aprovacao_2011_3 NUMERIC,
      vl_aprovacao_2011_4 NUMERIC,
      vl_indicador_rend_2011 NUMERIC,
      -- 2013
      vl_aprovacao_2013_si_4 NUMERIC,
      vl_aprovacao_2013_si NUMERIC,
      vl_aprovacao_2013_1 NUMERIC,
      vl_aprovacao_2013_2 NUMERIC,
      vl_aprovacao_2013_3 NUMERIC,
      vl_aprovacao_2013_4 NUMERIC,
      vl_indicador_rend_2013 NUMERIC,
      -- 2015
      vl_aprovacao_2015_si_4 NUMERIC,
      vl_aprovacao_2015_si NUMERIC,
      vl_aprovacao_2015_1 NUMERIC,
      vl_aprovacao_2015_2 NUMERIC,
      vl_aprovacao_2015_3 NUMERIC,
      vl_aprovacao_2015_4 NUMERIC,
      vl_indicador_rend_2015 NUMERIC,
      -- 2017
      vl_aprovacao_2017_si_4 NUMERIC,
      vl_aprovacao_2017_si NUMERIC,
      vl_aprovacao_2017_1 NUMERIC,
      vl_aprovacao_2017_2 NUMERIC,
      vl_aprovacao_2017_3 NUMERIC,
      vl_aprovacao_2017_4 NUMERIC,
      vl_indicador_rend_2017 NUMERIC,
      -- 2019
      vl_aprovacao_2019_si_4 NUMERIC,
      vl_aprovacao_2019_si NUMERIC,
      vl_aprovacao_2019_1 NUMERIC,
      vl_aprovacao_2019_2 NUMERIC,
      vl_aprovacao_2019_3 NUMERIC,
      vl_aprovacao_2019_4 NUMERIC,
      vl_indicador_rend_2019 NUMERIC,
      -- 2021
      vl_aprovacao_2021_si_4 NUMERIC,
      vl_aprovacao_2021_si NUMERIC,
      vl_aprovacao_2021_1 NUMERIC,
      vl_aprovacao_2021_2 NUMERIC,
      vl_aprovacao_2021_3 NUMERIC,
      vl_aprovacao_2021_4 NUMERIC,
      vl_indicador_rend_2021 NUMERIC,
      -- 2023
      vl_aprovacao_2023_si_4 NUMERIC,
      vl_aprovacao_2023_si NUMERIC,
      vl_aprovacao_2023_1 NUMERIC,
      vl_aprovacao_2023_2 NUMERIC,
      vl_aprovacao_2023_3 NUMERIC,
      vl_aprovacao_2023_4 NUMERIC,
      vl_indicador_rend_2023 NUMERIC,
      -- Notas
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
      -- IDEB observado
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
      -- Projeções
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
  COPY temp_ideb_anos_iniciais FROM '/data/divulgacao_anos_iniciais_escolas_2023.csv'
  CSV HEADER;

  -- Inserir dados normalizados para cada ano
  -- 2005
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2005 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2005_si_4, vl_aprovacao_2005_si), 
      vl_aprovacao_2005_1, vl_aprovacao_2005_2, vl_aprovacao_2005_3, vl_aprovacao_2005_4,
      vl_nota_matematica_2005, vl_nota_portugues_2005, vl_nota_media_2005,
      vl_observado_2005, NULL
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2005_si_4 IS NOT NULL OR vl_aprovacao_2005_si IS NOT NULL)
     OR vl_nota_matematica_2005 IS NOT NULL 
     OR vl_observado_2005 IS NOT NULL;

  -- 2007
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2007 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2007_si_4, vl_aprovacao_2007_si), 
      vl_aprovacao_2007_1, vl_aprovacao_2007_2, vl_aprovacao_2007_3, vl_aprovacao_2007_4,
      vl_nota_matematica_2007, vl_nota_portugues_2007, vl_nota_media_2007,
      vl_observado_2007, vl_projecao_2007
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2007_si_4 IS NOT NULL OR vl_aprovacao_2007_si IS NOT NULL)
     OR vl_nota_matematica_2007 IS NOT NULL 
     OR vl_observado_2007 IS NOT NULL;

  -- 2009
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2009 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2009_si_4, vl_aprovacao_2009_si), 
      vl_aprovacao_2009_1, vl_aprovacao_2009_2, vl_aprovacao_2009_3, vl_aprovacao_2009_4,
      vl_nota_matematica_2009, vl_nota_portugues_2009, vl_nota_media_2009,
      vl_observado_2009, vl_projecao_2009
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2009_si_4 IS NOT NULL OR vl_aprovacao_2009_si IS NOT NULL)
     OR vl_nota_matematica_2009 IS NOT NULL 
     OR vl_observado_2009 IS NOT NULL;

  -- 2011
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2011 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2011_si_4, vl_aprovacao_2011_si), 
      vl_aprovacao_2011_1, vl_aprovacao_2011_2, vl_aprovacao_2011_3, vl_aprovacao_2011_4,
      vl_nota_matematica_2011, vl_nota_portugues_2011, vl_nota_media_2011,
      vl_observado_2011, vl_projecao_2011
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2011_si_4 IS NOT NULL OR vl_aprovacao_2011_si IS NOT NULL)
     OR vl_nota_matematica_2011 IS NOT NULL 
     OR vl_observado_2011 IS NOT NULL;

  -- 2013
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2013 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2013_si_4, vl_aprovacao_2013_si), 
      vl_aprovacao_2013_1, vl_aprovacao_2013_2, vl_aprovacao_2013_3, vl_aprovacao_2013_4,
      vl_nota_matematica_2013, vl_nota_portugues_2013, vl_nota_media_2013,
      vl_observado_2013, vl_projecao_2013
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2013_si_4 IS NOT NULL OR vl_aprovacao_2013_si IS NOT NULL)
     OR vl_nota_matematica_2013 IS NOT NULL 
     OR vl_observado_2013 IS NOT NULL;

  -- 2015
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2015 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2015_si_4, vl_aprovacao_2015_si), 
      vl_aprovacao_2015_1, vl_aprovacao_2015_2, vl_aprovacao_2015_3, vl_aprovacao_2015_4,
      vl_nota_matematica_2015, vl_nota_portugues_2015, vl_nota_media_2015,
      vl_observado_2015, vl_projecao_2015
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2015_si_4 IS NOT NULL OR vl_aprovacao_2015_si IS NOT NULL)
     OR vl_nota_matematica_2015 IS NOT NULL 
     OR vl_observado_2015 IS NOT NULL;

  -- 2017
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2017 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2017_si_4, vl_aprovacao_2017_si), 
      vl_aprovacao_2017_1, vl_aprovacao_2017_2, vl_aprovacao_2017_3, vl_aprovacao_2017_4,
      vl_nota_matematica_2017, vl_nota_portugues_2017, vl_nota_media_2017,
      vl_observado_2017, vl_projecao_2017
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2017_si_4 IS NOT NULL OR vl_aprovacao_2017_si IS NOT NULL)
     OR vl_nota_matematica_2017 IS NOT NULL 
     OR vl_observado_2017 IS NOT NULL;

  -- 2019
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2019 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2019_si_4, vl_aprovacao_2019_si), 
      vl_aprovacao_2019_1, vl_aprovacao_2019_2, vl_aprovacao_2019_3, vl_aprovacao_2019_4,
      vl_nota_matematica_2019, vl_nota_portugues_2019, vl_nota_media_2019,
      vl_observado_2019, vl_projecao_2019
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2019_si_4 IS NOT NULL OR vl_aprovacao_2019_si IS NOT NULL)
     OR vl_nota_matematica_2019 IS NOT NULL 
     OR vl_observado_2019 IS NOT NULL;

  -- 2021
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2021 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2021_si_4, vl_aprovacao_2021_si), 
      vl_aprovacao_2021_1, vl_aprovacao_2021_2, vl_aprovacao_2021_3, vl_aprovacao_2021_4,
      vl_nota_matematica_2021, vl_nota_portugues_2021, vl_nota_media_2021,
      vl_observado_2021, vl_projecao_2021
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2021_si_4 IS NOT NULL OR vl_aprovacao_2021_si IS NOT NULL)
     OR vl_nota_matematica_2021 IS NOT NULL 
     OR vl_observado_2021 IS NOT NULL;

  -- 2023
  INSERT INTO clean.ideb_notas_escolas (id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede, ano, etapa,
      aprovacao_si_4, aprovacao_1, aprovacao_2, aprovacao_3, aprovacao_4,
      nota_matematica, nota_portugues, nota_media,
      ideb_observado, ideb_projecao)
  SELECT 
      id_escola, sg_uf, co_municipio, no_municipio, no_escola, rede,
      2023 AS ano,
      'fundamental_i' AS etapa,
      COALESCE(vl_aprovacao_2023_si_4, vl_aprovacao_2023_si), 
      vl_aprovacao_2023_1, vl_aprovacao_2023_2, vl_aprovacao_2023_3, vl_aprovacao_2023_4,
      vl_nota_matematica_2023, vl_nota_portugues_2023, vl_nota_media_2023,
      vl_observado_2023, NULL
  FROM temp_ideb_anos_iniciais
  WHERE (vl_aprovacao_2023_si_4 IS NOT NULL OR vl_aprovacao_2023_si IS NOT NULL)
     OR vl_nota_matematica_2023 IS NOT NULL 
     OR vl_observado_2023 IS NOT NULL;

  DROP TABLE temp_ideb_anos_iniciais;

  -- ============================================================
  -- Atualizar comentários da tabela
  -- ============================================================

  COMMENT ON TABLE clean.ideb_notas_escolas IS 'Dados do IDEB/SAEB para escolas brasileiras (2005-2023), incluindo aprovações, notas de proficiência e indicadores de qualidade para todas as etapas: fundamental I, fundamental II e ensino médio';

COMMIT;
