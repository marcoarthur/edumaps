-- Verify edumaps:edumaps_leitor_role from pg
-- requires: schemas
--
-- Falha (RAISE) se a role de leitura não existir ou se a proteção
-- transacional read-only não estiver ativa.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
    RAISE EXCEPTION 'role edumaps_leitor nao existe';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_db_role_setting s
    JOIN pg_roles r ON r.oid = s.setrole
    WHERE r.rolname = 'edumaps_leitor'
      AND s.setconfig::text LIKE '%default_transaction_read_only=on%'
  ) THEN
    RAISE EXCEPTION 'edumaps_leitor sem default_transaction_read_only=on';
  END IF;
END $$;