# R/model/semantic/school_evolution_model.R
#
# Modelo semântico da EVOLUÇÃO da escola (issue #110, roadmap do #105).
#
# Uma linha de `data` é uma observação de série histórica:
#
#   indicador (id canônico), label (PT-BR), ano, etapa (NA p/ SAEB), valor
#
# Fontes: `clean.ideb_notas_escolas` (IDEB por ano/etapa) e
# `clean.inep_notas_desagregadas` (notas SAEB por ano). A análise pura só
# reorganiza e resume; quem lê o banco é o DataSource.

EVOLUTION_LABELS <- c(
  ideb_observado  = "IDEB observado",
  saeb_media      = "Nota média (SAEB)",
  saeb_matematica = "Matemática (SAEB)",
  saeb_portugues  = "Português (SAEB)"
)

#' Constrói um `SchoolEvolutionModel`
#'
#' @param data `data.frame` longo com `indicador`, `label`, `ano`,
#'   `etapa` e `valor`.
#' @param metadata lista com a identificação da escola (`co_entidade`,
#'   `no_entidade`, `co_municipio`, `no_municipio`, `sg_uf`, `rede`).
#'
#' @return Objeto S3 da classe `school_evolution_model`.
#'
#' @export
new_school_evolution_model <- function(data, metadata = list()) {
  if (!is.data.frame(data)) {
    stop("data deve ser um data.frame")
  }

  required <- c("indicador", "label", "ano", "etapa", "valor")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    stop(sprintf("Colunas obrigatórias ausentes: %s", paste(missing, collapse = ", ")))
  }

  structure(
    list(data = data, metadata = metadata),
    class = "school_evolution_model"
  )
}

#' Retorna a série histórica (formato longo)
#'
#' @param model objeto da classe `school_evolution_model`.
#'
#' @return `data.frame` com uma linha por (indicador, ano, etapa).
#'
#' @export
evolution_data <- function(model) UseMethod("evolution_data")

#' @export
evolution_data.school_evolution_model <- function(model) {
  model$data
}

#' Retorna a identificação da escola da série
#'
#' @param model objeto da classe `school_evolution_model`.
#'
#' @return Lista com `co_entidade`, `no_entidade`, `co_municipio`,
#'   `no_municipio`, `sg_uf` e `rede`.
#'
#' @export
evolution_school_info <- function(model) UseMethod("evolution_school_info")

#' @export
evolution_school_info.school_evolution_model <- function(model) {
  m <- model$metadata
  list(
    co_entidade = m$co_entidade,
    no_entidade = m$no_entidade,
    co_municipio = m$co_municipio,
    no_municipio = m$no_municipio,
    sg_uf = m$sg_uf,
    rede = m$rede
  )
}