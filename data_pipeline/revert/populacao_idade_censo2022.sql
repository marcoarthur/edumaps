-- Revert edumaps:populacao_idade_censo2022 from pg

BEGIN;

DROP VIEW IF EXISTS clean.populacao_idade;

-- Comentários anteriores das faixas (raw_populacao_faixas_etarias).
DO $$
DECLARE
  col record;
  rotulo text;
BEGIN
  FOR col IN
    SELECT attname FROM pg_attribute
     WHERE attrelid = 'clean.populacao_municipal'::regclass
       AND attname LIKE 'faixa\_%' AND NOT attisdropped
  LOOP
    rotulo := CASE WHEN col.attname = 'faixa_100_mais' THEN '100 anos ou mais'
                   ELSE replace(regexp_replace(col.attname, '^faixa_(\d+)_(\d+)_anos$', '\1 a \2 anos'), '_', ' ') END;
    EXECUTE format('COMMENT ON COLUMN clean.populacao_municipal.%I IS %L',
      col.attname, 'População de ' || rotulo || ' - Fonte: IBGE');
  END LOOP;
END $$;

COMMIT;
