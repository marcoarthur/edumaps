-- Revert edumaps:canal_email_lgpd from pg
--
-- Ordem inversa: tabelas novas e depois as colunas acrescentadas às tabelas
-- das Fases 0/1. IF EXISTS: reverter num banco parcialmente aplicado não
-- aborta o restante. Inscrições só com e-mail (telefone NULL) recebem ''
-- para o NOT NULL original voltar (o e-mail delas se perde com a coluna).

BEGIN;

  DROP TABLE IF EXISTS clean.canal_exclusoes;
  DROP TABLE IF EXISTS clean.consentimento_versoes;

  ALTER TABLE clean.canal_confirmacao_refs
    DROP COLUMN IF EXISTS envios_email;

  COMMENT ON COLUMN clean.canal_confirmacao_refs.usada_em IS
    'Momento em que a ref concluiu a confirmação (uso único).';

  ALTER TABLE clean.canal_lista_membros
    DROP COLUMN IF EXISTS email_confirmado_via,
    DROP COLUMN IF EXISTS email_confirmado_em;

  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_em IS
    'Momento da confirmação de posse do telefone. NULL = não confirmado (pendente se a lista exige; "não exigida" caso contrário).';
  COMMENT ON COLUMN clean.canal_lista_membros.confirmado_via IS
    'Canal pelo qual a posse foi confirmada: telegram ou whatsapp (CHECK é a fonte de verdade do banco).';

  DROP INDEX IF EXISTS clean.idx_canal_inscricoes_email_norm;

  UPDATE clean.canal_inscricoes SET telefone = ''      WHERE telefone IS NULL;
  UPDATE clean.canal_inscricoes SET telefone_norm = '' WHERE telefone_norm IS NULL;

  ALTER TABLE clean.canal_inscricoes
    DROP COLUMN IF EXISTS anonimizado_em,
    DROP COLUMN IF EXISTS exclusao_hash,
    DROP COLUMN IF EXISTS consentimento_hash,
    DROP COLUMN IF EXISTS email_norm,
    DROP COLUMN IF EXISTS email,
    ALTER COLUMN telefone_norm SET NOT NULL,
    ALTER COLUMN telefone      SET NOT NULL;

  COMMENT ON COLUMN clean.canal_inscricoes.telefone IS
    'Telefone como digitado (bruto), sem normalizar.';
  COMMENT ON COLUMN clean.canal_inscricoes.telefone_norm IS
    'Telefone normalizado (somente dígitos) — chave de comparação do dedupe não destrutivo (RF-005).';

  ALTER TABLE clean.canal_listas
    DROP COLUMN IF EXISTS desativada_em,
    DROP COLUMN IF EXISTS coleta;

COMMIT;
