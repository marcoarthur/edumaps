-- Verify edumaps:brazilcrime_sem_patrimoniais to pg
--
-- Asserções em DO/RAISE EXCEPTION, nao SELECT.

-- 1. As 4 colunas de crimes patrimoniais nao podem voltar a existir.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(c.column_name, ', ' ORDER BY c.column_name)
    INTO v
  FROM information_schema.columns c
  WHERE c.table_schema = 'clean'
    AND c.table_name   = 'brazilcrime_municipio'
    AND c.column_name IN ('roubo_veiculo','roubo_carga',
                          'roubo_instituicao_financeira','furto_veiculo');
  IF v IS NOT NULL THEN
    RAISE EXCEPTION
      'REGRESSAO: colunas de crimes patrimoniais voltaram a existir: %', v;
  END IF;
END $$;

-- 2. O COMMENT da tabela tem de dizer que os crimes patrimoniais nao
--    estao disponiveis por municipio.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT obj_description(c.oid, 'pg_class') INTO v
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='clean' AND c.relname='brazilcrime_municipio';

  IF v IS NULL OR v !~* 'patrimoniais' THEN
    RAISE EXCEPTION
      'COMMENT da tabela nao documenta a ausencia de crimes patrimoniais: %', coalesce(v,'(nulo)');
  END IF;
END $$;

-- 3. Nenhum consumidor pode depender das colunas removidas.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(DISTINCT n.nspname || '.' || p.proname, ', ')
    INTO v
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('clean','analytics','public')
    AND p.prosrc ~* 'brazilcrime_municipio'
    AND p.prosrc ~* 'roubo_veiculo|roubo_carga|roubo_instituicao_financeira|furto_veiculo';

  IF v IS NOT NULL THEN
    RAISE EXCEPTION
      'funcoes ainda referenciam colunas de crimes patrimoniais: %', v;
  END IF;
END $$;
