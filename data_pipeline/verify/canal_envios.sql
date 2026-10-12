-- Verify edumaps:canal_envios on pg
-- Gate no estilo issue #160: o verify SÓ falha com RAISE EXCEPTION (um SELECT
-- que devolve 'f' contaria como sucesso). Colunas checadas por pg_attribute.

BEGIN;

DO $$
DECLARE
    n integer;
    t text;
BEGIN
    -- ------------------------------------------------------------------
    -- 1. as seis tabelas existem
    -- ------------------------------------------------------------------
    FOREACH t IN ARRAY ARRAY['clean.canal_segmentos', 'clean.canal_envios',
                             'clean.canal_envio_destinatarios', 'clean.canal_optouts',
                             'clean.canal_qr_acessos', 'clean.canal_envio_suspensoes']
    LOOP
        IF to_regclass(t) IS NULL THEN
            RAISE EXCEPTION '% ausente', t;
        END IF;
    END LOOP;

    -- ------------------------------------------------------------------
    -- 2. colunas
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_segmentos'::regclass
      AND attname IN ('id', 'cod_inep', 'gestor_id', 'nome', 'criterios',
                      'created_at', 'updated_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 7 THEN
        RAISE EXCEPTION 'canal_segmentos: colunas ausentes (esperadas 7, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_envios'::regclass
      AND attname IN ('id', 'cod_inep', 'gestor_id', 'alvo_tipo', 'alvo_id', 'alvo_nome',
                      'canal', 'operacao', 'assunto', 'corpo', 'status',
                      'agendado_para', 'iniciado_em', 'concluido_em', 'cancelado_em',
                      'destinatarios', 'enviados', 'falhas', 'ignorados',
                      'minion_job_id', 'created_at', 'updated_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 22 THEN
        RAISE EXCEPTION 'canal_envios: colunas ausentes (esperadas 22, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_envio_destinatarios'::regclass
      AND attname IN ('id', 'envio_id', 'contato_id', 'lista_id', 'email', 'email_hash',
                      'saida_hash', 'status', 'erro', 'mensagem_id', 'processado_em')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 11 THEN
        RAISE EXCEPTION 'canal_envio_destinatarios: colunas ausentes (esperadas 11, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_optouts'::regclass
      AND attname IN ('id', 'lista_id', 'canal', 'email_hash', 'envio_id', 'created_at')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 6 THEN
        RAISE EXCEPTION 'canal_optouts: colunas ausentes (esperadas 6, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_qr_acessos'::regclass
      AND attname IN ('qrcode_id', 'dia', 'acessos')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 3 THEN
        RAISE EXCEPTION 'canal_qr_acessos: colunas ausentes (esperadas 3, encontradas %)', n;
    END IF;

    SELECT count(*) INTO n
    FROM pg_attribute
    WHERE attrelid = 'clean.canal_envio_suspensoes'::regclass
      AND attname IN ('id', 'cod_inep', 'motivo', 'suspenso_por', 'suspenso_em',
                      'reativado_por', 'reativado_em')
      AND attnum > 0 AND NOT attisdropped;
    IF n <> 7 THEN
        RAISE EXCEPTION 'canal_envio_suspensoes: colunas ausentes (esperadas 7, encontradas %)', n;
    END IF;

    -- ------------------------------------------------------------------
    -- 3. constraints e índices
    -- ------------------------------------------------------------------
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conname IN ('canal_segmentos_cod_inep_nome_key',
                      'canal_envios_alvo_tipo_check', 'canal_envios_canal_check',
                      'canal_envios_operacao_check', 'canal_envios_status_check',
                      'canal_envio_destinatarios_saida_hash_key',
                      'canal_envio_destinatarios_status_check',
                      'canal_envio_destinatarios_envio_email_key',
                      'canal_optouts_canal_check', 'canal_optouts_lista_canal_email_key')
      AND connamespace = 'clean'::regnamespace;
    IF n <> 10 THEN
        RAISE EXCEPTION 'constraints ausentes (esperadas 10, encontradas %)', n;
    END IF;

    -- o CHECK de status NÃO aceita ignorado_duplicado (contrato da onda 1)
    SELECT count(*) INTO n
    FROM pg_constraint
    WHERE conname = 'canal_envio_destinatarios_status_check'
      AND pg_get_constraintdef(oid) LIKE '%ignorado_duplicado%';
    IF n <> 0 THEN
        RAISE EXCEPTION 'canal_envio_destinatarios_status_check aceita ignorado_duplicado';
    END IF;

    SELECT count(*) INTO n
    FROM pg_indexes
    WHERE schemaname = 'clean'
      AND indexname IN ('idx_canal_envios_escola', 'idx_canal_envio_dest_pend',
                        'idx_canal_envio_dest_processado', 'uq_canal_envio_suspensao_ativa');
    IF n <> 4 THEN
        RAISE EXCEPTION 'índices ausentes (esperados 4, encontrados %)', n;
    END IF;
END $$;

ROLLBACK;
