-- Deploy edumaps:canal_email_lgpd to pg
-- requires: canal_confirmacao_listas
--
-- E-mail e LGPD nas listas com QR (issue #214 — Fase 2). Change NOVA, única do
-- ciclo (decisão da execução): só ALTER em tabelas existentes + três tabelas
-- novas; nenhuma change já deployada é editada.
--
--   canal_listas.coleta              contatos coletados por lista
--                                    (telefone|email|ambos|qualquer; default
--                                    telefone: Fases 0/1 intactas);
--   canal_listas.desativada_em       momento da desativação (soft delete) —
--                                    base da retenção de listas inativas;
--   canal_inscricoes                 telefone passa a opcional; e-mail bruto e
--                                    normalizado; hash do texto de
--                                    consentimento aceito; hash do token de
--                                    exclusão; anonimizado_em;
--   canal_confirmacao_refs.envios_email limite de reenvio do código por e-mail;
--   canal_lista_membros.email_*      estado da confirmação do e-mail (o par
--                                    confirmado_em/via existente passa a
--                                    significar "telefone confirmado");
--   consentimento_versoes            textos de consentimento versionados
--                                    (rascunho -> vigente -> arquivada), com
--                                    seed da versão 1.0 vigente;
--   canal_exclusoes                  auditoria de exclusões/expurgos SEM PII.

BEGIN;

  -- ---------------------------------------------------------------------
  -- canal_listas: campos coletados (RF-201) e data de desativação (RF-207)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_listas
    ADD COLUMN coleta text NOT NULL DEFAULT 'telefone'
      CONSTRAINT canal_listas_coleta_check
      CHECK (coleta IN ('telefone', 'email', 'ambos', 'qualquer')),
    ADD COLUMN desativada_em timestamptz;

  COMMENT ON COLUMN clean.canal_listas.coleta IS
    'Contatos coletados pela lista: telefone | email | ambos (os dois obrigatórios) | qualquer (os dois exibidos, pelo menos um obrigatório). Default telefone (Fases 0/1 intactas).';
  COMMENT ON COLUMN clean.canal_listas.desativada_em IS
    'Momento em que a lista foi desativada (ativo=false). NULL enquanto ativa; limpo na reativação. Base da retenção de listas inativas (updated_at também muda em edições).';

  -- listas já desativadas antes desta change: melhor estimativa é updated_at
  UPDATE clean.canal_listas SET desativada_em = updated_at WHERE NOT ativo;

  -- ---------------------------------------------------------------------
  -- canal_inscricoes: e-mail, hash do consentimento, exclusão (RF-202/204/208)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_inscricoes
    ALTER COLUMN telefone      DROP NOT NULL,
    ALTER COLUMN telefone_norm DROP NOT NULL,
    ADD COLUMN email              text,
    ADD COLUMN email_norm         text,
    ADD COLUMN consentimento_hash text,
    ADD COLUMN exclusao_hash      text
      CONSTRAINT canal_inscricoes_exclusao_hash_key UNIQUE,
    ADD COLUMN anonimizado_em     timestamptz;

  COMMENT ON COLUMN clean.canal_inscricoes.telefone IS
    'Telefone como digitado (bruto), sem normalizar. NULL quando a lista não coleta telefone (ou coleta "qualquer" e só veio e-mail) e depois da anonimização.';
  COMMENT ON COLUMN clean.canal_inscricoes.telefone_norm IS
    'Telefone normalizado (somente dígitos) — chave de comparação do dedupe não destrutivo (RF-005). NULL sem telefone.';
  COMMENT ON COLUMN clean.canal_inscricoes.email IS
    'E-mail como digitado (bruto). NULL sem e-mail. PII — apagado na anonimização.';
  COMMENT ON COLUMN clean.canal_inscricoes.email_norm IS
    'E-mail normalizado (trim + minúsculas) — chave do dedupe por e-mail na escola. PII — apagado na anonimização.';
  COMMENT ON COLUMN clean.canal_inscricoes.consentimento_hash IS
    'SHA-256 (hex) do texto de consentimento aceito (clean.consentimento_versoes.texto_hash). NULL nas inscrições anteriores à Fase 2.';
  COMMENT ON COLUMN clean.canal_inscricoes.exclusao_hash IS
    'SHA-256 (hex) do token pessoal de exclusão (128 bits). O token em claro só vai ao titular (exclusao_url); sem validade.';
  COMMENT ON COLUMN clean.canal_inscricoes.anonimizado_em IS
    'Momento da anonimização (exclusão a pedido ou retenção). Preenchido = PII apagada; ficam data, lista e versão do consentimento.';

  CREATE INDEX idx_canal_inscricoes_email_norm
    ON clean.canal_inscricoes (email_norm);

  -- ---------------------------------------------------------------------
  -- canal_lista_membros: confirmação do e-mail (RF-203)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_lista_membros
    ADD COLUMN email_confirmado_em  timestamptz,
    ADD COLUMN email_confirmado_via text
      CONSTRAINT canal_lista_membros_email_confirmado_via_check
      CHECK (email_confirmado_via IN ('email'));

  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_em IS
    'Momento da confirmação de posse do TELEFONE. NULL = não confirmado (pendente se a lista exige; "não exigida" caso contrário).';
  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_via IS
    'Canal pelo qual a posse do TELEFONE foi confirmada: telegram ou whatsapp (CHECK é a fonte de verdade do banco).';
  COMMENT ON COLUMN clean.canal_lista_membros.email_confirmado_em IS
    'Momento da confirmação de posse do E-MAIL (código por e-mail). NULL = não confirmado.';
  COMMENT ON COLUMN clean.canal_lista_membros.email_confirmado_via IS
    'Canal pelo qual a posse do E-MAIL foi confirmada: email (CHECK é a fonte de verdade do banco).';

  -- ---------------------------------------------------------------------
  -- canal_confirmacao_refs: limite de envios do código por e-mail (RF-203)
  -- ---------------------------------------------------------------------
  ALTER TABLE clean.canal_confirmacao_refs
    ADD COLUMN envios_email integer NOT NULL DEFAULT 0;

  COMMENT ON COLUMN clean.canal_confirmacao_refs.envios_email IS
    'Quantos códigos por e-mail já foram enviados por esta ref (limite de reenvio, como envios_whatsapp).';
  COMMENT ON COLUMN clean.canal_confirmacao_refs.usada_em IS
    'Momento em que a ref concluiu a confirmação (uso único). Só é marcada quando TODOS os contatos da inscrição estão confirmados (estado geral confirmado).';

  -- ---------------------------------------------------------------------
  -- consentimento_versoes: textos versionados e imutáveis (RF-208)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.consentimento_versoes (
    id           bigserial   PRIMARY KEY,
    versao       text        NOT NULL
      CONSTRAINT consentimento_versoes_versao_key UNIQUE,
    texto        text        NOT NULL,
    texto_hash   text        NOT NULL,
    status       text        NOT NULL DEFAULT 'rascunho'
      CONSTRAINT consentimento_versoes_status_check
      CHECK (status IN ('rascunho', 'vigente', 'arquivada')),
    criado_por   bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    publicada_em timestamptz,
    created_at   timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.consentimento_versoes IS
    'Versões do texto de consentimento da autoinscrição (da instalação, não por escola). Ciclo rascunho -> vigente -> arquivada; publicada é imutável; uma única vigente (índice parcial). As inscrições gravam versao + texto_hash.';
  COMMENT ON COLUMN clean.consentimento_versoes.versao IS
    'Rótulo da versão (ex.: 1.0, 1.1). Único.';
  COMMENT ON COLUMN clean.consentimento_versoes.texto IS
    'Texto exibido ao inscrito, em markdown simples.';
  COMMENT ON COLUMN clean.consentimento_versoes.texto_hash IS
    'SHA-256 (hex) do texto (UTF-8). Recalculado a cada edição do rascunho; gravado na inscrição como prova do texto aceito.';
  COMMENT ON COLUMN clean.consentimento_versoes.status IS
    'rascunho (editável) | vigente (a exibida; no máximo uma) | arquivada (substituída por outra publicação).';
  COMMENT ON COLUMN clean.consentimento_versoes.criado_por IS
    'Gestor (admin) que criou a versão. SET NULL se o gestor for removido.';
  COMMENT ON COLUMN clean.consentimento_versoes.publicada_em IS
    'Momento em que a versão passou a vigente. NULL em rascunho.';

  CREATE UNIQUE INDEX uq_consentimento_vigente
    ON clean.consentimento_versoes ((true)) WHERE status = 'vigente';

  -- Seed: versão 1.0 vigente = texto da página /privacidade da Fase 0/1
  -- (compatível com as inscrições existentes, que gravaram '1.0'). Provisório:
  -- a redação definitiva depende de revisão jurídica.
  INSERT INTO clean.consentimento_versoes (versao, texto, texto_hash, status, publicada_em)
  SELECT '1.0', t.texto, encode(digest(t.texto, 'sha256'), 'hex'), 'vigente', NOW()
  FROM (VALUES ($txt$Ao enviar este formulário, você informa seu **nome** e **telefone**. Esses dados são gravados para que a escola possa entrar em contato com você.

- Nome e telefone são usados apenas para a escola entrar em contato.
- Os dados ficam restritos à escola e não são compartilhados com terceiros.
- A inscrição pode ser removida a pedido, falando com a escola.

O consentimento é registrado no momento do envio. Os dados de contato são sensíveis e ficam restritos à escola responsável pela lista.$txt$)) AS t (texto);

  -- ---------------------------------------------------------------------
  -- canal_exclusoes: auditoria de exclusões e expurgos, SEM PII (RF-206/207)
  -- ---------------------------------------------------------------------
  CREATE TABLE clean.canal_exclusoes (
    id          bigserial   PRIMARY KEY,
    cod_inep    bigint      NOT NULL,
    origem      text        NOT NULL
      CONSTRAINT canal_exclusoes_origem_check
      CHECK (origem IN ('titular', 'gestor', 'retencao')),
    regra       text,
    gestor_id   bigint      REFERENCES clean.gestores (id) ON DELETE SET NULL,
    motivo      text,
    contatos    integer     NOT NULL DEFAULT 0,
    inscricoes  integer     NOT NULL DEFAULT 0,
    membros     integer     NOT NULL DEFAULT 0,
    created_at  timestamptz NOT NULL DEFAULT NOW()
  );

  COMMENT ON TABLE clean.canal_exclusoes IS
    'Registro mínimo de cada exclusão (a pedido do titular, pelo gestor ou por retenção): escola, origem, contagens e quando. SEM PII — prova que houve inscrição e exclusão.';
  COMMENT ON COLUMN clean.canal_exclusoes.origem IS
    'titular (link pessoal) | gestor (pedido feito à escola) | retencao (expurgo automático).';
  COMMENT ON COLUMN clean.canal_exclusoes.regra IS
    'Só retenção: metadados | pendentes | lista_inativa.';
  COMMENT ON COLUMN clean.canal_exclusoes.gestor_id IS
    'Gestor que executou (origem gestor). SET NULL se o gestor for removido.';
  COMMENT ON COLUMN clean.canal_exclusoes.motivo IS
    'Motivo informado pelo gestor. Não deve conter PII do titular.';
  COMMENT ON COLUMN clean.canal_exclusoes.contatos IS
    'Contatos anonimizados nesta execução.';
  COMMENT ON COLUMN clean.canal_exclusoes.inscricoes IS
    'Inscrições anonimizadas (ou com metadados apagados) nesta execução.';
  COMMENT ON COLUMN clean.canal_exclusoes.membros IS
    'Vínculos de membro removidos nesta execução.';

  CREATE INDEX idx_canal_exclusoes_inep
    ON clean.canal_exclusoes (cod_inep, created_at);

COMMIT;
