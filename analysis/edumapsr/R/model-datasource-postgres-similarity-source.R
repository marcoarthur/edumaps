# R/model/datasource/postgres_similarity_source.R
#
# DataSource Postgres para a análise de similaridade.
#
# Complementa o memory_similarity_source (R/model/datasource/memory_
# similarity_source.R): enquanto aquele recebe um dataset em memória, este
# lê entidades de uma tabela (ex.: staging do censo) e produz o mesmo
# `school_similarity_model`. As features podem ser numéricas, categóricas
# ou lógicas — a conversão para factor acontece no modelo, preparando o
# terreno para a distância de Gower.
#
# Nomes de schema/tabela/coluna são sempre cifrados com
# DBI::dbQuoteIdentifier() e as features são validadas contra as colunas
# reais da tabela.

#' Carrega um `SchoolSimilarityModel` a partir do Postgres
#'
#' Implementação de `load_school_similarity()` para `postgres_source`.
#' Quando `features` é `NULL`, todas as colunas da tabela, exceto
#' `id_column`, são utilizadas.
#'
#' @param source objeto da classe `postgres_source`.
#' @param schema nome do schema onde a tabela vive.
#' @param table_name nome da tabela alvo.
#' @param id_column nome da coluna que identifica a entidade.
#' @param features vetor opcional de colunas usadas como características.
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `school_similarity_model`.
#'
#' @export
load_school_similarity.postgres_source <- function(
  source,
  schema,
  table_name,
  id_column,
  features = NULL,
  ...
) {
  con <- source$con
  quote <- function(x) DBI::dbQuoteIdentifier(con, x)
  qualified <- paste(quote(schema), quote(table_name), sep = ".")

  sample <- DBI::dbGetQuery(con, sprintf("SELECT * FROM %s LIMIT 1", qualified))

  if (!(id_column %in% names(sample))) {
    stop_invalid_parameter(sprintf(
      "Coluna de entidade não encontrada: %s", id_column
    ))
  }

  if (is.null(features)) {
    features <- setdiff(names(sample), id_column)
  }

  missing <- setdiff(features, names(sample))
  if (length(missing) > 0) {
    stop_invalid_parameter(sprintf(
      "Features não encontradas: %s",
      paste(missing, collapse = ", ")
    ))
  }

  columns <- c(
    quote(id_column),
    vapply(features, quote, character(1))
  )

  data <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT %s FROM %s",
      paste(columns, collapse = ", "),
      qualified
    )
  )

  new_school_similarity_model(
    data = data,
    entity_id = id_column,
    features = features,
    metadata = list(
      schema = schema,
      table_name = table_name
    )
  )
}