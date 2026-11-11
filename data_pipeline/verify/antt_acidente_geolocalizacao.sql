-- Verify edumaps:antt_acidente_geolocalizacao on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
DECLARE
  n integer;
BEGIN
  IF to_regclass('clean.antt_marco_km') IS NULL THEN
    RAISE EXCEPTION 'antt_acidente_geolocalizacao: falta clean.antt_marco_km';
  END IF;

  SELECT count(*) INTO n FROM pg_attribute
   WHERE attrelid = 'clean.antt_acidente_trecho'::regclass AND NOT attisdropped
     AND attname IN ('rodovia', 'uf', 'geom', 'codigo_ibge', 'geo_metodo');
  IF n <> 5 THEN
    RAISE EXCEPTION 'antt_acidente_geolocalizacao: esperava 5 colunas de localização no acidente, encontrei %', n;
  END IF;

  IF to_regprocedure('clean.antt_geolocalizar_acidentes(numeric)') IS NULL THEN
    RAISE EXCEPTION 'antt_acidente_geolocalizacao: falta clean.antt_geolocalizar_acidentes(numeric)';
  END IF;

  -- Normalização do trecho: o contrato com o texto da fonte.
  IF clean.antt_rodovia_normalizada('BR-393/RJ') IS DISTINCT FROM 'BR-393'
     OR clean.antt_rodovia_normalizada('BR 40/MG') IS DISTINCT FROM 'BR-040'
     OR clean.antt_rodovia_normalizada('SP-330') IS NOT NULL
     OR clean.antt_uf_do_trecho('BR-393/RJ') IS DISTINCT FROM 'RJ'
     OR clean.antt_uf_do_trecho('BR-393') IS NOT NULL THEN
    RAISE EXCEPTION 'antt_acidente_geolocalizacao: normalização do trecho fora do contrato';
  END IF;

  -- Coerência: ponto e método andam juntos (a CHECK garante; aqui documenta).
  SELECT count(*) INTO n FROM clean.antt_acidente_trecho
   WHERE codigo_ibge IS NOT NULL AND geom IS NULL;
  IF n > 0 THEN
    RAISE EXCEPTION 'antt_acidente_geolocalizacao: % acidente(s) com município sem ponto', n;
  END IF;
END
$$;

ROLLBACK;
