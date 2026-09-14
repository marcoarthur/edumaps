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

SIMILARITY_PAIRS_TABLE <- "similarity_pairs"

#' Garante a tabela de pares de similaridade (bootstrap)
#'
#' `analytics.similarity_pairs` não tem migration própria no repositório
#' (a tabela era criada em runtime pelos scripts legados). Aqui ela é
#' criada se não existir, mantendo o mesmo schema de saída do fluxo
#' legado.
#'
#' @keywords internal
ensure_similarity_pairs_table <- function(con, output_schema = "analytics") {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, output_schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       run_id      text NOT NULL,
       metric      text NOT NULL,
       target_table text NOT NULL,
       id_column   text NOT NULL,
       params_json jsonb,
       computed_at timestamp with time zone DEFAULT now(),
       entity_1    text NOT NULL,
       entity_2    text NOT NULL,
       distance    double precision,
       similarity  double precision
     );",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SIMILARITY_PAIRS_TABLE)
  ))
}

#' Persiste pares de similaridade com metadados da execução
#'
#' Generic S3 para persistência de pares em lote (append por run).
#'
#' @param repository objeto Repository.
#' @param result objeto da classe `analysis_result`.
#' @param target_table tabela de origem das entidades (ex.: "clean.censo_escolas").
#' @param metric métrica de distância usada (default: "gower").
#' @param id_column coluna de identificação das entidades.
#' @param params parâmetros da execução serializados em `params_json`.
#' @param run_id identificador da execução (default: gerado aqui).
#' @param output_schema schema onde a tabela de pares vive
#'   (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `run_id`, `pairs` e `table`.
#'
#' @export
persist_similarity_pairs <- function(
  repository,
  result,
  target_table,
  metric = "gower",
  id_column,
  params = list(),
  run_id = generate_run_id(),
  output_schema = "analytics",
  ...
) {
  UseMethod("persist_similarity_pairs")
}

#' Persiste pares de similaridade no PostgreSQL (append por run)
#'
#' Implementação de `persist_similarity_pairs()` para
#' `postgres_similarity_repository`. Insere uma linha por par em
#' `analytics.similarity_pairs`, carimbada com `run_id`, `metric`,
#' `target_table`, `id_column` e `params_json` — o equivalente HTTP do
#' que o script legado `backend/templates/rscripts/similarity/gower.R`
#' fazia em runtime.
#'
#' @param repository objeto da classe `postgres_similarity_repository`.
#' @param result objeto da classe `analysis_result`, produzido por
#'   `analyze_gower_similarity()`.
#' @param target_table tabela de origem das entidades (ex.: "clean.censo_escolas").
#' @param metric métrica de distância usada (default: "gower").
#' @param id_column coluna de identificação das entidades.
#' @param params parâmetros da execução serializados em `params_json`.
#' @param run_id identificador da execução (default: gerado aqui).
#' @param output_schema schema onde a tabela de pares vive
#'   (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `run_id`, `target_table`, `pairs` e
#'   `table`.
#'
#' @export
persist_similarity_pairs.postgres_similarity_repository <- function(
  repository,
  result,
  target_table,
  metric = "gower",
  id_column,
  params = list(),
  run_id = generate_run_id(),
  output_schema = "analytics",
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }

  if (!identical(result$analysis, "gower_similarity")) {
    stop("repository espera um resultado gower_similarity")
  }

  con <- repository$con
  ensure_similarity_pairs_table(con, output_schema)

  pairs <- result$data
  pairs_df <- data.frame(
    run_id = run_id,
    metric = metric,
    target_table = target_table,
    id_column = id_column,
    params_json = as.character(jsonlite::toJSON(params, auto_unbox = TRUE)),
    entity_1 = as.character(pairs$entity_id_a),
    entity_2 = as.character(pairs$entity_id_b),
    distance = as.numeric(pairs$distance),
    similarity = as.numeric(pairs$similarity),
    stringsAsFactors = FALSE
  )

  DBI::dbAppendTable(
    con,
    DBI::Id(schema = output_schema, table = SIMILARITY_PAIRS_TABLE),
    pairs_df
  )

  list(
    persisted = TRUE,
    run_id = run_id,
    target_table = target_table,
    pairs = nrow(pairs_df),
    table = paste0(output_schema, ".", SIMILARITY_PAIRS_TABLE)
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
