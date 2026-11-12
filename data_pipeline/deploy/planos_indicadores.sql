-- Deploy edumaps:planos_indicadores to pg
-- requires: planos_gestao
--
-- #370 (épico #368): metas dos planos ligadas a indicadores OFICIAIS da
-- escola, e medições (oficiais ou manuais) para o progresso.
--
-- * analytics.indicadores_meta_catalogo — a única fonte dos códigos: rótulo,
--   unidade, fonte e sentido sugerido. Público (só metadado).
-- * analytics.escola_indicadores_meta — o valor de cada indicador por escola
--   e ano, lido do que a plataforma JÁ TEM (nada é modelado aqui):
--     IDEB observado por etapa (clean.ideb_notas_escolas);
--     matrículas (clean.censo_matriculas);
--     itens de infraestrutura do Censo, 0/1 (clean.censo_escolas);
--     IVET publicável no raio padrão de 1 km (analytics.ivet_escola).
--   Valor ausente na fonte NÃO vira linha: a meta mostra "sem dado", nunca 0
--   (#154).
-- * clean.planos_metas_medicoes — histórico da meta. A medição oficial é
--   GRAVADA (um por ano de referência), para o histórico não depender de a
--   fonte manter os anos anteriores. Interna (sem GRANT ao leitor).

BEGIN;

  CREATE TABLE analytics.indicadores_meta_catalogo (
    codigo            text     PRIMARY KEY,
    grupo             text     NOT NULL CHECK (grupo IN ('desempenho', 'matriculas', 'infraestrutura', 'vulnerabilidade')),
    rotulo            text     NOT NULL,
    unidade           text     NOT NULL,
    fonte             text     NOT NULL,
    sentido_sugerido  text     NOT NULL CHECK (sentido_sugerido IN ('aumentar', 'reduzir', 'manter')),
    ordem             integer  NOT NULL
  );

  INSERT INTO analytics.indicadores_meta_catalogo VALUES
    ('ideb_ai',  'desempenho', 'IDEB — anos iniciais',  'pontos (0 a 10)', 'INEP — IDEB', 'aumentar', 10),
    ('ideb_af',  'desempenho', 'IDEB — anos finais',    'pontos (0 a 10)', 'INEP — IDEB', 'aumentar', 11),
    ('ideb_em',  'desempenho', 'IDEB — ensino médio',   'pontos (0 a 10)', 'INEP — IDEB', 'aumentar', 12),
    ('matriculas_total',    'matriculas', 'Matrículas — total da educação básica', 'alunos', 'INEP — Censo Escolar', 'aumentar', 20),
    ('matriculas_infantil', 'matriculas', 'Matrículas — educação infantil',        'alunos', 'INEP — Censo Escolar', 'aumentar', 21),
    ('matriculas_ai',       'matriculas', 'Matrículas — anos iniciais',            'alunos', 'INEP — Censo Escolar', 'aumentar', 22),
    ('matriculas_af',       'matriculas', 'Matrículas — anos finais',              'alunos', 'INEP — Censo Escolar', 'aumentar', 23),
    ('matriculas_em',       'matriculas', 'Matrículas — ensino médio',             'alunos', 'INEP — Censo Escolar', 'aumentar', 24),
    ('matriculas_eja',      'matriculas', 'Matrículas — EJA',                      'alunos', 'INEP — Censo Escolar', 'aumentar', 25),
    ('matriculas_especial', 'matriculas', 'Matrículas — educação especial',        'alunos', 'INEP — Censo Escolar', 'aumentar', 26),
    ('infra_biblioteca',          'infraestrutura', 'Tem biblioteca ou sala de leitura', 'sim/não', 'INEP — Censo Escolar', 'aumentar', 30),
    ('infra_lab_ciencias',        'infraestrutura', 'Tem laboratório de ciências',       'sim/não', 'INEP — Censo Escolar', 'aumentar', 31),
    ('infra_lab_informatica',     'infraestrutura', 'Tem laboratório de informática',    'sim/não', 'INEP — Censo Escolar', 'aumentar', 32),
    ('infra_quadra',              'infraestrutura', 'Tem quadra de esportes',            'sim/não', 'INEP — Censo Escolar', 'aumentar', 33),
    ('infra_internet_alunos',     'infraestrutura', 'Internet para os alunos',           'sim/não', 'INEP — Censo Escolar', 'aumentar', 34),
    ('infra_banda_larga',         'infraestrutura', 'Tem banda larga',                   'sim/não', 'INEP — Censo Escolar', 'aumentar', 35),
    ('infra_agua_potavel',        'infraestrutura', 'Tem água potável',                  'sim/não', 'INEP — Censo Escolar', 'aumentar', 36),
    ('infra_esgoto_rede',         'infraestrutura', 'Esgoto na rede pública',            'sim/não', 'INEP — Censo Escolar', 'aumentar', 37),
    ('infra_banheiro_pne',        'infraestrutura', 'Banheiro acessível (PNE)',          'sim/não', 'INEP — Censo Escolar', 'aumentar', 38),
    ('infra_acessibilidade',      'infraestrutura', 'Tem algum recurso de acessibilidade', 'sim/não', 'INEP — Censo Escolar', 'aumentar', 39),
    ('infra_refeitorio',          'infraestrutura', 'Tem refeitório',                    'sim/não', 'INEP — Censo Escolar', 'aumentar', 40),
    ('ivet', 'vulnerabilidade', 'IVET — vulnerabilidade territorial (raio de 1 km)', 'índice (0 a 1)', 'EduMaps — IVET', 'reduzir', 50);

  COMMENT ON TABLE analytics.indicadores_meta_catalogo IS
    'Catálogo dos indicadores oficiais a que uma meta de plano pode se ligar (#370). Única fonte dos códigos; os valores estão em analytics.escola_indicadores_meta.';

  CREATE VIEW analytics.escola_indicadores_meta AS
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

  ALTER TABLE clean.planos_metas
    ADD CONSTRAINT fk_planos_metas_indicador
    FOREIGN KEY (indicador_codigo) REFERENCES analytics.indicadores_meta_catalogo (codigo);

  CREATE TABLE clean.planos_metas_medicoes (
    id          bigserial   PRIMARY KEY,
    meta_id     bigint      NOT NULL REFERENCES clean.planos_metas (id) ON DELETE CASCADE,
    origem      text        NOT NULL CHECK (origem IN ('oficial', 'manual')),
    data_ref    date        NOT NULL,
    ano_ref     integer,
    valor       numeric     NOT NULL,
    nota        text,
    created_by  bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_planos_medicoes_ano CHECK ((origem = 'oficial') = (ano_ref IS NOT NULL))
  );
  -- Uma medição oficial por meta e ano de referência (a sincronização é idempotente).
  CREATE UNIQUE INDEX uq_planos_medicoes_oficial ON clean.planos_metas_medicoes (meta_id, ano_ref)
    WHERE origem = 'oficial';
  CREATE INDEX idx_planos_medicoes_meta ON clean.planos_metas_medicoes (meta_id, data_ref DESC);

  COMMENT ON TABLE clean.planos_metas_medicoes IS
    'Medições de uma meta de plano (#370): oficiais (gravadas da fonte, uma por ano de referência) ou manuais (informadas pelo gestor). A mais recente é o valor atual.';

COMMIT;
