-- Verify edumaps:censo_turno_comments from pg

BEGIN;

  -- Nenhuma coluna de turno pode manter rótulo de deficiência (espera COUNT=0;
  -- 1/0 força erro se ainda houver alguma).
  SELECT 1/CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END FROM pg_attribute a
    WHERE a.attrelid = 'clean.censo_matriculas'::regclass
      AND a.attnum > 0 AND NOT a.attisdropped
      AND a.attname ~ '_(d|dm|dv|n)$'
      AND col_description(a.attrelid, a.attnum) LIKE '%Defici%';

  -- As colunas basais ficaram com os rótulos de turno corretos (espera COUNT=4).
  SELECT 1/COUNT(*) FROM pg_attribute a
    WHERE a.attrelid = 'clean.censo_matriculas'::regclass
      AND a.attnum > 0 AND NOT a.attisdropped
      AND a.attname IN ('qt_mat_bas_d', 'qt_mat_bas_dm', 'qt_mat_bas_dv', 'qt_mat_bas_n')
      AND col_description(a.attrelid, a.attnum) IN ('Diurno', 'Matutino', 'Vespertino', 'Noturno');

COMMIT;
