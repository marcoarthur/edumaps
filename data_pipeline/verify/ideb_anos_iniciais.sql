-- Verify edumaps:ideb_anos_iniciais on pg

BEGIN;

  -- Verifica se existem dados de fundamental I
  DO $$
  DECLARE
      count_fundamental_i INTEGER;
  BEGIN
      SELECT COUNT(*) INTO count_fundamental_i 
      FROM clean.ideb_notas_escolas 
      WHERE etapa = 'fundamental_i';
      
      RAISE NOTICE 'Fundamental I: % registros', count_fundamental_i;
      
      IF count_fundamental_i = 0 THEN
          RAISE EXCEPTION 'Nenhum dado de Fundamental I encontrado (COPY pode ter falhado)';
      END IF;
  END $$;

ROLLBACK;
