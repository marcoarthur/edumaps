-- Deploy edumaps:antt_acidente_geolocalizacao to pg
-- requires: staging_schema
-- requires: antt_acidente_trecho_grao
-- requires: malha_municipio
--
-- #168: o acidente da ANTT chega sem município. A fonte traz só o trecho
-- (`BR-393/RJ`) e o km (`112,4`). O desenho original resolvia isso por uma
-- tabela de trechos com geometria (`antt_trecho_geodados`), mas a ANTT não
-- publica geometria de trecho; publica uma camada de PONTOS de km.
--
-- Esta change:
--   1. cria `clean.antt_marco_km` — um ponto por (rodovia, UF, km), da camada
--      de marcos quilométricos da ANTT;
--   2. acrescenta ao acidente a rodovia e a UF lidas do trecho, o ponto, o
--      município e o método da localização;
--   3. cria `clean.antt_geolocalizar_acidentes()`, que localiza todos os
--      acidentes de uma vez (o job ANTT chama-a depois de cada carga).
--
-- Localização do acidente (rodovia R, UF U, km K):
--   * há marco em K                          → ponto do marco      ('marco')
--   * há marcos vizinhos em K1 < K < K2, com
--     K2 − K1 ≤ tolerância (padrão 2 km)     → ponto interpolado   ('interpolado')
--   * qualquer outro caso                     → sem ponto (NULL)
-- O município é o polígono de `malha_municipio` que contém o ponto. Acidente
-- sem ponto, ou com ponto fora da malha, fica com `codigo_ibge` NULL: nunca é
-- atribuído a um município por aproximação (#154).

BEGIN;

CREATE TABLE clean.antt_marco_km (
    id_marco        BIGSERIAL PRIMARY KEY,
    rodovia         TEXT NOT NULL,               -- normalizada: 'BR-393'
    uf              CHAR(2) NOT NULL,
    km              NUMERIC(10,3) NOT NULL,
    concessionaria  TEXT,                        -- quando a camada informa
    geom            geometry(Point, 4674) NOT NULL,
    dt_carga        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_antt_marco_km UNIQUE (rodovia, uf, km)
);

CREATE INDEX idx_antt_marco_km_geom ON clean.antt_marco_km USING GIST (geom);

COMMENT ON TABLE clean.antt_marco_km IS
'Marcos quilométricos das rodovias federais concedidas (camada de pontos de km da ANTT). Um ponto por (rodovia, UF, km). Serve para localizar o acidente da ANTT, que só traz trecho e km (#168).';
COMMENT ON COLUMN clean.antt_marco_km.rodovia IS 'Rodovia normalizada (BR-NNN), mesma forma de antt_acidente_trecho.rodovia';
COMMENT ON COLUMN clean.antt_marco_km.km IS 'Quilômetro do marco na quilometragem da rodovia dentro da UF';

-- Colunas de localização do acidente.
ALTER TABLE clean.antt_acidente_trecho
  ADD COLUMN rodovia     TEXT,
  ADD COLUMN uf          CHAR(2),
  ADD COLUMN geom        geometry(Point, 4674),
  ADD COLUMN codigo_ibge TEXT,
  ADD COLUMN geo_metodo  TEXT,
  ADD CONSTRAINT ck_antt_acidente_geo_metodo
    CHECK (geo_metodo IS NULL OR geo_metodo IN ('marco', 'interpolado')),
  ADD CONSTRAINT ck_antt_acidente_geo_coerente
    CHECK ((geom IS NULL) = (geo_metodo IS NULL));

CREATE INDEX idx_antt_acidente_rodovia_km ON clean.antt_acidente_trecho (rodovia, uf, km);
CREATE INDEX idx_antt_acidente_codigo_ibge ON clean.antt_acidente_trecho (codigo_ibge);

COMMENT ON TABLE clean.antt_acidente_trecho IS
'Acidentes em rodovias federais concedidas (ANTT), um por evento. A fonte não traz município: rodovia/UF saem do trecho, o ponto sai dos marcos de km (clean.antt_marco_km) e o município do polígono que contém o ponto. Ver clean.antt_geolocalizar_acidentes() (#168).';
COMMENT ON COLUMN clean.antt_acidente_trecho.trecho IS 'Trecho como a fonte publica (ex.: BR-393/RJ)';
COMMENT ON COLUMN clean.antt_acidente_trecho.rodovia IS 'Rodovia lida do trecho, normalizada (BR-NNN); NULL se o trecho não segue o padrão BR-NNN/UF';
COMMENT ON COLUMN clean.antt_acidente_trecho.uf IS 'UF lida do trecho';
COMMENT ON COLUMN clean.antt_acidente_trecho.geom IS 'Ponto do acidente: marco do km ou interpolado entre marcos vizinhos; NULL se não localizável';
COMMENT ON COLUMN clean.antt_acidente_trecho.codigo_ibge IS 'Município que contém o ponto (malha_municipio); NULL sem ponto ou com ponto fora da malha — nunca por aproximação (#154)';
COMMENT ON COLUMN clean.antt_acidente_trecho.geo_metodo IS 'marco | interpolado | NULL (não localizado)';

-- Rodovia normalizada a partir do texto do trecho: 'BR-393/RJ', 'BR 040/MG',
-- 'BR-40/MG' → 'BR-393', 'BR-040', 'BR-040'. NULL fora do padrão.
CREATE FUNCTION clean.antt_rodovia_normalizada(p_texto TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT 'BR-' || lpad(m[1], 3, '0')
  FROM regexp_match(upper(coalesce(p_texto, '')), '^\s*BR\s*-?\s*0*(\d{1,3})\M') AS m
  WHERE m IS NOT NULL
$$;

-- UF a partir do texto do trecho ('BR-393/RJ' → 'RJ'). NULL fora do padrão.
CREATE FUNCTION clean.antt_uf_do_trecho(p_texto TEXT) RETURNS CHAR(2)
LANGUAGE sql IMMUTABLE AS $$
  SELECT m[1]::char(2)
  FROM regexp_match(upper(coalesce(p_texto, '')), '/\s*([A-Z]{2})\s*$') AS m
  WHERE m IS NOT NULL
$$;

CREATE FUNCTION clean.antt_geolocalizar_acidentes(p_tolerancia_km NUMERIC DEFAULT 2)
RETURNS TABLE (situacao TEXT, n BIGINT)
LANGUAGE plpgsql AS $$
BEGIN
  -- 1. Rodovia e UF lidas do trecho; a localização anterior é descartada
  --    (os marcos podem ter mudado desde a última carga).
  UPDATE clean.antt_acidente_trecho a
     SET rodovia     = clean.antt_rodovia_normalizada(a.trecho),
         uf          = clean.antt_uf_do_trecho(a.trecho),
         geom        = NULL,
         codigo_ibge = NULL,
         geo_metodo  = NULL;

  -- 2. Ponto: marco exato, ou interpolação entre os dois marcos vizinhos da
  --    mesma rodovia/UF se a distância entre eles não passa da tolerância.
  WITH loc AS (
    SELECT a.id_acidente,
           CASE
             WHEN lo.km = a.km THEN lo.geom
             WHEN hi.km = a.km THEN hi.geom
             WHEN hi.km - lo.km <= p_tolerancia_km THEN
               ST_LineInterpolatePoint(ST_MakeLine(lo.geom, hi.geom),
                                       ((a.km - lo.km) / (hi.km - lo.km))::float8)
           END AS geom,
           CASE
             WHEN lo.km = a.km OR hi.km = a.km THEN 'marco'
             WHEN hi.km - lo.km <= p_tolerancia_km THEN 'interpolado'
           END AS metodo
      FROM clean.antt_acidente_trecho a
      LEFT JOIN LATERAL (
        SELECT m.km, m.geom FROM clean.antt_marco_km m
         WHERE m.rodovia = a.rodovia AND m.uf = a.uf AND m.km <= a.km
         ORDER BY m.km DESC LIMIT 1) lo ON TRUE
      LEFT JOIN LATERAL (
        SELECT m.km, m.geom FROM clean.antt_marco_km m
         WHERE m.rodovia = a.rodovia AND m.uf = a.uf AND m.km >= a.km
         ORDER BY m.km ASC LIMIT 1) hi ON TRUE
     WHERE a.rodovia IS NOT NULL AND a.uf IS NOT NULL AND a.km IS NOT NULL
  )
  UPDATE clean.antt_acidente_trecho a
     SET geom = loc.geom, geo_metodo = loc.metodo
    FROM loc
   WHERE a.id_acidente = loc.id_acidente
     AND loc.geom IS NOT NULL;

  -- 3. Município: o polígono que contém o ponto. Ponto na divisa de dois
  --    municípios fica com o de menor código (determinístico).
  UPDATE clean.antt_acidente_trecho a
     SET codigo_ibge = (
       SELECT mm.codigo_ibge FROM clean.malha_municipio mm
        WHERE ST_Covers(mm.geometry, a.geom)
        ORDER BY mm.codigo_ibge LIMIT 1)
   WHERE a.geom IS NOT NULL;

  -- 4. Balanço: quem não foi localizado aparece contado, nunca some.
  RETURN QUERY
    SELECT s.situacao, count(*)
      FROM (
        SELECT CASE
                 WHEN a.rodovia IS NULL OR a.uf IS NULL THEN 'trecho_ilegivel'
                 WHEN a.km IS NULL                      THEN 'sem_km'
                 WHEN a.geom IS NULL                    THEN 'sem_marco'
                 WHEN a.codigo_ibge IS NULL             THEN 'fora_da_malha'
                 ELSE a.geo_metodo
               END AS situacao
          FROM clean.antt_acidente_trecho a
      ) s
     GROUP BY s.situacao
     ORDER BY s.situacao;
END
$$;

COMMENT ON FUNCTION clean.antt_geolocalizar_acidentes(NUMERIC) IS
'Localiza os acidentes da ANTT pelos marcos de km (clean.antt_marco_km) e atribui o município pela malha. Devolve o balanço por situação: marco, interpolado, sem_marco, sem_km, trecho_ilegivel, fora_da_malha (#168).';

-- Tabela pública (camada aberta da ANTT, sem dado pessoal): legível pelo
-- papel de leitura, conforme a regra de leitor_grants_explicitos.
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
    GRANT SELECT ON clean.antt_marco_km TO edumaps_leitor;
  END IF;
END
$$;

COMMIT;
