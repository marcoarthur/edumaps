-- Revert edumaps:import_metadata_fontes_p4 from pg
-- Desfaz só o que esta change declarou (marcador no motivo).

BEGIN;

UPDATE clean.import_metadata
   SET ultimo_status = NULL, ultimo_motivo = NULL
 WHERE table_name IN ('clean.snv_trecho_vmda', 'clean.recife_transporte_escolar')
   AND ultimo_status = 'nao_carregada'
   AND ultimo_motivo LIKE '%[declarado pela change import_metadata_fontes_p4]%';

COMMIT;
