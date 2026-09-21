-- Deploy edumaps:inventario_escolar to pg
-- requires: gestor_reunioes
--
-- Inventário escolar do gestor: categorias de nome livre, itens (recursos e
-- serviços unificados), fornecedores e anexos. Tudo escopado por escola.
-- O Censo (clean.censo_escolas) é apenas LIDO — nunca alterado; o baseline é
-- derivado em tempo real e "importado" para itens manuais via censo_ref.

BEGIN;

  -- Categorias: taxonomia livre do gestor (recurso ou serviço).
  CREATE TABLE clean.inventario_categorias (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    tipo       text        NOT NULL CHECK (tipo IN ('recurso', 'servico')),
    nome       text        NOT NULL,
    origem     text        NOT NULL DEFAULT 'manual' CHECK (origem IN ('censo', 'manual')),
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.inventario_categorias IS
    'Categorias do inventário da escola, criadas/nomeadas livremente pelo gestor (recurso ou serviço). Categorias de origem censo são semeadas a partir da taxonomia do Censo.';
  COMMENT ON COLUMN clean.inventario_categorias.tipo IS
    'recurso: bens físicos (computadores, giz, lousas). servico: contas/contratos (água, luz, internet).';
  COMMENT ON COLUMN clean.inventario_categorias.origem IS
    'censo: semeada a partir da taxonomia do Censo; manual: criada pelo gestor.';
  COMMENT ON COLUMN clean.inventario_categorias.gestor_id IS
    'Gestor que criou a categoria (NULL nas semeadas do censo).';

  CREATE UNIQUE INDEX uq_inventario_categorias_inep_tipo_nome
    ON clean.inventario_categorias (cod_inep, tipo, lower(nome));
  CREATE INDEX idx_inventario_categorias_inep ON clean.inventario_categorias (cod_inep);

  -- Fornecedores / prestadores de serviço.
  CREATE TABLE clean.inventario_fornecedores (
    id           bigserial   PRIMARY KEY,
    cod_inep     bigint      NOT NULL,
    gestor_id    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    nome         text        NOT NULL,
    tipo_servico text,
    email        text,
    telefone     text,
    site         text,
    documento    text,
    observacoes  text,
    atributos    jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at   timestamptz NOT NULL DEFAULT NOW(),
    updated_at   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.inventario_fornecedores IS
    'Fornecedores e prestadores de serviço da escola (água/luz/internet, limpeza, manutenção...). Campos extras vão em atributos (JSONB).';
  COMMENT ON COLUMN clean.inventario_fornecedores.tipo_servico IS
    'Ramo/tipo de serviço em texto livre (ex.: água, energia, internet, limpeza).';
  COMMENT ON COLUMN clean.inventario_fornecedores.documento IS
    'CNPJ/CPF ou outro documento em texto livre.';
  COMMENT ON COLUMN clean.inventario_fornecedores.atributos IS
    'Campos arbitrários definidos pelo gestor (chave/valor), sem alterar o schema.';

  CREATE UNIQUE INDEX uq_inventario_fornecedores_inep_nome
    ON clean.inventario_fornecedores (cod_inep, lower(nome));
  CREATE INDEX idx_inventario_fornecedores_inep ON clean.inventario_fornecedores (cod_inep);

  -- Itens: recursos e serviços unificados (o tipo vem da categoria).
  CREATE TABLE clean.inventario_itens (
    id             bigserial   PRIMARY KEY,
    cod_inep       bigint      NOT NULL,
    gestor_id      bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    categoria_id   bigint      NOT NULL REFERENCES clean.inventario_categorias (id) ON DELETE RESTRICT,
    fornecedor_id  bigint      REFERENCES clean.inventario_fornecedores (id) ON DELETE SET NULL,
    nome           text        NOT NULL,
    descricao      text,
    quantidade     numeric     NOT NULL DEFAULT 1,
    unidade        text,
    estado         text,
    identificador  text,
    periodicidade  text,
    valor          numeric,
    data_aquisicao date,
    censo_ref      text,
    atributos      jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT NOW(),
    updated_at     timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.inventario_itens IS
    'Itens do inventário da escola: recursos (bens) e serviços (contas/contratos), discriminados pelo tipo da categoria. Campos extras em atributos (JSONB).';
  COMMENT ON COLUMN clean.inventario_itens.categoria_id IS
    'Categoria do item. ON DELETE RESTRICT: não se apaga categoria com itens.';
  COMMENT ON COLUMN clean.inventario_itens.fornecedor_id IS
    'Fornecedor/prestador do item (típico de serviços). ON DELETE SET NULL.';
  COMMENT ON COLUMN clean.inventario_itens.quantidade IS
    'Quantidade do recurso (default 1). Para serviços costuma ser 1 (contrato/conta).';
  COMMENT ON COLUMN clean.inventario_itens.unidade IS
    'Unidade em texto livre (un, caixa, kg, m², conta, contrato...).';
  COMMENT ON COLUMN clean.inventario_itens.estado IS
    'Estado de conservação em texto livre (novo, bom, regular, ruim, danificado...).';
  COMMENT ON COLUMN clean.inventario_itens.identificador IS
    'Identificador livre: nº de série, patrimônio, nº da conta ou do contrato.';
  COMMENT ON COLUMN clean.inventario_itens.periodicidade IS
    'Periodicidade do serviço em texto livre (mensal, bimestral, anual...).';
  COMMENT ON COLUMN clean.inventario_itens.valor IS
    'Valor monetário (unitário para recursos, periódico para serviços). Opcional.';
  COMMENT ON COLUMN clean.inventario_itens.censo_ref IS
    'Referência ao campo do Censo que originou o item importado (idempotência da importação); NULL em itens manuais.';
  COMMENT ON COLUMN clean.inventario_itens.atributos IS
    'Campos arbitrários definidos pelo gestor (chave/valor), sem alterar o schema.';

  CREATE INDEX idx_inventario_itens_inep       ON clean.inventario_itens (cod_inep);
  CREATE INDEX idx_inventario_itens_categoria  ON clean.inventario_itens (categoria_id);
  CREATE INDEX idx_inventario_itens_fornecedor ON clean.inventario_itens (fornecedor_id);
  CREATE INDEX idx_inventario_itens_atributos  ON clean.inventario_itens USING gin (atributos);
  CREATE UNIQUE INDEX uq_inventario_itens_inep_censo_ref
    ON clean.inventario_itens (cod_inep, censo_ref) WHERE censo_ref IS NOT NULL;

  -- Anexos (fotos, notas fiscais) — vários por item; arquivo físico no upload_dir.
  CREATE TABLE clean.inventario_anexos (
    id            bigserial   PRIMARY KEY,
    item_id       bigint      NOT NULL REFERENCES clean.inventario_itens (id) ON DELETE CASCADE,
    nome_original text        NOT NULL,
    caminho       text        NOT NULL,
    mime          text,
    tamanho       bigint      NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.inventario_anexos IS
    'Anexos de um item do inventário (fotos, notas fiscais). Vários por item; o arquivo físico fica no dir de upload (upload_dir), não no banco.';
  COMMENT ON COLUMN clean.inventario_anexos.caminho IS
    'Caminho relativo ao upload_dir (ex.: <cod_inep>/inventario/<item_id>/<uuid>.<ext>).';

  CREATE INDEX idx_inventario_anexos_item ON clean.inventario_anexos (item_id);

COMMIT;
