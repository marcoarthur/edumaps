-- Deploy edumaps:gestores_email_unico_sem_caixa to pg
-- requires: gestor_pesquisas

-- Um e-mail = uma conta, sem diferenciar maiúsculas de minúsculas.
-- O cadastro anônimo do gestor só cria conta (INSERT ... ON CONFLICT DO
-- NOTHING); este índice é o que faz "Fulano@x" colidir com "fulano@x" no
-- próprio banco, e não só na checagem do backend.
-- Pré-condição medida em 2026-11-02: nenhum e-mail repetido por caixa nas
-- bases do Docker local e do LXC.

BEGIN;

CREATE UNIQUE INDEX uq_gestores_email_lower ON clean.gestores (lower(email));

COMMENT ON INDEX clean.uq_gestores_email_lower IS
  'Um e-mail por conta, sem diferenciar caixa. O cadastro anônimo só cria conta e nunca altera uma existente.';

COMMIT;
