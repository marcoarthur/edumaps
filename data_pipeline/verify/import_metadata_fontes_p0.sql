-- Verify edumaps:import_metadata_fontes_p0 on pg
--
-- DO/RAISE EXCEPTION (issue #160). As asserções sobre dados valem também
-- depois de cargas futuras: não exigem 'nao_carregada' para sempre, só que
-- as fontes fora do objetivo TENHAM estado, e que as URLs mortas não voltem.

BEGIN;

DO $$
DECLARE
  c TEXT;
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['clean.censo2022_setor', 'clean.malha_setor_censitario'] LOOP
    c := obj_description(t::regclass, 'pg_class');
    IF c IS NULL OR position('INEP' IN c) > 0 OR position('e-SIC do' IN c) > 0 THEN
      RAISE EXCEPTION 'import_metadata_fontes_p0: % ainda atribui a fonte ao INEP/e-SIC: %', t, c;
    END IF;
    IF position('IBGE' IN c) = 0 OR position('DOMÍNIO PÚBLICO' IN c) = 0 THEN
      RAISE EXCEPTION 'import_metadata_fontes_p0: % não declara IBGE/DOMÍNIO PÚBLICO: %', t, c;
    END IF;
  END LOOP;

  c := obj_description('clean.sisab_aps'::regclass, 'pg_class');
  IF c IS NULL OR position('exige allowlist' IN c) > 0 OR position('datasus_sisab' IN c) = 0 THEN
    RAISE EXCEPTION 'import_metadata_fontes_p0: sisab_aps ainda diz que falta allowlist (ou não cita datasus_sisab): %', c;
  END IF;
END $$;

-- URLs mortas (404 medido em 2026-10-13) não podem estar em import_metadata.
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(table_name || ' -> ' || source_url, '; ') INTO v
    FROM clean.import_metadata
   WHERE source_url IN (
     'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/Brasil/BR_Municipios_2024.gpkg',
     'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_setores_censitarios/setor_censitario_2022/Brasil/BR_Setor_Censitario_2022.gpkg',
     'https://geoftp.ibge.gov.br/recenseamento_2022/',
     'https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malha_rodoviaria');
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'import_metadata_fontes_p0: source_url morta: %', v;
  END IF;

  SELECT source_url INTO v FROM clean.import_metadata WHERE table_name = 'clean.snv_trecho_vmda';
  IF v LIKE '%ibge.gov.br%' THEN
    RAISE EXCEPTION 'import_metadata_fontes_p0: snv_trecho_vmda (DNIT) ainda aponta para o IBGE: %', v;
  END IF;
END $$;

-- Fontes fora do objetivo: se a linha existe, tem estado (e motivo, se não ok).
DO $$
DECLARE
  v TEXT;
BEGIN
  SELECT string_agg(table_name, ', ') INTO v
    FROM clean.import_metadata
   WHERE table_name IN ('clean.antt_od_municipio', 'clean.antt_acidente_trecho',
                        'clean.antt_trecho_geodados', 'clean.antt_contagem_equipamento',
                        'clean.isocrona_escolar', 'clean.inmet_bdmep', 'clean.inmet_alerta')
     AND (ultimo_status IS NULL
          OR (ultimo_status <> 'ok' AND coalesce(ultimo_motivo, '') = ''));
  IF v IS NOT NULL THEN
    RAISE EXCEPTION 'import_metadata_fontes_p0: fonte fora do objetivo sem estado/motivo: %', v;
  END IF;
END $$;

ROLLBACK;
