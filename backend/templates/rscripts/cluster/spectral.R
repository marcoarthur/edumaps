#' Compute Spectral Clustering, Save Cluster IDs and Metadata to Postgres
#'
#' @param con Conexao ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param k Numero de clusters
#' @param id_column Nome da chave primaria da tabela
#'
compute_and_save_spectral_with_meta <- function(con, schema, table_name, k, id_column) {

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
    library(kernlab, quietly = TRUE)
    library(jsonlite, quietly = TRUE)
  })

  run_id <- generate_run_id()

  # 1. Referencia preguicosa e introspeccao de colunas numericas
  db_table <- tbl(con, in_schema(schema, table_name))
  sample_data <- db_table %>% head(1) %>% collect()

  numeric_features <- select_numeric_features(sample_data, id_column)

  # 2. Coleta e limpeza dos dados locais
  local_data <- db_table %>%
    select(all_of(c(id_column, numeric_features))) %>%
    collect() %>%
    drop_na()

  # Spectral clustering tambem e sensivel a escala (a matriz de afinidade
  # usa distancia entre pontos)
  spectral_input <- local_data %>%
    select(all_of(numeric_features)) %>%
    scale() %>%
    as.matrix()

  # 3. Executa o Spectral Clustering
  # kernlab::specc retorna um objeto que se comporta como um vetor de
  # atribuicoes de cluster (1..k), alem de expor size() e withinss()
  set.seed(42)
  spectral_result <- kernlab::specc(spectral_input, centers = k)

  cluster_id <- as.integer(spectral_result)

  # 4. Preparacao dos metadados
  # Spectral clustering nao produz centroides verdadeiros (a particao vem
  # do espaco espectral, nao do espaco original das features). Como no
  # dbscan.R, calculamos centroides "analogos": a media de cada feature
  # (na escala original) por cluster, para manter a mesma coluna/formato
  # de metadado usado pelos demais algoritmos.
  centroids_by_cluster <- local_data %>%
    select(all_of(numeric_features)) %>%
    bind_cols(cluster_id = cluster_id) %>%
    group_by(cluster_id) %>%
    summarise(across(everything(), mean), .groups = "drop") %>%
    arrange(cluster_id)

  centroids_json <- sapply(seq_len(nrow(centroids_by_cluster)), function(i) {
    row <- centroids_by_cluster[i, ] %>% select(-cluster_id)
    jsonlite::toJSON(row, auto_unbox = TRUE) %>%
      stringr::str_remove_all("^\\[|\\]$")
  })

  # within-cluster sum of squares (no espaco espectral), analogo ao
  # within_ss do kmeans - metrica especifica do spectral clustering
  within_ss <- tryCatch(kernlab::withinss(spectral_result), error = function(e) NA_real_)

  clusters_df <- tibble(
    cluster_id = sort(unique(cluster_id)),
    cluster_size = as.integer(table(factor(cluster_id, levels = sort(unique(cluster_id))))),
    is_noise = FALSE,
    centroids = centroids_json,
    within_ss = if (length(within_ss) == length(unique(cluster_id))) within_ss else NA_real_
  )

  assignments_df <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id = cluster_id
  )

  # 5. Atualiza a tabela original com os cluster_id (in-place, via UPDATE)
  write_cluster_ids_to_table(con, schema, table_name, id_column, assignments_df)

  # 6. Grava os metadados na tabela compartilhada clustering_metadata
  write_cluster_metadata(
    con, schema,
    algorithm = "spectral",
    run_id = run_id,
    target_table = paste0(schema, ".", table_name),
    params = list(k = k),
    clusters_df = clusters_df
  )

  # 7. Monta e imprime o payload padrao em stdout, encerrando o processo
  build_response_payload(
    algorithm = "spectral",
    run_id = run_id,
    schema = schema,
    table_name = table_name,
    id_column = id_column,
    params = list(k = k),
    clusters_df = clusters_df
  )
}
