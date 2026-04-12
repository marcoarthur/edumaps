-- Deploy edumaps:analytics_municipios_similaridade to pg

BEGIN;

  -- Criar a materialized view no schema analytics
  CREATE MATERIALIZED VIEW analytics.municipio_similaridade AS
  WITH medias_municipio AS (
      SELECT 
          cod_municipio,
          AVG(salario_total) AS salario_medio,
          AVG(carga_horaria) AS carga_media,
          COUNT(DISTINCT cpf) AS total_profissionais
      FROM clean.remuneracao_municipal
      WHERE ano = 2024
      GROUP BY cod_municipio
  )
  SELECT 
      a.cod_municipio AS municipio_1,
      b.cod_municipio AS municipio_2,
      -- Distância Euclidiana (3 dimensões)
      SQRT(
          POWER(COALESCE(a.salario_medio, 0) - COALESCE(b.salario_medio, 0), 2) +
          POWER(COALESCE(a.carga_media, 0) - COALESCE(b.carga_media, 0), 2) +
          POWER(COALESCE(a.total_profissionais, 0) - COALESCE(b.total_profissionais, 0), 2)
      ) AS distancia_euclidiana,
      -- Similaridade (normalizada entre 0 e 1)
      1 / (1 + SQRT(
          POWER(COALESCE(a.salario_medio, 0) - COALESCE(b.salario_medio, 0), 2) +
          POWER(COALESCE(a.carga_media, 0) - COALESCE(b.carga_media, 0), 2) +
          POWER(COALESCE(a.total_profissionais, 0) - COALESCE(b.total_profissionais, 0), 2)
      )) AS similaridade
  FROM medias_municipio a
  CROSS JOIN medias_municipio b
  WHERE a.cod_municipio < b.cod_municipio  -- Evita duplicatas e auto-comparação
  ORDER BY similaridade DESC;

  -- Criar índices para melhor performance
  -- 1. Índice composto único para o par (municipio_1, municipio_2)
  -- Este é o mais importante: garante unicidade e acelera buscas por pares específicos
  CREATE UNIQUE INDEX idx_municipio_similaridade_pair ON analytics.municipio_similaridade (municipio_1, municipio_2);

  -- 2. Índice para ordenar por similaridade (mais comum: top N similares)
  CREATE INDEX idx_municipio_similaridade_sim ON analytics.municipio_similaridade (similaridade DESC);

  -- 3. Índice composto para buscar similares de um município ordenado por similaridade
  -- Este é muito útil para a query mais comum: "Top 10 similares de um município"
  CREATE INDEX idx_municipio_similaridade_m1_sim ON analytics.municipio_similaridade (municipio_1, similaridade DESC);

  -- Comentários para documentação
  COMMENT ON MATERIALIZED VIEW analytics.municipio_similaridade IS 
  'Similaridade entre municípios baseada em salário médio, carga horária média e número de profissionais para o ano de 2024';

  COMMENT ON COLUMN analytics.municipio_similaridade.municipio_1 IS 'Código IBGE do primeiro município';
  COMMENT ON COLUMN analytics.municipio_similaridade.municipio_2 IS 'Código IBGE do segundo município';
  COMMENT ON COLUMN analytics.municipio_similaridade.distancia_euclidiana IS 'Distância euclidiana entre os vetores de características dos municípios. Quanto menor, mais similares.';
  COMMENT ON COLUMN analytics.municipio_similaridade.similaridade IS 'Similaridade normalizada entre 0 e 1. Quanto mais próximo de 1, mais similares os municípios.';

COMMIT;
