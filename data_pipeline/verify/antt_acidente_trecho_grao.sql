-- Verify edumaps:antt_acidente_trecho_grao on pg
--
-- Gate estrutural (#160): só falha com ERRO (RAISE).
BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'clean.antt_acidente_trecho'::regclass
      AND attname = 'horario' AND attnum > 0 AND NOT attisdropped
  ) THEN
    RAISE EXCEPTION 'antt_acidente_trecho_grao: coluna horario ausente';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute
    WHERE attrelid = 'clean.antt_acidente_trecho'::regclass
      AND attname = 'n_ocorrencia' AND attnum > 0 AND NOT attisdropped
  ) THEN
    RAISE EXCEPTION 'antt_acidente_trecho_grao: coluna n_ocorrencia ausente';
  END IF;

  -- A chave do evento tem de cobrir as 4 colunas do grão real.
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint c
    WHERE c.conrelid = 'clean.antt_acidente_trecho'::regclass
      AND c.conname = 'uq_antt_acidente' AND c.contype = 'u'
      AND (SELECT count(*)
             FROM unnest(c.conkey) k
             JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k
            WHERE a.attname IN ('concessionaria', 'data_acidente', 'horario', 'n_ocorrencia')) = 4
  ) THEN
    RAISE EXCEPTION 'antt_acidente_trecho_grao: chave única não é (concessionaria, data_acidente, horario, n_ocorrencia)';
  END IF;
END $$;

COMMIT;
