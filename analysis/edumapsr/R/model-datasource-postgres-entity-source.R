# R/model/datasource/postgres_entity_source.R
#
# DataSource Postgres para entidades multidimensionais (escola, município).
#
# Uso restrito a pipelines batch/offline com parâmetros controlados — o
# mesmo critério documentado em postgres_source.R. Os nomes de colunas
# passados por parâmetro são SEMPRE citados via DBI::dbQuoteIdentifier()
# e validados contra as colunas reais da tabela (nunca interpolação crua).
#
# É a fonte usada pelas análises de clusterização, que precisam de um
# conjunto de features numéricas por entidade.

#' Carrega um `SchoolClusterModel` a partir de uma fonte
#'
#' Generic S3 para carregar o modelo semântico de cluster.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros específicos da implementação da fonte.
#'
#' @return Objeto da classe `school_cluster_model`.
#'
#' @export
load_school_entities <- function(source, ...) {
  UseMethod("load_school_entities")
}

#' Cria uma fonte de dados de entidades no Postgres
#'
#' @param con conexão DBI ativa (ex.: `RPostgres::dbConnect(...)`)
#'
#' @return Objeto S3 da classe `postgres_entity_source`.
#'
#' @export
postgres_entity_source <- function(con) {
  structure(
    list(con = con),
    class = c("postgres_entity_source", "data_source")
  )
}

#' Carrega um `SchoolClusterModel` a partir do Postgres
#'
#' Implementação de `load_school_entities()` para `postgres_entity_source`.
#' Quando `features` é `NULL`, as colunas numéricas da tabela (exceto o
#' `id_column`) são usadas como features.
#'
#' @param source objeto da classe `postgres_entity_source`.
#' @param schema nome do schema onde a tabela vive.
#' @param table_name nome da tabela alvo.
#' @param id_column nome da coluna de identificação da entidade.
#' @param features vetor opcional de colunas numéricas a usar.
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `school_cluster_model`.
#'
#' @export
load_school_entities.postgres_entity_source <- function(
  source,
  schema,
  table_name,
  id_column,
  features = NULL,
  ...
) {
  quote <- function(x) DBI::dbQuoteIdentifier(source$con, x)
  qualified <- paste(quote(schema), quote(table_name), sep = ".")

  sample <- DBI::dbGetQuery(
    source$con,
    sprintf("SELECT * FROM %s LIMIT 1", qualified)
  )

  if (!(id_column %in% names(sample))) {
    stop_invalid_parameter(sprintf(
      "Coluna de entidade não encontrada: %s", id_column
    ))
  }

  if (is.null(features)) {
    numeric_features <- names(sample)[
      vapply(sample, is.numeric, logical(1))
    ]
    features <- setdiff(numeric_features, id_column)

    if (length(features) == 0) {
      stop_invalid_dataset("Nenhuma coluna numérica encontrada para computar o clustering.")
    }
  }

  missing <- setdiff(features, names(sample))
  if (length(missing) > 0) {
    stop_invalid_parameter(sprintf(
      "Features não encontradas na tabela %s.%s: %s",
      schema, table_name, paste(missing, collapse = ", ")
    ))
  }

  columns <- c(
    quote(id_column),
    vapply(features, quote, character(1))
  )

  sql <- sprintf(
    "SELECT %s FROM %s",
    paste(columns, collapse = ", "),
    qualified
  )

  data <- DBI::dbGetQuery(source$con, sql)

  new_school_cluster_model(
    data = data,
    entity_id = id_column,
    features = features,
    metadata = list(
      schema = schema,
      table_name = table_name
    )
  )
}