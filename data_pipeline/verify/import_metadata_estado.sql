-- Verify edumaps:import_metadata_estado on pg
--
-- Asserções em DO/RAISE EXCEPTION (issue #160: um SELECT que devolve 'f'
-- passa como ok no Sqitch 1.6.1). Tudo dentro de BEGIN/ROLLBACK: as linhas
-- de prova nunca ficam no banco.

BEGIN;

-- 1. As 4 colunas, com os tipos certos.
DO $$
DECLARE
  esperado TEXT[][] := ARRAY[
    ['ultimo_status', 'text'],
    ['ultimo_motivo', 'text'],
    ['ultima_tentativa_em', 'timestamp with time zone'],
    ['raw_manifest', 'jsonb']];
  i INT;
  tipo TEXT;
BEGIN
  FOR i IN 1 .. array_length(esperado, 1) LOOP
    SELECT format_type(a.atttypid, a.atttypmod) INTO tipo
      FROM pg_attribute a
     WHERE a.attrelid = 'clean.import_metadata'::regclass
       AND a.attname = esperado[i][1] AND NOT a.attisdropped;
    IF tipo IS DISTINCT FROM esperado[i][2] THEN
      RAISE EXCEPTION 'import_metadata_estado: coluna % ausente ou com tipo % (esperado %)',
        esperado[i][1], coalesce(tipo, 'ausente'), esperado[i][2];
    END IF;
  END LOOP;
END $$;

-- 2. O CHECK de ultimo_status recusa valor fora do domínio.
DO $$
BEGIN
  BEGIN
    INSERT INTO clean.import_metadata (table_name, source_file, ultimo_status)
    VALUES ('__verify_estado_invalido__', '__verify__', 'sucesso');
    RAISE EXCEPTION 'import_metadata_estado: ultimo_status aceitou valor fora do domínio';
  EXCEPTION WHEN check_violation THEN
    NULL;  -- esperado
  END;
END $$;

-- 3. raw_manifest tem de ser lista.
DO $$
BEGIN
  BEGIN
    INSERT INTO clean.import_metadata (table_name, source_file, raw_manifest)
    VALUES ('__verify_estado_manifesto__', '__verify__', '{"url":"x"}'::jsonb);
    RAISE EXCEPTION 'import_metadata_estado: raw_manifest aceitou objeto (tem de ser lista)';
  EXCEPTION WHEN check_violation THEN
    NULL;  -- esperado
  END;
END $$;

-- 4. O upsert de ESTADO do Base.pm (o SQL real) não destrói a proveniência
--    da última carga boa — é a razão de existir desta change.
DO $$
DECLARE
  r RECORD;
BEGIN
  INSERT INTO clean.import_metadata
    (table_name, source_file, source_url, source_license, retrieved_at,
     row_count_loaded, notes, ultimo_status, raw_manifest)
  VALUES ('__verify_estado__', 'arquivo-bom', 'https://exemplo/bom', 'CC0',
          '2026-01-01', 42, 'carga boa', 'ok',
          '[{"url":"https://exemplo/bom","sha256":"abc","bytes":1}]');

  INSERT INTO clean.import_metadata AS im
    (table_name, source_file, ultimo_status, ultimo_motivo, ultima_tentativa_em)
  VALUES ('__verify_estado__', '(nenhuma carga registrada)', 'falhou', 'boom', NOW())
  ON CONFLICT (table_name) DO UPDATE SET
    ultimo_status = EXCLUDED.ultimo_status,
    ultimo_motivo = EXCLUDED.ultimo_motivo,
    ultima_tentativa_em = NOW();

  SELECT * INTO r FROM clean.import_metadata WHERE table_name = '__verify_estado__';
  IF r.source_file <> 'arquivo-bom' OR r.source_url <> 'https://exemplo/bom'
     OR r.row_count_loaded <> 42 OR r.retrieved_at <> '2026-01-01'::timestamptz
     OR r.raw_manifest IS NULL THEN
    RAISE EXCEPTION 'import_metadata_estado: registrar falha destruiu a proveniência da carga boa';
  END IF;
  IF r.ultimo_status <> 'falhou' OR r.ultimo_motivo <> 'boom' OR r.ultima_tentativa_em IS NULL THEN
    RAISE EXCEPTION 'import_metadata_estado: o estado da tentativa não foi gravado';
  END IF;
END $$;

ROLLBACK;
