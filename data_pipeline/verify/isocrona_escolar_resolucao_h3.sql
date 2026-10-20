-- Verify edumaps:isocrona_escolar_resolucao_h3 on pg
--
-- DO/RAISE EXCEPTION (issue #160): tem de falhar mesmo.

BEGIN;

DO $$
DECLARE
  c TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'clean'
       AND table_name   = 'isocrona_escolar'
       AND column_name  = 'resolucao_h3'
       AND is_nullable  = 'NO'
  ) THEN
    RAISE EXCEPTION 'isocrona_escolar_resolucao_h3: coluna resolucao_h3 ausente ou anulável';
  END IF;

  c := col_description('clean.isocrona_escolar'::regclass,
                       (SELECT attnum FROM pg_attribute
                         WHERE attrelid = 'clean.isocrona_escolar'::regclass
                           AND attname  = 'resolucao_h3'));

  IF c IS NULL OR position('#278' IN c) = 0 THEN
    RAISE EXCEPTION
      'isocrona_escolar_resolucao_h3: comentário da coluna sem o rastro #278: %', c;
  END IF;
END $$;

ROLLBACK;
