-- Verify edumaps:canal_listas_autoinscricao on pg
-- Gate no estilo issue #160: o verify SÓ passa se cada asserção falhar
-- explicitamente com RAISE EXCEPTION (um SELECT que devolve 'f' contaria como
-- sucesso). Assere as 4 tabelas, colunas esperadas, CHECKs, FKs e índices.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- ------------------------------------------------------------------
    -- 1. Tabelas existem
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean'
      AND table_name IN ('canal_listas', 'canal_qrcodes',
                         'canal_lista_membros', 'canal_inscricoes');
    IF n <> 4 THEN
        RAISE EXCEPTION 'canal_listas_autoinscricao: tabelas ausentes (esperadas 4, encontradas %)', n;
    END IF;

    -- ------------------------------------------------------------------
    -- 2. Colunas esperadas por tabela (nome e contagem)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_listas'
      AND column_name IN ('id','cod_inep','gestor_id','nome','canal',
                          'descricao','ativo','created_at','updated_at');
    IF n <> 9 THEN
        RAISE EXCEPTION 'canal_listas: colunas ausentes (esperadas 9, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_qrcodes'
      AND column_name IN ('id','lista_id','token','status','expira_em',
                          'max_usos','usos','criado_por','created_at','revogado_em');
    IF n <> 10 THEN
        RAISE EXCEPTION 'canal_qrcodes: colunas ausentes (esperadas 10, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_lista_membros'
      AND column_name IN ('id','lista_id','contato_id','origem','validado','created_at');
    IF n <> 6 THEN
        RAISE EXCEPTION 'canal_lista_membros: colunas ausentes (esperadas 6, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_inscricoes'
      AND column_name IN ('id','qrcode_id','lista_id','contato_id','nome',
                          'telefone','telefone_norm','validado','duplicado_de',
                          'conflito','ip_anon','user_agent','consentimento_em',
                          'consentimento_versao','created_at');
    IF n <> 15 THEN
        RAISE EXCEPTION 'canal_inscricoes: colunas ausentes (esperadas 15, encontradas %)', n;
    END IF;

    -- ------------------------------------------------------------------
    -- 3. CHECKs essenciais
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace ns ON ns.oid = t.relnamespace
    WHERE ns.nspname = 'clean'
      AND c.contype = 'c'
      AND c.conname IN ('canal_listas_canal_check', 'canal_qrcodes_status_check',
                        'canal_qrcodes_max_usos_check', 'canal_lista_membros_origem_check');
    IF n <> 4 THEN
        RAISE EXCEPTION 'canal_listas_autoinscricao: CHECKs essenciais ausentes (esperados 4, encontrados %)', n;
    END IF;

    -- o CHECK do max_usos precisa permitir NULL (valor do default).
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conname = 'canal_qrcodes_max_usos_check'
      AND pg_get_constraintdef(oid) LIKE '%max_usos IS NULL%';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_qrcodes_max_usos_check: deve permitir NULL (default "sem limite")';
    END IF;

    -- ------------------------------------------------------------------
    -- 4. FKs essenciais (e a regra de delete do qrcode_id = SET NULL)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace ns ON ns.oid = t.relnamespace
    WHERE ns.nspname = 'clean' AND c.contype = 'f'
      AND c.conname IN ('canal_listas_gestor_id_fkey',
                        'canal_qrcodes_lista_id_fkey', 'canal_qrcodes_criado_por_fkey',
                        'canal_lista_membros_lista_id_fkey', 'canal_lista_membros_contato_id_fkey',
                        'canal_inscricoes_qrcode_id_fkey', 'canal_inscricoes_lista_id_fkey',
                        'canal_inscricoes_contato_id_fkey', 'canal_inscricoes_duplicado_de_fkey');
    IF n <> 9 THEN
        RAISE EXCEPTION 'canal_listas_autoinscricao: FKs ausentes (esperadas 9, encontradas %)', n;
    END IF;

    -- refinamento da spec: qrcode_id nullable + ON DELETE SET NULL (never
    -- apagamos QRs; o histórico de inscrições permanece "sem descarte").
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conname = 'canal_inscricoes_qrcode_id_fkey'
      AND pg_get_constraintdef(oid) LIKE '%SET NULL%';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_inscricoes.qrcode_id: esperado ON DELETE SET NULL (refinamento da spec)';
    END IF;

    -- ------------------------------------------------------------------
    -- 5. Índices de apoio (dedupe/consulta)
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_qrcodes'
      AND indexname IN ('idx_canal_qrcodes_lista');
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_qrcodes: índice (lista_id) ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_lista_membros'
      AND indexname IN ('idx_canal_lista_membros_contato');
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_lista_membros: índice (contato_id) ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_inscricoes'
      AND indexname IN ('idx_canal_inscricoes_lista', 'idx_canal_inscricoes_telefone_norm',
                        'idx_canal_inscricoes_contato', 'idx_canal_inscricoes_qrcode');
    IF n <> 4 THEN
        RAISE EXCEPTION 'canal_inscricoes: índices ausentes (esperados 4, encontrados %)', n;
    END IF;
END $$;

ROLLBACK;