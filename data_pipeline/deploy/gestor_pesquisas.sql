-- Deploy edumaps:gestor_pesquisas to pg
-- requires: schemas

BEGIN;

  -- Gestores: pessoas que criam e gerem as pesquisas de uma escola.
  -- Um gestor só gere UMA escola (cod_inep); uma escola pode ter vários gestores.
  -- Sem autenticação no projeto ainda: o e-mail é a identidade da sessão (upsert).
  CREATE TABLE clean.gestores (
    id         bigserial    PRIMARY KEY,
    cod_inep   bigint       NOT NULL,
    nome       text         NOT NULL,
    email      text         NOT NULL UNIQUE,
    telefone   text,
    cargo      text,
    cpf        text         UNIQUE,
    created_at timestamptz  NOT NULL DEFAULT NOW(),
    updated_at timestamptz  NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.gestores IS
    'Gestores escolares: criam e gerem as pesquisas da comunidade. PII — CPF nunca é exposto completo na API.';
  COMMENT ON COLUMN clean.gestores.cod_inep IS
    'Código INEP da escola que o gestor gere (um gestor = uma escola; vários gestores podem gerir a mesma escola).';
  COMMENT ON COLUMN clean.gestores.nome IS
    'Nome completo do gestor (obrigatório).';
  COMMENT ON COLUMN clean.gestores.email IS
    'E-mail do gestor — identidade única da sessão (upsert por e-mail; sem login nesta fase).';
  COMMENT ON COLUMN clean.gestores.telefone IS
    'Telefone/WhatsApp do gestor (opcional).';
  COMMENT ON COLUMN clean.gestores.cargo IS
    'Cargo do gestor na escola, ex.: Diretor, Vice-diretor, Coordenador(a).';
  COMMENT ON COLUMN clean.gestores.cpf IS
    'CPF do gestor (opcional, LGPD). Armazenado válido, mas devolvido mascarado na API.';

  CREATE INDEX idx_gestores_cod_inep ON clean.gestores (cod_inep);

  -- Pesquisas (surveys) criadas pelo gestor para a comunidade escolar.
  CREATE TABLE clean.gestor_pesquisas (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id),
    titulo     text        NOT NULL,
    descricao  text,
    status     text        NOT NULL DEFAULT 'rascunho'
      CHECK (status IN ('rascunho', 'publicada', 'arquivada')),
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.gestor_pesquisas IS
    'Pesquisas criadas pelo gestor (creator_id = gestor_id) para a comunidade: pais, alunos e professores.';
  COMMENT ON COLUMN clean.gestor_pesquisas.cod_inep IS
    'Escola dona da pesquisa (copiada do gestor no momento da criação).';
  COMMENT ON COLUMN clean.gestor_pesquisas.gestor_id IS
    'Gestor criador da pesquisa (creator). Rascunhos são editáveis; publicada vira read-only na API.';
  COMMENT ON COLUMN clean.gestor_pesquisas.titulo IS
    'Título da pesquisa (3..120 caracteres).';
  COMMENT ON COLUMN clean.gestor_pesquisas.descricao IS
    'Descrição/apresentação opcional da pesquisa.';
  COMMENT ON COLUMN clean.gestor_pesquisas.status IS
    'rascunho (edição livre) → publicada (finalizada, read-only; pronta p/ fase 2 de coleta) → arquivada.';

  CREATE INDEX idx_gestor_pesquisas_cod_inep ON clean.gestor_pesquisas (cod_inep);
  CREATE INDEX idx_gestor_pesquisas_gestor   ON clean.gestor_pesquisas (gestor_id);

  -- Perguntas de cada pesquisa, em ordem.
  CREATE TABLE clean.gestor_pesquisas_perguntas (
    id          bigserial PRIMARY KEY,
    pesquisa_id bigint    NOT NULL REFERENCES clean.gestor_pesquisas (id) ON DELETE CASCADE,
    ordem       integer   NOT NULL,
    texto       text      NOT NULL,
    tipo        text      NOT NULL
      CHECK (tipo IN ('unica', 'multipla', 'dropdown', 'texto')),
    obrigatoria boolean   NOT NULL DEFAULT FALSE,
    opcoes      jsonb,
    UNIQUE (pesquisa_id, ordem)
  );

  COMMENT ON TABLE clean.gestor_pesquisas_perguntas IS
    'Perguntas de uma pesquisa, na ordem definida pelo gestor no wizard. Opções vêm como JSONB na resposta.';
  COMMENT ON COLUMN clean.gestor_pesquisas_perguntas.ordem IS
    'Posição da pergunta no formulário (1..N); substituição do autosave reescreve todas em transação.';
  COMMENT ON COLUMN clean.gestor_pesquisas_perguntas.texto IS
    'Texto da pergunta (1..500 caracteres).';
  COMMENT ON COLUMN clean.gestor_pesquisas_perguntas.tipo IS
    'Tipo de resposta: unica (radio, ex.: sim/não), multipla (checkbox), dropdown (lista) ou texto (livre).';
  COMMENT ON COLUMN clean.gestor_pesquisas_perguntas.obrigatoria IS
    'Se a resposta é obrigatória ao responder (fase 2).';
  COMMENT ON COLUMN clean.gestor_pesquisas_perguntas.opcoes IS
    'JSONB array [{id, label}] das opções — obrigatório p/ unica/multipla/dropdown, NULL p/ texto.';

  CREATE INDEX idx_gestor_pesquisas_perguntas_pesquisa
    ON clean.gestor_pesquisas_perguntas (pesquisa_id, ordem);

COMMIT;