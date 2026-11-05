-- Verify edumaps:leitor_grants_explicitos on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
    RETURN;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_default_acl d
      CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE d.defaclnamespace = 'clean'::regnamespace
       AND a.grantee = 'edumaps_leitor'::regrole
  ) THEN
    RAISE EXCEPTION 'edumaps_leitor ainda tem privilégio automático em clean';
  END IF;
  -- as permissões explícitas continuam
  IF to_regclass('clean.censo_escolas') IS NOT NULL
     AND NOT has_table_privilege('edumaps_leitor', 'clean.censo_escolas', 'SELECT') THEN
    RAISE EXCEPTION 'edumaps_leitor perdeu clean.censo_escolas';
  END IF;
  -- analytics mantém o automático
  IF NOT EXISTS (
    SELECT 1 FROM pg_default_acl d
      CROSS JOIN LATERAL aclexplode(d.defaclacl) a
     WHERE d.defaclnamespace = 'analytics'::regnamespace
       AND a.grantee = 'edumaps_leitor'::regrole
  ) THEN
    RAISE EXCEPTION 'edumaps_leitor perdeu o privilégio automático em analytics';
  END IF;
END
$$;

ROLLBACK;
