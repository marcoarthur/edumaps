#' clustering_utils.R
#'
#' Funções comuns compartilhadas por todos os scripts de clusterização
#' (kmeans.R, dbscan.R, gmm.R, spectral.R).
#'
#' Objetivo: centralizar o contrato de saída (stdout JSON), a persistência
#' de metadados e a atualização da tabela original, para que nenhum script
#' de algoritmo precise reimplementar (e potencialmente divergir) essas
#' responsabilidades.
#'
#' Cada script de algoritmo deve apenas:
#'   1. Calcular os clusters
#'   2. Montar um data.frame/tibble de atribuições (id_column, cluster_id)
#'   3. Montar um data.frame/tibble de estatísticas por cluster
#'   4. Chamar write_cluster_ids_to_table(), write_cluster_metadata()
#'      e finalizar com build_response_payload()
#'
#' @import DBI
#' @import jsonlite
#' @import dplyr

suppressPackageStartupMessages({
  library(DBI, quietly = TRUE)
  library(jsonlite, quietly = TRUE)
  library(dplyr, quietly = TRUE)
})

# Nome fixo da tabela de metadados, compartilhada entre todos os algoritmos.
# A coluna `algorithm` diferencia a origem de cada linha.
CLUSTERING_METADATA_TABLE <- "clustering_metadata"


#' Gera um identificador único de execução baseado em timestamp
#'
#' @return string no formato "run_<epoch>"
generate_run_id <- function() {
  paste0("run_", as.integer(Sys.time()))
}


#' Seleciona as colunas numéricas elegíveis para o algoritmo,
#' excluindo id_column e cluster_id (caso já exista de uma execução anterior)
#'
#' @param df data.frame ou tibble de origem
#' @param id_column nome da coluna de identificação
#' @return character vector com os nomes das colunas numéricas elegíveis
select_numeric_features <- function(df, id_column) {
  numeric_features <- df %>%
    dplyr::select(where(is.numeric)) %>%
    colnames()

  numeric_features <- setdiff(numeric_features, c(id_column, "cluster_id"))

  if (length(numeric_features) == 0) {
    stop("Nenhuma coluna numerica encontrada para computar o clustering.")
  }

  numeric_features
}


#' Escreve os cluster_id calculados de volta na tabela original,
#' via tabela temporária + UPDATE (join), de forma padronizada
#' para todos os algoritmos.
#'
#' @param con conexão DBI ativa
#' @param schema nome do schema
#' @param table_name nome da tabela alvo
#' @param id_column nome da coluna de identificação
#' @param assignments_df data.frame/tibble com colunas (id_column, cluster_id)
#' @return número de linhas afetadas pelo UPDATE
write_cluster_ids_to_table <- function(con, schema, table_name, id_column, assignments_df) {
  temp_table_name <- paste0("temp_clustering_", as.integer(Sys.time()))

  DBI::dbWriteTable(
    con, temp_table_name, assignments_df,
    row.names = FALSE, temporary = TRUE
  )

  # Garante que a coluna cluster_id exista na tabela original
  sql_add_col <- sprintf(
    "ALTER TABLE %s.%s ADD COLUMN IF NOT EXISTS cluster_id INTEGER;",
    schema, table_name
  )
  DBI::dbExecute(con, sql_add_col)

  # Executa o UPDATE via join com a tabela temporária
  sql_update <- sprintf(
    "UPDATE %s.%s AS t SET cluster_id = temp.cluster_id FROM %s AS temp WHERE t.%s = temp.%s;",
    schema, table_name, temp_table_name, id_column, id_column
  )
  rows_affected <- DBI::dbExecute(con, sql_update)

  rows_affected
}


