-- Deploy edumaps:leitor_grants_explicitos to pg
-- requires: auth_falhas_telegram
--
-- O papel edumaps_leitor (Assistente do Censo e relatórios do motor R)
-- recebia SELECT automaticamente em toda tabela nova do schema clean, via
-- ALTER DEFAULT PRIVILEGES da edumaps_leitor_role. Uma tabela nova com dado
-- pessoal ficava legível até alguém lembrar de revogar.
--
-- Esta change tira os privilégios automáticos do papel no schema clean
-- (tabelas e sequências), para todo quem os concedeu (o dono varia entre
-- ambientes). As permissões já concedidas ficam como estão.
--
-- Regra a partir daqui:
--   * tabela nova PÚBLICA em clean → GRANT SELECT ... TO edumaps_leitor na
--     própria migração;
--   * tabela com dado pessoal ou interna → sem GRANT, e o nome entra na lista
--     de sensíveis de backend/t/02-models/leitor_grants.t.
-- O teste falha no CI se uma relação de clean não tiver uma das duas decisões.
--
-- O schema analytics mantém o privilégio automático: só tem agregados
-- públicos, e as views materializadas são recriadas com frequência.

BEGIN;

  DO $$
  DECLARE r record;
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor') THEN
      RETURN;
    END IF;
    FOR r IN
      SELECT DISTINCT pg_get_userbyid(d.defaclrole) AS dono, d.defaclobjtype AS tipo
        FROM pg_default_acl d
        CROSS JOIN LATERAL aclexplode(d.defaclacl) a
       WHERE d.defaclnamespace = 'clean'::regnamespace
         AND a.grantee = 'edumaps_leitor'::regrole
    LOOP
      EXECUTE format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA clean REVOKE ALL ON %s FROM edumaps_leitor',
        r.dono,
        CASE r.tipo WHEN 'r' THEN 'TABLES' WHEN 'S' THEN 'SEQUENCES'
                    WHEN 'f' THEN 'FUNCTIONS' WHEN 'T' THEN 'TYPES' END
      );
    END LOOP;
  END
  $$;

COMMIT;
