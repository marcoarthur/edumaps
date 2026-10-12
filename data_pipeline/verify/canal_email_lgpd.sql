-- Verify edumaps:canal_email_lgpd on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Colunas checadas por pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
BEGIN
    -- ------------------------------------------------------------------
    -- 1. canal_listas: coleta (NOT NULL + CHECK) e desativada_em
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_listas'::regclass
      AND attname = 'coleta' AND attnum > 0 AND NOT attisdropped AND attnotnull;
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_listas.coleta ausente ou anulável';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_listas'::regclass
      AND attname = 'desativada_em' AND attnum > 0 AND NOT attisdropped;
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_listas.desativada_em ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_listas'::regclass
      AND contype = 'c' AND conname = 'canal_listas_coleta_check';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_listas_coleta_check ausente';
    END IF;

    -- ------------------------------------------------------------------
    -- 2. canal_inscricoes: telefone anulável + colunas novas + UNIQUE
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_inscricoes'::regclass
      AND attname IN ('telefone', 'telefone_norm')
      AND attnum > 0 AND NOT attisdropped AND NOT attnotnull;
    IF n <> 2 THEN
        RAISE EXCEPTION 'canal_inscricoes.telefone/telefone_norm continuam NOT NULL';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_inscricoes'::regclass
      AND attname IN ('email', 'email_norm', 'consentimento_hash',
                      'exclusao_hash', 'anonimizado_em')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 5 THEN
        RAISE EXCEPTION 'canal_inscricoes: colunas novas ausentes (esperadas 5, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_inscricoes'::regclass
      AND contype = 'u' AND conname = 'canal_inscricoes_exclusao_hash_key';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_inscricoes: UNIQUE (exclusao_hash) ausente';
    END IF;

    -- ------------------------------------------------------------------
    -- 3. canal_lista_membros: confirmação do e-mail
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_lista_membros'::regclass
      AND attname IN ('email_confirmado_em', 'email_confirmado_via')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 2 THEN
        RAISE EXCEPTION 'canal_lista_membros: colunas de e-mail ausentes (esperadas 2, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_lista_membros'::regclass
      AND contype = 'c' AND conname = 'canal_lista_membros_email_confirmado_via_check';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_lista_membros_email_confirmado_via_check ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_confirmacao_refs'::regclass
      AND attname = 'envios_email' AND attnum > 0 AND NOT attisdropped AND attnotnull;
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_confirmacao_refs.envios_email ausente ou anulável';
    END IF;

    -- ------------------------------------------------------------------
    -- 4. consentimento_versoes: tabela, vigente única e seed 1.0
    -- ------------------------------------------------------------------
    IF to_regclass('clean.consentimento_versoes') IS NULL THEN
        RAISE EXCEPTION 'clean.consentimento_versoes ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.consentimento_versoes'::regclass
      AND attname IN ('id', 'versao', 'texto', 'texto_hash', 'status',
                      'criado_por', 'publicada_em', 'created_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 8 THEN
        RAISE EXCEPTION 'consentimento_versoes: colunas ausentes (esperadas 8, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean' AND tablename = 'consentimento_versoes'
      AND indexname = 'uq_consentimento_vigente';
    IF n <> 1 THEN
        RAISE EXCEPTION 'consentimento_versoes: índice uq_consentimento_vigente ausente';
    END IF;

    SELECT count(*) INTO n
    FROM clean.consentimento_versoes
    WHERE status = 'vigente';
    IF n <> 1 THEN
        RAISE EXCEPTION 'consentimento_versoes: esperada exatamente 1 vigente (encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM clean.consentimento_versoes
    WHERE versao = '1.0'
      AND texto_hash = encode(digest(texto, 'sha256'), 'hex');
    IF n <> 1 THEN
        RAISE EXCEPTION 'consentimento_versoes: seed 1.0 ausente ou com hash divergente';
    END IF;

    -- ------------------------------------------------------------------
    -- 5. canal_exclusoes: tabela de auditoria sem PII
    -- ------------------------------------------------------------------
    IF to_regclass('clean.canal_exclusoes') IS NULL THEN
        RAISE EXCEPTION 'clean.canal_exclusoes ausente';
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_exclusoes'::regclass
      AND attname IN ('id', 'cod_inep', 'origem', 'regra', 'gestor_id', 'motivo',
                      'contatos', 'inscricoes', 'membros', 'created_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 10 THEN
        RAISE EXCEPTION 'canal_exclusoes: colunas ausentes (esperadas 10, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conrelid = 'clean.canal_exclusoes'::regclass
      AND contype = 'c' AND conname = 'canal_exclusoes_origem_check';
    IF n <> 1 THEN
        RAISE EXCEPTION 'canal_exclusoes_origem_check ausente';
    END IF;
END $$;

ROLLBACK;
