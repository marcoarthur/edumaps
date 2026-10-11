-- Deploy edumaps:canal_listas_autoinscricao to pg
-- requires: canal_mensagens
--
-- Listas nomeadas com QR code para autoinscrição de contatos (Fase 0 — issue
-- #208, canal telefone, sem validação). Quatro tabelas em `clean`:
--
--   canal_listas         a "lista nomeada" da escola (entidade canônica; NÃO
--                        depende de contato_grupos, que será deprecado);
--   canal_qrcodes        o segredo público por lista: token UUID (gerado pela
--                        aplicação, sem default no banco), status, expiração e
--                        limite de usos;
--   canal_lista_membros  pertencimento contato ↔ lista (desacoplado de grupos);
--   canal_inscricoes     proveniência/auditoria das submissões via QR
--                        (append-only, sem descarte).
--
-- Modelo de telefone SENSÍVEL e NÃO DESTRUTIVO (decisão da spec): guarda o
-- bruto + normalizado, MARCA (validado / duplicado_de / conflito) e nunca
-- descarta. PII — acesso restrito, como clean.contatos.

BEGIN;

  -- ---------------------------------------------------------------------
  -- canal_listas: a lista nomeada (RF-001)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_listas (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    nome       text        NOT NULL,
    canal      text        NOT NULL DEFAULT 'telefone'
      CHECK (canal IN ('telefone')),           -- expandir nas fases seguintes
    descricao  text,
    ativo      boolean     NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (cod_inep, nome)
    -- sem grupo_id: contato_grupos será deprecado; o pertencimento é da lista.
  );

  COMMENT ON TABLE clean.canal_listas IS
    'Lista nomeada de contatos da escola para autoinscrição (ex.: "Alunos 6ºA", "Responsáveis"). Entidade canônica da agenda — o pertencimento é da lista (canal_lista_membros), não de contato_grupos (a deprecar).';
  COMMENT ON COLUMN clean.canal_listas.cod_inep IS
    'Escola dona da lista. A visão de gestão filtra por aqui (posse do gestor).';
  COMMENT ON COLUMN clean.canal_listas.gestor_id IS
    'Gestor que criou a lista. DELETE CASCADE: remover o gestor remove as listas dele.';
  COMMENT ON COLUMN clean.canal_listas.nome IS
    'Nome da lista. Único por escola (UNIQUE cod_inep, nome).';
  COMMENT ON COLUMN clean.canal_listas.canal IS
    'Canal dos contatos da lista: telefone no MVP (CHECK é a fonte de verdade do banco).';
  COMMENT ON COLUMN clean.canal_listas.ativo IS
    'Desativar a lista impede novas inscrições via QR, sem apagar o histórico.';

  -- ---------------------------------------------------------------------
  -- canal_qrcodes: o token público por lista (RF-002)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_qrcodes (
    id          bigserial   PRIMARY KEY,
    lista_id    bigint      NOT NULL REFERENCES clean.canal_listas (id) ON DELETE CASCADE,
    token       uuid        NOT NULL UNIQUE,   -- 128 bits, segredo público; gerado pela aplicação
    status      text        NOT NULL DEFAULT 'ativo'
      CHECK (status IN ('ativo', 'revogado', 'expirado')),
    expira_em   timestamptz,                   -- NULL = sem expiração (default do MVP)
    max_usos    integer     CHECK (max_usos IS NULL OR max_usos > 0),
    usos        integer     NOT NULL DEFAULT 0,
    criado_por  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    created_at  timestamptz NOT NULL DEFAULT NOW(),
    revogado_em timestamptz
  );

  COMMENT ON TABLE clean.canal_qrcodes IS
    'Token público de inscrição de uma lista (o QR aponta para ele). Rotação = revoga o anterior e cria um novo; a lista mantém o histórico de tokens revogados para auditoria.';
  COMMENT ON COLUMN clean.canal_qrcodes.token IS
    '32 hex (UUID v4) gerado pela aplicação (gen_random_uuid); o banco não tem default. É a capability: quem o possui pode inscrever contatos na lista.';
  COMMENT ON COLUMN clean.canal_qrcodes.status IS
    'ativo (aceita inscrições) -> revogado (revogado_em preenchido) | expirado (expira_em vencido).';
  COMMENT ON COLUMN clean.canal_qrcodes.expira_em IS
    'Validade do token; NULL = sem expiração (default do MVP).';
  COMMENT ON COLUMN clean.canal_qrcodes.max_usos IS
    'Limite de inscrições aceitas; NULL = ilimitado. CHECK garante positivo quando definido.';
  COMMENT ON COLUMN clean.canal_qrcodes.usos IS
    'Quantas inscrições o token já aceitou (contador para max_usos e antiabuso).';
  COMMENT ON COLUMN clean.canal_qrcodes.criado_por IS
    'Gestor que gerou o token (auditoria).';
  COMMENT ON COLUMN clean.canal_qrcodes.revogado_em IS
    'Momento da revogação; NULL enquanto ativo.';

  CREATE INDEX idx_canal_qrcodes_lista
    ON clean.canal_qrcodes (lista_id);

  -- ---------------------------------------------------------------------
  -- canal_lista_membros: pertencimento contato ↔ lista (RF-005/RF-006)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_lista_membros (
    id         bigserial   PRIMARY KEY,
    lista_id   bigint      NOT NULL REFERENCES clean.canal_listas (id) ON DELETE CASCADE,
    contato_id bigint      NOT NULL REFERENCES clean.contatos (id) ON DELETE CASCADE,
    origem     text        NOT NULL DEFAULT 'qrcode'
      CHECK (origem IN ('qrcode', 'manual', 'import')),
    validado   boolean     NOT NULL DEFAULT false,  -- MVP: telefone não validado
    created_at timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (lista_id, contato_id)                   -- um contato por lista, idempotente
  );

  COMMENT ON TABLE clean.canal_lista_membros IS
    'Pertencimento de um contato a uma lista (desacoplado de contato_grupos). UNIQUE (lista_id, contato_id) garante idempotência sob concorrência.';
  COMMENT ON COLUMN clean.canal_lista_membros.contato_id IS
    'DELETE CASCADE: remover o contato desvincula-o das listas (sem descarte da inscrição, que guarda duplicado_de/contato_id SET NULL).';
  COMMENT ON COLUMN clean.canal_lista_membros.origem IS
    'Como o contato entrou na lista: qrcode (autoinscrição), manual ou import.';
  COMMENT ON COLUMN clean.canal_lista_membros.validado IS
    'false no MVP (telefone sem validação de posse). Nunca apagado — só marcado.';

  CREATE INDEX idx_canal_lista_membros_contato
    ON clean.canal_lista_membros (contato_id);

  -- ---------------------------------------------------------------------
  -- canal_inscricoes: proveniência das submissões (RF-004/RF-005)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_inscricoes (
    id                 bigserial   PRIMARY KEY,
    qrcode_id          bigint      REFERENCES clean.canal_qrcodes (id) ON DELETE SET NULL,
    lista_id           bigint      NOT NULL REFERENCES clean.canal_listas (id) ON DELETE CASCADE,
    contato_id         bigint      REFERENCES clean.contatos (id) ON DELETE SET NULL,
    nome               text        NOT NULL,
    telefone           text        NOT NULL,      -- como digitado (bruto)
    telefone_norm      text        NOT NULL,      -- só dígitos; chave de comparação
    validado           boolean     NOT NULL DEFAULT false,  -- MVP: telefone não validado
    duplicado_de       bigint      REFERENCES clean.contatos (id) ON DELETE SET NULL,
    conflito           boolean     NOT NULL DEFAULT false,
    ip_anon            text,      -- HMAC(ip + salt), nunca o IP puro
    user_agent         text,
    consentimento_em   timestamptz NOT NULL,
    consentimento_versao text      NOT NULL,
    created_at         timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_inscricoes IS
    'Proveniência/auditoria de cada submissão de autoinscrição (RF-004). Append-only e sem descarte: o mesmo telefone pode ter várias submissões registradas — é a "marca", não um erro. PII — acesso restrito ao gestor da escola.';
  COMMENT ON COLUMN clean.canal_inscricoes.qrcode_id IS
    'QR que originou a submissão. REFINAMENTO da spec (NOT NULL CASCADE): nullable + ON DELETE SET NULL — revogamos QRs (nunca os apagamos) e, se um dia forem removidos, o histórico de inscrições permanece "sem descarte".';
  COMMENT ON COLUMN clean.canal_inscricoes.lista_id IS
    'Lista alvo da submissão (denormalizado do token para auditoria estável).';
  COMMENT ON COLUMN clean.canal_inscricoes.contato_id IS
    'Contato criado ou reusado em clean.contatos. SET NULL se o contato for removido — a submissão (histórico) permanece.';
  COMMENT ON COLUMN clean.canal_inscricoes.telefone IS
    'Telefone como digitado (bruto), sem normalizar.';
  COMMENT ON COLUMN clean.canal_inscricoes.telefone_norm IS
    'Telefone normalizado (somente dígitos) — chave de comparação do dedupe não destrutivo (RF-005).';
  COMMENT ON COLUMN clean.canal_inscricoes.validado IS
    'false no MVP: telefone sem validação de posse. Nunca apagado — só marcado.';
  COMMENT ON COLUMN clean.canal_inscricoes.duplicado_de IS
    'Contato pré-existente reusado pelo dedupe (mesmo telefone normalizado na escola). NULL = submissão criou o contato.';
  COMMENT ON COLUMN clean.canal_inscricoes.conflito IS
    'true quando nome/telefone divergem do registro pré-existente — o dado antigo NÃO é sobrescrito, apenas marcado (RF-005).';
  COMMENT ON COLUMN clean.canal_inscricoes.ip_anon IS
    'IP anonimizado (HMAC-SHA256 com salt + dia), nunca o IP puro (RNF-002).';
  COMMENT ON COLUMN clean.canal_inscricoes.consentimento_em IS
    'Momento em que o inscrito marcou o consentimento (obrigatório no MVP).';
  COMMENT ON COLUMN clean.canal_inscricoes.consentimento_versao IS
    'Versão do texto de consentimento aceito (auditoria LGPD).';

  CREATE INDEX idx_canal_inscricoes_lista
    ON clean.canal_inscricoes (lista_id);
  CREATE INDEX idx_canal_inscricoes_telefone_norm
    ON clean.canal_inscricoes (telefone_norm);
  CREATE INDEX idx_canal_inscricoes_contato
    ON clean.canal_inscricoes (contato_id);
  CREATE INDEX idx_canal_inscricoes_qrcode
    ON clean.canal_inscricoes (qrcode_id);

COMMIT;