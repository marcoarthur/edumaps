-- Deploy edumaps:renaest_depara_declaracao to pg
-- requires: renaest_localidade_municipio

BEGIN;

-- =================================================================
-- CORREÇÃO #155 — o de-para RENAEST declara o que é
--
-- A change `renaest_localidade_municipio` documentava um de-para
-- "construído por fuzzy matching + validação humana" sobre uma semente
-- (`auto_seed`) que era uma auto-junção do IBGE. A 2026-10-02 o loader
-- passou a derivar o de-para do ficheiro `Localidade` da própria
-- RENAEST, que traz `codigo_ibge`: a resolução é pelo CÓDIGO da fonte,
-- validado contra clean.malha_municipio, e não por semelhança de nome.
-- `match_type` só rotula a grafia; `manual` e `validated_at` nunca
-- ocorreram.
--
-- Esta change faz o que faltava da #155:
--   1. reescreve os COMMENT para descrever o mecanismo real;
--   2. cria clean.renaest_localidade_nao_resolvida — destino explícito
--      para as localidades que a carga não resolve (antes: `next` com
--      uma contagem no log, isto é, descarte silencioso).
-- =================================================================

-- 1. O de-para como ele é ---------------------------------------------
COMMENT ON TABLE clean.renaest_localidade_municipio IS
  'De-para RENAEST localidade -> município IBGE. Grão: (localidade, uf, dt_snapshot) -> codigo_ibge. A resolução usa o codigo_ibge publicado pela própria RENAEST (ficheiro Localidade), validado contra clean.malha_municipio via fk_renaest_depara_municipio — não é semelhança de nome. match_type rotula a grafia: exact (grafia IBGE = grafia da fonte) ou fuzzy (grafias divergem, mas o código da fonte confirma o município). manual nunca ocorreu; validated_by é fonte_renaest em todas as linhas e validated_at é NULL. Localidades que não resolvem vão para clean.renaest_localidade_nao_resolvida.';

COMMENT ON COLUMN clean.renaest_localidade_municipio.localidade IS
  'Nome da localidade como a RENAEST publica (maiúsculas, sem acento). Ex.: ITAPAGE.';

COMMENT ON COLUMN clean.renaest_localidade_municipio.codigo_ibge IS
  'Código IBGE do município, transcrito do ficheiro Localidade da RENAEST e validado contra clean.malha_municipio (fk_renaest_depara_municipio). É ele que decide a resolução.';

COMMENT ON COLUMN clean.renaest_localidade_municipio.match_type IS
  'Rótulo da grafia: exact (grafia IBGE = grafia da fonte) | fuzzy (grafias divergem, mas o código da fonte confirma o município) | manual (validação humana — nunca usado).';

COMMENT ON COLUMN clean.renaest_localidade_municipio.match_score IS
  'similaridade() entre a grafia da fonte e a grafia IBGE (0-100). Mede a GRAFIA, não a confiança da resolução: score baixo com código coincidente continua a ser município certo.';

COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_by IS
  'Origem da validação: fonte_renaest (automática, pelo código da fonte) ou identificador humano. A semente antiga (auto_seed) era uma auto-junção do IBGE e foi removida pelo loader a 2026-10-02.';

COMMENT ON COLUMN clean.renaest_localidade_municipio.validated_at IS
  'Preenchido apenas quando houver validação humana. NULL em todas as linhas atuais (nenhuma validação humana ocorreu).';

-- 2. Destino explícito para o que não resolve -------------------------
CREATE TABLE clean.renaest_localidade_nao_resolvida (
    localidade        TEXT        NOT NULL DEFAULT '',
    uf                CHAR(2)     NOT NULL DEFAULT '',
    codigo_ibge_fonte TEXT        NOT NULL DEFAULT '',
    motivo            TEXT        NOT NULL,
    dt_carga          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dt_snapshot       DATE        NOT NULL,

    CONSTRAINT pk_renaest_localidade_nao_resolvida
      PRIMARY KEY (localidade, uf, codigo_ibge_fonte, dt_snapshot),
    CONSTRAINT ck_renaest_nao_resolvida_motivo
      CHECK (motivo IN ('codigo_fora_da_malha', 'codigo_sentinela', 'sem_nome_ou_uf'))
);

CREATE INDEX idx_renaest_nao_resolvida_motivo
  ON clean.renaest_localidade_nao_resolvida (motivo);

COMMENT ON TABLE clean.renaest_localidade_nao_resolvida IS
  'Localidades do ficheiro Localidade da RENAEST que a carga não conseguiu resolver para um município IBGE. Registá-las aqui é o que impede o descarte silencioso: o loader insere uma linha por (localidade, uf, codigo_ibge_fonte, dt_snapshot) e a contagem no log deixa de ser o único rasto. motivo: codigo_fora_da_malha (o código da fonte não existe em clean.malha_municipio) | codigo_sentinela (a fonte publica 0/0000000) | sem_nome_ou_uf (linha sem nome de município ou sem UF).';

COMMENT ON COLUMN clean.renaest_localidade_nao_resolvida.localidade IS
  'Nome como a RENAEST publica; vazio quando a linha não trazia nome (motivo sem_nome_ou_uf).';

COMMENT ON COLUMN clean.renaest_localidade_nao_resolvida.uf IS
  'UF como a RENAEST publica; vazio quando a linha não trazia UF.';

COMMENT ON COLUMN clean.renaest_localidade_nao_resolvida.codigo_ibge_fonte IS
  'Código IBGE que a fonte publicou (vazio quando ausente; 0/0000000 no caso de sentinela).';

COMMENT ON COLUMN clean.renaest_localidade_nao_resolvida.motivo IS
  'Porque não resolveu: codigo_fora_da_malha | codigo_sentinela | sem_nome_ou_uf.';

-- Nota: a proveniência desta tabela NÃO é semeada aqui. É o loader que a
-- registra em clean.import_metadata (upsert_metadata) na primeira carga —
-- uma tabela derivada não tem proveniência antes de ter sido derivada.

COMMIT;
