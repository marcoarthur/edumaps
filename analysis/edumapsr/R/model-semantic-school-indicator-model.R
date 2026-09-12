# R/model/semantic/school_indicator_model.R
#
# Modelo semântico central desta primeira fatia da camada analítica:
# "um conjunto de valores de UM indicador de escola, com opcionalmente um
# segundo indicador pareado (scatter) e/ou uma dimensão categórica de
# agrupamento (boxplot)". A partir daqui, uma análise nunca vê
# "id_escola", "rede", "analytics.ranking_escola" — só os accessors
# abaixo.
#
# É deliberadamente mais estreito que o "CitySchoolModel" do documento de
# arquitetura (que cobriria escolas/matrículas/docentes de um município
# inteiro) — esta é a fatia que a feature de gráficos precisa hoje. Novos
# modelos semânticos (CitySchoolModel, EnrollmentModel, ...) entram como
# novos arquivos em R/model/semantic/ conforme as próximas análises
# (city_summary, clusters, spatial, inequality) forem migradas pra este
# mesmo padrão — não construí todos de uma vez porque só temos dados/
# consumidores reais pra este aqui até agora.

#' Constrói um SchoolIndicatorModel
#'
#' @param data data.frame com colunas entre: `value`, `x_value`, `y_value`, `group`
#' @param metadata lista com rótulos: `value_label`, `x_label`, `y_label`, `group_label`
#' @export
new_school_indicator_model <- function(data, metadata = list()) {
  structure(list(data = data, metadata = metadata), class = "school_indicator_model")
}

#' @export
values <- function(model) UseMethod("values")
#' @export
values.school_indicator_model <- function(model) model$data$value

#' @export
values_x <- function(model) UseMethod("values_x")
#' @export
values_x.school_indicator_model <- function(model) model$data$x_value

#' @export
values_y <- function(model) UseMethod("values_y")
#' @export
values_y.school_indicator_model <- function(model) model$data$y_value

#' @export
groups <- function(model) UseMethod("groups")
#' @export
groups.school_indicator_model <- function(model) model$data$group

#' @export
sample_size <- function(model) UseMethod("sample_size")
#' @export
sample_size.school_indicator_model <- function(model) nrow(model$data)

#' Rótulo humano de um eixo/dimensão do modelo, com fallback sensato.
#'
#' @param which um de "value", "x", "y", "group"
#' @export
indicator_label <- function(model, which = c("value", "x", "y", "group")) {
  which <- match.arg(which)
  key <- switch(which,
    value = "value_label",
    x = "x_label",
    y = "y_label",
    group = "group_label"
  )
  default <- switch(which, value = "Valor", x = "X", y = "Y", group = "Grupo")
  # %||% vem de R/utils.R
  model$metadata[[key]] %||% default
}
