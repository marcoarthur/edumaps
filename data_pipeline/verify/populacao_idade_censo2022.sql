-- Verify edumaps:populacao_idade_censo2022 on pg

DO $$
BEGIN
  PERFORM populacao_total, populacao_0_3, populacao_4_5, populacao_6_14, populacao_15_17
     FROM clean.populacao_idade WHERE false;
  IF NOT has_table_privilege('edumaps_leitor', 'clean.populacao_idade', 'SELECT') THEN
    RAISE EXCEPTION 'edumaps_leitor sem SELECT em clean.populacao_idade';
  END IF;
  IF col_description('clean.populacao_municipal'::regclass,
       (SELECT attnum FROM pg_attribute WHERE attrelid = 'clean.populacao_municipal'::regclass
          AND attname = 'faixa_0_4_anos')) NOT LIKE '%sem fonte%' THEN
    RAISE EXCEPTION 'faixa_0_4_anos sem o comentário da origem (#533)';
  END IF;
END $$;
