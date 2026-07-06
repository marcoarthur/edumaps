library(tidyverse)
library(DBI)
library(dbplyr)

#' Compute K-means and Save Cluster ID Back to Postgres
#'
#' @param con Conexão ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "data_pipeline")
#' @param table_name Nome da tabela alvo
#' @param k Número de clusters para o K-means
#' @param id_column Nome da chave primária da tabela (necessária para o JOIN de retorno)
#'
compute_and_save_kmeans <- function(con, schema, table_name, k, id_column) {
  
  # 1. Cria uma referência preguiçosa (lazy table) para a tabela do banco
  db_table <- tbl(con, in_schema(schema, table_name))
  
  # 2. Introspecção: Lê apenas a primeira linha para identificar os tipos de colunas
  sample_data <- db_table %>% head(1) %>% collect()
  
  # Seleciona dinamicamente quais colunas da tabela são numéricas (double, integer, etc.)
  numeric_features <- sample_data %>% 
    select(where(is.numeric)) %>% 
    colnames()
  
  # Remove a coluna de ID das features numéricas (se ela for um número/serial)
  numeric_features <- setdiff(numeric_features, id_column)
  
  if (length(numeric_features) == 0) {
    stop("Nenhuma coluna numérica encontrada para computar o K-means.")
  }
  
  message("Features selecionadas para o K-means: ", paste(numeric_features, collapse = ", "))
  
  # 3. Baixa do banco apenas as colunas necessárias (ID + features numéricas)
  # O scale() é uma boa prática para normalizar as grandezas das colunas antes do K-means
  local_data <- db_table %>% 
    select(all_of(c(id_column, numeric_features))) %>% 
    collect() %>% 
    drop_na() # Remove linhas nulas que quebrariam o algoritmo
  
  # Prepara os dados normalizados para o K-means
  kmeans_input <- local_data %>% 
    select(all_of(numeric_features)) %>% 
    scale()
  
  # 4. Executa o algoritmo de K-means na memória do R
  set.seed(42) # Garante reprodutibilidade
  kmeans_result <- kmeans(kmeans_input, centers = k, nstart = 25)
  
  # 5. Prepara o dataframe de retorno contendo apenas o ID e o cluster correspondente
  output_data <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id       = kmeans_result$cluster
  )
  
  # 6. Salva de volta no banco criando uma tabela temporária para fazer o UPDATE/JOIN
  # Evita latência escrevendo os dados de uma vez só
  temp_table_name <- paste0("temp_kmeans_", as.integer(Sys.time()))
  
  dbWriteTable(con, temp_table_name, output_data, row.names = FALSE, temporary = TRUE)
  
  # 7. Adiciona a coluna cluster_id na tabela original caso ela não exista
  # Usamos SQL nativo via DBI para alterar a estrutura da tabela
  sql_add_col <- sprintf(
    "ALTER TABLE %s.%s ADD COLUMN IF NOT EXISTS cluster_id INTEGER;",
    schema, table_name
  )
  dbExecute(con, sql_add_col)
  
  # 8. Executa o UPDATE via JOIN para injetar os clusters de forma ultra rápida
  sql_update <- sprintf(
    "UPDATE %s.%s AS t
     SET cluster_id = temp.cluster_id
     FROM %s AS temp
     WHERE t.%s = temp.%s;",
    schema, table_name, temp_table_name, id_column, id_column
  )
  
  rows_affected <- dbExecute(con, sql_update)
  message(sprintf("Sucesso! %d linhas atualizadas com o cluster_id na tabela %s.%s.", 
                  rows_affected, schema, table_name))
  
  return(TRUE)
}

