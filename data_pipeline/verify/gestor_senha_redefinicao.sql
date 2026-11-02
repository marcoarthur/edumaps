-- Verify edumaps:gestor_senha_redefinicao on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.senha_redefinicoes') IS NULL THEN
    RAISE EXCEPTION 'falta a tabela clean.senha_redefinicoes';
  END IF;
  IF pg_get_constraintdef((SELECT oid FROM pg_constraint
        WHERE conname = 'auth_falhas_escopo_check')) NOT LIKE '%reset_email%' THEN
    RAISE EXCEPTION 'auth_falhas não aceita o escopo reset_email';
  END IF;
END
$$;

ROLLBACK;
