-- Deploy edumaps:import_metadata_estado to pg
-- requires: import_metadata_uniq_table_name
--
-- =================================================================
-- #231 (P0 da #156): estado da ÚLTIMA TENTATIVA em clean.import_metadata,
-- separado da proveniência da ÚLTIMA CARGA BOA.
--
-- Porquê:
-- `upsert_metadata` (Base.pm) só rodava no sucesso, com UNIQUE(table_name).
-- Não havia onde escrever "não carregou, porquê"; e gravar uma falha nas
-- colunas existentes apagaria a proveniência da carga boa anterior.
--
-- Contrato:
--   source_file, source_url, source_license, retrieved_at,
--   row_count_loaded, notes, raw_manifest
--       -> proveniência da última carga BOA; só o upsert de sucesso escreve.
--   ultimo_status, ultimo_motivo, ultima_tentativa_em
--       -> estado da última TENTATIVA; o Runner escreve em toda execução
--          (em_carga no início; ok / falhou / nao_carregada no fim).
--   ultimo_status NULL = nenhuma tentativa registrada desde esta change.
--
-- raw_manifest: lista JSON dos arquivos brutos preservados em
-- /srv/edumaps/raw/<fonte>/<AAAA-MM-DD>/ que deram origem à carga boa:
--   [{"url","caminho","sha256","bytes","baixado_em","reaproveitado",
--     "tabelas"?}]
-- =================================================================

BEGIN;

ALTER TABLE clean.import_metadata
  ADD COLUMN ultimo_status       TEXT,
  ADD COLUMN ultimo_motivo       TEXT,
  ADD COLUMN ultima_tentativa_em TIMESTAMPTZ,
  ADD COLUMN raw_manifest        JSONB;

ALTER TABLE clean.import_metadata
  ADD CONSTRAINT import_metadata_ultimo_status_check
    CHECK (ultimo_status IN ('ok', 'falhou', 'nao_carregada', 'em_carga')),
  ADD CONSTRAINT import_metadata_raw_manifest_lista_check
    CHECK (raw_manifest IS NULL OR jsonb_typeof(raw_manifest) = 'array');

COMMENT ON COLUMN clean.import_metadata.ultimo_status IS
'Estado da ÚLTIMA TENTATIVA de carga (#231): ok | falhou | nao_carregada | em_carga. NULL = nenhuma tentativa registrada. Não altera a proveniência da última carga boa (source_*, retrieved_at, row_count_loaded, notes, raw_manifest).';

COMMENT ON COLUMN clean.import_metadata.ultimo_motivo IS
'Motivo da última tentativa sem sucesso (mensagem do erro, ou o bloqueio: e-SIC não protocolado, API retirada, fora do objetivo). NULL quando ok.';

COMMENT ON COLUMN clean.import_metadata.ultima_tentativa_em IS
'Quando foi a última tentativa (início ou fim). NULL quando o estado foi declarado por decisão (migration) e não por uma execução.';

COMMENT ON COLUMN clean.import_metadata.raw_manifest IS
'Manifesto dos arquivos brutos da última carga boa, preservados fora do pgdata em /srv/edumaps/raw/<fonte>/<AAAA-MM-DD>/: lista de {url, caminho, sha256, bytes, baixado_em, reaproveitado, tabelas?}. NULL quando a carga não baixou arquivo (ex.: API JSON).';

COMMIT;
