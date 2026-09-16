-- Deploy edumaps:column_descriptions to pg
-- requires: school_embedding

BEGIN;

  -- Backfill de metadados: colunas de tabelas/views recentes que ficaram sem
  -- descricao. Texto orientado a "por que / para que serve" (uso pela app ou
  -- pelo usuario), sem repetir tipo de dado nem valor default.

  -- ===================== analytics.school_embedding =====================
  COMMENT ON COLUMN analytics.school_embedding.co_entidade IS 'Codigo INEP da escola; liga o vetor a escola no censo.';
  COMMENT ON COLUMN analytics.school_embedding.embedding   IS 'Vetor de 6 scores consolidados; usado para achar escolas semelhantes por similaridade de cosseno (pgvector).';

  -- ========================= clean.event_store =========================
  COMMENT ON COLUMN clean.event_store.id          IS 'Identificador sequencial do evento na telemetria.';
  COMMENT ON COLUMN clean.event_store.event_id    IS 'Identificador unico do evento disparado no EventBus.';
  COMMENT ON COLUMN clean.event_store.event_type  IS 'Tipo/namespace do evento; usado para filtrar e agregar a telemetria.';
  COMMENT ON COLUMN clean.event_store.codigo_ibge IS 'Codigo IBGE do municipio associado; permite recortar a telemetria por municipio.';
  COMMENT ON COLUMN clean.event_store.source      IS 'Origem que disparou o evento (frontend, job Minion).';
  COMMENT ON COLUMN clean.event_store.payload     IS 'Corpo do evento em JSON; contexto para auditoria e replay.';
  COMMENT ON COLUMN clean.event_store.created_at  IS 'Momento em que o evento foi registrado.';

  -- ======================= clean.mv_escolas_scores ======================
  COMMENT ON COLUMN clean.mv_escolas_scores.nu_ano_censo     IS 'Ano do Censo Escolar de referencia dos scores.';
  COMMENT ON COLUMN clean.mv_escolas_scores.co_entidade      IS 'Codigo INEP da escola; liga os scores aos demais dados.';
  COMMENT ON COLUMN clean.mv_escolas_scores.data_atualizacao IS 'Momento da materializacao; indica a frescura dos scores.';

  -- ======================== clean.censo_escolas =========================
  COMMENT ON COLUMN clean.censo_escolas.geometry   IS 'Geometria (ponto) da escola; usada em mapas e analises geoespaciais.';
  COMMENT ON COLUMN clean.censo_escolas.nro_etapas IS 'Quantidade de etapas/modalidades oferecidas; base para comparar a amplitude de oferta entre escolas.';

  -- ====================== clean.school_indicators =======================
  COMMENT ON COLUMN clean.school_indicators.geometry   IS 'Geometria (ponto) da escola; usada em mapas e analises geoespaciais.';
  COMMENT ON COLUMN clean.school_indicators.nro_etapas IS 'Quantidade de etapas/modalidades oferecidas pela escola.';

  -- ===================== analytics.mv_rede_escolas ======================
  COMMENT ON COLUMN analytics.mv_rede_escolas.no_municipio               IS 'Nome do municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.sg_uf                      IS 'Sigla da UF.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.no_regiao                  IS 'Regiao do pais.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.codigo_rede                IS 'Codigo da dependencia administrativa (1 federal, 2 estadual, 3 municipal, 4 privada).';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_infantil        IS 'Matriculas na educacao infantil da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental     IS 'Matriculas no ensino fundamental (total) da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_ai  IS 'Matriculas no fundamental - anos iniciais da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_fundamental_af  IS 'Matriculas no fundamental - anos finais da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_medio           IS 'Matriculas no ensino medio da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_profissional    IS 'Matriculas na educacao profissional da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_eja             IS 'Matriculas na EJA da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_especial        IS 'Matriculas na educacao especial da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.matriculas_integral        IS 'Matriculas em tempo integral da rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_superior          IS 'Docentes com ensino superior na rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.docentes_concursados       IS 'Docentes com vinculo efetivo/concursado na rede no municipio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_fund_i                IS 'IDEB da rede nos anos iniciais do fundamental.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.ideb_medio                 IS 'IDEB da rede no ensino medio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_fund_ii         IS 'Proficiencia media (Matematica+Portugues) nos anos finais.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_matematica_fund_ii    IS 'Proficiencia media em Matematica nos anos finais.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_portugues_fund_ii     IS 'Proficiencia media em Lingua Portuguesa nos anos finais.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.nota_media_medio           IS 'Proficiencia media (Matematica+Portugues) no ensino medio.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.ano_ideb                   IS 'Ano do IDEB/SAEB usado como referencia (ultimo disponivel).';
  COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_docente         IS 'Razao matriculas/docentes; carga de alunos por professor.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.alunos_por_escola          IS 'Razao matriculas/escolas; porte medio das escolas da rede.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_superior     IS 'Percentual de docentes com ensino superior.';
  COMMENT ON COLUMN analytics.mv_rede_escolas.perc_docentes_concursados  IS 'Percentual de docentes efetivos/concursados.';

  -- ================== colunas cluster_* (criadas em runtime) ==================
  -- Adicionadas pelo job de clusterizacao (R) via ALTER TABLE, portanto podem
  -- nao existir num deploy limpo. Comentar apenas se a coluna existir.
  DO $do$
  DECLARE
    r record;
  BEGIN
    FOR r IN
      SELECT * FROM (VALUES
        ('clean', 'censo_escolas',     'cluster_id',    'Cluster ao qual a escola foi atribuida na ultima clusterizacao.'),
        ('clean', 'school_indicators', 'cluster_id',    'Cluster ao qual a escola foi atribuida na ultima clusterizacao.'),
        ('clean', 'school_indicators', 'cluster_label', 'Rotulo semantico do cluster em linguagem natural.'),
        ('clean', 'school_indicators', 'cluster_rank',  'Posicao (rank) do cluster por score; 1 = pior, N = melhor.')
      ) AS t(esquema, tabela, coluna, descricao)
    LOOP
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = r.esquema
          AND table_name   = r.tabela
          AND column_name  = r.coluna
      ) THEN
        EXECUTE format(
          'COMMENT ON COLUMN %I.%I.%I IS %L',
          r.esquema, r.tabela, r.coluna, r.descricao
        );
      END IF;
    END LOOP;
  END
  $do$;

COMMIT;
