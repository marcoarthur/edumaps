# R/model/datasource/memory_similarity_source.R
#
# DataSource em memória para a análise de similaridade.
#
# É o equivalente especializado do `memory_source` existente para o
# domínio de indicadores. Mantemos os dois separados porque os contratos
# semânticos são diferentes:
#
#   memory_source
#       -> school_indicator_model
#
#   memory_similarity_source
#       -> school_similarity_model
#
# Isso evita transformar uma única fonte genérica em um objeto que precisa
# conhecer todos os formatos de dataset existentes no pacote.

#' Carrega um `SchoolSimilarityModel` a partir de uma fonte
#'
#' Generic S3 para carregar o modelo semântico de similaridade.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros específicos da implementação da fonte.
#'
#' @return Objeto da classe `school_similarity_model`.
#'
#' @export
load_school_similarity <- function(source, ...) {
  UseMethod("load_school_similarity")
}

#' Cria uma fonte de dados de similaridade em memória
#'
#' @param rows `data.frame`, ou objeto coercível para `data.frame`, contendo
#'   uma linha por entidade.
#' @param entity_id nome da coluna que identifica a entidade.
#' @param features vetor de nomes das features usadas na similaridade.
#' @param metadata lista opcional de metadados.
#'
#' @return Objeto S3 da classe `memory_similarity_source`.
#'
#' @export
memory_similarity_source <- function(
  rows,
  entity_id = "school_id",
  features = NULL,
  metadata = list()
) {
  structure(
    list(
      rows = rows,
      entity_id = entity_id,
      features = features,
      metadata = metadata
    ),
    class = c("memory_similarity_source", "data_source")
  )
}

#' Carrega um `SchoolSimilarityModel` a partir da memória
#'
#' Implementação de `load_school_similarity()` para
#' `memory_similarity_source`.
#'
#' @param source objeto da classe `memory_similarity_source`.
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `school_similarity_model`.
#'
#' @export
load_school_similarity.memory_similarity_source <- function(
  source,
  ...
) {
  new_school_similarity_model(
    data = as.data.frame(source$rows),
    entity_id = source$entity_id,
    features = source$features,
    metadata = source$metadata
  )
}
