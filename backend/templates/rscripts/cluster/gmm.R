#' Compute Gaussian Mixture Model (GMM), Save Cluster IDs and Metadata to Postgres
#'
#' @param con Conexao ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param k Numero de componentes/clusters do GMM
#' @param id_column Nome da chave primaria da tabela
#'
compute_and_save_gmm_with_meta <- function(con, schema, table_name, k, id_column) {

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
    library(mclust, quietly = TRUE)
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

  # GMM (assim como kmeans) e sensivel a escala das features
  gmm_input <- local_data %>%
    select(all_of(numeric_features)) %>%
    scale()

  scale_center <- attr(gmm_input, "scaled:center")
  scale_scale <- attr(gmm_input, "scaled:scale")

  # 3. Executa o GMM com numero fixo de componentes = k
  # modelNames = NULL deixa o mclust escolher a melhor parametrizacao de
  # covariancia para os dados; G = k fixa o numero de clusters desejado
  set.seed(42)
  gmm_result <- mclust::Mclust(gmm_input, G = k, verbose = FALSE)

  if (is.null(gmm_result)) {
    stop(sprintf("Nao foi possivel ajustar um GMM com G = %d para os dados fornecidos.", k))
  }

  # 4. Preparacao dos metadados
  # Centroides dos componentes, desnormalizados de volta a escala original
  centroids_scaled <- t(gmm_result$parameters$mean)
  centroids_original <- t(apply(centroids_scaled, 1, function(row) {
    row * scale_scale + scale_center
  }))
  centroids_df <- as_tibble(centroids_original)
  colnames(centroids_df) <- numeric_features

  centroids_json <- sapply(seq_len(nrow(centroids_df)), function(i) {
    jsonlite::toJSON(centroids_df[i, ], auto_unbox = TRUE) %>%
      stringr::str_remove_all("^\\[|\\]$")
  })

  cluster_sizes <- as.integer(table(factor(gmm_result$classification, levels = seq_len(k))))

  # Probabilidade media de pertencimento (confianca) de cada componente,
  # metrica especifica do GMM (equivalente ao within_ss do kmeans)
  avg_probability <- sapply(seq_len(k), function(g) {
    idx <- which(gmm_result$classification == g)
    if (length(idx) == 0) return(NA_real_)
    mean(gmm_result$z[idx, g])
  })

  clusters_df <- tibble(
    cluster_id = seq_len(k),
    cluster_size = cluster_sizes,
    is_noise = FALSE,
    centroids = centroids_json,
    avg_probability = avg_probability,
    bic = gmm_result$bic,
    log_likelihood = gmm_result$loglik
  )

  assignments_df <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id = gmm_result$classification
  )

  # 5. Atualiza a tabela original com os cluster_id (in-place, via UPDATE)
  write_cluster_ids_to_table(con, schema, table_name, id_column, assignments_df)

  # 6. Grava os metadados na tabela compartilhada clustering_metadata
  write_cluster_metadata(
    con, schema,
    algorithm = "gmm",
    run_id = run_id,
    target_table = paste0(schema, ".", table_name),
    params = list(k = k),
    clusters_df = clusters_df
  )

  # 7. Monta e imprime o payload padrao em stdout, encerrando o processo
  build_response_payload(
    algorithm = "gmm",
    run_id = run_id,
    schema = schema,
    table_name = table_name,
    id_column = id_column,
    params = list(k = k),
    clusters_df = clusters_df
  )
}
