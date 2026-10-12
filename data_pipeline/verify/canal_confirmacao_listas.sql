-- Verify edumaps:canal_confirmacao_listas on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Colunas checadas por pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- ------------------------------------------------------------------
    -- 1. Colunas novas nas tabelas da Fase 0
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_listas'::regclass
      AND attname = 'exige_confirmacao' AND attnum > 0 AND NOT attisdropped
      AND attnotnull;
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_listas.exige_confirmacao ausente ou anulável';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_lista_membros'::regclass
      AND attname IN ('confirmado_em', 'confirmado_via', 'telegram_chat_id')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 3 THEN
        RAISE EXCEPTION 'canal_lista_membros: colunas de confirmação ausentes (esperadas 3, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_lista_membros'::regclass
      AND contype = 'c'
      AND conname = 'canal_lista_membros_confirmado_via_check';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_lista_membros_confirmado_via_check ausente';
    END IF;

    -- ------------------------------------------------------------------
    -- 2. Tabelas novas
    -- ------------------------------------------------------------------
    IF to_regclass('clean.canal_confirmacao_refs') IS NULL THEN
        RAISE EXCEPTION 'clean.canal_confirmacao_refs ausente';
    END IF;
    IF to_regclass('clean.canal_telegram_estado') IS NULL THEN
        RAISE EXCEPTION 'clean.canal_telegram_estado ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_confirmacao_refs'::regclass
      AND attname IN ('id', 'inscricao_id', 'membro_id', 'ref_hash', 'expira_em',
                      'usada_em', 'invalidada_em', 'envios_whatsapp',
                      'telegram_chat_pendente', 'created_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 10 THEN
        RAISE EXCEPTION 'canal_confirmacao_refs: colunas ausentes (esperadas 10, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_telegram_estado'::regclass
      AND attname IN ('bot_username', 'update_offset', 'updated_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 3 THEN
        RAISE EXCEPTION 'canal_telegram_estado: colunas ausentes (esperadas 3, encontradas %)', n;
    END IF;

    -- ------------------------------------------------------------------
    -- 3. Restrições: FKs (CASCADE), UNIQUE do hash e índice por membro
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_confirmacao_refs'::regclass
      AND contype = 'f'
      AND conname IN ('canal_confirmacao_refs_inscricao_id_fkey',
                      'canal_confirmacao_refs_membro_id_fkey')
      AND pg_get_constraintdef(oid) LIKE '%ON DELETE CASCADE%';
    IF n <> 2 THEN
        RAISE EXCEPTION 'canal_confirmacao_refs: FKs com ON DELETE CASCADE ausentes (esperadas 2, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_confirmacao_refs'::regclass
      AND contype = 'u'
      AND conname = 'canal_confirmacao_refs_ref_hash_key';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_confirmacao_refs: UNIQUE (ref_hash) ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_confirmacao_refs'
      AND indexname = 'idx_canal_confirmacao_refs_membro';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_confirmacao_refs: índice (membro_id) ausente';
    END IF;
END $$;

ROLLBACK;
