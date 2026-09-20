-- Deploy edumaps:gestor_reunioes to pg
-- requires: gestor_respostas
--
-- Reuniões e atas do gestor: agenda de contatos, grupos (organizados por
-- drag-and-drop) e reuniões com convidados, pauta e ata.
--   - contato_grupos / contatos: agenda PII — exposta apenas ao gestor logado.
--   - reunioes: agendadas pelo wizard (quando/quem/aviso/onde/pauta).
--   - reunioes_participantes: snapshot dos convidados (via grupo opcional).
--   - reuniao_anexos: upload real de arquivos (um 'pauta' e um 'ata' por reunião);
--     arquivo físico fica fora do banco (dir de upload configurável).

BEGIN;

  -- Grupos de contatos (professores, colaboradores, pais, conselho...).
  CREATE TABLE clean.contato_grupos (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    nome       text        NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (cod_inep, nome)
  );

  COMMENT ON TABLE clean.contato_grupos IS
    'Grupos de contatos da escola (ex.: Professores, Pais, Conselho). Cria/edita pelo gestor logado; contatos entram via drag-and-drop no painel.';
  COMMENT ON COLUMN clean.contato_grupos.nome IS
    'Nome do grupo (1..60 caracteres). Único por escola (UNIQUE cod_inep, nome).';

  -- Contatos da agenda da escola (PII).
  CREATE TABLE clean.contatos (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    nome       text        NOT NULL,
    email      text,
    telefone   text,
    cargo      text,
    grupo_id   bigint      REFERENCES clean.contato_grupos (id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.contatos IS
    'Agenda de contatos da escola (professores, colaboradores, pais, órgãos). PII — só o gestor logado da escola acessa.';
  COMMENT ON COLUMN clean.contatos.email IS
    'E-mail do contato (opcional). Único por escola quando preenchido (índice parcial lower(email)).';
  COMMENT ON COLUMN clean.contatos.grupo_id IS
    'Grupo do contato. DELETE SET NULL: remover um grupo não apaga os contatos, apenas os deixa sem grupo.';

  CREATE UNIQUE INDEX uq_contatos_inep_email
    ON clean.contatos (cod_inep, lower(email)) WHERE email IS NOT NULL;
  CREATE INDEX idx_contatos_cod_inep ON clean.contatos (cod_inep);
  CREATE INDEX idx_contatos_grupo    ON clean.contatos (grupo_id);

  -- Reuniões (agenda + atas).
  CREATE TABLE clean.reunioes (
    id           bigserial   PRIMARY KEY,
    cod_inep     bigint      NOT NULL,
    gestor_id    bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    titulo       text        NOT NULL,
    quando       timestamptz NOT NULL,
    duracao_min  integer     NOT NULL DEFAULT 60,
    onde_label   text,
    onde_link    text,
    aviso_metodo text        NOT NULL DEFAULT 'todos'
      CHECK (aviso_metodo IN ('whatsapp', 'email', 'todos')),
    status       text        NOT NULL DEFAULT 'agendada'
      CHECK (status IN ('agendada', 'realizada', 'cancelada')),
    pauta_texto  text,
    ata_texto    text,
    created_at   timestamptz NOT NULL DEFAULT NOW(),
    updated_at   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.reunioes IS
    'Reuniões agendadas pelo gestor. Não recria as ferramentas profissionais de vídeo/reunião: guarda quando/quem/método de aviso/onde (plataforma externa) e os anexos pauta e ata.';
  COMMENT ON COLUMN clean.reunioes.quando IS
    'Data/hora agendada (timestamptz). Representa o "quando" do wizard.';
  COMMENT ON COLUMN clean.reunioes.aviso_metodo IS
    'Método de aviso escolhido no wizard: whatsapp, email ou todos. Sem infra de envio real — o frontend gera convite copiável.';
  COMMENT ON COLUMN clean.reunioes.status IS
    'agendada → realizada (libera edição da ata) | agendada → cancelada. Ata editável também enquanto agendada.';
  COMMENT ON COLUMN clean.reunioes.pauta_texto IS
    'Material/conteúdo a disponibilizar antes da reunião (anexo de texto; arquivo vai em reuniao_anexos tipo pauta).';
  COMMENT ON COLUMN clean.reunioes.ata_texto IS
    'Ata da reunião (texto). Arquivo anexado vai em reuniao_anexos tipo ata.';

  CREATE INDEX idx_reunioes_cod_inep_quando ON clean.reunioes (cod_inep, quando);
  CREATE INDEX idx_reunioes_cod_inep_status ON clean.reunioes (cod_inep, status);

  -- Participantes: snapshot dos contatos convidados.
  CREATE TABLE clean.reunioes_participantes (
    reuniao_id   bigint NOT NULL REFERENCES clean.reunioes (id) ON DELETE CASCADE,
    contato_id   bigint NOT NULL REFERENCES clean.contatos (id) ON DELETE CASCADE,
    via_grupo_id bigint REFERENCES clean.contato_grupos (id) ON DELETE SET NULL,
    PRIMARY KEY (reuniao_id, contato_id)
  );

  COMMENT ON TABLE clean.reunioes_participantes IS
    'Convidados de uma reunião. Grupos são resolvidos em contatos no momento do agendamento (snapshot), guardando via_grupo_id para exibição ("convidado via grupo X").';
  COMMENT ON COLUMN clean.reunioes_participantes.via_grupo_id IS
    'Grupo que originou o convite (se o contato entrou por um grupo). NULL se foi selecionado individualmente.';

  CREATE INDEX idx_reunioes_participantes_contato ON clean.reunioes_participantes (contato_id);

  -- Anexos (upload real): um de 'pauta' e um de 'ata' por reunião.
  CREATE TABLE clean.reuniao_anexos (
    id            bigserial   PRIMARY KEY,
    reuniao_id    bigint      NOT NULL REFERENCES clean.reunioes (id) ON DELETE CASCADE,
    tipo          text        NOT NULL CHECK (tipo IN ('pauta', 'ata')),
    nome_original text        NOT NULL,
    caminho       text        NOT NULL,
    mime          text,
    tamanho       bigint      NOT NULL DEFAULT 0,
    criado_em     timestamptz NOT NULL DEFAULT NOW(),
    UNIQUE (reuniao_id, tipo)
  );

  COMMENT ON TABLE clean.reuniao_anexos IS
    'Arquivo anexado a uma reunião: "pauta" (material a disponibilizar) ou "ata" (minuta salva). Um por tipo por reunião (UNIQUE). O arquivo físico fica no dir de upload configurado (upload_dir), não no banco.';
  COMMENT ON COLUMN clean.reuniao_anexos.nome_original IS
    'Nome original enviado pelo gestor (exibição). O arquivo em disco usa nome sanitizado (uuid + extensão).';
  COMMENT ON COLUMN clean.reuniao_anexos.caminho IS
    'Caminho relativo ao upload_dir do arquivo (ex.: <cod_inep>/<reuniao_id>/<uuid>.<ext>).';

COMMIT;