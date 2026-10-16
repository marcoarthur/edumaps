# R/ivet-socioeconomico.R
#
# Extração do bloco **B — socioeconômico** do IVET (#137, entregável 3).
#
# A geometria/extração (a arealização dos setores do Censo 2022 sobre a área de
# influência da escola) vive no banco: tabela
# `clean.escola_entorno_socioeconomico`, populada por
# `clean.refresh_escola_entorno_socioeconomico()` (change
# `escola_entorno_socioeconomico`). Aqui fica só a **metade determinística**: o
# mapeamento componente bruto → dimensão B, sem banco.
#
# Direção: o IVET mede **vulnerabilidade** — em toda esta camada, quanto MAIOR
# o valor, mais vulnerável o território. Os componentes são orientados para essa
# direção:
#
#   componente             bruto (tabela)        normalização              direção
#   ---------------------  --------------------  ------------------------  --------------
#   renda                  renda_per_capita      1 − clamp(x/teto)         renda baixa = +
#   sem_instrucao           pct_sem_instrucao     proporção                 mais sem estudo = +
#   fund_incomp             pct_fund_incomp       proporção                 mais incompleto = +
#   preto_pardo             pct_preto_pardo       proporção (equidade)      mais negra/parda = +
#
# Vazio ≠ zero (#154): componente `NA` (setor suprimido / sem dado) é **excluído**
# da média (não entra como 0). Se **todos** faltarem, a dimensão é `NA` (não
# calculada), nunca 0. É por isso que a dimensão usa `ivet_agregar()` (que tira a
# ausente do denominador) e **não** `ivet_dimensao()` (§4.1, onde NA→0 vale para
# o bloco escolar, onde "não tem o recurso" é de facto 0).
#
# `componentes` por omissão = renda, instrução e fundamental incompleto. A
# proporção preto/pardo é **calculada e exposta**, mas fica fora da dimensão por
# omissão: usá-la como componente de vulnerabilidade é uma decisão de **equidade**
# que exige justificativa registada e sobe a versão da fórmula (§4.3).

# Teto de renda documentado (R$ per capita/mês) acima do qual **não há
# vulnerabilidade de renda** (componente = 0). Default = 2 salários mínimos de
# jul/2022 (Censo 2022) = 2 × 1.212 = 2.424. É um parâmetro de produto: mudá-lo
# exige registo e nova versão da fórmula (§4.3).
IVET_TETO_RENDA <- 2 * 1212

#' Componente de renda → vulnerabilidade de renda em `[0,1]` (maior = pior).
#'
#' `renda` é o rendimento per capita (R$/mês); normaliza-se pelo teto
#' `teto_renda` e **inverte-se** (renda baixa = vulnerabilidade alta). Vazio/NA
#' devolve `NA` (nunca 0 — #154).
#'
#' @param renda valor(es) de renda per capita.
#' @param teto teto documentado (> 0) acima do qual o componente é 0.
#' @return numérico em `[0,1]`, ou `NA` se `renda` for vazio/não-numérico.
#' @export
ivet_componente_renda <- function(renda, teto = IVET_TETO_RENDA) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_renda: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(renda))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  1 - pmin(pmax(x / teto, 0), 1)
}

#' Componente de proporção → vulnerabilidade em `[0,1]` (maior = pior).
#'
#' `clamp(0,1)`. Vazio/NA devolve `NA` (nunca 0 — #154).
#'
#' @param x proporção bruta.
#' @return numérico em `[0,1]`, ou `NA` se `x` for vazio/não-numérico.
#' @export
ivet_componente_proporcao <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(x, 0), 1)
}

#' Componentes do bloco B em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' @param renda renda per capita (R$/mês) — `clean.escola_entorno_socioeconomico.renda_per_capita`.
#' @param pct_sem_instrucao proporção de 25+ sem instrução.
#' @param pct_fund_incomp proporção de 25+ com fundamental incompleto.
#' @param pct_preto_pardo proporção de população preta/parda (equidade).
#' @param teto_renda teto documentado de renda (ver `ivet_componente_renda`).
#' @return vetor nomeado `renda`, `sem_instrucao`, `fund_incomp`, `preto_pardo`.
#' @export
ivet_bloco_socioeconomico_componentes <- function(
    renda = NULL,
    pct_sem_instrucao = NULL,
    pct_fund_incomp = NULL,
    pct_preto_pardo = NULL,
    teto_renda = IVET_TETO_RENDA) {
  c(
    renda         = ivet_componente_renda(renda, teto = teto_renda),
    sem_instrucao = ivet_componente_proporcao(pct_sem_instrucao),
    fund_incomp   = ivet_componente_proporcao(pct_fund_incomp),
    preto_pardo   = ivet_componente_proporcao(pct_preto_pardo)
  )
}

#' Dimensão **B (socioeconômico)** do IVET a partir dos componentes arealizados.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Sem nenhum componente disponível devolve `NA` (dimensão não
#' calculada), nunca 0.
#'
#' @param renda,pct_sem_instrucao,pct_fund_incomp,pct_preto_pardo componentes
#'   brutos (ver `ivet_bloco_socioeconomico_componentes`); `NULL`/`NA` = ausente.
#' @param teto_renda teto de renda documentado (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão, renda,
#'   instrução e fundamental incompleto — ver o cabeçalho do ficheiro).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_socioeconomico <- function(renda = NULL, pct_sem_instrucao = NULL,
                                      pct_fund_incomp = NULL, pct_preto_pardo = NULL,
                                      teto_renda = IVET_TETO_RENDA,
                                      componentes = c("renda", "sem_instrucao",
                                                      "fund_incomp")) {
  comps <- ivet_bloco_socioeconomico_componentes(
    renda            = renda,
    pct_sem_instrucao = pct_sem_instrucao,
    pct_fund_incomp   = pct_fund_incomp,
    pct_preto_pardo   = pct_preto_pardo,
    teto_renda        = teto_renda
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_socioeconomico: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
