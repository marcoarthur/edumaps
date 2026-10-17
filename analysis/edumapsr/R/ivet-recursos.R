# R/ivet-recursos.R
#
# Extração do bloco **G — recursos** do IVET (#137, entregável 3; fatia E/G).
#
# Fonte: `analytics.esforco_fiscal_educacao` (SIOPE/SICONFI, catálogo #123),
# grão município × exercício. A escola é o **ponto de observação**; o município
# onde ela está entra como o território observado (§1).
#
# Direção: o IVET mede **vulnerabilidade** (quanto maior, pior). Os indicadores de
# recurso medem **quanto MAIOR, MELHOR** (mais investimento, mais autonomia), logo
# o componente é **invertido** (`1 − clamp(valor/teto)`, como a renda do bloco B):
#
#   componente                 bruto (tabela)                     normalização
#   -------------------------  --------------------------------  --------------------
#   fundeb_por_aluno           fundeb_por_aluno (R$/aluno)        1 − clamp(x/10000)
#   despesa_educ_por_aluno     despesa_educ_por_aluno (R$/aluno)  1 − clamp(x/15000)
#   autonomia_fiscal_pct       autonomia_fiscal_pct (%)           1 − clamp(x/50)
#
# `pct_receita_em_educ` **não é usado**: está corrompido na tabela (valores fora
# de `[0,100]` — achado da medição no dev a 2026-10-17).
#
# Vazio ≠ zero (#154): valor `NULL`/`NA` (município sem dado fiscal) vira
# componente `NA`, fora do denominador da dimensão — nunca 0.

# Tetos dos indicadores de recurso. São **parâmetros de produto** (como o teto de
# renda do bloco B): mudá-los exige registro e nova versão da fórmula.
# Calibração (dev, `database.edumaps`, exercício 2025/2026): fundeb/aluno p90 ≈
# R$ 9.336 (máx ≈ 16.370) -> teto 10.000; despesa educ/aluno p90 ≈ R$ 14.521
# (máx ≈ 50.710) -> teto 15.000; autonomia fiscal p90 ≈ 30,9% (máx 100) -> teto
# 50% (satura o topo ~5%).
IVET_TETO_FUNDEB_POR_ALUNO <- 10000
IVET_TETO_DESPESA_EDUC_POR_ALUNO <- 15000
IVET_TETO_AUTONOMIA_FISCAL_PCT <- 50

# Default do bloco G: os três indicadores usáveis da tabela.
IVET_BLOCO_G_COMPONENTES <- c(
  "fundeb_por_aluno", "despesa_educ_por_aluno", "autonomia_fiscal_pct"
)

#' Componente de recurso → vulnerabilidade em `[0,1]` (maior = pior).
#'
#' Indicadores de recurso medem "quanto maior, melhor"; o componente é invertido
#' (`1 − clamp(valor / teto, 0, 1)`). `NA` devolve `NA` (nunca 0 — #154).
#'
#' @param valor valor do indicador (R$/aluno, ou %).
#' @param teto teto documentado (> 0) acima do qual o componente é 0.
#' @return numérico em `[0,1]`, ou `NA` se `valor` for vazio/não-numérico.
#' @export
ivet_componente_investimento <- function(valor, teto) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_investimento: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(valor))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  1 - pmin(pmax(x / teto, 0), 1)
}

#' Componentes do bloco G em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os três indicadores de `analytics.esforco_fiscal_educacao` e devolve os
#' componentes já invertidos para a direção do IVET. `NULL`/`NA` vira `NA`
#' (#154). `pct_receita_em_educ` não é usado (corrompido na fonte).
#'
#' @param fundeb_por_aluno receita do FUNDEB por aluno (R$/aluno/ano).
#' @param despesa_educ_por_aluno despesa em educação por aluno (R$/aluno/ano).
#' @param autonomia_fiscal_pct autonomia fiscal do município (%).
#' @param teto_fundeb_por_aluno,teto_despesa_educ_por_aluno,teto_autonomia_fiscal_pct
#'   tetos documentados (ver as constantes `IVET_TETO_*`).
#' @return vetor nomeado, na ordem `fundeb_por_aluno`, `despesa_educ_por_aluno`,
#'   `autonomia_fiscal_pct`.
#' @export
ivet_bloco_recursos_componentes <- function(
    fundeb_por_aluno = NULL,
    despesa_educ_por_aluno = NULL,
    autonomia_fiscal_pct = NULL,
    teto_fundeb_por_aluno = IVET_TETO_FUNDEB_POR_ALUNO,
    teto_despesa_educ_por_aluno = IVET_TETO_DESPESA_EDUC_POR_ALUNO,
    teto_autonomia_fiscal_pct = IVET_TETO_AUTONOMIA_FISCAL_PCT) {
  c(
    fundeb_por_aluno = ivet_componente_investimento(
      fundeb_por_aluno, teto_fundeb_por_aluno
    ),
    despesa_educ_por_aluno = ivet_componente_investimento(
      despesa_educ_por_aluno, teto_despesa_educ_por_aluno
    ),
    autonomia_fiscal_pct = ivet_componente_investimento(
      autonomia_fiscal_pct, teto_autonomia_fiscal_pct
    )
  )
}

#' Dimensão **G (recursos)** do IVET a partir dos indicadores fiscais municipais.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Sem nenhum componente disponível devolve `NA` (dimensão não
#' calculada), nunca 0.
#'
#' @param fundeb_por_aluno,despesa_educ_por_aluno,autonomia_fiscal_pct
#'   indicadores de `analytics.esforco_fiscal_educacao`.
#' @param teto_fundeb_por_aluno,teto_despesa_educ_por_aluno,teto_autonomia_fiscal_pct
#'   tetos documentados (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão, os três).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_recursos <- function(
    fundeb_por_aluno = NULL,
    despesa_educ_por_aluno = NULL,
    autonomia_fiscal_pct = NULL,
    teto_fundeb_por_aluno = IVET_TETO_FUNDEB_POR_ALUNO,
    teto_despesa_educ_por_aluno = IVET_TETO_DESPESA_EDUC_POR_ALUNO,
    teto_autonomia_fiscal_pct = IVET_TETO_AUTONOMIA_FISCAL_PCT,
    componentes = IVET_BLOCO_G_COMPONENTES) {
  comps <- ivet_bloco_recursos_componentes(
    fundeb_por_aluno = fundeb_por_aluno,
    despesa_educ_por_aluno = despesa_educ_por_aluno,
    autonomia_fiscal_pct = autonomia_fiscal_pct,
    teto_fundeb_por_aluno = teto_fundeb_por_aluno,
    teto_despesa_educ_por_aluno = teto_despesa_educ_por_aluno,
    teto_autonomia_fiscal_pct = teto_autonomia_fiscal_pct
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_recursos: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
