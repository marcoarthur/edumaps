-- Verify edumaps:inse_2023 on pg

BEGIN;

  DO $$
  BEGIN
      IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                     WHERE table_schema = 'clean' AND table_name = 'inse') THEN
          RAISE EXCEPTION 'Tabela clean.inse não encontrada';
      END IF;
      
      IF (SELECT COUNT(*) FROM clean.inse WHERE nu_ano_saeb = 2023) = 0 THEN
          RAISE EXCEPTION 'Nenhum registro para o ano 2023 na tabela clean.inse';
      END IF;
      
      -- Verifica se a chave primária está definida
      IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                     WHERE constraint_type = 'PRIMARY KEY' 
                       AND table_schema = 'clean' 
                       AND table_name = 'inse') THEN
          RAISE EXCEPTION 'Chave primária não encontrada em clean.inse';
      END IF;
  END $$;
ROLLBACK;
