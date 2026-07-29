-- Deploy edumaps:ranking_escola to pg
-- requires: escolas_scores

BEGIN;

  -- Schema 'analytics' pode já existir por causa de outras tabelas;
  -- IF NOT EXISTS torna o deploy idempotente/seguro para re-execução.
  CREATE SCHEMA IF NOT EXISTS analytics;

  -- ============================================================
  -- Tabela: analytics.ranking_escola
  -- Descrição: Ranking pré-computado por escola/indicador/rede,
  -- substituindo o RANK() via window function calculado a cada
  -- requisição em EduMaps::Model::Rank::School->rank(). Um job
  -- batch recalcula e substitui as linhas (ver refresh_ranking_escola.sql).
  --
  -- Decisões de design:
  -- - PK é (indicador_id, rede, id_escola), SEM o ano. A tabela
  --   guarda sempre o ranking mais recente; ao recalcular, o job
  --   faz UPSERT, então o "ano" varia por indicador (mv e ideb têm
  --   fontes/anos diferentes) mas nunca há duas linhas vigentes
  --   para a mesma escola/indicador/rede.
  -- - 'rede' usa o valor literal 'todas' em vez de NULL para
  --   representar "sem filtro de rede", pois um índice único do
  --   Postgres não bloqueia múltiplos NULLs — usar um sentinel
  --   evita duplicidade e mantém a PK simples.
  -- - rank_nacional/total_nacional são sempre calculados no job de
  --   refresh (mesmo que a maioria das chamadas de rank() passe
  --   national=0), já que o custo de computar é pago uma vez só;
  --   a API decide se expõe esse campo ou não.
  -- ============================================================
  CREATE TABLE analytics.ranking_escola (
      indicador_id      text          NOT NULL,
      rede              text          NOT NULL DEFAULT 'todas',
      id_escola         integer       NOT NULL,
      ano               integer       NOT NULL,
      valor             numeric(10,4),
      rank_municipio    integer,
      total_municipio   integer,
      rank_estado       integer,
      total_estado      integer,
      rank_nacional     integer,
      total_nacional    integer,
      data_atualizacao  timestamptz   NOT NULL DEFAULT now(),

      CONSTRAINT pk_ranking_escola
          PRIMARY KEY (indicador_id, rede, id_escola),

      CONSTRAINT ck_ranking_escola_rede
          CHECK (rede IN ('todas', 'municipal', 'estadual', 'privada')),

      CONSTRAINT ck_ranking_escola_rank_municipio
          CHECK (rank_municipio IS NULL OR rank_municipio >= 1),
      CONSTRAINT ck_ranking_escola_rank_estado
          CHECK (rank_estado IS NULL OR rank_estado >= 1),
      CONSTRAINT ck_ranking_escola_rank_nacional
          CHECK (rank_nacional IS NULL OR rank_nacional >= 1),

      CONSTRAINT ck_ranking_escola_total_municipio
          CHECK (total_municipio IS NULL OR total_municipio >= 1),
      CONSTRAINT ck_ranking_escola_total_estado
          CHECK (total_estado IS NULL OR total_estado >= 1),
      CONSTRAINT ck_ranking_escola_total_nacional
          CHECK (total_nacional IS NULL OR total_nacional >= 1)
  );

  -- Lookup principal: rank($cod_inep, $indicator_id, {network=>...})
  -- já é atendido pela PK (indicador_id, rede, id_escola), pois a
  -- consulta sempre informa os três valores.

  -- Consultas de "top N" / leaderboard por indicador+rede (ex.: painéis
  -- administrativos, exportações), ordenando pelo ranking nacional.
  CREATE INDEX idx_ranking_escola_rank_nacional
      ON analytics.ranking_escola (indicador_id, rede, rank_nacional)
      WHERE rank_nacional IS NOT NULL;

  -- Suporte a checagem de "quão desatualizado está o ranking" e a
  -- filtros administrativos por ano de referência.
  CREATE INDEX idx_ranking_escola_ano
      ON analytics.ranking_escola (ano);

  COMMENT ON TABLE analytics.ranking_escola IS
      'Rankings pré-computados por escola/indicador/rede. Substitui o cálculo via RANK() OVER (...) feito a cada requisição em EduMaps::Model::Rank::School. Recalculada por job batch (ver refresh_ranking_escola.sql), disparado após o refresh de clean.mv_escolas_scores e a carga do IDEB.';

  COMMENT ON COLUMN analytics.ranking_escola.indicador_id IS
      'Chave do indicator_registry do model Perl (ex.: infraestrutura, ideb_anos_iniciais, nota_matematica_medio).';
  COMMENT ON COLUMN analytics.ranking_escola.rede IS
      'Rede de ensino usada como partição do ranking: todas | municipal | estadual | privada. "todas" = sem filtro de rede (equivalente a network=undef no model).';
  COMMENT ON COLUMN analytics.ranking_escola.id_escola IS
      'Código INEP da escola (co_entidade / id_escola conforme a fonte).';
  COMMENT ON COLUMN analytics.ranking_escola.ano IS
      'Ano de referência do dado-fonte (nu_ano_censo para indicadores "mv"; ano do IDEB para indicadores "ideb") usado para calcular esta linha.';
  COMMENT ON COLUMN analytics.ranking_escola.valor IS
      'Valor do indicador para a escola no ano de referência (equivalente a "value" retornado pela query original).';
  COMMENT ON COLUMN analytics.ranking_escola.rank_municipio IS
      'Posição da escola no município (RANK() particionado por co_municipio, dentro da rede filtrada).';
  COMMENT ON COLUMN analytics.ranking_escola.total_municipio IS
      'Total de escolas comparadas no município para esse indicador/rede/ano.';
  COMMENT ON COLUMN analytics.ranking_escola.rank_estado IS
      'Posição da escola no estado.';
  COMMENT ON COLUMN analytics.ranking_escola.total_estado IS
      'Total de escolas comparadas no estado.';
  COMMENT ON COLUMN analytics.ranking_escola.rank_nacional IS
      'Posição da escola nacionalmente. Sempre computado no refresh, independente do opts.national usado na consulta em tempo real.';
  COMMENT ON COLUMN analytics.ranking_escola.total_nacional IS
      'Total de escolas comparadas nacionalmente.';
  COMMENT ON COLUMN analytics.ranking_escola.data_atualizacao IS
      'Timestamp da última recomputação desta linha pelo job de refresh.';

COMMIT;
