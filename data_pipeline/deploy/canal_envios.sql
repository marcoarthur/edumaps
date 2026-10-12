-- Deploy edumaps:canal_envios to pg
-- requires: canal_email_lgpd
--
-- Envio por e-mail para listas com QR (issue #216 — Fase 3). Change NOVA,
-- única do ciclo (contrato da onda 1): só tabelas novas; nenhuma change já
-- deployada é editada.
--
--   canal_segmentos            listas dinâmicas (regra sobre membros das listas
--                              da escola, resolvida no disparo);
--   canal_envios               envio em massa (rascunho -> agendado/enviando ->
--                              concluído), com contadores e fotografia do alvo;
--   canal_envio_destinatarios  destinatários fixados no disparo (um por
--                              e-mail normalizado), estado por destinatário;
--   canal_optouts              saída de uma lista (por hash do e-mail, sem PII);
--   canal_qr_acessos           funil: acessos diários por QR (sem PII);
--   canal_envio_suspensoes     suspensão do envio de uma escola (admin).
--
-- Ajuste do contrato à spec: duplicados NÃO viram linha de destinatário (o
-- UNIQUE (envio_id, email_hash) impede); só entram no contador `ignorados`
-- do envio — por isso o CHECK de status não tem 'ignorado_duplicado'.

BEGIN;

  -- ---------------------------------------------------------------------
  -- canal_segmentos: listas dinâmicas (RF-305)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_segmentos (
    id         bigserial   PRIMARY KEY,
    cod_inep   bigint      NOT NULL,
    gestor_id  bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    nome       text        NOT NULL,
    criterios  jsonb       NOT NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    updated_at timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT canal_segmentos_cod_inep_nome_key UNIQUE (cod_inep, nome)
  );

  COMMENT ON TABLE clean.canal_segmentos IS
    'Listas dinâmicas da escola: regra salva sobre os membros das listas da própria escola, resolvida na hora do envio (RF-305). Nome único por escola.';
  COMMENT ON COLUMN clean.canal_segmentos.cod_inep IS
    'Escola dona da lista dinâmica (código INEP).';
  COMMENT ON COLUMN clean.canal_segmentos.gestor_id IS
    'Gestor que criou ou editou por último a lista dinâmica.';
  COMMENT ON COLUMN clean.canal_segmentos.nome IS
    'Nome da lista dinâmica (único por escola).';
  COMMENT ON COLUMN clean.canal_segmentos.criterios IS
    'Regra: {listas: [ids da escola, união], estado: [pendente|parcial|confirmado|nao_exigida] (vazio = todos), email_confirmado: true|false|null, inscritos_desde/inscritos_ate: YYYY-MM-DD|null}. Listas excluídas depois são ignoradas.';

  -- ---------------------------------------------------------------------
  -- canal_envios: envio em massa por e-mail (RF-301/302/307)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_envios (
    id            bigserial   PRIMARY KEY,
    cod_inep      bigint      NOT NULL,
    gestor_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    alvo_tipo     text        NOT NULL
      CONSTRAINT canal_envios_alvo_tipo_check
      CHECK (alvo_tipo IN ('lista', 'segmento')),
    alvo_id       bigint      NOT NULL,
    alvo_nome     text        NOT NULL,
    canal         text        NOT NULL DEFAULT 'email'
      CONSTRAINT canal_envios_canal_check
      CHECK (canal IN ('email')),
    operacao      text        NOT NULL
      CONSTRAINT canal_envios_operacao_check
      CHECK (operacao IN ('aviso', 'informacao', 'pedido', 'convite', 'lembrete', 'alerta')),
    assunto       text        NOT NULL,
    corpo         text        NOT NULL,
    status        text        NOT NULL DEFAULT 'rascunho'
      CONSTRAINT canal_envios_status_check
      CHECK (status IN ('rascunho', 'agendado', 'enviando', 'pausado_cota',
                        'suspenso', 'concluido', 'cancelado')),
    agendado_para timestamptz,
    iniciado_em   timestamptz,
    concluido_em  timestamptz,
    cancelado_em  timestamptz,
    destinatarios integer     NOT NULL DEFAULT 0,
    enviados      integer     NOT NULL DEFAULT 0,
    falhas        integer     NOT NULL DEFAULT 0,
    ignorados     integer     NOT NULL DEFAULT 0,
    minion_job_id bigint,
    created_at    timestamptz NOT NULL DEFAULT NOW(),
    updated_at    timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_envios IS
    'Envio em massa por e-mail para uma lista ou lista dinâmica da escola. Ciclo: rascunho -> agendado|enviando -> concluido; desvios pausado_cota, suspenso, cancelado. Processado em lotes pelo job Minion canais_envio.';
  COMMENT ON COLUMN clean.canal_envios.cod_inep IS
    'Escola que envia (código INEP).';
  COMMENT ON COLUMN clean.canal_envios.gestor_id IS
    'Gestor autor do envio. SET NULL se o gestor for removido.';
  COMMENT ON COLUMN clean.canal_envios.alvo_tipo IS
    'Tipo do alvo: lista (clean.canal_listas) ou segmento (clean.canal_segmentos).';
  COMMENT ON COLUMN clean.canal_envios.alvo_id IS
    'Id do alvo (lista ou segmento). Sem FK: o alvo pode ser excluído depois; o envio guarda alvo_nome.';
  COMMENT ON COLUMN clean.canal_envios.alvo_nome IS
    'Nome do alvo: o atual enquanto rascunho, fotografia no disparo.';
  COMMENT ON COLUMN clean.canal_envios.canal IS
    'Canal do envio. Só e-mail nesta fase.';
  COMMENT ON COLUMN clean.canal_envios.operacao IS
    'Motivo/operação (Channel::Operacoes, exceto confirmacao). Aparece no rodapé e no histórico.';
  COMMENT ON COLUMN clean.canal_envios.assunto IS
    'Assunto do e-mail (1..200).';
  COMMENT ON COLUMN clean.canal_envios.corpo IS
    'Corpo do e-mail em markdown simples (1..20000); sai em text/plain com o rodapé de saída e privacidade.';
  COMMENT ON COLUMN clean.canal_envios.status IS
    'rascunho | agendado | enviando | pausado_cota (cota diária esgotou; retoma 00:05) | suspenso (escola suspensa) | concluido | cancelado.';
  COMMENT ON COLUMN clean.canal_envios.agendado_para IS
    'Momento agendado do disparo (NULL = imediato).';
  COMMENT ON COLUMN clean.canal_envios.iniciado_em IS
    'Momento em que o job começou a enviar.';
  COMMENT ON COLUMN clean.canal_envios.concluido_em IS
    'Momento da conclusão (todos os destinatários processados).';
  COMMENT ON COLUMN clean.canal_envios.cancelado_em IS
    'Momento do cancelamento pelo gestor.';
  COMMENT ON COLUMN clean.canal_envios.destinatarios IS
    'Destinatários fixados no disparo (após dedupe; inclui os ignorados por opt-out).';
  COMMENT ON COLUMN clean.canal_envios.enviados IS
    'E-mails entregues ao SMTP.';
  COMMENT ON COLUMN clean.canal_envios.falhas IS
    'E-mails que falharam no SMTP (sem nova tentativa automática).';
  COMMENT ON COLUMN clean.canal_envios.ignorados IS
    'Endereços ignorados: duplicados (sem linha), opt-out e anonimizados.';
  COMMENT ON COLUMN clean.canal_envios.minion_job_id IS
    'Job Minion canais_envio enfileirado no disparo.';

  CREATE INDEX idx_canal_envios_escola
    ON clean.canal_envios (cod_inep, created_at DESC);

  -- ---------------------------------------------------------------------
  -- canal_envio_destinatarios: fotografia do alvo no disparo (RF-301/302)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_envio_destinatarios (
    id            bigserial   PRIMARY KEY,
    envio_id      bigint      NOT NULL REFERENCES clean.canal_envios (id) ON DELETE CASCADE,
    contato_id    bigint      REFERENCES clean.contatos (id) ON DELETE SET NULL,
    lista_id      bigint      REFERENCES clean.canal_listas (id) ON DELETE SET NULL,
    email         text,
    email_hash    text        NOT NULL,
    saida_hash    text
      CONSTRAINT canal_envio_destinatarios_saida_hash_key UNIQUE,
    status        text        NOT NULL DEFAULT 'pendente'
      CONSTRAINT canal_envio_destinatarios_status_check
      CHECK (status IN ('pendente', 'enviado', 'falhou', 'cancelado',
                        'ignorado_optout', 'ignorado_anonimizado')),
    erro          text,
    mensagem_id   bigint      REFERENCES clean.canal_mensagens (id) ON DELETE SET NULL,
    processado_em timestamptz,
    CONSTRAINT canal_envio_destinatarios_envio_email_key UNIQUE (envio_id, email_hash)
  );

  COMMENT ON TABLE clean.canal_envio_destinatarios IS
    'Destinatários de um envio, fixados no disparo: um por e-mail normalizado (duplicados não viram linha). Só pendente é processado — reprocessar nunca reenvia.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.contato_id IS
    'Contato da agenda da escola. SET NULL se o contato for apagado.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.lista_id IS
    'Lista de origem (a de menor id do alvo em que o endereço é membro) — base do opt-out por lista.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.email IS
    'E-mail normalizado (lower(trim)), em claro SÓ enquanto o envio não terminou; NULL ao concluir/cancelar. PII.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.email_hash IS
    'SHA-256 (hex) do e-mail normalizado — dedupe e opt-out sem PII.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.saida_hash IS
    'SHA-256 (hex) do token de saída (HMAC do id do destinatário com o segredo do app). O token em claro só vai no e-mail.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.status IS
    'pendente | enviado | falhou | cancelado | ignorado_optout | ignorado_anonimizado.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.erro IS
    'Erro do SMTP quando falhou.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.mensagem_id IS
    'Linha do histórico (clean.canal_mensagens) do e-mail enviado.';
  COMMENT ON COLUMN clean.canal_envio_destinatarios.processado_em IS
    'Momento do processamento (envio, falha ou descarte) — base da cota diária.';

  CREATE INDEX idx_canal_envio_dest_pend
    ON clean.canal_envio_destinatarios (envio_id) WHERE status = 'pendente';
  CREATE INDEX idx_canal_envio_dest_processado
    ON clean.canal_envio_destinatarios (processado_em) WHERE status = 'enviado';

  -- ---------------------------------------------------------------------
  -- canal_optouts: saída de uma lista, sem PII (RF-303)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_optouts (
    id         bigserial   PRIMARY KEY,
    lista_id   bigint      NOT NULL REFERENCES clean.canal_listas (id) ON DELETE CASCADE,
    canal      text        NOT NULL DEFAULT 'email'
      CONSTRAINT canal_optouts_canal_check
      CHECK (canal IN ('email')),
    email_hash text        NOT NULL,
    envio_id   bigint      REFERENCES clean.canal_envios (id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT canal_optouts_lista_canal_email_key UNIQUE (lista_id, canal, email_hash)
  );

  COMMENT ON TABLE clean.canal_optouts IS
    'Endereços que saíram dos envios de uma lista (opt-out por lista, sem PII: só o hash do e-mail). Sobrevive à anonimização.';
  COMMENT ON COLUMN clean.canal_optouts.email_hash IS
    'SHA-256 (hex) do e-mail normalizado.';
  COMMENT ON COLUMN clean.canal_optouts.envio_id IS
    'Envio cujo link gerou a saída. SET NULL se o envio for apagado.';

  -- ---------------------------------------------------------------------
  -- canal_qr_acessos: funil, agregado diário sem PII (RF-306)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_qr_acessos (
    qrcode_id bigint  NOT NULL REFERENCES clean.canal_qrcodes (id) ON DELETE CASCADE,
    dia       date    NOT NULL,
    acessos   integer NOT NULL DEFAULT 0,
    PRIMARY KEY (qrcode_id, dia)
  );

  COMMENT ON TABLE clean.canal_qr_acessos IS
    'Acessos diários à página pública de inscrição, por QR (funil de conversão). Só contagem: nada de IP, user agent ou cookie.';
  COMMENT ON COLUMN clean.canal_qr_acessos.dia IS
    'Dia do acesso (America/Sao_Paulo).';
  COMMENT ON COLUMN clean.canal_qr_acessos.acessos IS
    'Número de acessos válidos no dia.';

  -- ---------------------------------------------------------------------
  -- canal_envio_suspensoes: controle da administração (RF-304)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_envio_suspensoes (
    id            bigserial   PRIMARY KEY,
    cod_inep      bigint      NOT NULL,
    motivo        text        NOT NULL,
    suspenso_por  bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    suspenso_em   timestamptz NOT NULL DEFAULT NOW(),
    reativado_por bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    reativado_em  timestamptz
  );

  COMMENT ON TABLE clean.canal_envio_suspensoes IS
    'Suspensões do envio em massa por escola (auditoria: quem, quando, motivo). Ativa = reativado_em NULL (no máximo uma por escola). Bloqueia novos disparos e pausa os envios em curso.';
  COMMENT ON COLUMN clean.canal_envio_suspensoes.motivo IS
    'Motivo da suspensão, exibido ao gestor.';
  COMMENT ON COLUMN clean.canal_envio_suspensoes.suspenso_por IS
    'Administrador que suspendeu.';
  COMMENT ON COLUMN clean.canal_envio_suspensoes.reativado_por IS
    'Administrador que reativou.';
  COMMENT ON COLUMN clean.canal_envio_suspensoes.reativado_em IS
    'Momento da reativação. NULL = suspensão ativa.';

  CREATE UNIQUE INDEX uq_canal_envio_suspensao_ativa
    ON clean.canal_envio_suspensoes (cod_inep) WHERE reativado_em IS NULL;

COMMIT;
