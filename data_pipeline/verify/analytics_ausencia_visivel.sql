-- Verify edumaps:analytics_ausencia_visivel on pg

BEGIN;

-- =================================================================
-- REGRESSÃO #154 — ausência de dado NÃO é valor zero
--
-- NOTA SOBRE O MECANISMO DESTE SCRIPT
--
-- O `sqitch verify` só considera a verificação FALHADA quando o script
-- produz um ERRO. Um `SELECT ... THEN FALSE` que devolve a linha `f`
-- passa como "ok" — foi testado empiricamente contra o Sqitch 1.6.1.
-- Por isso cada asserção abaixo é um bloco DO com RAISE EXCEPTION: a
-- falha tem de ser um erro para ter efeito.
--
-- (Os scripts verify mais antigos do repositório usam `SELECT 1` e por
-- isso não falham nunca. Não é defeito deles, é uma propriedade do
-- Sqitch que vale a pena saber.)
--
-- A propriedade testada, para cada indicador, é:
--   "se a tabela-fonte está vazia, a view NÃO pode reportar 0".
--
-- Cada asserção só morde quando a fonte está de fato vazia e passa
-- trivialmente quando há dado. É isso que a faz ser um teste e não uma
-- fotografia do banco.
-- =================================================================

DO $$
DECLARE
    n integer;
