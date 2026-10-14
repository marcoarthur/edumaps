-- Deploy edumaps:import_metadata_fontes_p4 to pg
-- requires: import_metadata_fontes_p0
-- requires: snv_trecho_vmda
-- requires: recife_transporte_escolar
--
-- #156 P4 (fechamento): as duas entradas que seguiam sem dado e sem motivo
-- passam a 'nao_carregada' por decisão do developer (2026-10-14). Mesmo
-- padrão da import_metadata_fontes_p0: ultima_tentativa_em fica NULL (não
-- houve tentativa) e só onde ainda não há estado — não pisa numa carga real.

BEGIN;

UPDATE clean.import_metadata
   SET ultimo_status = 'nao_carregada',
       ultimo_motivo = 'Fora do objetivo por ora (decisão do developer de 2026-10-14, fechamento da #156): a camada VMDA do DNIT só tem espelho publicado para o ES (GeoNode do ES), cobertura de 1 UF, e o uso depende de ADR jurídico pendente. Volta em issue própria. [declarado pela change import_metadata_fontes_p4]'
 WHERE table_name = 'clean.snv_trecho_vmda'
   AND ultimo_status IS NULL;

UPDATE clean.import_metadata
   SET ultimo_status = 'nao_carregada',
       ultimo_motivo = 'Fora do objetivo por ora (decisão do developer de 2026-10-14, fechamento da #156): a base de transporte escolar de Recife é ODbL (share-alike), que obrigaria a abrir as bases derivadas sob a mesma licença — exige decisão jurídica. Volta em issue própria. [declarado pela change import_metadata_fontes_p4]'
 WHERE table_name = 'clean.recife_transporte_escolar'
   AND ultimo_status IS NULL;

COMMIT;
