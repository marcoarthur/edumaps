-- Deploy edumaps:planos_gestao to pg
-- requires: antt_sem_fonte
-- requires: gestor_documentos
--
-- #369 (épico #368): o plano da escola como objeto acompanhável, e não só
-- arquivo. Estrutura: plano → objetivos → metas (mensuráveis) e ações
-- (responsável, prazo, situação, recurso). Medições, indicadores oficiais
-- (#370) e evidências (#372) entram em changes próprias.
--
-- Tabelas INTERNAS da gestão escolar (o responsável é texto livre e pode ter
-- nome de servidor): sem GRANT ao edumaps_leitor — os nomes estão na lista de
-- sensíveis de backend/t/02-models/leitor_grants.t.

BEGIN;

  CREATE TABLE clean.planos_gestao (
    id            bigserial   PRIMARY KEY,
    cod_inep      bigint      NOT NULL,
    criado_por    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    tipo          text        NOT NULL CHECK (tipo IN ('gestao', 'acao', 'ppp', 'outro')),
    titulo        text        NOT NULL CHECK (length(btrim(titulo)) BETWEEN 1 AND 200),
    descricao     text,
    inicio        date,
    fim           date,
    situacao      text        NOT NULL DEFAULT 'rascunho'
                              CHECK (situacao IN ('rascunho', 'vigente', 'encerrado')),
    documento_id  bigint      REFERENCES clean.escola_documentos (id) ON DELETE SET NULL,
    alertas_ativos boolean    NOT NULL DEFAULT TRUE,
    arquivado_em  timestamptz,
    created_at    timestamptz NOT NULL DEFAULT NOW(),
    updated_at    timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_planos_gestao_periodo CHECK (inicio IS NULL OR fim IS NULL OR fim >= inicio)
  );
  CREATE INDEX idx_planos_gestao_escola ON clean.planos_gestao (cod_inep, situacao);

  COMMENT ON TABLE clean.planos_gestao IS
    'Plano da escola acompanhável (#369): plano de gestão do diretor, plano de ação (PDDE/PDE Escola), PPP ou outro. O arquivo do plano continua em Documentos (documento_id).';
  COMMENT ON COLUMN clean.planos_gestao.tipo IS 'gestao (plano de gestão do diretor) | acao (plano de ação PDDE/PDE Escola) | ppp | outro';
  COMMENT ON COLUMN clean.planos_gestao.situacao IS 'rascunho -> vigente -> encerrado. Encerrado é só leitura (pode ser reaberto, com auditoria).';
  COMMENT ON COLUMN clean.planos_gestao.arquivado_em IS 'Arquivado (excluído da lista) — o plano não é apagado: tem valor de histórico.';

  CREATE TABLE clean.planos_objetivos (
    id          bigserial   PRIMARY KEY,
    plano_id    bigint      NOT NULL REFERENCES clean.planos_gestao (id) ON DELETE CASCADE,
    titulo      text        NOT NULL CHECK (length(btrim(titulo)) BETWEEN 1 AND 300),
    descricao   text,
    ordem       integer     NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT NOW(),
    updated_at  timestamptz NOT NULL DEFAULT NOW()
  );
  CREATE INDEX idx_planos_objetivos_plano ON clean.planos_objetivos (plano_id, ordem);

  COMMENT ON TABLE clean.planos_objetivos IS 'Objetivos de um plano da escola (#369).';

  CREATE TABLE clean.planos_metas (
    id                bigserial   PRIMARY KEY,
    objetivo_id       bigint      NOT NULL REFERENCES clean.planos_objetivos (id) ON DELETE CASCADE,
    descricao         text        NOT NULL CHECK (length(btrim(descricao)) BETWEEN 1 AND 500),
    unidade           text,
    sentido           text        NOT NULL DEFAULT 'aumentar'
                                  CHECK (sentido IN ('aumentar', 'reduzir', 'manter')),
    indicador_codigo  text,
    linha_base        numeric,
    alvo              numeric,
    prazo             date,
    created_at        timestamptz NOT NULL DEFAULT NOW(),
    updated_at        timestamptz NOT NULL DEFAULT NOW()
  );
  CREATE INDEX idx_planos_metas_objetivo ON clean.planos_metas (objetivo_id);

  COMMENT ON TABLE clean.planos_metas IS
    'Metas mensuráveis de um objetivo (#369). Sem linha de base ou alvo a meta é rascunho e fica fora do progresso (não vira 0%).';
  COMMENT ON COLUMN clean.planos_metas.indicador_codigo IS
    'Indicador oficial da escola a que a meta se liga (catálogo da #370); NULL = meta manual.';

  CREATE TABLE clean.planos_acoes (
    id              bigserial   PRIMARY KEY,
    objetivo_id     bigint      NOT NULL REFERENCES clean.planos_objetivos (id) ON DELETE CASCADE,
    meta_id         bigint      REFERENCES clean.planos_metas (id) ON DELETE SET NULL,
    descricao       text        NOT NULL CHECK (length(btrim(descricao)) BETWEEN 1 AND 500),
    responsavel     text,
    inicio          date,
    prazo           date,
    situacao        text        NOT NULL DEFAULT 'nao_iniciada'
                                CHECK (situacao IN ('nao_iniciada', 'em_andamento', 'concluida', 'cancelada')),
    concluida_em    timestamptz,
    custo_previsto  numeric     CHECK (custo_previsto IS NULL OR custo_previsto >= 0),
    fonte_recurso   text        CHECK (fonte_recurso IS NULL OR fonte_recurso IN ('pdde', 'fundeb', 'proprio', 'parceria', 'outro')),
    created_at      timestamptz NOT NULL DEFAULT NOW(),
    updated_at      timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_planos_acoes_periodo CHECK (inicio IS NULL OR prazo IS NULL OR prazo >= inicio),
    CONSTRAINT ck_planos_acoes_conclusao CHECK ((situacao = 'concluida') = (concluida_em IS NOT NULL))
  );
  CREATE INDEX idx_planos_acoes_objetivo ON clean.planos_acoes (objetivo_id);
  CREATE INDEX idx_planos_acoes_prazo ON clean.planos_acoes (prazo) WHERE situacao IN ('nao_iniciada', 'em_andamento');

  COMMENT ON TABLE clean.planos_acoes IS
    'Ações de um objetivo (#369), opcionalmente ligadas a uma meta do mesmo objetivo. "Atrasada" é derivada (prazo vencido e não concluída), nunca gravada.';
  COMMENT ON COLUMN clean.planos_acoes.responsavel IS
    'Responsável em texto livre (a escola tem profissionais sem conta na plataforma).';
  COMMENT ON COLUMN clean.planos_acoes.fonte_recurso IS 'pdde | fundeb | proprio | parceria | outro';

  -- A meta de uma ação tem de ser do MESMO objetivo (a FK sozinha não garante).
  CREATE FUNCTION clean.planos_acoes_meta_do_objetivo() RETURNS trigger
  LANGUAGE plpgsql AS $$
  BEGIN
    IF NEW.meta_id IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM clean.planos_metas m
          WHERE m.id = NEW.meta_id AND m.objetivo_id = NEW.objetivo_id) THEN
      RAISE EXCEPTION 'a meta % não pertence ao objetivo %', NEW.meta_id, NEW.objetivo_id
        USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END
  $$;
  CREATE TRIGGER trg_planos_acoes_meta_do_objetivo
    BEFORE INSERT OR UPDATE OF meta_id, objetivo_id ON clean.planos_acoes
    FOR EACH ROW EXECUTE FUNCTION clean.planos_acoes_meta_do_objetivo();

  CREATE TABLE clean.planos_auditoria (
    id           bigserial   PRIMARY KEY,
    plano_id     bigint      NOT NULL REFERENCES clean.planos_gestao (id) ON DELETE CASCADE,
    cod_inep     bigint      NOT NULL,
    gestor_id    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    entidade     text        NOT NULL CHECK (entidade IN ('plano', 'objetivo', 'meta', 'acao')),
    entidade_id  bigint      NOT NULL,
    acao         text        NOT NULL CHECK (acao IN ('criado', 'alterado', 'excluido', 'encerrado', 'reaberto', 'arquivado')),
    detalhes     jsonb       NOT NULL DEFAULT '{}',
    criado_em    timestamptz NOT NULL DEFAULT NOW()
  );
  CREATE INDEX idx_planos_auditoria_plano ON clean.planos_auditoria (plano_id, criado_em DESC);

  COMMENT ON TABLE clean.planos_auditoria IS
    'Auditoria dos planos da escola (#369): quem mudou o quê e quando, por plano.';

COMMIT;
