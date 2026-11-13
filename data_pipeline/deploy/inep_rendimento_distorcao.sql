-- Deploy edumaps:inep_rendimento_distorcao to pg
-- requires: planos_custo_executado
--
-- #376 (épico #368): indicadores educacionais do INEP por escola e ano, para
-- metas oficiais dos planos ("reduzir o abandono", "aumentar a aprovação").
--
-- Fonte medida em 2026-11-13 (download.inep.gov.br/informacoes_estatisticas/
-- indicadores_educacionais/<ano>/): tx_rend_escolas_<ano>.zip e
-- TDI_<ano>_ESCOLAS.zip, uma linha por escola (CO_ENTIDADE), taxas em % com
-- uma casa; "--" = sem dado. Carga pelo job de ingestão INEPIndicadores.
--
-- * clean.inep_rendimento_escola — aprovação, reprovação e abandono por
--   escola, ano e etapa (fun = fundamental total, ai, af, em).
-- * clean.inep_distorcao_escola — distorção idade-série, mesmo grão.
--   Sem dado na fonte = NULL, nunca 0 (#154); etapa sem nenhum valor não
--   vira linha.
--   Dado público e agregado por escola: GRANT SELECT ao edumaps_leitor.
-- * Catálogo das metas: 12 códigos novos (aprovação, reprovação, abandono e
--   distorção nos anos iniciais, finais e ensino médio), grupo 'fluxo'; a
--   view analytics.escola_indicadores_meta passa a ler as duas tabelas.

BEGIN;

  CREATE TABLE clean.inep_rendimento_escola (
    cod_inep    bigint       NOT NULL,
    ano         smallint     NOT NULL CHECK (ano BETWEEN 2000 AND 2100),
    etapa       text         NOT NULL CHECK (etapa IN ('fun', 'ai', 'af', 'em')),
    aprovacao   numeric(4,1) CHECK (aprovacao BETWEEN 0 AND 100),
    reprovacao  numeric(4,1) CHECK (reprovacao BETWEEN 0 AND 100),
    abandono    numeric(4,1) CHECK (abandono BETWEEN 0 AND 100),
    carregado_em timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY (cod_inep, ano, etapa),
    CONSTRAINT ck_inep_rendimento_algum CHECK (aprovacao IS NOT NULL OR reprovacao IS NOT NULL OR abandono IS NOT NULL)
  );
  COMMENT ON TABLE clean.inep_rendimento_escola IS
    'Taxas de rendimento (aprovação, reprovação, abandono, em %) por escola, ano e etapa (#376). Fonte: INEP, tx_rend_escolas_<ano>. Sem dado na fonte = NULL, nunca 0 (#154). Etapas: fun (fundamental total), ai, af, em.';

  CREATE TABLE clean.inep_distorcao_escola (
    cod_inep    bigint       NOT NULL,
    ano         smallint     NOT NULL CHECK (ano BETWEEN 2000 AND 2100),
    etapa       text         NOT NULL CHECK (etapa IN ('fun', 'ai', 'af', 'em')),
    distorcao   numeric(4,1) NOT NULL CHECK (distorcao BETWEEN 0 AND 100),
    carregado_em timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY (cod_inep, ano, etapa)
  );
  COMMENT ON TABLE clean.inep_distorcao_escola IS
    'Taxa de distorção idade-série (%) por escola, ano e etapa (#376). Fonte: INEP, TDI_<ano>_ESCOLAS. Etapa sem dado na fonte não vira linha (nunca 0, #154).';

  GRANT SELECT ON clean.inep_rendimento_escola, clean.inep_distorcao_escola TO edumaps_leitor;

  ALTER TABLE analytics.indicadores_meta_catalogo DROP CONSTRAINT indicadores_meta_catalogo_grupo_check;
  ALTER TABLE analytics.indicadores_meta_catalogo ADD CONSTRAINT indicadores_meta_catalogo_grupo_check
    CHECK (grupo IN ('desempenho', 'fluxo', 'matriculas', 'infraestrutura', 'vulnerabilidade'));

  INSERT INTO analytics.indicadores_meta_catalogo VALUES
    ('aprovacao_ai',  'fluxo', 'Taxa de aprovação — anos iniciais',  '%', 'INEP — Taxas de Rendimento', 'aumentar', 60),
    ('aprovacao_af',  'fluxo', 'Taxa de aprovação — anos finais',    '%', 'INEP — Taxas de Rendimento', 'aumentar', 61),
    ('aprovacao_em',  'fluxo', 'Taxa de aprovação — ensino médio',   '%', 'INEP — Taxas de Rendimento', 'aumentar', 62),
    ('reprovacao_ai', 'fluxo', 'Taxa de reprovação — anos iniciais', '%', 'INEP — Taxas de Rendimento', 'reduzir', 63),
    ('reprovacao_af', 'fluxo', 'Taxa de reprovação — anos finais',   '%', 'INEP — Taxas de Rendimento', 'reduzir', 64),
    ('reprovacao_em', 'fluxo', 'Taxa de reprovação — ensino médio',  '%', 'INEP — Taxas de Rendimento', 'reduzir', 65),
    ('abandono_ai',   'fluxo', 'Taxa de abandono — anos iniciais',   '%', 'INEP — Taxas de Rendimento', 'reduzir', 66),
    ('abandono_af',   'fluxo', 'Taxa de abandono — anos finais',     '%', 'INEP — Taxas de Rendimento', 'reduzir', 67),
    ('abandono_em',   'fluxo', 'Taxa de abandono — ensino médio',    '%', 'INEP — Taxas de Rendimento', 'reduzir', 68),
    ('distorcao_ai',  'fluxo', 'Distorção idade-série — anos iniciais', '%', 'INEP — Distorção Idade-Série', 'reduzir', 69),
    ('distorcao_af',  'fluxo', 'Distorção idade-série — anos finais',   '%', 'INEP — Distorção Idade-Série', 'reduzir', 70),
    ('distorcao_em',  'fluxo', 'Distorção idade-série — ensino médio',  '%', 'INEP — Distorção Idade-Série', 'reduzir', 71);

  CREATE OR REPLACE VIEW analytics.escola_indicadores_meta AS
  WITH valores AS (
    SELECT i.id_escola AS cod_inep,
           CASE i.etapa WHEN 'fundamental_i' THEN 'ideb_ai'
                        WHEN 'fundamental_ii' THEN 'ideb_af'
                        WHEN 'ensino_medio' THEN 'ideb_em' END AS codigo,
           i.ano, i.ideb_observado::numeric AS valor
      FROM clean.ideb_notas_escolas i
     WHERE i.ideb_observado IS NOT NULL
       AND i.etapa IN ('fundamental_i', 'fundamental_ii', 'ensino_medio')
    UNION ALL
    SELECT m.co_entidade, v.codigo, m.nu_ano_censo, v.valor::numeric
      FROM clean.censo_matriculas m
     CROSS JOIN LATERAL (VALUES
       ('matriculas_total',    m.qt_mat_bas),
       ('matriculas_infantil', m.qt_mat_inf),
       ('matriculas_ai',       m.qt_mat_fund_ai),
       ('matriculas_af',       m.qt_mat_fund_af),
       ('matriculas_em',       m.qt_mat_med),
       ('matriculas_eja',      m.qt_mat_eja),
       ('matriculas_especial', m.qt_mat_esp)
     ) AS v(codigo, valor)
     WHERE v.valor IS NOT NULL
    UNION ALL
    SELECT e.co_entidade, v.codigo, e.nu_ano_censo, v.valor::numeric
      FROM clean.censo_escolas e
     CROSS JOIN LATERAL (VALUES
       ('infra_biblioteca',      CASE WHEN e.in_biblioteca IS NULL AND e.in_biblioteca_sala_leitura IS NULL THEN NULL
                                      ELSE GREATEST(COALESCE(e.in_biblioteca, 0), COALESCE(e.in_biblioteca_sala_leitura, 0)) END),
       ('infra_lab_ciencias',    e.in_laboratorio_ciencias),
       ('infra_lab_informatica', e.in_laboratorio_informatica),
       ('infra_quadra',          e.in_quadra_esportes),
       ('infra_internet_alunos', e.in_internet_alunos),
       ('infra_banda_larga',     e.in_banda_larga),
       ('infra_agua_potavel',    e.in_agua_potavel),
       ('infra_esgoto_rede',     e.in_esgoto_rede_publica),
       ('infra_banheiro_pne',    e.in_banheiro_pne),
       ('infra_acessibilidade',  CASE WHEN e.in_acessibilidade_inexistente IS NULL THEN NULL
                                      ELSE 1 - e.in_acessibilidade_inexistente END),
       ('infra_refeitorio',      e.in_refeitorio)
     ) AS v(codigo, valor)
     WHERE v.valor IS NOT NULL
    UNION ALL
    SELECT iv.co_entidade, 'ivet', iv.nu_ano_censo, iv.ivet::numeric
      FROM analytics.ivet_escola iv
     WHERE iv.raio_m = 1000 AND iv.publicavel AND iv.ivet IS NOT NULL
    UNION ALL
    SELECT r.cod_inep, v.codigo, r.ano, v.valor
      FROM clean.inep_rendimento_escola r
     CROSS JOIN LATERAL (VALUES
       ('aprovacao_'  || r.etapa, r.aprovacao),
       ('reprovacao_' || r.etapa, r.reprovacao),
       ('abandono_'   || r.etapa, r.abandono)
     ) AS v(codigo, valor)
     WHERE r.etapa IN ('ai', 'af', 'em') AND v.valor IS NOT NULL
    UNION ALL
    SELECT d.cod_inep, 'distorcao_' || d.etapa, d.ano, d.distorcao
      FROM clean.inep_distorcao_escola d
     WHERE d.etapa IN ('ai', 'af', 'em') AND d.distorcao IS NOT NULL
  )
  SELECT v.cod_inep, v.codigo, c.rotulo, c.unidade, c.fonte, v.ano, v.valor
    FROM valores v
    JOIN analytics.indicadores_meta_catalogo c ON c.codigo = v.codigo;

  COMMENT ON VIEW analytics.escola_indicadores_meta IS
    'Valor dos indicadores oficiais por escola e ano (#370, #376), para as metas dos planos. Valor ausente na fonte não gera linha (sem dado, nunca 0 — #154). Nada é calculado: é leitura do IDEB, do Censo Escolar, das taxas de rendimento e distorção do INEP e do IVET.';

COMMIT;
