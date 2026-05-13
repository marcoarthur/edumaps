-- Deploy edumaps:consistent_schools_mv to pg
-- requires: ideb_notas_escolas

BEGIN;

  CREATE MATERIALIZED VIEW consistent_schools AS
  WITH anos_por_etapa AS (
      SELECT etapa, COUNT(DISTINCT ano) AS total_anos
      FROM ideb_notas_escolas
      WHERE ideb_observado IS NOT NULL
      GROUP BY etapa
  ),
  participacao_escola AS (
      SELECT 
          id_escola,
          no_escola,
          sg_uf,
          rede,
          etapa,
          COUNT(DISTINCT ano) AS anos_participou
      FROM ideb_notas_escolas
      WHERE ideb_observado IS NOT NULL
      GROUP BY id_escola, no_escola, sg_uf, rede, etapa
  )
  SELECT 
      pe.id_escola,
      pe.no_escola,
      pe.sg_uf,
      pe.rede,
      pe.etapa,
      pe.anos_participou,
      ape.total_anos
  FROM participacao_escola pe
  JOIN anos_por_etapa ape ON pe.etapa = ape.etapa
  WHERE pe.anos_participou = ape.total_anos;

  -- Comentários
  COMMENT ON MATERIALIZED VIEW consistent_schools IS 'Escolas consistentes: participaram de todas as avaliações d
  isponíveis para sua etapa.';
  COMMENT ON COLUMN consistent_schools.id_escola IS 'Código único da escola (INEP)';
  COMMENT ON COLUMN consistent_schools.no_escola IS 'Nome da escola';
  COMMENT ON COLUMN consistent_schools.sg_uf IS 'Sigla da Unidade da Federação';
  COMMENT ON COLUMN consistent_schools.rede IS 'Rede de ensino (Municipal, Estadual, Privada, Federal)';
  COMMENT ON COLUMN consistent_schools.etapa IS 'Etapa de ensino (fundamental_ii ou ensino_medio)';
  COMMENT ON COLUMN consistent_schools.anos_participou IS 'Número de anos em que a escola possui IDEB observado';
  COMMENT ON COLUMN consistent_schools.total_anos IS 'Número total de anos disponíveis na base para a respectiva 
  etapa';

  -- Índices opcionais para melhor performance
  CREATE INDEX idx_consistent_schools_uf ON consistent_schools (sg_uf);
  CREATE INDEX idx_consistent_schools_rede ON consistent_schools (rede);
  CREATE INDEX idx_consistent_schools_etapa ON consistent_schools (etapa);

COMMIT;
