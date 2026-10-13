-- Verify edumaps:comments_ingestao_p2 on pg
--
-- DO/RAISE EXCEPTION (issue #160).

BEGIN;

DO $$
DECLARE
  t TEXT;
  c TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['clean.transferencia_educ', 'clean.malha_setor_censitario',
                           'clean.censo2022_setor', 'clean.sisab_aps'] LOOP
    c := obj_description(t::regclass, 'pg_class');
    IF c IS NULL OR position('NÃO CARREGADA' IN c) > 0 OR position('#238' IN c) = 0 THEN
      RAISE EXCEPTION 'comments_ingestao_p2: % ainda diz NÃO CARREGADA ou não cita o loader (#238): %', t, c;
    END IF;
  END LOOP;

  c := col_description('clean.sisab_aps'::regclass,
         (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.sisab_aps'::regclass AND attname = 'cobertura_aps'));
  IF c IS NULL OR position('NÃO é percentual' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_ingestao_p2: sisab_aps.cobertura_aps ainda sugere percentual: %', c;
  END IF;

  c := col_description('clean.censo2022_setor'::regclass,
         (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.censo2022_setor'::regclass AND attname = 'esc_sup_comp'));
  IF c IS NULL OR position('NULL por desenho' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_ingestao_p2: censo2022_setor.esc_* não declara a ausência de fonte: %', c;
  END IF;
END $$;

ROLLBACK;
