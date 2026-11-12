-- Verify edumaps:planos_evidencias on pg
-- (DO + RAISE: o sqitch só falha a verificação com erro)

BEGIN;

DO $$
BEGIN
  IF to_regclass('clean.planos_evidencias') IS NULL THEN
    RAISE EXCEPTION 'planos_evidencias: falta clean.planos_evidencias';
  END IF;
  -- origem apagada não apaga a evidência
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'clean.planos_evidencias'::regclass AND contype = 'f'
         AND confrelid IN ('clean.reunioes'::regclass, 'clean.escola_documentos_versoes'::regclass)
         AND confdeltype = 'n') <> 2 THEN
    RAISE EXCEPTION 'planos_evidencias: reunião e versão de documento precisam de ON DELETE SET NULL';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_planos_evidencias_dono') THEN
    RAISE EXCEPTION 'planos_evidencias: falta o CHECK de ação ou meta';
  END IF;
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'edumaps_leitor')
     AND has_table_privilege('edumaps_leitor', 'clean.planos_evidencias', 'SELECT') THEN
    RAISE EXCEPTION 'planos_evidencias: edumaps_leitor não pode ler clean.planos_evidencias';
  END IF;
END
$$;

ROLLBACK;
