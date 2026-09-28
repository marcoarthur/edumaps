# R/analysis/school_profile.R
#
# Análise pura do "Perfil da Escola" (issue #105).
#
# Contrato:
#
#   school_profile_model
#            ↓
#   analyze_school_profile()
#            ↓
#      analysis_result
#
# Recebe TUDO do modelo semântico (DataSource): valores da escola, dos
# comparativos (município/rede/Brasil) e a distribuição do cluster a que
# a escola pertence. Não faz I/O e não conhece SQL — apenas classifica a
# posição relativa, monta as tabelas do payload e os sinais de atenção.
#
# Regra dos sinais de atenção (v1, fiel ao issue): um indicador vira
# `atencao = TRUE` quando a escola está no QUARTIL INFERIOR
# (`quartil_no_cluster == 1`) do seu cluster. O campo `cluster` das
# comparações é a MEDIANA do indicador no cluster (benchmark robusto);
# `cluster_resumo` carrega p25/p50/p75 + média + tamanho.

#' Classifica em qual quartil do cluster o valor da escola cai
#'
#' @param value valor da escola (pode ser `NA`).
#' @param p25,p50,p75 quartis do cluster (podem ser `NA`).
#'
#' @return Vetor inteiro (1..4) ou `NA` quando não há como classificar.
#'
#' @keywords internal
.profile_quartile <- function(value, p25, p50, p75) {
  n <- length(value)
  out <- rep(NA_integer_, n)

  for (i in seq_len(n)) {
    v <- value[i]
    if (is.na(v)) next

    if (is.na(p25[i])) next

    if (v <= p25[i]) {
      out[i] <- 1L
    } else if (is.na(p50[i]) || v <= p50[i]) {
      out[i] <- 2L
    } else if (is.na(p75[i]) || v <= p75[i]) {
      out[i] <- 3L
    } else {
      out[i] <- 4L
    }
  }

  out
}

#' Monta o perfil analítico de uma escola
#'
#' @param model objeto da classe `school_profile_model`.
#' @param parameters lista de parâmetros da execução (preservada no
#'   `analysis_result`).
#'
#' @return Objeto da classe `analysis_result`, com as tabelas
#'   `indicadores_comparados`, `cluster_resumo`, `peers` e `flags`.
#'
#' @export
analyze_school_profile <- function(model, parameters = list()) {
  if (!inherits(model, "school_profile_model")) {
    stop_invalid_parameter("analyze_school_profile requer um school_profile_model")
  }

  indicators <- profile_indicators(model)
  peers <- profile_peers(model)
  flags_meta <- profile_flags(model)
  cluster <- profile_cluster(model)

  quartil <- .profile_quartile(
    indicators$escola,
    indicators$cluster_p25,
    indicators$cluster_p50,
    indicators$cluster_p75
  )
  atencao <- !is.na(quartil) & quartil == 1L

  labels <- unname(PROFILE_LABELS[indicators$indicador])

  comparados <- data.frame(
    indicador = indicators$indicador,
    label = labels,
    escola = indicators$escola,
    municipio = indicators$municipio,
    rede = indicators$rede,
    brasil = indicators$brasil,
    cluster = indicators$cluster,
    quartil_no_cluster = quartil,
    atencao = atencao,
    stringsAsFactors = FALSE
  )

  cluster_resumo <- data.frame(
    indicador = indicators$indicador,
    label = labels,
    media = indicators$cluster_media,
    p25 = indicators$cluster_p25,
    p50 = indicators$cluster_p50,
    p75 = indicators$cluster_p75,
    n = indicators$cluster_n,
    stringsAsFactors = FALSE
  )

  flags <- flags_meta[flags_meta$indicador %in% indicators$indicador[atencao], , drop = FALSE]
  flags <- flags[match(indicators$indicador[atencao], flags$indicador), , drop = FALSE]
  flags$escola <- indicators$escola[match(flags$indicador, indicators$indicador)]
  flags$quartil_no_cluster <- quartil[match(flags$indicador, indicators$indicador)]
  flags <- flags[, c("indicador", "codigo", "severidade", "mensagem", "escola", "quartil_no_cluster"), drop = FALSE]
  rownames(flags) <- NULL

  metrics <- list(
    cluster_size = cluster$cluster_size,
    n_indicadores = nrow(indicators),
    n_peers = nrow(peers),
    n_flags = nrow(flags),
    total_escolas_municipio = model$metadata$n_municipio,
    total_escolas_rede = model$metadata$n_rede,
    total_escolas_brasil = model$metadata$n_brasil
  )

  new_analysis_result(
    analysis = "school_profile",
    parameters = parameters,
    data = data.frame(),
    metrics = metrics,
    tables = list(
      indicadores_comparados = comparados,
      cluster_resumo = cluster_resumo,
      peers = peers,
      flags = flags
    ),
    metadata = model$metadata
  )
}