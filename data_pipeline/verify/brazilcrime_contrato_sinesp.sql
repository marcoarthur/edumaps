-- Verify edumaps:brazilcrime_contrato_sinesp to pg
--
-- Assercoes em DO/RAISE EXCEPTION, nao SELECT.
--
-- Razao (medida contra Sqitch 1.6.1): o sqitch considera o verify
-- bem-sucedido se o script nao produzir ERRO. Um SELECT que devolve
-- `f` conta como sucesso. A change analytics_ausencia_visivel (#154)
-- usa esta forma por esse motivo, e e a mesma aqui.

-- 1. As 5 colunas sem evento na fonte nao podem voltar a existir.
DO $$
DECLARE
 v TEXT;
BEGIN
  SELECT string_agg(c.column_name, ', ' ORDER BY c.column_name)
    INTO v
  FROM information_schema.columns c
  WHERE c.table_schema = 'clean'
    AND c.table_name   = 'brazilcrime_municipio'
    AND c.column_name IN ('homicidio_culposo','furto_outros','estelionato',
                          'ameaca','violacao_domicilio');
  IF v IS NOT NULL THEN
    RAISE EXCEPTION
      'REGRESSAO: colunas sem evento na fonte SINESP voltaram a existir: %', v;
  END IF;
END $$;

-- 2. A lesao_corporal original nao pode existir: o nome e mais largo
--    do que o conteudo, e foi por isso que foi renomeada.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='clean' AND table_name='brazilcrime_municipio'
                AND column_name='lesao_corporal') THEN
    RAISE EXCEPTION
      'REGRESSAO: lesao_corporal voltou a existir; a fonte so publica "Lesao corporal seguida de morte"';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='clean' AND table_name='brazilcrime_municipio'
                    AND column_name='lesao_corporal_seguida_de_morte') THEN
    RAISE EXCEPTION
      'REGRESSAO: lesao_corporal_seguida_de_morte nao existe';
  END IF;
END $$;

-- 3. O nome antigo do roubo nao pode voltar.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_schema='clean' AND table_name='brazilcrime_municipio'
                AND column_name='roubo_outros') THEN
    RAISE EXCEPTION
      'REGRESSAO: roubo_outros voltou a existir; a fonte so publica "Roubo a instituicao financeira", portanto "outros" mente sobre o conteudo';
  END IF;
END $$;

-- 4. Toda a coluna tem de estar documentada. Uma coluna sem COMMENT e
--    uma coluna cuja origem ninguem sabe.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(c.column_name, ', ' ORDER BY c.column_name)
    INTO v
  FROM information_schema.columns c
  JOIN pg_class r ON r.relname = c.table_name
  JOIN pg_namespace n ON n.oid = r.relnamespace AND n.nspname = c.table_schema
  WHERE c.table_schema='clean' AND c.table_name='brazilcrime_municipio'
    AND col_description(r.oid, c.ordinal_position) IS NULL;
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'colunas sem COMMENT: %', v;
  END IF;
END $$;

-- 5. O COMMENT da tabela tem de dizer de onde vem o dado. Sem isto,
--    um leitor futuro pode tomar "BrazilCrime/CRAN" por fonte primaria.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT obj_description(c.oid, 'pg_class') INTO v
  FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='clean' AND c.relname='brazilcrime_municipio';

  IF v IS NULL OR v !~* 'SINESP' THEN
    RAISE EXCEPTION
      'COMMENT da tabela nao identifica o SINESP como fonte real: %', coalesce(v,'(nulo)');
  END IF;
  IF v ~* 'SSP' AND v !~* 'SSP/Minist' THEN
    RAISE EXCEPTION
      'COMMENT da tabela ainda atribui o dado a SSP/IBGE: %', v;
  END IF;
END $$;

-- 6. Nenhum consumidor pode depender das colunas removidas.
--
--    Medido contra PostgreSQL 16.15: uma VIEW que referencie uma coluna
--    a remover faz o proprio DROP falhar, portanto nao chega aqui. O
--    caso perigoso e o CORPO DE UMA FUNCAO, que o Postgres nao
--    rastreia como dependencia: a funcao sobrevive ao DROP e passa a
--    falhar em runtime, sem erro em lado nenhum. Verificado nesta base:
--    apos o deploy, analytics.fn_estelionato continuava a existir e a
--    falhar so ao ser chamada.
--
--    Por isso esta assercao varre os dois: definicoes de view E prosrc
--    de funcoes. E uma varredura textual porque o Postgres nao guarda
--    a dependencia -- mas falhar alto aqui e melhor do que deixar a
--    peca partir no utilizador.
DO $$
DECLARE
  v_cols CONSTANT TEXT :=
    'homicidio_culposo|furto_outros|estelionato|ameaca|violacao_domicilio';
  v_found TEXT;
BEGIN
  -- 6a. definicoes de view
  SELECT string_agg(DISTINCT vn.nspname || '.' || vw.relname, ', ')
    INTO v_found
  FROM pg_rewrite r
  JOIN pg_class vw    ON vw.oid = r.ev_class
  JOIN pg_namespace vn ON vn.oid = vw.relnamespace
  WHERE r.ev_class <> (SELECT oid FROM pg_class WHERE relname = 'brazilcrime_municipio')
    AND vn.nspname IN ('clean','analytics','public')
    AND pg_get_viewdef(r.ev_class, true) ~* v_cols
    AND pg_get_viewdef(r.ev_class, true) ~* 'brazilcrime_municipio';

  IF v_found IS NOT NULL THEN
    RAISE EXCEPTION 'views ainda referenciam colunas removidas: %', v_found;
  END IF;

  -- 6b. corpos de funcao (nao rastreados pelo Postgres)
  SELECT string_agg(DISTINCT n.nspname || '.' || p.proname, ', ')
    INTO v_found
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('clean','analytics','public')
    AND p.prosrc ~* 'brazilcrime_municipio'
    AND p.prosrc ~* v_cols;

  IF v_found IS NOT NULL THEN
    RAISE EXCEPTION
      'funcoes ainda referenciam colunas removidas e vao falhar em runtime: %', v_found;
  END IF;
END $$;

-- 7. Se a tabela ja tiver linhas, este DROP de colunas foi destrutivo
--    e o change devia ter vindo acompanhado de um dump. Falhar alto
--    e melhor do que perder dado em silencio.
DO $$
DECLARE
  v BIGINT;
BEGIN
  SELECT count(*) INTO v FROM clean.brazilcrime_municipio;
  IF v > 0 THEN
    RAISE EXCEPTION
      'a tabela tem % linhas: o drop de colunas foi destrutivo sem dump', v;
  END IF;
END $$;