-- Deploy edumaps:idempotencia to pg
-- requires: inep_rendimento_distorcao
--
-- #416: trava no servidor contra criação repetida. O cliente manda o
-- cabeçalho Idempotency-Key nos POSTs; a mesma chave da mesma conta devolve a
-- resposta guardada em vez de criar de novo (ex.: o primeiro pedido chegou, a
-- resposta se perdeu por tempo esgotado e a pessoa clicou de novo).
--
-- * status NULL = em andamento; preenchido = resposta 2xx guardada.
-- * corpo_hash: SHA-256 do corpo do pedido; a mesma chave com outro corpo ou
--   outra rota é recusada (nunca devolve, calada, a resposta de outro envio).
-- * Validade curta (10 min, aplicada pelo backend): as chaves antigas da
--   conta são apagadas a cada envio novo, sem job.
-- * A resposta guardada pode ter dado pessoal (contatos): tabela interna, sem
--   GRANT ao edumaps_leitor; nome na lista de sensíveis de leitor_grants.t.

BEGIN;

  CREATE TABLE clean.idempotencia (
    gestor_id   bigint      NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
    chave       text        NOT NULL CHECK (length(chave) BETWEEN 8 AND 128),
    rota        text        NOT NULL,
    corpo_hash  text        NOT NULL,
    status      smallint    CHECK (status BETWEEN 200 AND 299),
    resposta    text,
    criado_em   timestamptz NOT NULL DEFAULT NOW(),
    PRIMARY KEY (gestor_id, chave)
  );
  CREATE INDEX idx_idempotencia_criado_em ON clean.idempotencia (gestor_id, criado_em);
  COMMENT ON TABLE clean.idempotencia IS
    'Chaves de idempotência dos POSTs autenticados (#416): a mesma chave da mesma conta devolve a resposta guardada. status NULL = em andamento. Validade curta, limpa pelo backend.';

COMMIT;