#' Grava os metadados de uma execução na tabela compartilhada
#' `clustering_metadata`, sempre em modo append (preserva histórico).
#'
#' IMPORTANTE sobre uniformidade de schema: `dbWriteTable(..., append = TRUE)`
#' usa COPY internamente, que exige que as colunas do data.frame batam
#' exatamente com as colunas ja existentes na tabela no Postgres. Como
#' algoritmos diferentes produzem colunas extras diferentes em clusters_df
#' (ex: kmeans tem `within_ss`, dbscan nao tem), NAO podemos gravar essas
#' colunas "soltas" na tabela compartilhada: o primeiro algoritmo a criar
#' a tabela fixaria um schema que quebraria o proximo algoritmo com colunas
#' diferentes (foi exatamente o erro "column within_ss does not exist").
#'
#' Por isso o schema da tabela e sempre fixo — cluster_id, cluster_size,
#' is_noise, centroids, mais o restante de qualquer coluna especifica de
#' algoritmo (ex: within_ss) serializado dentro de `extra_metrics` (JSON).
#' Isso preserva a informacao sem exigir migracao de schema a cada novo
#' algoritmo/coluna.
#'
#' @param con conexão DBI ativa
#' @param schema nome do schema onde a tabela de metadados vive
#' @param algorithm nome do algoritmo ("kmeans", "dbscan", "gmm", "spectral")
#' @param run_id identificador da execução (ver generate_run_id())
#' @param target_table nome completo "schema.tabela" da tabela alvo
#' @param params lista nomeada com os parâmetros usados (ex: list(k = 5))
#' @param clusters_df data.frame/tibble com uma linha por cluster, contendo
#'   ao menos: cluster_id, cluster_size. Colunas extras (within_ss, etc.)
#'   sao preservadas dentro de `extra_metrics` (JSON), nao como colunas
#'   soltas na tabela.
#' @return invisible(TRUE)
write_cluster_metadata <- function(con, schema, algorithm, run_id, target_table, params, clusters_df) {
  core_cols  <- c("cluster_id", "cluster_size", "is_noise", "centroids")
  extra_cols <- setdiff(colnames(clusters_df), core_cols)

  # Serializa qualquer coluna extra (especifica de um algoritmo, ex:
  # within_ss do kmeans) num unico campo JSON por linha
  extra_metrics_json <- if (length(extra_cols) > 0) {
    sapply(seq_len(nrow(clusters_df)), function(i) {
      jsonlite::toJSON(clusters_df[i, extra_cols, drop = FALSE], auto_unbox = TRUE) %>%
        stringr::str_remove_all("^\\[|\\]$")
    })
  } else {
    rep(NA_character_, nrow(clusters_df))
  }

  metadata_tb <- tibble::tibble(
    run_id        = run_id,
    algorithm     = algorithm,
    target_table  = target_table,
    params_json   = as.character(jsonlite::toJSON(params, auto_unbox = TRUE)),
    cluster_id    = clusters_df$cluster_id,
    cluster_size  = clusters_df$cluster_size,
    is_noise      = if ("is_noise" %in% colnames(clusters_df)) clusters_df$is_noise else FALSE,
    centroids     = if ("centroids" %in% colnames(clusters_df)) clusters_df$centroids else NA_character_,
    extra_metrics = extra_metrics_json
  )

  DBI::dbWriteTable(
    con,
    Id(schema = schema, table = CLUSTERING_METADATA_TABLE),
    metadata_tb,
    append = TRUE
  )

  invisible(TRUE)
}


#' Monta o payload de resposta padrão e o imprime em stdout como JSON,
#' encerrando o processo R com status 0. Esse é o único ponto de saída
#' esperado pelo EduMaps::Analysis::R::Pipe (que faz decode_json do stdout).
#'
#' IMPORTANTE: todo script de algoritmo DEVE terminar chamando esta função.
#' Nunca usar message()/print()/cat() adicionais antes dela, e nunca
#' finalizar com return(TRUE) ou qualquer valor visível no top level,
#' sob pena do R imprimir output extra que quebra o parser JSON do Perl.
#'
#' @param algorithm nome do algoritmo
#' @param run_id identificador da execução
#' @param schema nome do schema
#' @param table_name nome da tabela alvo
#' @param id_column nome da coluna de identificação
#' @param params lista nomeada com os parâmetros usados
#' @param clusters_df data.frame/tibble com uma linha por cluster
#'   (mesma estrutura passada para write_cluster_metadata)
#' @return não retorna; encerra o processo via quit(status = 0)
build_response_payload <- function(algorithm, run_id, schema, table_name, id_column, params, clusters_df) {
  response_payload <- list(
    status = "success",
    algorithm = as.character(algorithm),
    run_id = as.character(run_id),
    schema = as.character(schema),
    table_name = as.character(table_name),
    id_column = as.character(id_column),
    metadata_table = paste0(schema, ".", CLUSTERING_METADATA_TABLE),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    params = params,
    n_clusters = nrow(clusters_df),
    clusters = clusters_df
  )

  # cat envia texto puro ao stdout, sem os índices [1] do print classico do R
  cat(jsonlite::toJSON(response_payload, auto_unbox = TRUE))
  quit(status = 0)
}
