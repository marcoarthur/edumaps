-- Deploy edumaps:mapbiomas_escola_risco to pg
-- requires: escola_influencia
--
-- #278 (bloco F do IVET): **exposição a risco no entorno da escola** — as
-- arealizações do **MapBiomas Fogo** (frequência de queimada) e do **MapBiomas
-- Solo** (carbono total do solo) sobre o buffer da escola
-- (`clean.escola_influencia`, metodologia influencia-v1).
--
-- Mesma arquitetura da #255 (`clean.mapbiomas_escola`): o raster de 30 m não
-- cabe no banco; a arealização lê o COG em *streaming* (`terra::extract`) no
-- host de ingestão e grava só o indicador por escola.
--
-- Grão: uma linha por escola × ano do Censo × ano do raster × raio. Diferente
-- da cobertura (que é composição por classe), aqui cada indicador é um
-- **escalar** do buffer:
--
--   fogo_frequencia_media  média da frequência de queimada (anos em que ardeu)
--   fogo_frequencia_max    frequência máxima de um pixel no buffer
--   fogo_fracao_queimada   fração da área do buffer que já ardeu (freq > 0)
--   solo_carbono_medio     média do carbono total do solo (tC/ha) no buffer
--
-- Vazio ≠ zero (#154): buffer sem interseção com o raster → coluna `NULL`, e
-- sem NENHUM dos dois indicadores → **sem linha**. Nunca 0.

BEGIN;

DROP TABLE IF EXISTS clean.mapbiomas_escola_risco;

CREATE TABLE clean.mapbiomas_escola_risco (
    co_entidade          BIGINT      NOT NULL,
    nu_ano_censo         INTEGER     NOT NULL,
    ano                  SMALLINT    NOT NULL,
    raio_m               INTEGER     NOT NULL,
    fogo_frequencia_media NUMERIC(6,3),
    fogo_frequencia_max   INTEGER,
    fogo_fracao_queimada  NUMERIC(7,6),
    solo_carbono_medio    NUMERIC,
    versao               TEXT        NOT NULL DEFAULT 'influencia-v1',
    computado_em         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT pk_mapbiomas_escola_risco
      PRIMARY KEY (co_entidade, nu_ano_censo, ano, raio_m),
    CONSTRAINT mapbiomas_escola_risco_raio_ck CHECK (raio_m > 0),
    CONSTRAINT mapbiomas_escola_risco_ano_ck  CHECK (ano BETWEEN 1985 AND 2025),
    CONSTRAINT mapbiomas_escola_risco_fracao_ck CHECK (fogo_fracao_queimada IS NULL OR (fogo_fracao_queimada >= 0 AND fogo_fracao_queimada <= 1))
);

COMMENT ON TABLE clean.mapbiomas_escola_risco IS
'Exposição a risco no entorno da escola (#278, bloco F do IVET): frequência de queimada (MapBiomas Fogo) e carbono do solo (MapBiomas Solo) arealizados sobre o buffer de clean.escola_influencia. Uma linha por escola × ano do Censo × ano do raster × raio. Vazio ≠ zero (#154): sem interseção com o raster, a coluna é NULL; sem nenhum indicador, não há linha. Populada pelo job MapBiomasRisco.';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.co_entidade IS 'Código INEP da escola.';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.nu_ano_censo IS 'Ano do Censo Escolar da geometria de origem.';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.ano IS 'Ano do raster (fogo: fim da série 1985–ANO; solo: ano).';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.raio_m IS 'Raio do buffer em metros (tier=buffer).';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.fogo_frequencia_media IS 'Média da frequência de queimada no buffer (nº de anos em que ardeu, 1985–ano).';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.fogo_frequencia_max IS 'Frequência de queimada máxima de um pixel no buffer.';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.fogo_fracao_queimada IS 'Fração da área do buffer que já ardeu (frequência > 0), em [0,1].';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.solo_carbono_medio IS 'Média do carbono total do solo no buffer (tC/ha).';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.versao IS 'Versão da metodologia de influência (influencia-v1).';
COMMENT ON COLUMN clean.mapbiomas_escola_risco.computado_em IS 'Quando a arealização foi (re)calculada.';

CREATE INDEX ix_mapbiomas_escola_risco_ano ON clean.mapbiomas_escola_risco (ano, raio_m);
CREATE INDEX ix_mapbiomas_escola_risco_escola ON clean.mapbiomas_escola_risco (co_entidade, nu_ano_censo);

INSERT INTO clean.import_metadata (table_name, source_file, ultimo_status, ultimo_motivo)
VALUES ('clean.mapbiomas_escola_risco', '(nenhuma carga registrada)', 'nao_carregada',
        'aguarda a primeira execução do job MapBiomasRisco (#278)')
ON CONFLICT (table_name) DO NOTHING;

COMMIT;
