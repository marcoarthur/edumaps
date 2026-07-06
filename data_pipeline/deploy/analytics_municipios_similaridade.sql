-- Deploy edumaps:analytics_municipios_similaridade to pg

BEGIN;

  -- Criar a materialized view no schema analytics com padronização estatística (Z-Score)
  CREATE MATERIALIZED VIEW analytics.municipio_similaridade AS
  WITH medias_municipio AS (
      SELECT 
          cod_municipio,
          AVG(salario_total) AS salario_medio,
          AVG(carga_horaria) AS carga_media,
          COUNT(DISTINCT cpf)::numeric AS total_profissionais
      FROM clean.remuneracao_municipal
      WHERE ano = 2025
      GROUP BY cod_municipio
  ),
  municipios_normalizados AS (
      -- Aplica a normalização Z-Score para remover o viés de escala
      -- Cada dimensão passa a ter peso idêntico na distância euclidiana
      SELECT 
          cod_municipio,
          (salario_medio - AVG(salario_medio) OVER()) / NULLIF(STDDEV_SAMP(salario_medio) OVER(), 0) AS sal_z,
          (carga_media - AVG(carga_media) OVER()) / NULLIF(STDDEV_SAMP(carga_media) OVER(), 0) AS ch_z,
          (total_profissionais - AVG(total_profissionais) OVER()) / NULLIF(STDDEV_SAMP(total_profissionais) OVER(), 0) AS prof_z
      FROM medias_municipio
  )
  SELECT 
      a.cod_municipio AS municipio_1,
      b.cod_municipio AS municipio_2,
      -- Distância Euclidiana baseada em valores z-score padronizados
      SQRT(
          POWER(COALESCE(a.sal_z, 0) - COALESCE(b.sal_z, 0), 2) +
          POWER(COALESCE(a.ch_z, 0) - COALESCE(b.ch_z, 0), 2) +
          POWER(COALESCE(a.prof_z, 0) - COALESCE(b.prof_z, 0), 2)
      ) AS distancia_euclidiana,
      -- Similaridade estatisticamente justa normalizada entre 0 e 1
      1 / (1 + SQRT(
          POWER(COALESCE(a.sal_z, 0) - COALESCE(b.sal_z, 0), 2) +
          POWER(COALESCE(a.ch_z, 0) - COALESCE(b.ch_z, 0), 2) +
          POWER(COALESCE(a.prof_z, 0) - COALESCE(b.prof_z, 0), 2)
      )) AS similaridade
  FROM municipios_normalizados a
  CROSS JOIN municipios_normalizados b
  WHERE a.cod_municipio < b.cod_municipio  -- Evita duplicatas e auto-comparação
  ORDER BY similaridade DESC;

  -- Criar índices para melhor performance
  -- 1. Índice composto único para o par (municipio_1, municipio_2)
  CREATE UNIQUE INDEX idx_municipio_similaridade_pair ON analytics.municipio_similaridade (municipio_1, municipio_2);

  -- 2. Índice para ordenar por similaridade (mais comum: top N similares)
  CREATE INDEX idx_municipio_similaridade_sim ON analytics.municipio_similaridade (similaridade DESC);

  -- 3. Índice composto para buscar similares de um município ordenado por similaridade
  CREATE INDEX idx_municipio_similaridade_m1_sim ON analytics.municipio_similaridade (municipio_1, similaridade DESC);

  -- Comentários para documentação
  COMMENT ON MATERIALIZED VIEW analytics.municipio_similaridade IS 
  'Similaridade entre municípios baseada em salário médio, carga horária média e número de profissionais para o ano de 2025. Utiliza normalização Z-Score para equalizar o peso das variáveis.';

  COMMENT ON COLUMN analytics.municipio_similaridade.municipio_1 IS 'Código IBGE do primeiro município';
  COMMENT ON COLUMN analytics.municipio_similaridade.municipio_2 IS 'Código IBGE do segundo município';
  COMMENT ON COLUMN analytics.municipio_similaridade.distancia_euclidiana IS 'Distância euclidiana calculada sobre os Z-Scores das variáveis. Quanto menor, mais próximos os perfis.';
  COMMENT ON COLUMN analytics.municipio_similaridade.similaridade IS 'Similaridade balanceada entre 0 e 1. Valores próximos a 1 indicam forte semelhança no comportamento de carga horária, salários e porte técnico.';

COMMIT;
