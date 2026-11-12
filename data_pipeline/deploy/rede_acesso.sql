-- Deploy edumaps:rede_acesso to pg
-- requires: gestor_access_role
-- requires: planos_base_oficial
--
-- #394 (visão da rede, #375): papel da secretaria. Uma conta com
-- access_role = 'rede' (cod_inep reservado 0, como o admin) é ligada a uma ou
-- mais REDES por vínculo concedido pelo admin: dependência (2 estadual,
-- 3 municipal) + município. A escola é da rede quando, no Censo mais recente
-- dela, tp_dependencia e co_municipio batem com um vínculo ativo — conferido
-- pela aplicação a cada pedido.
--
-- A conta nasce sem senha; a pessoa define a senha por um CONVITE de uso
-- único (token guardado só como hash, 7 dias). Conceder, revogar, convidar e
-- aceitar ficam em clean.rede_auditoria.
--
-- Tudo interno (dados de acesso): sem GRANT ao edumaps_leitor; nomes na lista
-- de sensíveis do backend/t/02-models/leitor_grants.t.

BEGIN;

  ALTER TABLE clean.gestores DROP CONSTRAINT gestores_access_role_check;
  ALTER TABLE clean.gestores ADD CONSTRAINT gestores_access_role_check
    CHECK (access_role IN ('gestor', 'admin', 'rede'));
  COMMENT ON COLUMN clean.gestores.access_role IS
    'Papel na plataforma: gestor (a própria escola), admin (a instalação) ou rede (secretaria: as escolas dos vínculos em clean.rede_vinculos). Padrão: gestor.';

  CREATE TABLE clean.rede_vinculos (
    id             bigserial   PRIMARY KEY,
    gestor_id      bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    tp_dependencia smallint    NOT NULL CHECK (tp_dependencia IN (2, 3)),
    co_municipio   integer     NOT NULL CHECK (co_municipio BETWEEN 1000000 AND 9999999),
    concedido_por  bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    concedido_em   timestamptz NOT NULL DEFAULT NOW(),
    revogado_por   bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    revogado_em    timestamptz
  );
  CREATE UNIQUE INDEX uq_rede_vinculos_ativo ON clean.rede_vinculos (gestor_id, tp_dependencia, co_municipio)
    WHERE revogado_em IS NULL;
  COMMENT ON TABLE clean.rede_vinculos IS
    'Vínculos da conta de rede (#394): dependência (2 estadual, 3 municipal) + município. Revogado = revogado_em preenchido; o histórico fica.';

  CREATE TABLE clean.rede_convites (
    id            bigserial   PRIMARY KEY,
    gestor_id     bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    token_hash    text        NOT NULL UNIQUE,
    expira_em     timestamptz NOT NULL,
    usado_em      timestamptz,
    invalidado_em timestamptz,
    criado_por    bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    criado_em     timestamptz NOT NULL DEFAULT NOW()
  );
  COMMENT ON TABLE clean.rede_convites IS
    'Convites de uso único da conta de rede (#394): token só como SHA-256; um convite novo invalida o anterior.';

  CREATE TABLE clean.rede_auditoria (
    id          bigserial   PRIMARY KEY,
    gestor_id   bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    ator_id     bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    acao        text        NOT NULL CHECK (acao IN ('conta_criada', 'convite_gerado', 'convite_aceito',
                                                     'vinculo_concedido', 'vinculo_revogado')),
    detalhes    jsonb       NOT NULL DEFAULT '{}',
    criado_em   timestamptz NOT NULL DEFAULT NOW()
  );
  CREATE INDEX idx_rede_auditoria_gestor ON clean.rede_auditoria (gestor_id, criado_em DESC);
  COMMENT ON TABLE clean.rede_auditoria IS
    'Auditoria das contas de rede (#394): quem criou, convidou, concedeu e revogou, e quando.';

  -- escolas de uma rede: filtro por município no Censo
  CREATE INDEX IF NOT EXISTS idx_censo_escolas_co_municipio ON clean.censo_escolas (co_municipio);

COMMIT;
