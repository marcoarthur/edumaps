#' Compute Gower Similarity between entities and save pairs to Postgres
#'
#' Distancia de Gower (cluster::daisy) lida nativamente com mistura de
#' colunas numericas, categoricas (character/factor) e logicas, cada uma
#' contribuindo com um "range-scaled" comparavel, sem exigir normalizacao
#' manual previa (ao contrario de euclidean_zscore.R/mahalanobis.R).
#' Boa escolha default quando o perfil da entidade combina tipos diferentes
#' de coluna, ou quando nao se sabe de antemao.
#'
#' @param con Conexao ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema de origem dos dados (ex: "staging")
#' @param table_name Nome da tabela de origem (uma linha por entidade)
#' @param id_column Nome da chave primaria/identificador da entidade
#' @param output_schema Nome do esquema onde analytics.similarity_pairs vive
#'
compute_and_save_gower_similarity <- function(con, schema, table_name, id_column, output_schema) {

  # 0. Localiza e carrega similarity_utils.R no mesmo diretorio deste
  # script. Ver comentario equivalente em kmeans.R/dbscan.R para o
  # racional completo (o processo Rscript de fato executa um wrapper
  # temporario em /tmp, nao este arquivo).
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

  source(file.path(resolve_script_dir(), "similarity_utils.R"))

  suppressPackageStartupMessages({
    library(tidyverse, quietly = TRUE)
    library(DBI, quietly = TRUE)
    library(dbplyr, quietly = TRUE)
    library(cluster, quietly = TRUE)
    library(jsonlite, quietly = TRUE)
  })

  run_id <- generate_run_id()

  # 1. Referencia preguicosa e introspeccao de colunas elegiveis (numericas
  # + categoricas/logicas - gower lida com todas nativamente)
  db_table <- tbl(con, in_schema(schema, table_name))
  sample_data <- db_table %>% head(1) %>% collect()

  mixed_features <- select_mixed_features(sample_data, id_column)

  # 2. Coleta e limpeza dos dados locais
  local_data <- db_table %>%
    select(all_of(c(id_column, mixed_features))) %>%
    collect() %>%
    drop_na()

  if (nrow(local_data) < 2) {
    stop("Sao necessarias pelo menos 2 entidades (linhas) para calcular similaridade par-a-par.")
  }

  ids <- local_data[[id_column]]

  # daisy() trata character como categoria nominal apenas se for factor -
  # colunas character puras precisam ser convertidas explicitamente,
  # senao daisy() as ignora silenciosamente (ou erra, dependendo da versao)
  data_for_daisy <- local_data %>%
    select(all_of(mixed_features)) %>%
    mutate(across(where(is.character), as.factor))

  # 3. Calcula a matriz de distancia de Gower
  # daisy() ja normaliza cada variavel para o intervalo [0,1] internamente
  # (range-scaling por coluna), entao nao ha necessidade de z-score previo
  dist_obj <- cluster::daisy(data_for_daisy, metric = "gower")

  # 4. Converte a matriz de distancia em pares (entity_1 < entity_2)
  pairs_df <- pairs_from_distance(ids, dist_obj)

  # 5. Persiste os pares na tabela compartilhada analytics.similarity_pairs
  write_similarity_pairs(
    con, output_schema,
    metric = "gower",
    run_id = run_id,
    target_table = paste0(schema, ".", table_name),
    id_column = id_column,
    params = list(features = mixed_features),
    pairs_df = pairs_df
  )

  # 6. Monta e imprime o resumo padrao em stdout, encerrando o processo
  # (os pares completos NAO vao no stdout - ver similarity_utils.R)
  build_similarity_response_payload(
    metric = "gower",
    run_id = run_id,
    schema = schema,
    table_name = table_name,
    id_column = id_column,
    output_schema = output_schema,
    params = list(features = mixed_features),
    pairs_df = pairs_df
  )
}
