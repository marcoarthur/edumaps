-- Deploy edumaps:relacoes_escolar to pg
-- requires: gestor_reunioes
--
-- Relações institucionais da escola: cadastro de entidades externas (órgãos,
-- escolas, fornecedores, famílias, comunidade, parceiros, conselhos) e das
-- relações da escola com elas (o centro do modelo), com taxonomia editável.
--
-- NÃO é um CRM: nada de leads/oportunidades; o centro é a RELAÇÃO
-- (Entidade -> Relação -> Gestão). A gestão (interações/documentos/tarefas)
-- entra em etapas seguintes.

BEGIN;

  -- Taxonomia editável: eixo 'entidade' (grupo do ator externo) e
  -- 'finalidade' (por que a escola se relaciona). Semeada por escola.
  CREATE TABLE clean.relacoes_categorias (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    eixo       text        NOT NULL CHECK (eixo IN ('entidade', 'finalidade')),
    nome       text        NOT NULL,
    origem     text        NOT NULL DEFAULT 'manual' CHECK (origem IN ('padrao', 'manual')),
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes_categorias IS
    'Taxonomia das relações institucionais, nomeada livremente pelo gestor. eixo=entidade (grupo do ator externo) ou eixo=finalidade (motivo da relação). Categorias de origem padrao são semeadas.';
  COMMENT ON COLUMN clean.relacoes_categorias.origem IS
    'padrao: semeada com a taxonomia inicial; manual: criada pelo gestor.';

  CREATE UNIQUE INDEX uq_relacoes_categorias_inep_eixo_nome
    ON clean.relacoes_categorias (cod_inep, eixo, lower(nome));
  CREATE INDEX idx_relacoes_categorias_inep ON clean.relacoes_categorias (cod_inep);

  -- Entidades externas: com quem a escola se relaciona.
  CREATE TABLE clean.relacoes_entidades (
    id                  bigserial   PRIMARY KEY,
    cod_inep            bigint      NOT NULL,
    gestor_id           bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    tipo                text,
    nome                text        NOT NULL,
    identificador       text,
    responsavel_externo text,
    email               text,
    telefone            text,
    site                text,
    endereco            text,
    observacoes         text,
    atributos           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT NOW(),
    updated_at          timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes_entidades IS
    'Atores externos com quem a escola se relaciona (órgãos públicos, outras escolas, fornecedores, famílias, comunidade, parceiros, conselhos). O tipo é livre e normalmente corresponde a uma categoria de eixo=entidade.';
  COMMENT ON COLUMN clean.relacoes_entidades.identificador IS
    'CNPJ/registro ou outro identificador oficial, em texto livre.';
  COMMENT ON COLUMN clean.relacoes_entidades.atributos IS
    'Campos arbitrários definidos pelo gestor (chave/valor), sem alterar o schema.';

  CREATE UNIQUE INDEX uq_relacoes_entidades_inep_nome
    ON clean.relacoes_entidades (cod_inep, lower(nome));
  CREATE INDEX idx_relacoes_entidades_inep ON clean.relacoes_entidades (cod_inep);
  CREATE INDEX idx_relacoes_entidades_atributos ON clean.relacoes_entidades USING gin (atributos);

  -- Relações: o centro do modelo (entidade -> assunto -> responsável -> próxima ação).
  CREATE TABLE clean.relacoes (
    id                  bigserial   PRIMARY KEY,
    cod_inep            bigint      NOT NULL,
    gestor_id           bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    entidade_id         bigint      NOT NULL REFERENCES clean.relacoes_entidades (id) ON DELETE RESTRICT,
    finalidade          text,
    assunto             text        NOT NULL,
    descricao           text,
    status              text        NOT NULL DEFAULT 'aberta'
      CHECK (status IN ('aberta', 'em_andamento', 'aguardando', 'concluida', 'cancelada')),
    prioridade          text        NOT NULL DEFAULT 'media'
      CHECK (prioridade IN ('baixa', 'media', 'alta', 'urgente')),
    responsavel_interno text,
    inicio              date,
    proxima_acao        text,
    prazo               date,
    atributos           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT NOW(),
    updated_at          timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.relacoes IS
    'Relações institucionais da escola com uma entidade externa: assunto, finalidade, responsável interno, próxima ação e prazo. É o centro do módulo (a escola não "possui um fornecedor": ela tem uma relação com ele).';
  COMMENT ON COLUMN clean.relacoes.entidade_id IS
    'Entidade externa da relação. ON DELETE RESTRICT: não se apaga entidade com relações.';
  COMMENT ON COLUMN clean.relacoes.finalidade IS
    'Motivo da relação (obrigação/regulação, solicitação, prestação de contas, contratação, comunicação, parceria, participação, resolução de problema, projeto, acompanhamento). Texto livre.';
  COMMENT ON COLUMN clean.relacoes.status IS
    'aberta -> em_andamento -> aguardando -> concluida | cancelada.';
  COMMENT ON COLUMN clean.relacoes.responsavel_interno IS
    'Quem na escola responde pela relação (texto livre; a escola tem vários profissionais além do gestor).';
  COMMENT ON COLUMN clean.relacoes.proxima_acao IS
    'Próximo passo combinado (ex.: "cobrar orçamento do telhado").';
  COMMENT ON COLUMN clean.relacoes.atributos IS
    'Campos arbitrários definidos pelo gestor (chave/valor), sem alterar o schema.';

  CREATE INDEX idx_relacoes_inep        ON clean.relacoes (cod_inep);
  CREATE INDEX idx_relacoes_entidade    ON clean.relacoes (entidade_id);
  CREATE INDEX idx_relacoes_status      ON clean.relacoes (status);
  CREATE INDEX idx_relacoes_prazo       ON clean.relacoes (prazo);
  CREATE INDEX idx_relacoes_atributos   ON clean.relacoes USING gin (atributos);

COMMIT;
