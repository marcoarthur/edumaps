# R/ivet-mobilidade.R
#
# Extração do bloco **C — acesso/mobilidade** do IVET (#137, entregável 3).
#
# Fonte: `analytics.mobilidade_escola` (view por escola, uma linha por escola) e
# `clean.populacao_municipal` como denominador das taxas. O grão do bloco é o
# **município da escola** (a escola é o ponto de observação; §1).
#
# ⚠️ PROXY (decisão de produto, 2026-10-18). A dimensão central de C é o
# **acesso** — isócrona / distância-tempo —, e `clean.isocrona_escolar` está
# **vazia**: depende de um motor de roteamento (OSRM/Valhalla) que não existe em
# nenhum host. Enquanto isso, C é lido como **exposição viária** — o que a fonte
# de facto entrega: os sinistros de trânsito do RENAEST (município) e a frota do
# RENAVAM. Quando a isócrona existir, entra como componente (mesmo bloco).
#
# Direção: o IVET mede **vulnerabilidade** (maior = pior). Os dois componentes
# entram **diretos** (mais sinistros / mais frota por habitante = mais exposição):
#
#   componente        bruto (tabela)                     normalização
#   ----------------  ---------------------------------  ----------------------
#   risco_sinistros   sinistros_12m (RENAEST)            clamp(taxa100k/500)
#   exposicao_frota   renavam_total_frota (RENAVM)       clamp(frota_hab/1)
#
#   taxa100k   = sinistros_12m / populacao * 1e5   (ivet_taxa_100k)
#   frota_hab  = renavam_total_frota / populacao
#
# Vazio ≠ zero (#154): sem o dado, o componente é `NA` e fica FORA do
# denominador da dimensão — nunca 0. `sinistros_fatais_12m` está **0 em todas as
# 5.533 escolas-município do dev** (RENAEST), logo NÃO entra como componente
# (constante); se a fonte passar a publicar fatais, vira componente novo.

# Tetos das taxas. São **parâmetros de produto** (como os do bloco D): mudá-los
# exige registro e nova versão da fórmula. Calibração (dev, `database.edumaps`,
# 2026-10-18, por município): sinistros por 100 mil hab p50 ≈ 60, p90 ≈ 429,
# p99 ≈ 988 -> teto 500 satura o topo ~10%; frota por habitante p90 ≈ 0,89 ->
# teto 1 satura ~p90.
IVET_TETO_SINISTROS_100K <- 500
IVET_TETO_FROTA_POR_HAB <- 1

# Default do bloco C: os dois componentes que a fonte entrega.
IVET_BLOCO_C_COMPONENTES <- c("risco_sinistros", "exposicao_frota")

#' Componente de risco de sinistros viários no município (maior = pior).
#'
#' A taxa de sinistros por 100 mil habitantes mede "mais = pior" e entra
#' **direta**: `clamp(taxa / teto, 0, 1)`. `NA`/vazio devolve `NA` (nunca 0 —
#' #154). Grão municipal (a escola observa o território do seu município).
#'
#' @param sinistros_12m sinistros de trânsito em 12 meses
#'   (`analytics.mobilidade_escola.sinistros_12m`, RENAEST).
#' @param populacao população do município (denominador).
#' @param teto teto documentado (> 0) em sinistros por 100 mil
#'   (default `IVET_TETO_SINISTROS_100K`).
#' @return numérico em `[0,1]`, ou `NA_real_` se a taxa não puder ser calculada.
#' @export
ivet_componente_risco_sinistros <- function(
    sinistros_12m,
    populacao,
    teto = IVET_TETO_SINISTROS_100K) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_risco_sinistros: 'teto' precisa ser > 0")
  }
  taxa <- ivet_taxa_100k(sinistros_12m, populacao)
  if (length(taxa) != 1 || !is.finite(taxa)) {
    return(NA_real_)
  }
  pmin(pmax(taxa / teto, 0), 1)
}

