# R/app/tasks.R
#
# Fachadas de compatibilidade com jobs batch — o que o documento de
# arquitetura chama de "compute_and_save_*() deixa de ser a unidade
# fundamental, passa a ser apenas uma fachada". Pensado pra uma futura
# task batch (Minion no lado Perl, ou um cron chamando `Rscript -e
# 'edumapsAnalytics::compute_and_save_school_chart(...)'`).
#
# O caminho HTTP ao vivo (inst/plumber/endpoints.R) NÃO usa isto — ele
# chama run_analysis()/render_plotly() diretamente e deixa o Perl gravar
# o cache, porque é lá que o cache_key e o whitelist de variáveis já são
# validados por requisição. Esta função é o exemplo de como uma análise
# batch fica no mesmo padrão, agora com PostgresSource + Repository.

#' Calcula um gráfico de indicador escolar e persiste no cache do Postgres
#'
#' @param con conexão DBI ativa
#' @param indicator_id ver INDICATOR_WHITELIST em postgres_source.R
#' @param chart_type "histogram" | "scatter" | "boxplot"
#' @param rede "todas" | "municipal" | "estadual" | "privada"
#' @param municipio_id inteiro ou NULL
#' @param feature nome da feature (coluna `feature` em analytics.chart_cache)
#' @param cache_key chave já calculada (mesmo esquema usado no lado Perl:
#'   SHA-256 de {feature, chart_type, variables, filters} canônico)
#' @export
compute_and_save_school_chart <- function(con, indicator_id, chart_type,
                                           rede = "todas", municipio_id = NULL,
                                           feature = "escola", cache_key) {
  source <- postgres_source(con)
  model <- load_dataset(source, indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)

  parameters <- list(indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)
  result <- run_analysis(chart_type, model, parameters)

  repository <- postgres_repository(con)
  persist_result(result, repository, feature = feature, cache_key = cache_key)

  invisible(result)
}

# ---------------------------------------------------------------------------
# Batch do Perfil da Escola (issue #107 — Fase 2): referências, percentis de
# cluster e perfil por escola. Mesmo contrato das demais `compute_and_save_*`.
# ---------------------------------------------------------------------------

#' Calcula e persiste as referências comparativas do perfil
#'
#' Materializa as médias de Brasil/rede/município em
#' `analytics.school_profile_reference` (UPSERT por ano/escopo/chave/
#' indicador).
#'
#' @param con conexão DBI ativa.
#' @param nu_ano_censo ano do censo (`NULL` resolve o mais recente).
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas.
#' @param output_schema schema de destino (default: "analytics").
#'
#' @return Lista com `persisted`, `nu_ano_censo`, `rows` e `table`.
#'
#' @export
compute_and_save_school_profile_reference <- function(
  con,
  nu_ano_censo = NULL,
  schema = "clean",
  include_inactive = FALSE,
  output_schema = "analytics"
) {
  ano <- if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    resolve_censo_ano(con, schema)
  } else {
    as.integer(nu_ano_censo)
  }

  source <- postgres_source(con)
  rows <- load_school_profile_reference(
    source,
    nu_ano_censo = ano,
    schema = schema,
    include_inactive = include_inactive
  )

  persist_school_profile_reference(
    postgres_school_profile_reference_repository(con),
    rows,
    nu_ano_censo = ano,
    output_schema = output_schema
  )
}

#' Calcula e persiste os percentis por cluster do perfil
#'
#' Materializa p25/p50/p75/média por indicador de cada `cluster_id` em
#' `analytics.school_cluster_profile`.
#'
#' @param con conexão DBI ativa.
#' @param nu_ano_censo ano do censo (`NULL` resolve o mais recente).
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas.
#' @param output_schema schema de destino (default: "analytics").
#' @param run_id identificador da execução (procedência).
#'
#' @return Lista com `persisted`, `clusters`, `rows` e `table`.
#'
#' @export
compute_and_save_school_cluster_profile <- function(
  con,
  nu_ano_censo = NULL,
  schema = "clean",
  include_inactive = FALSE,
  output_schema = "analytics",
  run_id = generate_run_id()
) {
  ano <- if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    resolve_censo_ano(con, schema)
  } else {
    as.integer(nu_ano_censo)
  }

  source <- postgres_source(con)
  rows <- load_school_cluster_profile(
    source,
    nu_ano_censo = ano,
    schema = schema,
    include_inactive = include_inactive
  )

  persist_school_cluster_profile(
    postgres_school_cluster_profile_repository(con),
    rows,
    nu_ano_censo = ano,
    run_id = run_id,
    output_schema = output_schema
  )
}

#' Calcula e persiste o perfil de UMA escola
#'
#' Fachada batch do perfil: reusa `load_school_profile()` +
#' `run_school_profile()` + `persist_school_profile()`, com `persist`
#' desligado no endpoint HTTP (quem persiste é este caminho).
#'
#' @param con conexão DBI ativa.
#' @param co_entidade código INEP da escola (8 dígitos).
#' @param schema schema do censo (default: "clean").
#' @param output_schema schema de destino (default: "analytics").
#' @param ... parâmetros repassados a `load_school_profile()`.
#'
#' @return O `analysis_result` do perfil, invisivelmente.
#'
#' @export
compute_and_save_school_profile <- function(
  con,
  co_entidade,
  schema = "clean",
  output_schema = "analytics",
  ...
) {
  co_entidade <- as.character(co_entidade)
  source <- postgres_source(con)

  model <- load_school_profile(
    source,
    co_entidade = co_entidade,
    schema = schema,
    ...
  )
  result <- run_school_profile(model, parameters = list(co_entidade = co_entidade))

  persist_school_profile_result(
    result,
    postgres_school_profile_repository(con),
    output_schema = output_schema
  )

  invisible(result)
}
