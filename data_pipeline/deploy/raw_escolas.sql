-- Deploy edumaps:raw_escolas to pg
-- requires: extensions

BEGIN;

  -- Criar tabela raw para importação do CSV
  DROP TABLE IF EXISTS raw.escolas_raw;
  CREATE TABLE raw.escolas_raw (
      restricao_atendimento text,
      escola                text,
      codigo_inep           text,
      uf                    text,
      municipio             text,
      localizacao           text,
      localidade_diferenciada text,
      categoria_administrativa text,
      endereco              text,
      telefone              text,
      dependencia_administrativa text,
      categoria_escola_privada text,
      conveniada_poder_publico text,
      regulamentacao_conselho text,
      porte_escola          text,
      etapas_modalidades    text,
      outras_ofertas        text,
      latitude              text,
      longitude             text
  );

  -- Importar dados do CSV (caminho deve ser ajustado para o ambiente)
  COPY raw.escolas_raw
  FROM '/data/escolas.csv'
  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

  -- Criar tabela limpa com dados tratados
  DROP TABLE IF EXISTS clean.escolas;
  CREATE TABLE clean.escolas AS
  SELECT
      restricao_atendimento,
      escola,
      codigo_inep::bigint as codigo_inep,
      uf,
      municipio,
      localizacao,
      localidade_diferenciada,
      categoria_administrativa,
      endereco,
      telefone,
      dependencia_administrativa,
      categoria_escola_privada,
      conveniada_poder_publico,
      regulamentacao_conselho,
      porte_escola,
      etapas_modalidades,
      outras_ofertas,
      NULLIF(trim(latitude), '')::double precision AS latitude,
      NULLIF(trim(longitude), '')::double precision AS longitude
  FROM raw.escolas_raw;

  -- Remover registros sem coordenadas
  DELETE FROM clean.escolas
  WHERE latitude IS NULL OR longitude IS NULL;

  -- Adicionar coluna de geometria
  ALTER TABLE clean.escolas
      ADD COLUMN geometry geometry(Point, 4674);

  -- Popular geometria a partir de longitude/latitude
  UPDATE clean.escolas
  SET geometry = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 4674)
  WHERE longitude IS NOT NULL AND latitude IS NOT NULL;

  -- Remover registros com geometria inválida
  DELETE FROM clean.escolas
  WHERE geometry IS NULL OR NOT ST_IsValid(geometry);

  -- Adicionar constraints e índices
  ALTER TABLE clean.escolas 
      ADD CONSTRAINT pk_escolas PRIMARY KEY (codigo_inep),
      ADD CONSTRAINT enforce_valid_geometry CHECK (ST_IsValid(geometry));

  CREATE INDEX ix_escolas_geometry ON clean.escolas USING GIST (geometry);
  CREATE INDEX ix_escolas_codigo_inep ON clean.escolas (codigo_inep);
  CREATE INDEX ix_escolas_uf ON clean.escolas (uf);
  CREATE INDEX ix_escolas_municipio ON clean.escolas (municipio);

  -- Comentários para documentação
  COMMENT ON TABLE clean.escolas IS 'Dados limpos de escolas com geometrias georreferenciadas';
  COMMENT ON COLUMN clean.escolas.codigo_inep IS 'Código INEP único da escola';
  COMMENT ON COLUMN clean.escolas.escola IS 'Nome da escola';
  COMMENT ON COLUMN clean.escolas.uf IS 'Unidade Federativa';
  COMMENT ON COLUMN clean.escolas.municipio IS 'Município onde a escola está localizada';
  COMMENT ON COLUMN clean.escolas.latitude IS 'Latitude em graus decimais (WGS84)';
  COMMENT ON COLUMN clean.escolas.longitude IS 'Longitude em graus decimais (WGS84)';
  COMMENT ON COLUMN clean.escolas.geometry IS 'Geometria do ponto da escola em SIRGAS 2000 (4674)';

COMMIT;
