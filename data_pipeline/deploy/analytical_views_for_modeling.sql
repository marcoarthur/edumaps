-- Deploy edumaps:analytical_views_for_modeling to pg

BEGIN;

  --
  -- VIEW: analytics.view_escolas_ml
  -- DESCRIÇÃO: Dataset consolidado para Machine Learning (previsão de nota SAEB/IDEB)
  --            Combina dados estruturais das escolas com histórico de desempenho
  --            Evita vazamento de dados (leakage) usando apenas informações até 2021
  --            Target: vl_nota_media_2023
  --
  CREATE OR REPLACE VIEW analytics.view_escolas_ml AS
  SELECT
    -- Identificação
    e.codigo_inep,

    -- Localização
    e.uf,
    e.municipio,
    e.localizacao,
    e.latitude,
    e.longitude,
    e.geometry,

    -- Estrutura
    e.dependencia_administrativa,
    e.porte_escola,

    -- Histórico de notas (SAFE - até 2021)
    i.vl_nota_media_2019,
    i.vl_nota_media_2021,

    -- Histórico de rendimento (SAFE)
    i.vl_indicador_rend_2019,
    i.vl_indicador_rend_2021,

    -- Features derivadas
    (i.vl_nota_media_2021 - i.vl_nota_media_2019) AS tendencia_nota,

    (i.vl_indicador_rend_2021 - i.vl_indicador_rend_2019) AS tendencia_aprovacao,

    -- TARGET (não usar como feature!)
    i.vl_nota_media_2023

  FROM clean.escolas e
  JOIN clean.inep i
    ON e.codigo_inep = i.id_escola

  WHERE
    i.vl_nota_media_2023 IS NOT NULL
    AND i.vl_nota_media_2021 IS NOT NULL
    AND i.vl_nota_media_2019 IS NOT NULL;

  --
  -- Comentário da view
  --
  COMMENT ON VIEW analytics.view_escolas_ml IS
  'View consolidada para Machine Learning (previsão de nota SAEB/IDEB).
   Inclui dados estruturais e históricos até 2021.
   Evita data leakage ao não utilizar variáveis de 2023 como features.
   Target: vl_nota_media_2023.';


  CREATE OR REPLACE VIEW analytics.view_escolas_ml_spatial AS
  WITH base AS (
      SELECT
          e.codigo_inep,
          e.uf,
          e.municipio,
          e.localizacao,
          e.latitude,
          e.longitude,
          e.geometry,
          e.dependencia_administrativa,
          e.porte_escola,

          i.vl_nota_media_2019,
          i.vl_nota_media_2021,
          i.vl_indicador_rend_2019,
          i.vl_indicador_rend_2021,

          (i.vl_nota_media_2021 - i.vl_nota_media_2019) AS tendencia_nota,
          (i.vl_indicador_rend_2021 - i.vl_indicador_rend_2019) AS tendencia_aprovacao,

          i.vl_nota_media_2023

      FROM clean.escolas e
      JOIN clean.inep i ON e.codigo_inep = i.id_escola
      WHERE
          i.vl_nota_media_2023 IS NOT NULL
          AND i.vl_nota_media_2021 IS NOT NULL
          AND i.vl_nota_media_2019 IS NOT NULL
          AND e.geometry IS NOT NULL
  ),

  vizinhanca AS (
      SELECT
          b1.codigo_inep,

          COUNT(b2.codigo_inep) AS n_vizinhos_5km,

          AVG(b2.vl_nota_media_2021) AS media_nota_vizinhos_2021,
          AVG(b2.vl_indicador_rend_2021) AS media_aprov_vizinhos_2021,

          STDDEV(b2.vl_nota_media_2021) AS sd_nota_vizinhos_2021,

          -- diversidade de redes
          COUNT(DISTINCT b2.dependencia_administrativa) AS diversidade_redes,

          -- proporção de escolas urbanas
          AVG(CASE WHEN b2.localizacao = 'Urbana' THEN 1 ELSE 0 END) AS prop_urbano_vizinhos

      FROM base b1
      JOIN base b2
        ON ST_DWithin(b1.geometry, b2.geometry, 5000)
       AND b1.codigo_inep <> b2.codigo_inep

      GROUP BY b1.codigo_inep
  )

  SELECT
      b.*,

      COALESCE(v.n_vizinhos_5km, 0) AS n_vizinhos_5km,
      v.media_nota_vizinhos_2021,
      v.media_aprov_vizinhos_2021,
      v.sd_nota_vizinhos_2021,
      v.diversidade_redes,
      v.prop_urbano_vizinhos

  FROM base b
  LEFT JOIN vizinhanca v
    ON b.codigo_inep = v.codigo_inep;

  --
  -- Comentário
  --
  COMMENT ON VIEW analytics.view_escolas_ml_spatial IS
  'View de Machine Learning com features espaciais.
   Inclui estatísticas de vizinhança (raio de 5km) calculadas com dados até 2021.
   Evita data leakage e adiciona contexto geográfico local para melhoria preditiva.';

COMMIT;
