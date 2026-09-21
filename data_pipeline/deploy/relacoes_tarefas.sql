-- Deploy edumaps:relacoes_tarefas to pg
-- requires: relacoes_gestao
--
-- Etapa 5: tarefas (checklist) de uma relação institucional. Os indicadores
-- são derivados (sem tabela nova) de relacoes/interacoes/tarefas.

BEGIN;

  CREATE TABLE clean.relacoes_tarefas (
    id           bigserial   PRIMARY KEY,
    relacao_id   bigint      NOT NULL REFERENCES clean.relacoes (id) ON DELETE CASCADE,
    gestor_id    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    descricao    text        NOT NULL,
    responsavel  text,
    prazo        date,
    status       text        NOT NULL DEFAULT 'pendente'
      CHECK (status IN ('pendente', 'concluida')),
    concluida_em timestamptz,
    created_at   timestamptz NOT NULL DEFAULT NOW(),
    updated_at   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes_tarefas IS
    'Tarefas (checklist) de uma relação institucional: o que precisa ser feito, por quem e até quando.';
  COMMENT ON COLUMN clean.relacoes_tarefas.status IS
    'pendente -> concluida. Ao concluir, concluida_em é preenchido.';
  COMMENT ON COLUMN clean.relacoes_tarefas.responsavel IS
    'Responsável pela tarefa em texto livre (a escola tem vários profissionais).';

  CREATE INDEX idx_relacoes_tarefas_relacao ON clean.relacoes_tarefas (relacao_id);
  CREATE INDEX idx_relacoes_tarefas_status  ON clean.relacoes_tarefas (status);

COMMIT;
