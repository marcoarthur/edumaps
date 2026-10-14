-- Verify edumaps:comments_ingestao_p3 on pg
--
-- DO/RAISE EXCEPTION (issue #160).

BEGIN;

DO $$
DECLARE
  c TEXT;
BEGIN
  c := obj_description('clean.mapbiomas_cobertura'::regclass, 'pg_class');
  IF c IS NULL OR position('NÃO CONSTRUÍDA' IN c) > 0 OR position('Coleção 10' IN c) = 0 OR position('#241' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_ingestao_p3: mapbiomas_cobertura sem a fonte real (Coleção 10/#241): %', c;
  END IF;

  c := obj_description('clean.cnes_estabelecimentos'::regclass, 'pg_class');
  IF c IS NULL OR position('SANITIZADOS' IN c) = 0 OR position('CC BY-ND 3.0' IN c) = 0 OR position('#241' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_ingestao_p3: cnes_estabelecimentos sem sanitização/licença/#241: %', c;
  END IF;

  c := col_description('clean.cnes_estabelecimentos'::regclass,
         (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.cnes_estabelecimentos'::regclass AND attname = 'status'));
  IF c IS NULL OR position('Sempre 1' IN c) = 0 THEN
    RAISE EXCEPTION 'comments_ingestao_p3: cnes_estabelecimentos.status não declara o recorte (só ativos): %', c;
  END IF;
END $$;

ROLLBACK;
