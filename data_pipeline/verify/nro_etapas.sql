-- Verify edumaps:nro_etapas on pg

BEGIN;

  SELECT column_name 
  FROM information_schema.columns 
  WHERE table_schema = 'clean' 
    AND table_name = 'censo_escolas' 
    AND column_name = 'nro_etapas';

ROLLBACK;
