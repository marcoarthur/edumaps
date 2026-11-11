-- Revert edumaps:antt_acidente_geolocalizacao from pg

BEGIN;

DROP FUNCTION clean.antt_geolocalizar_acidentes(NUMERIC);
DROP FUNCTION clean.antt_uf_do_trecho(TEXT);
DROP FUNCTION clean.antt_rodovia_normalizada(TEXT);

DROP INDEX clean.idx_antt_acidente_codigo_ibge;
DROP INDEX clean.idx_antt_acidente_rodovia_km;

ALTER TABLE clean.antt_acidente_trecho
  DROP CONSTRAINT ck_antt_acidente_geo_coerente,
  DROP CONSTRAINT ck_antt_acidente_geo_metodo,
  DROP COLUMN geo_metodo,
  DROP COLUMN codigo_ibge,
  DROP COLUMN geom,
  DROP COLUMN uf,
  DROP COLUMN rodovia;

COMMENT ON TABLE clean.antt_acidente_trecho IS 'Acidentes ANTT por trecho rodoviário. CHAVE BRUTA não tem município — JOIN OBRIGATÓRIO com antt_trecho_geodados (trecho → município via geodados ANTT).';
COMMENT ON COLUMN clean.antt_acidente_trecho.trecho IS 'Código do trecho (chave para join com geodados ANTT)';

DROP TABLE clean.antt_marco_km;

COMMIT;
