-- Deploy edumaps:analytics_ivet_escola to pg
-- requires: isocrona_escolar_resolucao_h3

BEGIN;

  -- ============================================================
  -- Tabela: analytics.ivet_escola
  -- Descrição: Painel do IVET (ivet-v1.2) por escola, MATERIALIZADO
  -- pelo job refresh_ivet (#296). A lógica de cálculo continua só
  -- no pacote R edumapsr (`ivet_medir_nacional()` / `ivet_painel()`);
  -- esta tabela é artefato de entrega (mesmo padrão de
  -- analytics.ranking_escola, bloco B).
  --
  -- Decisões de design:
  -- - dt_snapshot na PK: cada refresh guarda a medição do dia e a
  --   API lê o snapshot mais recente por escola — histórico/rollback
  --   sem tabela extra (mesmo padrão de clean.isocrona_escolar).
  -- - ivet NULL quando não publicável (falta bloco territorial
  --   mínimo C+D+E); bloco_* NULL = bloco não calculado (#154:
  --   ausência NUNCA vira 0).
  -- - publicavel mantém a convenção do painel R (C, D e E presentes),
  --   duplicada de propósito para o consumo da API não recalcular.
  -- ============================================================
  CREATE TABLE analytics.ivet_escola (
      co_entidade       bigint        NOT NULL,
      nu_ano_censo      integer       NOT NULL,
      raio_m            integer       NOT NULL DEFAULT 1000,
      ivet              double precision,
      publicavel        boolean       NOT NULL,
      bloco_a           double precision,
      bloco_b           double precision,
      bloco_c           double precision,
      bloco_d           double precision,
      bloco_e           double precision,
      bloco_f           double precision,
      bloco_g           double precision,
      formula           text          NOT NULL,
      dataset_version   text,
      transform_version text,
      dt_snapshot       date          NOT NULL,
      calculado_em      timestamptz   NOT NULL DEFAULT now(),

      CONSTRAINT pk_ivet_escola
          PRIMARY KEY (co_entidade, nu_ano_censo, raio_m, dt_snapshot),

      CONSTRAINT ck_ivet_escola_ivet
          CHECK (ivet IS NULL OR (ivet >= 0 AND ivet <= 1)),

      CONSTRAINT ck_ivet_escola_raio
          CHECK (raio_m > 0)
  );

  -- A API lê o snapshot vigente por escola: atendido pela PK
  -- (co_entidade, ...). O índice de snapshot apoia consultas
  -- administrativas ("qual é o último?", limpeza de históricos).
  CREATE INDEX idx_ivet_escola_dt_snapshot
      ON analytics.ivet_escola (dt_snapshot);

  COMMENT ON TABLE analytics.ivet_escola IS
      'Painel do IVET (ivet-v1.2) por escola, materializado pelo job refresh_ivet (#296). A lógica de cálculo vive só no edumapsr (ivet_medir_nacional/ivet_painel); aqui fica o resultado vigente por dt_snapshot. ivet NULL = não publicável (falta bloco territorial mínimo); bloco_* NULL = bloco não calculado (#154).';
  COMMENT ON COLUMN analytics.ivet_escola.co_entidade IS
      'Código INEP da escola.';
  COMMENT ON COLUMN analytics.ivet_escola.nu_ano_censo IS
      'Ano do Censo Escolar usado nas entradas do painel.';
  COMMENT ON COLUMN analytics.ivet_escola.raio_m IS
      'Raio da área de influência (bloco B) em metros usado no painel.';
  COMMENT ON COLUMN analytics.ivet_escola.ivet IS
      'Índice composto [0,1], maior = mais vulnerável; NULL quando não publicável (C+D+E ausentes).';
  COMMENT ON COLUMN analytics.ivet_escola.publicavel IS
      'TRUE quando os blocos territoriais mínimos C, D e E estão disponíveis.';
  COMMENT ON COLUMN analytics.ivet_escola.formula IS
      'Versão da fórmula de agregação (attr formula do painel R, ex.: ivet-v1.2).';
  COMMENT ON COLUMN analytics.ivet_escola.dt_snapshot IS
      'Data da medição (dia do refresh). A API lê o max(dt_snapshot) por escola.';
  COMMENT ON COLUMN analytics.ivet_escola.calculado_em IS
      'Timestamp do upsert desta linha pelo refresh.';

COMMIT;
