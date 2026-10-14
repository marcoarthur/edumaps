-- Verify edumaps:import_metadata_fontes_p4 on pg
--
-- DO/RAISE EXCEPTION (issue #160). Vale depois de cargas futuras: exige que
-- VMDA e Recife TENHAM estado (carregada ou não carregada com motivo), não
-- 'nao_carregada' para sempre.

BEGIN;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT table_name, ultimo_status, ultimo_motivo
             FROM clean.import_metadata
            WHERE table_name IN ('clean.snv_trecho_vmda', 'clean.recife_transporte_escolar') LOOP
    IF r.ultimo_status IS NULL THEN
      RAISE EXCEPTION 'import_metadata_fontes_p4: % sem estado (nem carregada nem justificada)', r.table_name;
    END IF;
    IF r.ultimo_status = 'nao_carregada' AND coalesce(r.ultimo_motivo, '') = '' THEN
      RAISE EXCEPTION 'import_metadata_fontes_p4: % não carregada sem motivo', r.table_name;
    END IF;
  END LOOP;
END $$;

ROLLBACK;
