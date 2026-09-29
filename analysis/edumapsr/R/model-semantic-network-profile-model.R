# R/model/semantic/network_profile_model.R
#
# Modelo semântico do PERFIL DA REDE (issue #109, roadmap do #105).
#
# Blocos:
#   clusters    - data.frame longo, uma linha por (cluster, indicador):
#                 cluster_id, cluster_label, n, indicador, label, media
#   indicadores - data.frame, uma linha por indicador:
#                 indicador, label, rede, brasil, variacao
#   metadata    - codigo_ibge, no_municipio, sg_uf, tp_dependencia,
#                 nu_ano_censo, n_escolas, n_clusters, n_brasil

#' Constrói um `NetworkProfileModel`
#'
#' @param clusters `data.frame` longo (`cluster_id`, `cluster_label`, `n`,
#'   `indicador`, `label`, `media`).
#' @param indicadores `data.frame` (`indicador`, `label`, `rede`, `brasil`,
#'   `variacao`).
#' @param metadata lista de metadados do recorte.
#'
#' @return Objeto S3 da classe `network_profile_model`.
#'
#' @export
new_network_profile_model <- function(clusters, indicadores, metadata = list()) {
  if (!is.data.frame(clusters) || !is.data.frame(indicadores)) {
    stop("clusters e indicadores devem ser data.frames")
  }

  structure(
    list(clusters = clusters, indicadores = indicadores, metadata = metadata),
    class = "network_profile_model"
  )
}

#' Retorna a distribuição da rede por cluster
#'
#' @param model objeto da classe `network_profile_model`.
#'
#' @return `data.frame` longo por (cluster, indicador).
#'
#' @export
network_clusters <- function(model) UseMethod("network_clusters")

#' @export
network_clusters.network_profile_model <- function(model) {
  model$clusters
}

#' Retorna os indicadores da rede vs. Brasil
#'
#' @param model objeto da classe `network_profile_model`.
#'
#' @return `data.frame` por indicador.
#'
#' @export
network_indicators <- function(model) UseMethod("network_indicators")

#' @export
network_indicators.network_profile_model <- function(model) {
  model$indicadores
}

#' Retorna a identificação do recorte da rede
#'
#' @param model objeto da classe `network_profile_model`.
#'
#' @return Lista com `codigo_ibge`, `no_municipio`, `sg_uf`,
#'   `tp_dependencia` e `nu_ano_censo`.
#'
#' @export
network_school_info <- function(model) UseMethod("network_school_info")

#' @export
network_school_info.network_profile_model <- function(model) {
  m <- model$metadata
  list(
    codigo_ibge = m$codigo_ibge,
    no_municipio = m$no_municipio,
    sg_uf = m$sg_uf,
    tp_dependencia = m$tp_dependencia,
    nu_ano_censo = m$nu_ano_censo
  )
}