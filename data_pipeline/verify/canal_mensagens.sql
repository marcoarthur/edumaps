-- Verify edumaps:canal_mensagens on pg
-- Assere de facto tabela, colunas e índices — padrão issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'canal_mensagens';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_mensagens: tabela clean.canal_mensagens ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_mensagens'
      AND column_name IN ('id','canal','operacao','destinatario','assunto','corpo',
                          'referente_tipo','referente_id','status','erro',
                          'provider_message_id','tentativas','contato_id','cod_inep',
                          'created_at','sent_at');
    IF n <> 16 THEN
        RAISE EXCEPTION 'canal_mensagens: colunas ausentes (esperadas 16, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_mensagens'
      AND indexname IN ('idx_canal_mensagens_canal_created','idx_canal_mensagens_contato',
                        'idx_canal_mensagens_cod_inep','idx_canal_mensagens_status');
    IF n <> 4 THEN
        RAISE EXCEPTION 'canal_mensagens: índices ausentes (esperados 4, encontrados %)', n;
    END IF;

    -- O CHECK da operação precisa refletir EduMaps::Channel::Operacoes.
    SELECT count(*) INTO n
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace ns ON ns.oid = t.relnamespace
    WHERE ns.nspname = 'clean' AND t.relname = 'canal_mensagens'
      AND c.contype = 'c' AND pg_get_constraintdef(c.oid) LIKE '%confirmacao%';
    IF n < 1 THEN
        RAISE EXCEPTION 'canal_mensagens: CHECK de operacao ausente/desatualizado';
    END IF;
END $$;

ROLLBACK;
