-- Verify edumaps:gestor_pesquisas from pg
-- requires: schemas
-- Verificação que FALHA MESMO (DO … RAISE EXCEPTION) — ver issue #160.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    SELECT count(*) INTO n
    FROM information_schema.tables
    WHERE table_schema = 'clean'
      AND table_name IN ('gestores', 'gestor_pesquisas', 'gestor_pesquisas_perguntas');
    IF n <> 3 THEN
        RAISE EXCEPTION 'gestor_pesquisas: esperava 3 tabelas (gestores, gestor_pesquisas, gestor_pesquisas_perguntas), encontrei %', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'gestor_pesquisas'
      AND column_name IN ('id', 'cod_inep', 'gestor_id', 'titulo', 'descricao',
                          'status', 'created_at', 'updated_at');
    IF n <> 8 THEN
        RAISE EXCEPTION 'gestor_pesquisas: esperava 8 colunas em gestor_pesquisas, encontrei %', n;
    END IF;

    SELECT count(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'clean' AND table_name = 'gestor_pesquisas_perguntas'
      AND column_name IN ('id', 'pesquisa_id', 'ordem', 'texto', 'tipo',
                          'obrigatoria', 'opcoes');
    IF n <> 7 THEN
        RAISE EXCEPTION 'gestor_pesquisas: esperava 7 colunas em gestor_pesquisas_perguntas, encontrei %', n;
    END IF;
END $$;

ROLLBACK;