BEGIN
    -- 1) mobilidade: acidentes_12m
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.acidentes_12m = 0
      AND NOT EXISTS (SELECT 1 FROM clean.antt_acidente_trecho);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com acidentes_12m = 0 enquanto clean.antt_acidente_trecho está vazia. Fonte vazia não pode virar zero.', n;
    END IF;

    -- 2) mobilidade: acidentes_fatais_12m
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.acidentes_fatais_12m = 0
      AND NOT EXISTS (SELECT 1 FROM clean.antt_acidente_trecho);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com acidentes_fatais_12m = 0 enquanto a fonte ANTT está vazia.', n;
    END IF;

    -- 3) mobilidade: sinistros_12m
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.sinistros_12m = 0
      AND NOT EXISTS (SELECT 1 FROM clean.renaest_sinistro);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com sinistros_12m = 0 enquanto clean.renaest_sinistro está vazia.', n;
    END IF;

    -- 4) mobilidade: sinistros_fatais_12m
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.sinistros_fatais_12m = 0
      AND NOT EXISTS (SELECT 1 FROM clean.renaest_sinistro);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com sinistros_fatais_12m = 0 enquanto a fonte RENAEST está vazia.', n;
    END IF;

    -- 5) mobilidade: vmda_total_municipio
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.vmda_total_municipio = 0
      AND NOT EXISTS (SELECT 1 FROM clean.snv_trecho_vmda);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com vmda_total_municipio = 0 enquanto clean.snv_trecho_vmda está vazia.', n;
    END IF;

    -- 6) mobilidade: vmda_leve / vmda_pesado
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE (v.vmda_leve_municipio = 0 OR v.vmda_pesado_municipio = 0)
      AND NOT EXISTS (SELECT 1 FROM clean.snv_trecho_vmda);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com vmda_leve/pesado = 0 enquanto a fonte SNV está vazia.', n;
    END IF;

    -- 7) mobilidade: renavam (fonte vazia => NULL, não 0)
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.renavam_total_frota = 0
      AND NOT EXISTS (SELECT 1 FROM clean.renavam_frota_municipio);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com renavam_total_frota = 0 enquanto a fonte RENAVAM está vazia.', n;
    END IF;

    -- 8) acessibilidade: n_ubs_municipio
    SELECT COUNT(*) INTO n
    FROM analytics.acessibilidade_saude v
    WHERE v.n_ubs_municipio = 0
      AND NOT EXISTS (SELECT 1 FROM clean.cnes_estabelecimentos);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com n_ubs_municipio = 0 enquanto clean.cnes_estabelecimentos está vazia.', n;
    END IF;

    -- 9) acessibilidade: a view não pode AFIRMAR 'Sem UBS no município'
    --    quando o CNES não tem snapshot. Esta é a asserção mais
    --    importante do ficheiro: não é um valor, é uma afirmação falsa
    --    publicada como facto.
    SELECT COUNT(*) INTO n
    FROM analytics.acessibilidade_saude v
    WHERE v.classificacao_acesso = 'Sem UBS no município'
      AND NOT EXISTS (SELECT 1 FROM clean.cnes_estabelecimentos);
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com classificacao_acesso = ''Sem UBS no município'' enquanto a fonte CNES está vazia. A view está a afirmar algo que não sabe.', n;
    END IF;

    -- 10) mobilidade: fonte de isocrona vazia TEM de dar 'fonte_vazia'.
    --     Não basta o valor estar no vocabulário: a definição anterior
    --     devolvia 'sem_isocrona', que é válido e ainda assim mente
    --     sobre a causa.
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE NOT EXISTS (SELECT 1 FROM clean.isocrona_escolar)
      AND v.status_isocrona <> 'fonte_vazia';
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com status_isocrona = ''%'' em vez de ''fonte_vazia'' (fonte isocrona vazia).',
            n, (SELECT DISTINCT status_isocrona FROM analytics.mobilidade_escola LIMIT 1);
    END IF;

    -- 11) mobilidade: fonte ANTT vazia TEM de dar 'fonte_vazia'
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE NOT EXISTS (SELECT 1 FROM clean.antt_od_municipio)
      AND v.status_conexao_antt <> 'fonte_vazia';
    IF n > 0 THEN
        RAISE EXCEPTION
            'REGRESSÃO #154: % escola(s) com status_conexao_antt em vez de ''fonte_vazia'' (fonte ANTT OD vazia).', n;
    END IF;

    -- 12) vocabulário dos dois status é o esperado
    SELECT COUNT(*) INTO n
    FROM analytics.mobilidade_escola v
    WHERE v.status_isocrona     NOT IN ('fonte_vazia', 'coberto', 'sem_isocrona')
       OR v.status_conexao_antt NOT IN ('fonte_vazia', 'conectado_antt', 'sem_conexao_antt');
    IF n > 0 THEN
        RAISE EXCEPTION
            'Contrato: % escola(s) com status_isocrona/status_conexao_antt fora do vocabulário definido.', n;
    END IF;

    -- 13) acessibilidade: vocabulário da classificação
    SELECT COUNT(DISTINCT classificacao_acesso) INTO n
    FROM analytics.acessibilidade_saude
    WHERE classificacao_acesso NOT IN (
        'Não avaliado (fonte CNES sem snapshot)',
        'Acesso excelente (<1km)',
        'Acesso bom (1-3km)',
        'Acesso regular (3-5km)',
        'Acesso difícil (>5km)',
        'Sem UBS no município'
    );
    IF n > 0 THEN
        RAISE EXCEPTION 'Contrato: % valor(es) de classificacao_acesso fora do vocabulário definido.', n;
    END IF;

    -- =================================================================
    -- ANTI-FAN-OUT — uma linha por escola
    --
    -- A definição anterior fazia sete LEFT JOIN numa única query com
    -- GROUP BY, o que é produto cartesiano: COUNT(acidentes) era
    -- multiplicado pelas linhas das outras seis fontes. Com as tabelas
    -- vazias o efeito é invisível; com dado carregado, inflaria.
    -- =================================================================

    -- 14) mobilidade_escola não pode duplicar escola
    SELECT COUNT(*) INTO n FROM (
        SELECT co_entidade FROM analytics.mobilidade_escola
        GROUP BY co_entidade HAVING COUNT(*) > 1
    ) d;
    IF n > 0 THEN
        RAISE EXCEPTION
            'Fan-out: % escola(s) aparecem mais de uma vez em analytics.mobilidade_escola. Alguma fonte está a ser pré-agregada ao grão errado.', n;
    END IF;

    -- 15) acessibilidade_saude não pode duplicar escola
    SELECT COUNT(*) INTO n FROM (
        SELECT co_entidade FROM analytics.acessibilidade_saude
        GROUP BY co_entidade HAVING COUNT(*) > 1
    ) d;
    IF n > 0 THEN
        RAISE EXCEPTION
            'Fan-out: % escola(s) aparecem mais de uma vez em analytics.acessibilidade_saude.', n;
    END IF;

    -- =================================================================
    -- O OUTRO LADO DO CONTRATO — zero real não pode virar NULL
    --
    -- As asserções acima protegem contra "fonte vazia virou 0". Estas
    -- protegem o contrário: com a fonte carregada, um município que de
    -- facto não tem UBS tem de devolver 0, não NULL. Sem elas, a
    -- correção de #154 seria fácil de "resolver" apagando todos os
    -- zeros — e a view passaria a esconder municípios inteiros.
    --
    -- Hoje passam por vacuidade (as fontes estão vazias). Vão morder
    -- depois da carga real (#156) — que é para quando servem.
    -- =================================================================

    -- 16) acessibilidade: com CNES carregado, município sem UBS => 0
    IF EXISTS (SELECT 1 FROM clean.cnes_estabelecimentos) THEN
        SELECT COUNT(*) INTO n
        FROM analytics.acessibilidade_saude v
        WHERE v.n_ubs_municipio IS NULL;
        IF n > 0 THEN
            RAISE EXCEPTION
                'Contrato invertido: % escola(s) com n_ubs_municipio NULL apesar de o CNES estar carregado. Ausência de oferta é zero, não indeterminada.', n;
        END IF;
    END IF;

    -- 17) mobilidade: com SNV carregado, município sem trecho => 0
    IF EXISTS (SELECT 1 FROM clean.snv_trecho_vmda) THEN
        SELECT COUNT(*) INTO n
        FROM analytics.mobilidade_escola v
        WHERE v.vmda_total_municipio IS NULL;
        IF n > 0 THEN
            RAISE EXCEPTION
                'Contrato invertido: % escola(s) com vmda_total_municipio NULL apesar de a fonte SNV estar carregada.', n;
        END IF;
    END IF;

    -- 18) mobilidade: com ANTT carregada, município sem acidente => 0
    IF EXISTS (SELECT 1 FROM clean.antt_acidente_trecho) THEN
        SELECT COUNT(*) INTO n
        FROM analytics.mobilidade_escola v
        WHERE v.acidentes_12m IS NULL;
        IF n > 0 THEN
            RAISE EXCEPTION
                'Contrato invertido: % escola(s) com acidentes_12m NULL apesar de a fonte ANTT estar carregada.', n;
        END IF;
    END IF;

    -- =================================================================
    -- CONTRATO DE COLUNAS
    --
    -- O CREATE OR REPLACE VIEW já falha se a assinatura mudar, mas
    -- só quando a change é aplicada. Isto apanha uma view regenerada
    -- à mão, e documenta o contrato para quem for consumir.
    -- =================================================================

    -- 19) total de colunas: 31 (mobilidade) + 16 (acessibilidade) = 47
    SELECT COUNT(*) INTO n
    FROM information_schema.columns
    WHERE table_schema = 'analytics'
      AND table_name IN ('mobilidade_escola', 'acessibilidade_saude');
    IF n <> 47 THEN
        RAISE EXCEPTION 'Contrato: esperado 47 colunas nas duas views, encontrei %.', n;
    END IF;

    -- 20) nomes e ordem das colunas de mobilidade_escola idênticos
    --     aos da change analytics_mobilidade_escola
    SELECT COUNT(*) INTO n FROM (
        SELECT column_name, ordinal_position
        FROM information_schema.columns
        WHERE table_schema = 'analytics' AND table_name = 'mobilidade_escola'
        EXCEPT
        SELECT * FROM (VALUES
            ('co_entidade', 1), ('no_entidade', 2), ('codigo_ibge', 3),
            ('municipio_escola', 4), ('uf_escola', 5), ('tp_dependencia', 6),
            ('tp_localizacao', 7), ('latitude', 8), ('longitude', 9), ('geom', 10),
            ('isocronas_por_tempo', 11), ('antt_od_saida', 12), ('antt_od_entrada', 13),
            ('renavam_total_frota', 14), ('renavam_automoveis', 15),
            ('renavam_moto', 16), ('renavam_onibus', 17),
            ('vmda_total_municipio', 18), ('vmda_leve_municipio', 19),
            ('vmda_pesado_municipio', 20),
            ('acidentes_12m', 21), ('acidentes_fatais_12m', 22),
            ('sinistros_12m', 23), ('sinistros_fatais_12m', 24),
            ('recife_vagas_transporte', 25), ('recife_turno', 26),
            ('pct_acidentes_fatais', 27), ('pct_onibus_frota', 28),
            ('status_isocrona', 29), ('status_conexao_antt', 30),
            ('computed_at', 31)
        ) AS v(column_name, ordinal_position)
    ) diff;
    IF n > 0 THEN
        RAISE EXCEPTION
            'Contrato: % coluna(s) de analytics.mobilidade_escola não batem com a definição original (nome ou ordem).', n;
    END IF;
END
$$;

ROLLBACK;
