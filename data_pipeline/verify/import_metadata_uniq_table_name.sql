-- Verify edumaps:import_metadata_uniq_table_name to pg
--
-- Asserções em DO/RAISE EXCEPTION, nunca SELECT (ver AGENTS.md: um
-- SELECT que devolve 'f' conta como sucesso para o Sqitch, e portanto
-- passaria com o defeito presente).

-- 1. A restrição de unicidade tem de existir. É isto que torna o
--    ON CONFLICT (table_name) do Base.pm legal em vez de um erro.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM pg_constraint c
      JOIN pg_class t   ON t.oid = c.conrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE n.nspname = 'clean'
       AND t.relname = 'import_metadata'
       AND c.contype  = 'u'
       AND c.conkey = ARRAY[
             (SELECT attnum FROM pg_attribute
               WHERE attrelid = t.oid AND attname = 'table_name')]::smallint[]
  ) THEN
    RAISE EXCEPTION
      'REGRESSAO: clean.import_metadata nao tem unicidade em table_name -- o ON CONFLICT (table_name) de upsert_metadata() volta a falhar em TODOS os jobs';
  END IF;
END $$;

-- 2. Não pode haver duplicados: a restrição acabaria de os impedir,
--    mas um estado já sujo esconderia o que se verificou.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(table_name, ', ') INTO v
    FROM (SELECT table_name FROM clean.import_metadata
           GROUP BY table_name HAVING count(*) > 1) d;

  IF v IS NOT NULL THEN
    RAISE EXCEPTION
      'REGRESSAO: clean.import_metadata tem table_name duplicado: %', v;
  END IF;
END $$;

-- 3. Sanidade: a deduplicação não pode ter comido a tabela toda.
--    Medido antes do deploy: 32 linhas, 1 duplicado
--    (clean.censo_data_dictionary) -> 31 linhas distintas.
DO $$
DECLARE
  n INT;
BEGIN
  SELECT count(*) INTO n FROM clean.import_metadata;
  IF n <> 31 THEN
    RAISE EXCEPTION
      'REGRESSAO: clean.import_metadata tem % linhas (esperado 31 -- 32 antes do deploy, menos 1 duplicado removido)', n;
  END IF;
END $$;

-- 4. O upsert_metadata tem de correr a sério. Um SELECT sobre a
--    constraint passa mesmo que o Base.pm escreva SQL inválido, e
--    foi exactamente por isso que o defeito durou: o Base.pm foi
--    escrito com um ON CONFLICT que a tabela nunca suportou, e nada
--    o executou até agora.
--    Este teste faz o ON CONFLICT real e desfaz.
DO $$
DECLARE
  n INT;
BEGIN
  INSERT INTO clean.import_metadata (table_name, source_file, notes)
  VALUES ('__verify_import_metadata_uniq__', '__verify__', 'verificacao temporaria')
  ON CONFLICT (table_name) DO UPDATE SET notes = 'verificacao temporaria';

  SELECT count(*) INTO n FROM clean.import_metadata
   WHERE table_name = '__verify_import_metadata_uniq__';
  IF n <> 1 THEN
    RAISE EXCEPTION
      'REGRESSAO: o ON CONFLICT (table_name) de upsert_metadata() deixou %d linhas (esperado 1)', n;
  END IF;

  DELETE FROM clean.import_metadata WHERE table_name = '__verify_import_metadata_uniq__';
END $$;