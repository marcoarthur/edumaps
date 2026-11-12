-- Revert edumaps:rede_acesso from pg

BEGIN;
  DROP INDEX IF EXISTS clean.idx_censo_escolas_co_municipio;
  DROP TABLE clean.rede_auditoria;
  DROP TABLE clean.rede_convites;
  DROP TABLE clean.rede_vinculos;
  UPDATE clean.gestores SET access_role = 'gestor' WHERE access_role = 'rede';
  ALTER TABLE clean.gestores DROP CONSTRAINT gestores_access_role_check;
  ALTER TABLE clean.gestores ADD CONSTRAINT gestores_access_role_check
    CHECK (access_role IN ('gestor', 'admin'));
COMMIT;
