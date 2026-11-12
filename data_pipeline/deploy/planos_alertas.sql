-- Deploy edumaps:planos_alertas to pg
-- requires: planos_indicadores
--
-- #373 (épico #368): resumo diário por e-mail das ações dos planos que vencem
-- nos próximos 7 dias e das atrasadas. Esta tabela é a IDEMPOTÊNCIA do resumo:
--   * no máximo um resumo por gestor por dia (UNIQUE gestor_id, data);
--   * `assinatura` resume o conteúdo; se for igual à do último resumo enviado,
--     não há novidade e nada sai.
-- Interna (sem GRANT ao edumaps_leitor; lista de sensíveis do leitor_grants.t).

BEGIN;

  CREATE TABLE clean.planos_alertas_envio (
    id          bigserial   PRIMARY KEY,
    gestor_id   bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    cod_inep    bigint      NOT NULL,
    data        date        NOT NULL,
    assinatura  text        NOT NULL,
    n_acoes     integer     NOT NULL,
    ok          boolean     NOT NULL,
    erro        text,
    enviado_em  timestamptz NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_planos_alertas_gestor_dia UNIQUE (gestor_id, data)
  );

  COMMENT ON TABLE clean.planos_alertas_envio IS
    'Resumos diários de prazo dos planos enviados aos gestores (#373). Um por gestor por dia; a assinatura do conteúdo evita reenviar quando não há novidade.';

COMMIT;
