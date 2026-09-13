# R/model/semantic/school_cluster_model.R
#
# Modelo semântico para análise de clusterização de escolas.
#
# Uma observação representa uma entidade (escola/município) e `features`
# identifica as colunas numéricas que descrevem essa entidade. A análise
# de cluster recebe exclusivamente este modelo semântico — ela não
# conhece Postgres, nomes de tabelas ou o formato de entrada HTTP.
#
# Segue o mesmo contrato do `school_similarity_model` (uma entidade por
# linha), mas restrito a features numéricas, que são o que os algoritmos
# de cluster (kmeans/dbscan/gmm/spectral) exigem.

#' Constrói um `SchoolClusterModel`
#'
#' Cria o modelo semântico usado pelas análises de clusterização.
#' Cada linha de `data` representa uma entidade e `features` identifica
#' as colunas numéricas que descrevem essa entidade.
#'
#' @param data `data.frame` com uma linha por entidade.
#' @param entity_id nome da coluna que identifica unicamente a entidade.
#' @param features vetor de nomes de colunas numéricas usadas como
#'   características do cluster. Quando `NULL`, todas as colunas
#'   numéricas, exceto `entity_id`, são usadas.
#' @param metadata lista opcional de metadados (schema, tabela, etc.).
#'
#' @return Objeto S3 da classe `school_cluster_model`.
#'
#' @export
new_school_cluster_model <- function(
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

  column_types <- vapply(data, function(col) {
    is.numeric(col)
  }, logical(1))

  numeric_features <- names(column_types)[column_types]

  if (is.null(features)) {
    features <- setdiff(numeric_features, entity_id)
  }

  missing <- setdiff(features, names(data))

  if (length(missing) > 0) {
    stop(sprintf(
      "Features não encontradas: %s",
      paste(missing, collapse = ", ")
    ))
  }

  not_numeric <- features[!vapply(
    data[features],
    is.numeric,
    logical(1)
  )]

  if (length(not_numeric) > 0) {
    stop(sprintf(
      "Features devem ser numéricas: %s",
      paste(not_numeric, collapse = ", ")
    ))
  }

  structure(
    list(
      data = data,
      entity_id = entity_id,
      features = features,
      metadata = metadata
    ),
    class = "school_cluster_model"
  )
}

#' Retorna os dados do modelo de cluster
#'
#' @param model objeto da classe `school_cluster_model`.
#'
#' @return `data.frame` contendo as entidades e suas features.
#'
#' @export
cluster_data <- function(model) UseMethod("cluster_data")

#' @export
cluster_data.school_cluster_model <- function(model) {
  model$data
}

#' Retorna os identificadores das entidades
#'
#' @param model objeto da classe `school_cluster_model`.
#'
#' @return Vetor com um identificador por entidade.
#'
#' @export
cluster_entity_ids <- function(model) UseMethod("cluster_entity_ids")

#' @export
cluster_entity_ids.school_cluster_model <- function(model) {
  model$data[[model$entity_id]]
}

#' Retorna as features usadas pela análise
#'
#' @param model objeto da classe `school_cluster_model`.
#'
#' @return Vetor de nomes de colunas.
#'
#' @export
cluster_features <- function(model) UseMethod("cluster_features")

#' @export
cluster_features.school_cluster_model <- function(model) {
  model$features
}

#' Retorna o número de entidades do modelo
#'
#' @param model objeto da classe `school_cluster_model`.
#'
#' @return Inteiro com o número de entidades.
#'
#' @export
cluster_sample_size <- function(model) UseMethod("cluster_sample_size")

#' @export
cluster_sample_size.school_cluster_model <- function(model) {
  nrow(model$data)
}