#' Compute K-means, Save Cluster IDs and Centroid Metadata to Postgres
#'
#' @param con Conexão ativa com o banco (DBI/RPostgres)
#' @param schema Nome do esquema no banco (ex: "analytics")
#' @param table_name Nome da tabela alvo
#' @param k Número de clusters para o K-means
#' @param id_column Nome da chave primária da tabela
#'
compute_and_save_kmeans_with_meta <- function(con, schema, table_name, k, id_column) {
  
  # Gerar um ID único para esta execução baseado no timestamp
  run_id <- paste0("run_", as.integer(Sys.time()))
  
  # 1. Referência preguiçosa e introspecção de colunas numéricas
  db_table <- tbl(con, in_schema(schema, table_name))
  sample_data <- db_table %>% head(1) %>% collect()
  
  numeric_features <- sample_data %>% 
    select(where(is.numeric)) %>% 
    colnames()
  
  # Ignora colunas de ID ou clusters anteriores
  numeric_features <- setdiff(numeric_features, c(id_column, "cluster_id"))
  
  if (length(numeric_features) == 0) {
    stop("Nenhuma coluna numérica encontrada para computar o K-means.")
  }
  
  # 2. Coleta e limpeza dos dados locais
  local_data <- db_table %>% 
    select(all_of(c(id_column, numeric_features))) %>% 
    collect() %>% 
    drop_na()
  
  # Dados para o algoritmo (K-means necessita de escala normalizada)
  kmeans_input <- local_data %>% 
    select(all_of(numeric_features)) %>% 
    scale()
  
  # Salva os atributos de escala (média e desvio padrão) para desnormalizar os centróides depois
  scale_center <- attr(kmeans_input, "scaled:center")
  scale_scale  <- attr(kmeans_input, "scaled:scale")
  
  # 3. Executa o K-means
  set.seed(42)
  kmeans_result <- kmeans(kmeans_input, centers = k, nstart = 25)
  
  
  # 4. PREPARAÇÃO DOS METADADOS (Transformação em JSON por linha)
  centroids_scaled <- kmeans_result$centers
  centroids_original <- t(apply(centroids_scaled, 1, function(row) row * scale_scale + scale_center))
  centroids_df <- as_tibble(centroids_original)

  centroids_json <- sapply(seq_len(nrow(centroids_df)), function(i) {
    # jsonlite::toJSON de um dataframe de 1 linha gera um array contendo um objeto: [{...}]
    # Usando auto_unbox e simplificando para extrair apenas o objeto literal: {...}
    jsonlite::toJSON(centroids_df[i, ], auto_unbox = TRUE) %>% 
      # Remove os colchetes externos se o R insistir em envelopar como array de 1 elemento
      stringr::str_remove_all("^\\[|\\]$") 
  })
  # Monta o dataframe final com estrutura genérica e fixa
  metadata_tb <- tibble(
    run_id       = run_id,
    target_table = paste0(schema, ".", table_name),
    cluster_id   = 1:k,
    cluster_size = kmeans_result$size,
    within_ss    = kmeans_result$withinss,
    centroids    = centroids_json  # Texto JSON que o Postgres interpretará como JSONB
  )
  # 5. SALVAMENTO DOS METADADOS
  meta_table_name <- "kmeans_metadata"
  
  # Garante que a tabela de metadados exista (adiciona se não existir)
  dbWriteTable(con, Id(schema = schema, table = meta_table_name), metadata_tb, append = TRUE)
  message("Metadados e centróides salvos em: ", schema, ".", meta_table_name)
  
  # 6. ATUALIZAÇÃO DA TABELA ORIGINAL (IDs dos Clusters)
  output_data <- tibble(
    !!sym(id_column) := local_data[[id_column]],
    cluster_id       = kmeans_result$cluster
  )
  
  temp_table_name <- paste0("temp_kmeans_", as.integer(Sys.time()))
  dbWriteTable(con, temp_table_name, output_data, row.names = FALSE, temporary = TRUE)
  
  # Adiciona a coluna cluster_id se não existir
  sql_add_col <- sprintf("ALTER TABLE %s.%s ADD COLUMN IF NOT EXISTS cluster_id INTEGER;", schema, table_name)
  dbExecute(con, sql_add_col)
  
  # Executa o Join Update massivo
  sql_update <- sprintf(
    "UPDATE %s.%s AS t SET cluster_id = temp.cluster_id FROM %s AS temp WHERE t.%s = temp.%s;",
    schema, table_name, temp_table_name, id_column, id_column
  )
  rows_affected <- dbExecute(con, sql_update)
  
  message(sprintf("Sucesso! %d escolas atualizadas com o cluster_id.", rows_affected))
  return(metadata_tb)
}