#' Componente de exposição da frota (maior = pior).
#'
#' A frota por habitante mede a **exposição** viária do território e entra
#' **direta**: `clamp((frota / populacao) / teto, 0, 1)`. `NA`/vazio devolve
#' `NA` (nunca 0 — #154). É um proxy de densidade de tráfego, não de acesso.
#'
#' @param renavam_total_frota frota total do município
#'   (`analytics.mobilidade_escola.renavam_total_frota`, RENAVAM).
#' @param populacao população do município (denominador).
#' @param teto teto documentado (> 0) em veículos por habitante
#'   (default `IVET_TETO_FROTA_POR_HAB`).
#' @return numérico em `[0,1]`, ou `NA_real_`.
#' @export
ivet_componente_exposicao_frota <- function(
    renavam_total_frota,
    populacao,
    teto = IVET_TETO_FROTA_POR_HAB) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_exposicao_frota: 'teto' precisa ser > 0")
  }
  frota <- suppressWarnings(as.numeric(renavam_total_frota))
  pop <- suppressWarnings(as.numeric(populacao))
  if (length(frota) != 1 || !is.finite(frota)) {
    return(NA_real_)
  }
  if (length(pop) != 1 || !is.finite(pop) || pop <= 0) {
    return(NA_real_)
  }
  pmin(pmax((frota / pop) / teto, 0), 1)
}

#' Componentes do bloco C em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os indicadores de `analytics.mobilidade_escola` e a população do
#' município; devolve os dois componentes na ordem `risco_sinistros`,
#' `exposicao_frota`. Vazio/`NA` vira `NA` (#154): fica fora do denominador da
#' dimensão, não penaliza o território por falta de dado.
#'
#' @param sinistros_12m sinistros de trânsito em 12 meses (RENAEST).
#' @param renavam_total_frota frota total do município (RENAVAM).
#' @param populacao população do município (denominador).
#' @param teto_sinistros_100k,teto_frota_por_hab tetos documentados (> 0).
#' @return vetor nomeado com os dois componentes.
#' @export
ivet_bloco_mobilidade_componentes <- function(
    sinistros_12m = NULL,
    renavam_total_frota = NULL,
    populacao = NULL,
    teto_sinistros_100k = IVET_TETO_SINISTROS_100K,
    teto_frota_por_hab = IVET_TETO_FROTA_POR_HAB) {
  c(
    risco_sinistros = ivet_componente_risco_sinistros(
      sinistros_12m, populacao, teto_sinistros_100k
    ),
    exposicao_frota = ivet_componente_exposicao_frota(
      renavam_total_frota, populacao, teto_frota_por_hab
    )
  )
}

#' Dimensão **C (acesso/mobilidade)** do IVET — proxy de exposição viária.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. ⚠️ Enquanto a isócrona não existir, o bloco é um **proxy de
#' exposição viária** (sinistros RENAEST + frota RENAVAM), não de acesso. Sem
#' nenhum componente disponível devolve `NA` (dimensão não calculada), nunca 0.
#'
#' @param sinistros_12m,renavam_total_frota,populacao indicadores de
#'   `analytics.mobilidade_escola` e a população do município.
#' @param teto_sinistros_100k,teto_frota_por_hab tetos documentados (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão,
#'   `IVET_BLOCO_C_COMPONENTES`).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_mobilidade <- function(
    sinistros_12m = NULL,
    renavam_total_frota = NULL,
    populacao = NULL,
    teto_sinistros_100k = IVET_TETO_SINISTROS_100K,
    teto_frota_por_hab = IVET_TETO_FROTA_POR_HAB,
    componentes = IVET_BLOCO_C_COMPONENTES) {
  comps <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = sinistros_12m,
    renavam_total_frota = renavam_total_frota,
    populacao = populacao,
    teto_sinistros_100k = teto_sinistros_100k,
    teto_frota_por_hab = teto_frota_por_hab
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    return(NA_real_)
  }
  ivet_agregar(comps[selecionados])
}
