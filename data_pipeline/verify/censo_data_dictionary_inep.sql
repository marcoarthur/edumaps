-- Verify edumaps:censo_data_dictionary_inep on pg
--
-- Gate (issue #160): cada checagem levanta exceção; SELECT que devolve 'f'
-- passaria como sucesso no Sqitch 1.6.1. `codigo_fora_do_dominio` NÃO entra
-- aqui (dados não travam deploy): é responsabilidade do teste e da carga.

BEGIN;

DO $$
DECLARE
    faltando text;
BEGIN
    -- 1) Coluna origem existe.
    IF NOT EXISTS (
        SELECT 1 FROM pg_attribute
        WHERE attrelid = 'clean.censo_data_dictionary'::regclass
          AND attname = 'origem' AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION 'clean.censo_data_dictionary.origem não existe';
    END IF;

    -- 2) Função de violações existe.
    IF to_regprocedure('clean.censo_dict_violacoes()') IS NULL THEN
        RAISE EXCEPTION 'função clean.censo_dict_violacoes() não existe';
    END IF;

    -- 3) Nenhuma coluna real das 4 tabelas fora do dicionário (mesma regra do
    --    tipo coluna_sem_dicionario da função, sem varrer os dados).
    SELECT string_agg(cl.relname || '.' || a.attname, ', ' ORDER BY cl.relname, a.attname)
    INTO faltando
    FROM pg_attribute a
    JOIN pg_class cl ON cl.oid = a.attrelid
    JOIN pg_namespace ns ON ns.oid = cl.relnamespace
    WHERE ns.nspname = 'clean'
      AND cl.relname IN ('censo_escolas', 'censo_matriculas', 'censo_docentes', 'censo_gestor')
      AND a.attnum > 0 AND NOT a.attisdropped
      AND NOT EXISTS (
          SELECT 1 FROM clean.censo_data_dictionary d
          WHERE d.table_name = 'clean.' || cl.relname AND d.column_name = a.attname
      );
    IF faltando IS NOT NULL THEN
        RAISE EXCEPTION 'colunas sem dicionário: %', faltando;
    END IF;

    -- 4) A carga do INEP aconteceu: tp_aee com o domínio oficial 0/1/2.
    IF NOT EXISTS (
        SELECT 1 FROM clean.censo_data_dictionary
        WHERE table_name = 'clean.censo_escolas' AND column_name = 'tp_aee'
          AND origem = 'inep' AND value_domain ? '0' AND value_domain ? '2'
          AND NOT value_domain ? '5'
    ) THEN
        RAISE EXCEPTION 'tp_aee sem o domínio do INEP (carga não aplicada?)';
    END IF;
END $$;

ROLLBACK;
