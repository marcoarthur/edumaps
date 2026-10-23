-- Verify edumaps:isocrona_escolar_indices_minimos on pg
--
-- Gate real (issue #160): um `SELECT` que devolve 0 linhas conta como sucesso
-- no Sqitch 1.6.1, então o verify PRECISA produzir erro quando a asserção
-- falha. Aqui verificamos a ausência dos 4 índices removidos e a presença dos
-- 2 mantidos.

BEGIN;

-- Os 4 índices removidos NÃO podem existir.
DO $$
DECLARE
  v_idx text;
BEGIN
  FOREACH v_idx IN ARRAY ARRAY[
    'idx_isocrona_co_entidade',
    'idx_isocrona_grid',
    'idx_isocrona_tempo',
    'idx_isocrona_dt_snapshot'
  ] LOOP
    IF EXISTS (
      SELECT 1 FROM pg_indexes
       WHERE schemaname = 'clean'
         AND tablename  = 'isocrona_escolar'
         AND indexname  = v_idx
    ) THEN
      RAISE EXCEPTION 'índice % deveria ter sido removido (#295)', v_idx;
    END IF;
  END LOOP;
END $$;

-- A PK e o índice municipal DEVEM existir.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
     WHERE schemaname = 'clean' AND tablename = 'isocrona_escolar'
       AND indexname = 'pk_isocrona_escolar'
  ) THEN
    RAISE EXCEPTION 'PK pk_isocrona_escolar ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
     WHERE schemaname = 'clean' AND tablename = 'isocrona_escolar'
       AND indexname = 'idx_isocrona_codigo_ibge'
  ) THEN
    RAISE EXCEPTION 'índice idx_isocrona_codigo_ibge ausente (agregação municipal)';
  END IF;
END $$;

COMMIT;
