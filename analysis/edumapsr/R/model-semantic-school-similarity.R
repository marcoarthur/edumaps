# R/model/semantic/school_similarity_model.R
#
# Modelo semântico para análise de similaridade entre escolas.
#
# Diferentemente de `school_indicator_model`, em que uma observação
# representa um único valor de indicador (ou duas dimensões para scatter),
# aqui uma observação representa uma entidade e um conjunto de features
# que descrevem essa entidade.
#
# A análise de similaridade recebe exclusivamente este modelo semântico.
# Ela não conhece Postgres, nomes de tabelas, SQL ou o formato de entrada
# usado pelo endpoint HTTP.
#
# O modelo é deliberadamente pequeno: seu papel é estabelecer o contrato
# entre DataSource e Analysis. Novas análises que precisem de entidades
# multidimensionais podem reutilizar este modelo sem acoplar-se à fonte
# dos dados.

#' Constrói um `SchoolSimilarityModel`
#'
#' Cria o modelo semântico usado pelas análises de similaridade entre
#' escolas. Cada linha de `data` representa uma entidade e `features`
#' identifica as colunas que descrevem essa entidade.
#'
#' @param data `data.frame` com uma linha por entidade.
#' @param entity_id nome da coluna que identifica unicamente a entidade.
#' @param features vetor de nomes das colunas usadas como características
#'   para o cálculo da similaridade. Quando `NULL`, todas as colunas,
#'   exceto `entity_id`, são usadas.
#' @param metadata lista opcional de metadados sobre o dataset.
#'
#' @return Objeto S3 da classe `school_similarity_model`.
#'
#' @export
new_school_similarity_model <- function(
  data,
  entity_id = "school_id",
  features = NULL,
  metadata = list()
) {
  if (!is.data.frame(data)) {
    stop("data deve ser um data.frame")
  }

  if (!(entity_id %in% names(data))) {
    stop(sprintf("Coluna de entidade não encontrada: %s", entity_id))
  }

  if (is.null(features)) {
    features <- setdiff(names(data), entity_id)
  }

  missing <- setdiff(features, names(data))

  if (length(missing) > 0) {
    stop(sprintf(
      "Features não encontradas: %s",
      paste(missing, collapse = ", ")
    ))
  }

  data <- as.data.frame(data)

  for (feature in features) {
    if (is.character(data[[feature]]) ||
        is.logical(data[[feature]])) {
      data[[feature]] <- factor(data[[feature]])
    }
  }

  structure(
    list(
      data = data,
      entity_id = entity_id,
      features = features,
      metadata = metadata
    ),
    class = "school_similarity_model"
  )
}

#' Retorna os dados do modelo de similaridade
#'
#' @param model objeto da classe `school_similarity_model`.
#'
#' @return `data.frame` contendo as entidades e suas features.
#'
#' @export
similarity_data <- function(model) UseMethod("similarity_data")

#' @export
similarity_data.school_similarity_model <- function(model) {
  model$data
}

#' Retorna os identificadores das entidades
#'
#' @param model objeto da classe `school_similarity_model`.
#'
#' @return Vetor contendo um identificador por entidade.
#'
#' @export
similarity_entity_ids <- function(model) UseMethod("similarity_entity_ids")

#' @export
similarity_entity_ids.school_similarity_model <- function(model) {
  model$data[[model$entity_id]]
}

#' Retorna as features usadas pela análise
#'
#' @param model objeto da classe `school_similarity_model`.
#'
#' @return Vetor de nomes de colunas.
#'
#' @export
similarity_features <- function(model) UseMethod("similarity_features")

#' @export
similarity_features.school_similarity_model <- function(model) {
  model$features
}

#' Retorna o número de entidades do modelo
#'
#' @param model objeto da classe `school_similarity_model`.
#'
#' @return Inteiro com o número de entidades.
#'
#' @export
similarity_sample_size <- function(model) UseMethod("similarity_sample_size")

#' @export
similarity_sample_size.school_similarity_model <- function(model) {
  nrow(model$data)
}
