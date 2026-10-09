-- Verify edumaps:siconfi_despesa_dca on pg
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION): um SELECT
-- preguiçoso devolve 'f' e o Sqitch 1.6.1 reporta 'ok' (issue #160).

BEGIN;

DO $$
DECLARE
  n_col INTEGER;
  n_pk  INTEGER;
  n_bad INTEGER;
BEGIN
  -- 1) A coluna inventada para a fonte antiga não pode existir mais
  SELECT count(*) INTO n_col
    FROM information_schema.columns
   WHERE table_schema = 'clean'
     AND table_name   = 'siconfi_despesa'
     AND column_name  = 'coluna_despesa';
  IF n_col > 0 THEN
    RAISE EXCEPTION 'siconfi_despesa_dca: coluna_despesa ainda existe em clean.siconfi_despesa';
  END IF;

  -- 2) PK com o nome esperado (o verify da change original depende dele)
  SELECT count(*) INTO n_pk
    FROM information_schema.table_constraints
   WHERE table_schema    = 'clean'
     AND table_name      = 'siconfi_despesa'
     AND constraint_type = 'PRIMARY KEY'
     AND constraint_name = 'pk_siconfi_despesa';
  IF n_pk = 0 THEN
    RAISE EXCEPTION 'siconfi_despesa_dca: pk_siconfi_despesa ausente em clean.siconfi_despesa';
  END IF;

  -- 3) Contrato do dado (só morde se houver linhas fora dele): função
  --    1..28 e subfuncao = 0 (linha de função).
  SELECT count(*) INTO n_bad
    FROM clean.siconfi_despesa
   WHERE funcao NOT BETWEEN 1 AND 28
      OR subfuncao <> 0;
  IF n_bad > 0 THEN
    RAISE EXCEPTION 'siconfi_despesa_dca: % linhas fora do contrato (funcao 1..28, subfuncao=0)', n_bad;
  END IF;
END $$;

ROLLBACK;