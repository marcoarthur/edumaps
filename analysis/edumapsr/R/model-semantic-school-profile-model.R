# R/model/semantic/school_profile_model.R
#
# Modelo semântico para o "Perfil da Escola" (issue #105).
#
# Uma observação do `data` é UM INDICADOR (linha longa) com os valores da
# escola, dos comparativos (município, rede, Brasil) e da distribuição do
# cluster a que a escola pertence. Quem monta os blocos (escola,
# agregados, cluster, peers) é o DataSource — que conhece Postgres; a
# análise pura (`R/analysis-school-profile.R`) só reorganiza e classifica
# (quartis, posição relativa, sinais de atenção), nunca faz I/O.
#
# Blocos do modelo:
#
#   data       - data.frame longo, 1 linha por indicador:
#                indicador, escola, municipio, rede, brasil,
#                cluster (mediana do cluster), cluster_p25, cluster_p50,
#                cluster_p75, cluster_media, cluster_n
#   peers      - data.frame com as escolas similares (já filtradas e
#                ordenadas por similaridade desc): co_entidade,
#                no_entidade, similarity, ideb_observado
#   flags_meta - data.frame com os templates de sinais de atenção
#                (indicador, codigo, severidade, mensagem); a análise
#                preenche o campo `atencao` com base nos quartis
#   metadata   - co_entidade, no_entidade, co_municipio, no_municipio,
#                sg_uf, nu_ano_censo, cluster_id, cluster_label,
#                cluster_source, cluster_scope, cluster_size, peers_source

#' Constrói um `SchoolProfileModel`
#'
#' Cria o modelo semântico usado pela análise `school_profile`.
#' Cada linha de `data` representa um indicador (formato longo), com os
#' valores da escola, dos comparativos (município/rede/Brasil) e da
#' distribuição do cluster da escola.
#'
#' @param data `data.frame` longo, uma linha por indicador, contendo ao
#'   menos: `indicador`, `escola`, `municipio`, `rede`, `brasil`,
#'   `cluster`, `cluster_p25`, `cluster_p50`, `cluster_p75`,
#'   `cluster_media` e `cluster_n`.
#' @param peers `data.frame` (pode ser vazio) com as escolas similares:
#'   `co_entidade`, `no_entidade`, `similarity` e `ideb_observado`.
#' @param flags_meta `data.frame` com os templates de sinais de atenção:
#'   `indicador`, `codigo`, `severidade` e `mensagem`.
#' @param metadata lista com os metadados do perfil (co_entidade,
#'   no_entidade, co_municipio, no_municipio, sg_uf, nu_ano_censo,
#'   cluster_id, cluster_label, cluster_source, cluster_scope,
#'   cluster_size, peers_source, etc.).
#'
#' @return Objeto S3 da classe `school_profile_model`.
#'
#' @export
new_school_profile_model <- function(
  data,
  peers = data.frame(),
  flags_meta = data.frame(),
  metadata = list()
) {
  if (!is.data.frame(data)) {
    stop("data deve ser um data.frame")
  }

  required_cols <- c(
    "indicador", "escola", "municipio", "rede", "brasil",
    "cluster", "cluster_p25", "cluster_p50", "cluster_p75",
    "cluster_media", "cluster_n"
  )
  missing <- setdiff(required_cols, names(data))
  if (length(missing) > 0) {
    stop(sprintf("Colunas obrigatórias ausentes no data: %s", paste(missing, collapse = ", ")))
  }

  if (!is.data.frame(peers)) {
    stop("peers deve ser um data.frame")
  }
  if (!is.data.frame(flags_meta)) {
    stop("flags_meta deve ser um data.frame")
  }

  structure(
    list(
      data = data,
      peers = peers,
      flags_meta = flags_meta,
      metadata = metadata
    ),
    class = "school_profile_model"
  )
}

#' Retorna os indicadores do perfil (formato longo)
#'
#' @param model objeto da classe `school_profile_model`.
#'
#' @return `data.frame` longo, uma linha por indicador.
#'
#' @export
profile_indicators <- function(model) UseMethod("profile_indicators")

#' @export
profile_indicators.school_profile_model <- function(model) {
  model$data
}

#' Retorna as escolas similares do perfil
#'
#' @param model objeto da classe `school_profile_model`.
#'
#' @return `data.frame` com `co_entidade`, `no_entidade`, `similarity` e
#'   `ideb_observado` (pode ser vazio quando não há semelhantes).
#'
#' @export
profile_peers <- function(model) UseMethod("profile_peers")

#' @export
profile_peers.school_profile_model <- function(model) {
  model$peers
}

#' Retorna o bloco de cluster do perfil
#'
#' @param model objeto da classe `school_profile_model`.
#'
#' @return Lista com `cluster_id`, `cluster_label`, `cluster_source`,
#'   `cluster_scope` e `cluster_size`.
#'
#' @export
profile_cluster <- function(model) UseMethod("profile_cluster")

#' @export
profile_cluster.school_profile_model <- function(model) {
  m <- model$metadata
  list(
    cluster_id = m$cluster_id,
    cluster_label = m$cluster_label,
    cluster_source = m$cluster_source,
    cluster_scope = m$cluster_scope,
    cluster_size = m$cluster_size
  )
}

#' Retorna os metadados de identificação da escola
#'
#' @param model objeto da classe `school_profile_model`.
#'
#' @return Lista com `co_entidade`, `no_entidade`, `co_municipio`,
#'   `no_municipio`, `sg_uf` e `nu_ano_censo`.
#'
#' @export
profile_school_info <- function(model) UseMethod("profile_school_info")

#' @export
profile_school_info.school_profile_model <- function(model) {
  m <- model$metadata
  list(
    co_entidade = m$co_entidade,
    no_entidade = m$no_entidade,
    co_municipio = m$co_municipio,
    no_municipio = m$no_municipio,
    sg_uf = m$sg_uf,
    nu_ano_censo = m$nu_ano_censo
  )
}

#' Retorna os templates de sinais de atenção
#'
#' @param model objeto da classe `school_profile_model`.
#'
#' @return `data.frame` com `indicador`, `codigo`, `severidade` e
#'   `mensagem`; a análise preenche `atencao`.
#'
#' @export
profile_flags <- function(model) UseMethod("profile_flags")

#' @export
profile_flags.school_profile_model <- function(model) {
  model$flags_meta
}