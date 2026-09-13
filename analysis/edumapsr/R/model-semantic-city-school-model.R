# R/model/semantic/city_school_model.R
#
# Modelo semântico para análise de uma cidade (município).
#
# Uma observação representa uma escola do município, com agregados de
# matrículas e docentes por nível de ensino. É o modelo usado pelas
# análises de resumo de cidade (full_summary — e, futuramente,
# score_distributions e school_clusters por cidade).
#
# Segue o mesmo padrão dos demais modelos: a análise recebe apenas os
# accessors deste objeto e nunca vê SQL/Postgres.

#' Constrói um `CitySchoolModel`
#'
#' Cria o modelo semântico das escolas de um município.
#'
#' @param data `data.frame` com uma linha por escola, contendo ao menos:
#'   `co_entidade`, `no_entidade`, `tp_dependencia`, `tp_localizacao`,
#'   `qt_mat_bas`, `qt_mat_inf`, `qt_mat_fund`, `qt_mat_med`, `qt_doc_bas`,
#'   `dependencia`, `localizacao` e `ratio_aluno_docente`.
#' @param codigo_ibge código IBGE do município (7 dígitos).
#' @param metadata lista opcional de metadados (schema, censo, etc.).
#'
#' @return Objeto S3 da classe `city_school_model`.
#'
#' @export
new_city_school_model <- function(
  data,
  codigo_ibge,
  metadata = list()
) {
  if (!is.data.frame(data)) {
    stop("data deve ser um data.frame")
  }

  if (is.null(codigo_ibge) || nchar(as.character(codigo_ibge)) == 0) {
    stop("codigo_ibge é obrigatório")
  }

  structure(
    list(
      data = data,
      codigo_ibge = codigo_ibge,
      metadata = metadata
    ),
    class = "city_school_model"
  )
}

#' Retorna os dados do modelo de cidade
#'
#' @param model objeto da classe `city_school_model`.
#'
#' @return `data.frame` com uma linha por escola.
#'
#' @export
city_school_data <- function(model) UseMethod("city_school_data")

#' @export
city_school_data.city_school_model <- function(model) {
  model$data
}

#' Retorna o código IBGE do município
#'
#' @param model objeto da classe `city_school_model`.
#'
#' @return Código IBGE (caracter).
#'
#' @export
city_codigo_ibge <- function(model) UseMethod("city_codigo_ibge")

#' @export
city_codigo_ibge.city_school_model <- function(model) {
  model$codigo_ibge
}

#' Retorna o número de escolas do município
#'
#' @param model objeto da classe `city_school_model`.
#'
#' @return Inteiro com o número de escolas.
#'
#' @export
city_sample_size <- function(model) UseMethod("city_sample_size")

#' @export
city_sample_size.city_school_model <- function(model) {
  nrow(model$data)
}