-- Verify edumaps:rede_acesso on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['rede_vinculos', 'rede_convites', 'rede_auditoria'] LOOP
    IF to_regclass('clean.' || t) IS NULL THEN
      RAISE EXCEPTION 'rede_acesso: falta clean.%', t;
    END IF;
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
       AND has_table_privilege('edumaps_leitor', 'clean.' || t, 'SELECT') THEN
      RAISE EXCEPTION 'rede_acesso: edumaps_leitor não pode ler clean.%', t;
    END IF;
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conname = 'gestores_access_role_check'
                    AND pg_get_constraintdef(oid) LIKE '%rede%') THEN
    RAISE EXCEPTION 'rede_acesso: access_role não aceita rede';
  END IF;
END
$$;

ROLLBACK;
