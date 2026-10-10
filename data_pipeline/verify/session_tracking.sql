-- Verify edumaps:session_tracking on pg
-- Assere de facto tabela, colunas e índice — padrão issue #160
-- (DO $$ RAISE EXCEPTION; um SELECT que devolve vazio conta como sucesso).
--
-- Schema `clean`: a migration `schemas` seta o search_path do banco com
-- `clean` primeiro, logo toda tabela não-qualificada cai em clean.* (não em
-- public). informação_schema.columns vale aqui — são tabelas, não matviews.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'session_tracking';
    IF n <> 1 THEN
        RAISE EXCEPTION 'session_tracking: tabela clean.session_tracking ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'session_tracking'
      AND column_name IN ('session_id','ip','ip_anon','user_agent','is_logged',
                          'gestor_id','first_seen_at','last_seen_at','seen_count');
    IF n <> 9 THEN
        RAISE EXCEPTION 'session_tracking: colunas ausentes (esperadas 9, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'session_tracking'
      AND indexname = 'idx_session_tracking_last_seen';
    IF n <> 1 THEN
        RAISE EXCEPTION 'session_tracking: índice idx_session_tracking_last_seen ausente';
    END IF;
END $$;

ROLLBACK;