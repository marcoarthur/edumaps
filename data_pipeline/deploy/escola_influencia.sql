-- Deploy edumaps:escola_influencia to pg
-- requires: quarantine_censo_escolas_scores
-- requires: censo_escolar_2025
--
-- #255 e #137: camada de influência da escola (metodologia `influencia-v1`,
-- docs/analises/influencia.md).
--
-- Tier 1 (buffer de raio documentado): materializa, por escola, o polígono de
-- buffer **em metros** — a geometria reusável que o zonal statistics do raster
-- de 30 m do MapBiomas (#255) e a arealização dos blocos territoriais B–F
-- (#137) consomem. Determinística: mesma entrada (escola + raio) -> mesma
-- geometria.
--
--   tier = 'buffer'  -> raio_m em metros (Tier 1)
--   tier = 'isocrona'-> Tier 2 (mobilidade), reservado — não populado aqui
--
-- Tier 0 (ponto) não precisa de tabela. Tier 2 (isócrona) e Tier 3 (setor
-- censitário) entram depois no mesmo `tier`.
--
-- Buffer em metros: `ST_Buffer(geography, raio)` (o overload de geography
-- trabalha em metros; o de geometry trabalharia em graus). O SRID 4674 é
-- preservado no round-trip geography->geometry.

BEGIN;

CREATE TABLE clean.escola_influencia (
  co_entidade  BIGINT      NOT NULL,
  nu_ano_censo INTEGER     NOT NULL,
  tier         TEXT        NOT NULL DEFAULT 'buffer',
  raio_m       INTEGER     NOT NULL,
  geom         geometry(Polygon, 4674) NOT NULL,
  versao       TEXT        NOT NULL DEFAULT 'influencia-v1',
  computado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT pk_escola_influencia PRIMARY KEY (co_entidade, nu_ano_censo, tier, raio_m),
  CONSTRAINT escola_influencia_tier_ck CHECK (tier IN ('buffer', 'isocrona')),
  CONSTRAINT escola_influencia_raio_ck CHECK (raio_m > 0),
  CONSTRAINT escola_influencia_geom_ck CHECK (ST_IsValid(geom))
);

COMMENT ON TABLE clean.escola_influencia IS
'Camada de influência da escola (#255/#137): geometria do entorno, por tier. Tier 1 = buffer de raio documentado (raio_m). Metodologia influencia-v1 (docs/analises/influencia.md): 500 m (feições locais), 1 km (uso do solo), 2 km (fogo/chuva). Populada por clean.refresh_escola_influencia() (task Minion refresh_influencia).';
COMMENT ON COLUMN clean.escola_influencia.co_entidade IS 'Código INEP da escola (clean.censo_escolas.co_entidade).';
COMMENT ON COLUMN clean.escola_influencia.nu_ano_censo IS 'Ano do Censo Escolar da geometria de origem.';
COMMENT ON COLUMN clean.escola_influencia.tier IS 'buffer (Tier 1) | isocrona (Tier 2, reservado).';
COMMENT ON COLUMN clean.escola_influencia.raio_m IS 'Raio do buffer em metros (tier=buffer).';
COMMENT ON COLUMN clean.escola_influencia.geom IS 'Polígono da área de influência, SIRGAS 2000 (4674), em graus — área em metros via ::geography.';
COMMENT ON COLUMN clean.escola_influencia.versao IS 'Versão da metodologia (influencia-v1).';
COMMENT ON COLUMN clean.escola_influencia.computado_em IS 'Quando a geometria foi (re)calculada.';

CREATE INDEX ix_escola_influencia_geom ON clean.escola_influencia USING GIST (geom);
CREATE INDEX ix_escola_influencia_ano  ON clean.escola_influencia (nu_ano_censo, tier, raio_m);

-- ---------------------------------------------------------------------------
-- refresh_escola_influencia(): (re)materializa os buffers de forma idempotente.
--
--   p_raios        raios em metros a gerar (default: os três da metodologia)
--   p_co_entidades filtro opcional por escola (testes / refresh incremental)
--
-- Devolve o número de linhas afetadas. Não apaga raios que não foram pedidos.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION clean.refresh_escola_influencia(
  p_raios        integer[] DEFAULT ARRAY[500, 1000, 2000],
  p_co_entidades bigint[]  DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_n integer;
BEGIN
  IF p_raios IS NULL OR array_length(p_raios, 1) IS NULL THEN
    RAISE EXCEPTION 'p_raios não pode ser nulo/vazio';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(p_raios) r WHERE r <= 0) THEN
    RAISE EXCEPTION 'raio precisa ser > 0';
  END IF;

  INSERT INTO clean.escola_influencia
    (co_entidade, nu_ano_censo, tier, raio_m, geom, versao, computado_em)
  SELECT
    e.co_entidade,
    e.nu_ano_censo,
    'buffer',
    r.raio,
    ST_Buffer(e.geometry::geography, r.raio)::geometry,
    'influencia-v1',
    now()
  FROM clean.censo_escolas e
  CROSS JOIN unnest(p_raios) AS r(raio)
  WHERE e.geometry IS NOT NULL
    AND (p_co_entidades IS NULL OR e.co_entidade = ANY (p_co_entidades))
  ON CONFLICT (co_entidade, nu_ano_censo, tier, raio_m)
  DO UPDATE SET geom         = EXCLUDED.geom,
                versao       = EXCLUDED.versao,
                computado_em = EXCLUDED.computado_em;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;

COMMENT ON FUNCTION clean.refresh_escola_influencia(integer[], bigint[]) IS
'Materializa os buffers da camada de influência (influencia-v1). Idempotente (UPSERT). '
'p_raios default [500,1000,2000]; p_co_entidades opcional (refresh incremental/teste). '
'Base: clean.censo_escolas.geometry; buffer em metros via geography.';

COMMIT;
