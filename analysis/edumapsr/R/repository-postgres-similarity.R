# R/repository/postgres_similarity.R
#
# Repository PostgreSQL específico para resultados de similaridade.
#
# Não reutilizamos `postgres_repository` porque aquele Repository possui
# um contrato explícito com `analytics.chart_cache`. Similaridade não é
# um gráfico e não deve ser persistida fingindo que é um.
#
# O Repository recebe um AnalysisResult já calculado e é responsável
# exclusivamente por sua persistência.

#' Cria um repository PostgreSQL para resultados de similaridade
#'
# @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_similarity_repository`.
#'
#' @export
postgres_similarity_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_similarity_repository"
  )
}

#' Persiste um resultado de similaridade
#'
#' Generic S3 para persistência de resultados produzidos pela análise
#' de similaridade.
#'
#' @param repository objeto Repository.
#' @param result objeto da classe `analysis_result`.
#' @param ... parâmetros específicos da implementação.
#'
#' @return O objeto `result`, invisivelmente.
#'
#' @export
persist_similarity <- function(repository, result, ...) {
  UseMethod("persist_similarity")
}

#' Persiste um resultado de similaridade no PostgreSQL
#'
#' @param repository objeto da classe `postgres_similarity_repository`.
#' @param result objeto da classe `analysis_result`, produzido por
#'   `analyze_gower_similarity()`.
#' @param table `DBI::Id` ou identificador de tabela aceito por
#'   `DBI::dbWriteTable()`.
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return O objeto `result`, invisivelmente.
#'
#' @export
persist_similarity.postgres_similarity_repository <- function(
  repository,
  result,
  table = DBI::Id(
    schema = "analytics",
    table = "school_similarity"
  ),
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }

  if (!identical(result$analysis, "gower_similarity")) {
    stop("repository espera um resultado gower_similarity")
  }

  DBI::dbWriteTable(
    repository$con,
    table,
    result$data,
    append = TRUE,
    row.names = FALSE
  )

  invisible(result)
}
