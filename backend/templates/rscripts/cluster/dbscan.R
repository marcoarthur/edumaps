#' Compute DBSCAN, Save Cluster IDs and Cluster Metadata to Postgres
#'
#' @param con Conexao ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param eps Raio maximo da vizinhanca (tamanho do passo)
#' @param min_pts Numero minimo de pontos para regiao densa
#' @param id_column Nome da chave primaria da tabela
#'
compute_and_save_dbscan_with_meta <- function(con, schema, table_name, eps, min_pts, id_column) {

  # 0. Localiza e carrega clustering_utils.R no mesmo diretorio deste script.
  # Ver comentario equivalente em kmeans.R para o racional completo.
  resolve_script_dir <- function() {
    initial_options <- commandArgs(trailingOnly = FALSE)
    file_arg <- "--file="
    wrapper_path <- sub(file_arg, "", initial_options[grep(file_arg, initial_options)])

    if (length(wrapper_path) > 0 && file.exists(wrapper_path)) {
      first_line <- readLines(wrapper_path, n = 1, warn = FALSE)
      extracted <- sub('^source\\("([^"]+)"\\).*$', '\\1', first_line)
      if (nzchar(extracted) && extracted != first_line) {
        return(dirname(normalizePath(extracted)))
      }
    }

    if (length(wrapper_path) > 0) {
      return(dirname(normalizePath(wrapper_path)))
    }

    getwd()
  }

  source(file.path(resolve_script_dir(), "clustering_utils.R"))

  suppressPackageStartupMessages({
    library(tidyverse, quietly = TRUE)
    library(DBI, quietly = TRUE)
    library(dbplyr, quietly = TRUE)
    library(dbscan, quietly = TRUE)
    library(jsonlite, quietly = TRUE)
  })

  run_id <- generate_run_id()

  # 1. Referencia preguicosa e introspeccao de colunas numericas
  # (mesma estrategia lazy do kmeans.R, em vez de dbReadTable direto,
  # para nao trazer a tabela inteira so para inspecionar os tipos)
  db_table <- tbl(con, in_schema(schema, table_name))
  sample_data <- db_table %>% head(1) %>% collect()

  numeric_features <- select_numeric_features(sample_data, id_column)

  # 2. Coleta e limpeza dos dados locais
  local_data <- db_table %>%
    select(all_of(c(id_column, numeric_features))) %>%
    collect() %>%
    drop_na()

  # Dados para o algoritmo. DBSCAN e sensivel a escala das features
  # (ex: "10 professores" nao pode pesar menos que "400 alunos"),
  # entao a matriz PADRONIZADA e a que efetivamente entra no dbscan()
  dbscan_input <- local_data %>%
    select(all_of(numeric_features)) %>%
    scale()

  # 3. Execucao do DBSCAN (dbscan::dbscan usa arvores kd, otimizado)
  dbscan_result <- dbscan::dbscan(dbscan_input, eps = eps, minPts = min_pts)

  # 4. Preparacao da tabela de mapeamento de IDs -> Clusters
  # No dbscan, a classe '0' e explicitamente atribuida a ruido/outliers
  assignments_df <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id = dbscan_result$cluster
  )

  # 5. Centroides "analogos": media de cada feature (na escala original)
  # por cluster, incluindo o cluster de ruido (0). Mantem a mesma forma
  # de metadado usada pelo kmeans.R, mesmo o DBSCAN nao tendo centroides
  # verdadeiros por construcao.
  centroids_by_cluster <- local_data %>%
    select(all_of(numeric_features)) %>%
    bind_cols(cluster_id = dbscan_result$cluster) %>%
    group_by(cluster_id) %>%
    summarise(across(everything(), mean), .groups = "drop")

  centroids_json <- sapply(seq_len(nrow(centroids_by_cluster)), function(i) {
    row <- centroids_by_cluster[i, ] %>% select(-cluster_id)
    jsonlite::toJSON(row, auto_unbox = TRUE) %>%
      stringr::str_remove_all("^\\[|\\]$")
  })

  # 6. Estrutura generica e fixa, compartilhada com os demais algoritmos
  clusters_df <- assignments_df %>%
    group_by(cluster_id) %>%
    summarise(cluster_size = n(), .groups = "drop") %>%
    mutate(is_noise = cluster_id == 0) %>%
    arrange(cluster_id) %>%
    mutate(centroids = centroids_json)

  # 7. Atualiza a tabela original com os cluster_id (in-place, via UPDATE)
  write_cluster_ids_to_table(con, schema, table_name, id_column, assignments_df)

  # 8. Grava os metadados na tabela compartilhada clustering_metadata
  write_cluster_metadata(
    con, schema,
    algorithm = "dbscan",
    run_id = run_id,
    target_table = paste0(schema, ".", table_name),
    params = list(eps = eps, min_pts = min_pts),
    clusters_df = clusters_df
  )

  # 9. Monta e imprime o payload padrao em stdout, encerrando o processo
  build_response_payload(
    algorithm = "dbscan",
    run_id = run_id,
    schema = schema,
    table_name = table_name,
    id_column = id_column,
    params = list(eps = eps, min_pts = min_pts),
    clusters_df = clusters_df
  )
}
