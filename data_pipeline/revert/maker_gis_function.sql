-- Revert edumaps:maker_gis_function from pg

BEGIN;

  DROP FUNCTION IF EXISTS clean.get_cities_markers(text, integer, integer);

COMMIT;
