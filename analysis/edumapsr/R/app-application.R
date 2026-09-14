# R/app/application.R
#
# Fachada funcional (não OO — combina melhor com o ecossistema R e deixa
# tudo testável como função pura, seguindo a preferência do documento de
# arquitetura). É o que um script/endpoint chama do início ao fim:
#
#   model  <- load_dataset(source, ...)
#   result <- run_analysis(name, model, parameters)
#   export_result(result, "json")
#   persist_result(result, repository)

#' Carrega um SchoolIndicatorModel a partir de qualquer DataSource
#' (memory_source, postgres_source, ou uma futura parquet_source/csv_source)
#' @export
load_dataset <- function(source, ...) load_school_indicator(source, ...)

#' Renderiza um AnalysisResult no formato pedido
#' @param format "plotly" ou "json"
#' @export
export_result <- function(result, format = c("plotly", "json")) {
  format <- match.arg(format)
  switch(format,
    plotly = render_plotly(result),
    json = render_json(result)
  )
}

#' Persiste um AnalysisResult usando um Repository
#' @export
persist_result <- function(result, repository, ...) {
  persist(repository, result, ...)
}

#' Carrega um `SchoolSimilarityModel` a partir de qualquer DataSource
#'
#' @param source DataSource compatível com `load_school_similarity()`.
#' @param ... parâmetros específicos da fonte.
#'
#' @return Objeto da classe `school_similarity_model`.
#'
#' @export
load_similarity_dataset <- function(source, ...) {
  load_school_similarity(source, ...)
}

#' Executa a análise de similaridade de Gower
#'
#' @param model objeto da classe `school_similarity_model`.
#' @param parameters lista de parâmetros da execução.
#'
#' @return Objeto da classe `analysis_result`.
#'
#' @export
run_similarity <- function(
  model,
  parameters = list()
) {
  analyze_gower_similarity(model, parameters)
}

#' Persiste um resultado de similaridade
#'
#' @param result objeto da classe `analysis_result`.
#' @param repository Repository compatível com `persist_similarity()`.
#' @param ... parâmetros específicos do Repository.
#'
#' @return O objeto `result`, invisivelmente.
#'
#' @export
persist_similarity_result <- function(
  result,
  repository,
  ...
) {
  persist_similarity(repository, result, ...)
}

#' Carrega um `SchoolClusterModel` a partir de qualquer DataSource
#'
#' @param source DataSource compatível com `load_school_entities()`.
#' @param ... parâmetros específicos da fonte.
#'
#' @return Objeto da classe `school_cluster_model`.
#'
#' @export
load_cluster_dataset <- function(source, ...) {
  load_school_entities(source, ...)
}

#' Executa a análise de clusterização
#'
#' @param model objeto da classe `school_cluster_model`.
#' @param parameters lista com `algorithm` (kmeans/dbscan/gmm/spectral),
#'   `clusters`, `eps` e `min_pts`.
#'
#' @return Objeto da classe `analysis_result`.
#'
#' @export
run_cluster <- function(
  model,
  parameters = list()
) {
  analyze_cluster(model, parameters)
}

#' Persiste um resultado de clusterização
#'
#' @param result objeto da classe `analysis_result`.
#' @param repository Repository compatível com `persist_cluster()`.
#' @param ... parâmetros específicos do Repository.
#'
#' @return Lista com `run_id`, `rows_updated` e `metadata_table`.
#'
#' @export
persist_cluster_result <- function(
  result,
  repository,
  ...
) {
  persist_cluster(repository, result, ...)
}

#' Carrega um `CitySchoolModel` a partir de qualquer DataSource
#'
#' @param source DataSource compatível com `load_city_schools()`.
#' @param ... parâmetros específicos da fonte.
#'
#' @return Objeto da classe `city_school_model`.
#'
#' @export
load_city_dataset <- function(source, ...) {
  load_city_schools(source, ...)
}

#' Executa o resumo estatístico de um município
#'
#' @param model objeto da classe `city_school_model`.
#' @param parameters lista com `type` (full_summary | school_clusters |
#'   score_distributions).
#'
#' @return Objeto da classe `analysis_result`.
#'
#' @export
run_city_summary <- function(
  model,
  parameters = list()
) {
  analyze_city_summary(model, parameters)
}

#' Persiste um resumo estatístico de município
#'
#' @param result objeto da classe `analysis_result`.
#' @param repository Repository compatível com `persist_city_summary()`.
#' @param ... parâmetros específicos do Repository.
#'
#' @return Lista com `persisted`, `codigo_ibge`, `analysis` e
#'   `records_processed`.
#'
#' @export
persist_city_summary_result <- function(
  result,
  repository,
  ...
) {
  persist_city_summary(repository, result, ...)
}

#' Persiste pares de similaridade em lote (append por run)
#'
#' @param result objeto da classe `analysis_result`.
#' @param repository Repository compatível com
#'   `persist_similarity_pairs()`.
#' @param ... parâmetros específicos do Repository.
#'
#' @return Lista com `persisted`, `run_id`, `pairs` e `table`.
#'
#' @export
persist_similarity_pairs_result <- function(
  result,
  repository,
  ...
) {
  persist_similarity_pairs(repository, result, ...)
}
