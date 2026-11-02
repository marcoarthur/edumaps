-- Verify edumaps:auth_falhas on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.auth_falhas') IS NULL THEN
    RAISE EXCEPTION 'falta a tabela clean.auth_falhas';
  END IF;
  IF to_regclass('clean.auth_falhas_escopo_chave_idx') IS NULL THEN
    RAISE EXCEPTION 'falta o índice clean.auth_falhas_escopo_chave_idx';
  END IF;
END
$$;

ROLLBACK;
