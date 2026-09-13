# R/repository/postgres_cluster.R
#
# Repository PostgreSQL para resultados de clusterização.
#
# O contrário das análises puras (R/analysis/), que nunca tocam banco.
# Aqui acontecem os dois efeitos colaterais que o fluxo legado
# (backend/templates/rscripts/cluster/) já tinha, em ordem:
#
#   1. write_cluster_ids_to_table() — grava os cluster_id de volta na
#      tabela de origem (in-place, via UPDATE join com tabela temporária);
#   2. write_cluster_metadata() — insere uma linha por cluster em
#      `analytics.clustering_metadata`, incluindo métricas específicas do
#      algoritmo serializadas em `extra_metrics` (JSON), para manter o
#      schema da tabela compartilhada fixo entre algoritmos diferentes.
#
# A tabela de metadados é criada aqui se não existir (self-provisioning,
# mesma postura dos scripts legados, que não tinham migration própria).

CLUSTERING_METADATA_TABLE <- "clustering_metadata"

#' Cria um repository PostgreSQL para resultados de cluster
#'
#' @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_cluster_repository`.
#'
#' @export
postgres_cluster_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_cluster_repository"
  )
}

#' Persiste um resultado de clusterização
#'
#' Generic S3 para persistência de resultados de cluster. As implementações
#' recebem os parâmetros de persistência (tabela de origem, coluna de
#' identificação, schema de saída) como argumentos nomeados adicionais.
#'
#' @param repository objeto Repository.
#' @param result objeto da classe `analysis_result`.
#' @param schema nome do schema da tabela de origem (ex.: "staging").
#' @param table_name nome da tabela de origem.
#' @param id_column nome da coluna de identificação da entidade.
#' @param output_schema schema onde a tabela de metadados vive
#'   (default: "analytics").
#' @param run_id identificador da execução (default: gerado aqui).
#' @param ... parâmetros específicos da implementação.
#'
#' @return O objeto `result`, invisivelmente.
#'
#' @export
persist_cluster <- function(
  repository,
  result,
  schema,
  table_name,
  id_column,
  output_schema = "analytics",
  run_id = generate_run_id(),
  ...
) {
  UseMethod("persist_cluster")
}

#' Persiste um resultado de clusterização no PostgreSQL
#'
#' Grava as atribuições de volta na tabela de origem e insere os
#' metadados por cluster em `analytics.clustering_metadata`.
#'
#' @param repository objeto da classe `postgres_cluster_repository`.
#' @param result objeto da classe `analysis_result`, produzido por
#'   `analyze_cluster()`.
#' @param schema nome do schema da tabela de origem (ex.: "staging").
#' @param table_name nome da tabela de origem.
#' @param id_column nome da coluna de identificação da entidade.
#' @param output_schema schema onde a tabela de metadados vive
#'   (default: "analytics").
#' @param run_id identificador da execução (default: gerado aqui).
#'
#' @return Lista com `run_id`, `rows_updated`, `metadata_table`,
#'   `algorithm` e `target_table`.
#'
#' @export
persist_cluster.postgres_cluster_repository <- function(
  repository,
  result,
  schema,
  table_name,
  id_column,
  output_schema = "analytics",
  run_id = generate_run_id(),
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }
  if (!startsWith(result$analysis, "cluster_")) {
    stop("repository espera um resultado de clusterização")
  }

  con <- repository$con
  algorithm <- sub("^cluster_", "", result$analysis)
  assignments <- result$data
  clusters_df <- result$tables$clusters
  parameters <- result$parameters
  target_table <- paste0(schema, ".", table_name)

  # 1. cluster_id de volta na tabela de origem
  rows_updated <- .write_cluster_ids(
    con, schema, table_name, id_column, assignments
  )

  # 2. metadados em analytics.clustering_metadata
  .write_cluster_metadata(
    con, output_schema,
    algorithm = algorithm,
    run_id = run_id,
    target_table = target_table,
    params = parameters,
    clusters_df = clusters_df
  )

  list(
    run_id = run_id,
    rows_updated = rows_updated,
    metadata_table = paste0(output_schema, ".", CLUSTERING_METADATA_TABLE),
    algorithm = algorithm,
    target_table = target_table
  )
}

#' Grava os cluster_id na tabela de origem via UPDATE join
#'
#' @keywords internal
.write_cluster_ids <- function(con, schema, table_name, id_column, assignments) {
  temp_table_name <- paste0("temp_clustering_", as.integer(Sys.time()))

  DBI::dbWriteTable(
    con,
    temp_table_name,
    assignments,
    row.names = FALSE,
    temporary = TRUE
  )

  DBI::dbExecute(con, sprintf(
    "ALTER TABLE %s.%s ADD COLUMN IF NOT EXISTS cluster_id INTEGER;",
    DBI::dbQuoteIdentifier(con, schema),
    DBI::dbQuoteIdentifier(con, table_name)
  ))

  rows_updated <- DBI::dbExecute(
    con,
    sprintf(
      "UPDATE %s.%s AS t SET cluster_id = temp.cluster_id
       FROM %s AS temp
       WHERE t.%s = temp.%s;",
      DBI::dbQuoteIdentifier(con, schema),
      DBI::dbQuoteIdentifier(con, table_name),
      DBI::dbQuoteIdentifier(con, temp_table_name),
      DBI::dbQuoteIdentifier(con, id_column),
      DBI::dbQuoteIdentifier(con, id_column)
    )
  )

  rows_updated
}

#' Insere os metadados por cluster na tabela compartilhada
#'
#' @keywords internal
.write_cluster_metadata <- function(con, schema, algorithm, run_id,
                                    target_table, params, clusters_df) {
  .ensure_cluster_metadata_table(con, schema)

  core_cols <- c("cluster_id", "cluster_size", "is_noise", "centroids")
  extra_cols <- setdiff(colnames(clusters_df), core_cols)

  extra_metrics_json <- if (length(extra_cols) > 0 && nrow(clusters_df) > 0) {
    sapply(seq_len(nrow(clusters_df)), function(i) {
      jsonlite::toJSON(
        clusters_df[i, extra_cols, drop = FALSE],
        auto_unbox = TRUE
      )
    })
  } else {
    rep(NA_character_, max(nrow(clusters_df), 0L))
  }

  metadata_df <- data.frame(
    run_id = run_id,
    algorithm = algorithm,
    target_table = target_table,
    params_json = as.character(jsonlite::toJSON(params, auto_unbox = TRUE)),
    cluster_id = clusters_df$cluster_id,
    cluster_size = clusters_df$cluster_size,
    is_noise = if (nrow(clusters_df) > 0) clusters_df$is_noise else logical(0),
    centroids = if (nrow(clusters_df) > 0) clusters_df$centroids else character(0),
    extra_metrics = extra_metrics_json,
    stringsAsFactors = FALSE
  )

  if (nrow(metadata_df) > 0) {
    DBI::dbAppendTable(
      con,
      DBI::Id(schema = schema, table = CLUSTERING_METADATA_TABLE),
      metadata_df
    )
  }

  invisible(TRUE)
}

#' Garante o schema e a tabela de metadados (self-provisioning)
#'
#' @keywords internal
.ensure_cluster_metadata_table <- function(con, schema) {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       run_id        text,
       algorithm     text,
       target_table  text,
       params_json   jsonb,
       cluster_id    integer,
       cluster_size  integer,
       is_noise      boolean,
       centroids     text,
       extra_metrics text
     );",
    DBI::dbQuoteIdentifier(con, schema),
    DBI::dbQuoteIdentifier(con, CLUSTERING_METADATA_TABLE)
  ))
}