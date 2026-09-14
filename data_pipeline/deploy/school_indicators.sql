-- Deploy edumaps:school_indicators to pg
-- requires: censo_escolar_2025
-- requires: censo_docentes
-- requires: ideb_notas_escolas

BEGIN;

  -- Tabela denormalizada para clusterização multi-tabela. Estrutura vazia;
  -- o job de clusterização (Task::Clustering) popula dinamicamente via
  -- TRUNCATE + INSERT, materializando as três fontes (censo escolar, docentes
  -- e IDEB) para o ano IDEB selecionado pelo usuário.
  --
  -- Razão de ser uma tabela (e não uma view): o motor R/Plumber grava
  -- cluster_id de volta na MESMA tabela que lê (ALTER TABLE ... ADD COLUMN +
  -- UPDATE), o que não é possível em uma view.
  CREATE TABLE clean.school_indicators AS
  SELECT
    e.*,
    d.qt_doc_bas,
    d.qt_doc_bas_esco_sup_grad_licen::float / NULLIF(d.qt_doc_bas, 0) AS prop_licenciatura,
    d.qt_doc_bas_esco_sup_pos_mestra::float / NULLIF(d.qt_doc_bas, 0)  AS prop_mestrado,
    d.qt_doc_bas_esco_sup_pos_douto::float / NULLIF(d.qt_doc_bas, 0)   AS prop_doutorado,
    d.qt_doc_bas_vinculo_concur::float / NULLIF(d.qt_doc_bas, 0)       AS prop_efetivos,
    d.qt_doc_bas_espec_nenhum::float / NULLIF(d.qt_doc_bas, 0)         AS prop_sem_especializacao,
    NULL::integer AS ano_ideb,
    NULL::numeric AS nota_media,
    NULL::numeric AS nota_matematica,
    NULL::numeric AS nota_portugues,
    NULL::numeric AS ideb_observado,
    NULL::numeric AS aprovacao_si_4
  FROM clean.censo_escolas e
  LEFT JOIN clean.censo_docentes d
    ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = e.nu_ano_censo
  LEFT JOIN (
    SELECT id_escola, ano
    FROM clean.ideb_notas_escolas
  ) i ON e.co_entidade = i.id_escola AND e.nu_ano_censo = i.ano
  LIMIT 0;

  ALTER TABLE clean.school_indicators ADD PRIMARY KEY (co_entidade);

  COMMENT ON TABLE clean.school_indicators IS
    'Indicadores para clusterização multi-tabela: censo_escolas + docentes (proporções) + IDEB/SAEB agregado por ano. Populada pelo job de clusterização.';
  COMMENT ON COLUMN clean.school_indicators.qt_doc_bas IS
    'Docentes na educação básica (total) - usado como denominador das proporções de docência';
  COMMENT ON COLUMN clean.school_indicators.prop_licenciatura IS
    'Proporção de docentes com licenciatura (qt_doc_bas_esco_sup_grad_licen / qt_doc_bas)';
  COMMENT ON COLUMN clean.school_indicators.prop_mestrado IS
    'Proporção de docentes com mestrado (qt_doc_bas_esco_sup_pos_mestra / qt_doc_bas)';
  COMMENT ON COLUMN clean.school_indicators.prop_doutorado IS
    'Proporção de docentes com doutorado (qt_doc_bas_esco_sup_pos_douto / qt_doc_bas)';
  COMMENT ON COLUMN clean.school_indicators.prop_efetivos IS
    'Proporção de docentes concursados/efetivos (qt_doc_bas_vinculo_concur / qt_doc_bas)';
  COMMENT ON COLUMN clean.school_indicators.prop_sem_especializacao IS
    'Proporção de docentes sem especialização (qt_doc_bas_espec_nenhum / qt_doc_bas)';
  COMMENT ON COLUMN clean.school_indicators.ano_ideb IS
    'Ano IDEB/SAEB usado na materialização (mesmo para todas as linhas do build atual)';
  COMMENT ON COLUMN clean.school_indicators.nota_media IS
    'Média das proficiências em Matemática e Português (SAEB), média entre etapas';
  COMMENT ON COLUMN clean.school_indicators.nota_matematica IS
    'Proficiência média em Matemática (escala SAEB), média entre etapas';
  COMMENT ON COLUMN clean.school_indicators.nota_portugues IS
    'Proficiência média em Língua Portuguesa (escala SAEB), média entre etapas';
  COMMENT ON COLUMN clean.school_indicators.ideb_observado IS
    'IDEB observado no ano, média entre etapas';
  COMMENT ON COLUMN clean.school_indicators.aprovacao_si_4 IS
    'Indicador de rendimento (0-1) - taxa de aprovação ajustada, média entre etapas';

  -- Herda os comentários das colunas do censo (e.*) para que o endpoint
  -- /api/cluster/columns consiga exibir o metadado das features.
  DO $$
  DECLARE
    r record;
  BEGIN
    FOR r IN
      SELECT c.column_name,
             col_description('clean.censo_escolas'::regclass, c.ordinal_position) AS comment
      FROM information_schema.columns c
      WHERE c.table_schema = 'clean' AND c.table_name = 'censo_escolas'
    LOOP
      IF r.comment IS NOT NULL THEN
        EXECUTE format('COMMENT ON COLUMN clean.school_indicators.%I IS %L',
                       r.column_name, r.comment);
      END IF;
    END LOOP;
  END $$;

COMMIT;