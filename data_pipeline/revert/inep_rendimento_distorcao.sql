-- Revert edumaps:inep_rendimento_distorcao from pg

BEGIN;

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
  )
  SELECT v.cod_inep, v.codigo, c.rotulo, c.unidade, c.fonte, v.ano, v.valor
    FROM valores v
    JOIN analytics.indicadores_meta_catalogo c ON c.codigo = v.codigo;

  COMMENT ON VIEW analytics.escola_indicadores_meta IS
    'Valor dos indicadores oficiais por escola e ano (#370), para as metas dos planos. Valor ausente na fonte não gera linha (sem dado, nunca 0 — #154). Nada é calculado: é leitura do IDEB, do Censo Escolar e do IVET.';

  -- metas ligadas aos códigos novos voltam a ser manuais (o catálogo é a FK)
  UPDATE clean.planos_metas SET indicador_codigo = NULL
   WHERE indicador_codigo ~ '^(aprovacao|reprovacao|abandono|distorcao)_';
  DELETE FROM analytics.indicadores_meta_catalogo WHERE grupo = 'fluxo';

  ALTER TABLE analytics.indicadores_meta_catalogo DROP CONSTRAINT indicadores_meta_catalogo_grupo_check;
  ALTER TABLE analytics.indicadores_meta_catalogo ADD CONSTRAINT indicadores_meta_catalogo_grupo_check
    CHECK (grupo IN ('desempenho', 'matriculas', 'infraestrutura', 'vulnerabilidade'));

  DROP TABLE clean.inep_distorcao_escola;
  DROP TABLE clean.inep_rendimento_escola;

COMMIT;
