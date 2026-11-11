-- Verify edumaps:planos_gestao on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
DECLARE
  t text;
  n integer;
BEGIN
  FOREACH t IN ARRAY ARRAY['planos_gestao', 'planos_objetivos', 'planos_metas', 'planos_acoes', 'planos_auditoria'] LOOP
    IF to_regclass('clean.' || t) IS NULL THEN
      RAISE EXCEPTION 'planos_gestao: falta a tabela clean.%', t;
    END IF;
  END LOOP;

  -- Os vocabulários fechados são CHECKs (a API depende deles).
  SELECT count(*) INTO n FROM pg_constraint
   WHERE contype = 'c'
     AND conrelid IN ('clean.planos_gestao'::regclass, 'clean.planos_metas'::regclass, 'clean.planos_acoes'::regclass);
  IF n < 8 THEN
    RAISE EXCEPTION 'planos_gestao: esperava ao menos 8 CHECKs (tipo, situação, sentido, fonte...), encontrei %', n;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgname = 'trg_planos_acoes_meta_do_objetivo' AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'planos_gestao: falta o trigger que prende a meta da ação ao mesmo objetivo';
  END IF;

  -- Internas: o papel de leitura não lê (regra de leitor_grants_explicitos).
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
     AND has_table_privilege('edumaps_leitor', 'clean.planos_acoes', 'SELECT') THEN
    RAISE EXCEPTION 'planos_gestao: edumaps_leitor não pode ler clean.planos_acoes (dado interno)';
  END IF;
END
$$;

ROLLBACK;
