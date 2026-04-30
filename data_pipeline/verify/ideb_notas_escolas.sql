-- Verify edumaps:ideb_notas_escolas on pg

BEGIN;

  -- Verifica existência da tabela
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'clean'
    AND table_name = 'ideb_notas_escolas';

  -- Verifica existência da coluna chave
  SELECT 1 FROM information_schema.columns
  WHERE table_schema = 'clean'
    AND table_name = 'ideb_notas_escolas'
    AND column_name = 'id_escola';

  -- Verifica se há dados carregados (fundamental II e ensino médio)
  DO $$
  DECLARE
      count_fundamental INTEGER;
      count_medio INTEGER;
  BEGIN
      SELECT COUNT(*) INTO count_fundamental 
      FROM clean.ideb_notas_escolas 
      WHERE etapa = 'fundamental_ii';
      
      SELECT COUNT(*) INTO count_medio 
      FROM clean.ideb_notas_escolas 
      WHERE etapa = 'ensino_medio';
      
      RAISE NOTICE 'Fundamental II: % registros, Ensino Médio: % registros', count_fundamental, count_medio;
      
      IF count_fundamental = 0 AND count_medio = 0 THEN
          RAISE EXCEPTION 'Nenhum dado encontrado na tabela clean.ideb_notas_escolas (COPY pode ter falhado)';
      END IF;
  END $$;

ROLLBACK;
