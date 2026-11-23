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
# Regra dos sinais de atenção (v2, #421): um indicador vira
# `atencao = TRUE` quando a escola está no quartil do LADO RUIM do seu
# cluster (inferior se "quanto maior, melhor"; superior se "quanto menor,
# melhor", ver `PROFILE_DIRECAO`) e estritamente pior que a mediana. O
# `quartil_no_cluster` continua sendo a posição do valor (1 = menores). O campo `cluster` das
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

#' Sentido de cada indicador ("maior" ou "menor" é melhor)
#'
#' Indicador fora de `PROFILE_DIRECAO` vale "maior" (regra antiga).
#'
#' @keywords internal
.profile_direcao <- function(indicador) {
  d <- unname(PROFILE_DIRECAO[indicador])
  d[is.na(d)] <- "maior"
  d
}

#' Rótulos dos indicadores com a edição e a etapa do IDEB (#431)
#'
#' IDEB e nota SAEB da escola vêm da edição mais recente e, com mais de uma
#' etapa, da de maior nota (`.profile_pop_body`). O rótulo diz qual:
#' "IDEB observado 2023, anos iniciais". Desde a #483, as médias de
#' comparação (município, rede, Brasil, grupo) são da mesma etapa, por isso
#' a etapa vale para a linha inteira. Sem a etapa no metadata, fica o
#' rótulo simples.
#'
#' @keywords internal
.profile_labels <- function(indicador, metadata = list()) {
  labels <- unname(PROFILE_LABELS[indicador])
  etapa <- metadata$ideb_etapa
  ano <- metadata$ideb_ano
  if (is.null(etapa) || is.null(ano) || is.na(etapa) || is.na(ano)) return(labels)
  etapa_txt <- switch(etapa,
    fundamental_i = "anos iniciais",
    fundamental_ii = "anos finais",
    ensino_medio = "ensino médio",
    etapa
  )
  ideb <- indicador %in% c("ideb_observado", "nota_media")
  labels[ideb] <- sprintf("%s %d, %s", labels[ideb], as.integer(ano), etapa_txt)
  labels
}

#' Sinal de atenção pela regra v2 (#421)
#'
#' Atenção quando a escola está no quartil do lado ruim do cluster
#' (inferior se "maior" é melhor; superior se "menor" é melhor) **e**
#' estritamente pior que a mediana. Sem a segunda condição, escola e
#' cluster empatados (ex.: doutorado 0% com mediana 0%) davam sinal.
#'
#' @param quartil vetor 1..4 (ou `NA`) de `.profile_quartile`.
#' @param value valor da escola.
#' @param p50 mediana do cluster.
#' @param direcao vetor "maior"/"menor".
#'
#' @return Vetor lógico, sem `NA`.
#'
#' @keywords internal
.profile_atencao <- function(quartil, value, p50, direcao) {
  ruim_lado <- ifelse(direcao == "menor", quartil == 4L, quartil == 1L)
  pior_que_mediana <- ifelse(direcao == "menor", value > p50, value < p50)
  out <- ruim_lado & pior_que_mediana
  out[is.na(out)] <- FALSE
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
  direcao <- .profile_direcao(indicators$indicador)
  atencao <- .profile_atencao(quartil, indicators$escola, indicators$cluster_p50, direcao)
  # #493 (RI-02): o INSE é contexto, não sinal.
  atencao[indicators$indicador %in% PROFILE_SEM_SINAL] <- FALSE

  labels <- .profile_labels(indicators$indicador, model$metadata)

  # #527: na escola privada, o indicador só perguntado na pública fica sem
  # comparação (município e Brasil seriam médias só das públicas) e diz o
  # motivo.
  nota <- rep(NA_character_, nrow(indicators))
  if (identical(as.integer(model$metadata$tp_dependencia), 4L)) {
    so_pub <- indicators$indicador %in% names(PROFILE_SO_PUBLICA)
    nota[so_pub] <- unname(PROFILE_SO_PUBLICA[indicators$indicador[so_pub]])
    for (col in c("escola", "municipio", "rede", "brasil", "cluster",
                  "cluster_media", "cluster_p25", "cluster_p50", "cluster_p75")) {
      if (!is.null(indicators[[col]])) indicators[[col]][so_pub] <- NA_real_
    }
    if (!is.null(indicators$cluster_n)) indicators$cluster_n[so_pub] <- 0L
    quartil[so_pub] <- NA_integer_
    atencao[so_pub] <- FALSE
  }

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
    direcao = direcao,
    nota = nota,
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
      flags = flags,
      # #483 (RN-02): o IDEB de cada etapa da escola, com as comparações da
      # mesma etapa. Modelo sem a tabela (fixtures antigas): vazia.
      ideb_por_etapa = if (is.data.frame(model$ideb_por_etapa)) model$ideb_por_etapa else data.frame()
    ),
    metadata = c(model$metadata, list(regra_sinais = PROFILE_REGRA_SINAIS))
  )
}