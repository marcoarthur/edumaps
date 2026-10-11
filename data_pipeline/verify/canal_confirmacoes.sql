-- Verify edumaps:canal_confirmacoes on pg
-- Assere de facto tabela, colunas e índices — padrão issue #160
-- (DO $$ RAISE EXCEPTION; um SELECT vazio conta como sucesso).
--
-- Schema `clean`: a migration `schemas` seta o search_path com `clean` primeiro,
-- logo as tabelas caem em clean.*; information_schema vale aqui (tabelas, não
-- matviews).

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean' AND table_name = 'canal_confirmacoes';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_confirmacoes: tabela clean.canal_confirmacoes ausente';
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'canal_confirmacoes'
      AND column_name IN ('id','canal','endereco','codigo_hash','salt','expira_em',
                          'confirmado_em','tentativas','contato_id','cod_inep','created_at');
    IF n <> 11 THEN
        RAISE EXCEPTION 'canal_confirmacoes: colunas ausentes (esperadas 11, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'canal_confirmacoes'
      AND indexname IN ('idx_canal_confirmacoes_lookup','idx_canal_confirmacoes_contato');
    IF n <> 2 THEN
        RAISE EXCEPTION 'canal_confirmacoes: índices ausentes (esperados 2, encontrados %)', n;
    END IF;
END $$;

ROLLBACK;
