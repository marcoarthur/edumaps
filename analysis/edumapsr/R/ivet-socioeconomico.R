# R/ivet-socioeconomico.R
#
# Extração do bloco **B — socioeconômico** do IVET (#137, entregável 3).
#
# A geometria/extração (a arealização dos setores do Censo 2022 sobre a área de
# influência da escola) vive no banco: tabela
# `clean.escola_entorno_socioeconomico`, populada por
# `clean.refresh_escola_entorno_socioeconomico()` (changes
# `escola_entorno_socioeconomico` e `escola_entorno_socioeconomico_saneamento`).
# Aqui fica só a **metade determinística**: o mapeamento componente bruto →
# dimensão B, sem banco.
#
# Direção: o IVET mede **vulnerabilidade** — em toda esta camada, quanto MAIOR
# o valor, mais vulnerável o território. Os componentes são orientados para essa
# direção:
#
#   componente        bruto (tabela)            normalização          direção
#   ----------------  ------------------------  --------------------  --------------
#   analfabetismo     pct_analfabeto            proporção             mais analfabeto = +
#   agua_sem_rede     pct_agua_sem_rede         proporção             menos rede = +
#   esgoto_inadequado pct_esgoto_inadequado     proporção             mais inadequado = +
#   lixo_inadequado   pct_lixo_inadequado       proporção             mais inadequado = +
#   sem_banheiro      pct_sem_banheiro          proporção             mais sem banheiro = +
#   saneamento        (média dos 4 acima)       agregação             pior saneamento = +
#   renda             renda_per_capita          1 − clamp(x/teto)     renda baixa = +
#   sem_instrucao     pct_sem_instrucao         proporção             mais sem estudo = +
#   fund_incomp       pct_fund_incomp            proporção             mais incompleto = +
#   preto_pardo       pct_preto_pardo            proporção (equidade)  mais negra/parda = +
#
# **Default do bloco B (fórmula ivet-v1.1)**: `componentes =
# c("analfabetismo", "saneamento")` — instrução + saneamento, a fonte que o
# Censo 2022 por setor efetivamente publica. `renda`, `sem_instrucao` e
# `fund_incomp` **saíram do default**: o Censo 2022 por setor não publica renda
# nem escolaridade 25+ (#238; ver docs/analises/fontes/socioeconomico.md), mas
# os componentes continuam calculados para outra fonte (ex.: renda municipal).
# `preto_pardo` continua fora por omissão (equidade, §4.3).
#
# Vazio ≠ zero (#154): componente `NA` (setor suprimido / sem dado) é **excluído**
# da média (não entra como 0). Se **todos** faltarem, a dimensão é `NA` (não
# calculada), nunca 0. É por isso que a dimensão usa `ivet_agregar()` (que tira a
# ausente do denominador) e **não** `ivet_dimensao()` (§4.1, onde NA→0 vale para
# o bloco escolar).

# Teto de renda documentado (R$ per capita/mês) acima do qual **não há
# vulnerabilidade de renda** (componente = 0). Default = 2 salários mínimos de
# jul/2022 (Censo 2022) = 2 × 1.212 = 2.424. É um parâmetro de produto: mudá-lo
# exige registo e nova versão da fórmula (§4.3).
IVET_TETO_RENDA <- 2 * 1212

# Componentes do sub-bloco **saneamento** (média via `ivet_agregar`, NA fora).
IVET_SANEAMENTO_COMPONENTES <- c("agua_sem_rede", "esgoto_inadequado",
                                 "lixo_inadequado", "sem_banheiro")

# Default do bloco B na fórmula ivet-v1.1 (§4.3): instrução + saneamento.
IVET_BLOCO_B_COMPONENTES <- c("analfabetismo", "saneamento")

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
#' As proporções vêm da arealização (`clean.escola_entorno_socioeconomico`):
#' `pct_analfabeto`, `pct_agua_sem_rede`, `pct_esgoto_inadequado`,
#' `pct_lixo_inadequado`, `pct_sem_banheiro`. O componente `saneamento` é a
#' **média dos quatro** sub-indicadores disponíveis (`ivet_agregar`, `NA` fora —
#' #154): mede o domicílio, não o serviço isolado.
#'
#' Os componentes `renda`, `sem_instrucao` e `fund_incomp` são calculados para
#' quando houver fonte (o Censo 2022 por setor não tem — #238); `preto_pardo` é
#' calculado para a leitura de equidade (§4.3).
#'
#' @param pct_analfabeto proporção de 15+ que não sabe ler/escrever.
#' @param pct_agua_sem_rede proporção de DPPO sem rede geral de água.
#' @param pct_esgoto_inadequado proporção de DPPO com esgoto inadequado.
#' @param pct_lixo_inadequado proporção de DPPO com lixo inadequado.
#' @param pct_sem_banheiro proporção de DPPO sem banheiro de uso exclusivo.
#' @param renda renda per capita (R$/mês) — sem fonte por setor no Censo 2022.
#' @param pct_sem_instrucao proporção de 25+ sem instrução — sem fonte por setor.
#' @param pct_fund_incomp proporção de 25+ com fundamental incompleto — sem fonte.
#' @param pct_preto_pardo proporção de população preta/parda (equidade).
#' @param teto_renda teto documentado de renda (ver `ivet_componente_renda`).
#' @return vetor nomeado, na ordem `analfabetismo`, `renda`, `sem_instrucao`,
#'   `fund_incomp`, `agua_sem_rede`, `esgoto_inadequado`, `lixo_inadequado`,
#'   `sem_banheiro`, `saneamento`, `preto_pardo`.
#' @export
ivet_bloco_socioeconomico_componentes <- function(
    pct_analfabeto = NULL,
    pct_agua_sem_rede = NULL,
    pct_esgoto_inadequado = NULL,
    pct_lixo_inadequado = NULL,
    pct_sem_banheiro = NULL,
    renda = NULL,
    pct_sem_instrucao = NULL,
    pct_fund_incomp = NULL,
    pct_preto_pardo = NULL,
    teto_renda = IVET_TETO_RENDA) {
  agua   <- ivet_componente_proporcao(pct_agua_sem_rede)
  esgoto <- ivet_componente_proporcao(pct_esgoto_inadequado)
  lixo   <- ivet_componente_proporcao(pct_lixo_inadequado)
  banheiro <- ivet_componente_proporcao(pct_sem_banheiro)

  c(
    analfabetismo     = ivet_componente_proporcao(pct_analfabeto),
    renda             = ivet_componente_renda(renda, teto = teto_renda),
    sem_instrucao     = ivet_componente_proporcao(pct_sem_instrucao),
    fund_incomp       = ivet_componente_proporcao(pct_fund_incomp),
    agua_sem_rede     = agua,
    esgoto_inadequado = esgoto,
    lixo_inadequado   = lixo,
    sem_banheiro      = banheiro,
    saneamento        = ivet_agregar(c(agua, esgoto, lixo, banheiro)),
    preto_pardo       = ivet_componente_proporcao(pct_preto_pardo)
  )
}

#' Dimensão **B (socioeconômico)** do IVET a partir dos componentes arealizados.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Sem nenhum componente disponível devolve `NA` (dimensão não
#' calculada), nunca 0.
#'
#' @param pct_analfabeto,pct_agua_sem_rede,pct_esgoto_inadequado,pct_lixo_inadequado,pct_sem_banheiro
#'   proporções brutas (ver `ivet_bloco_socioeconomico_componentes`).
#' @param renda,pct_sem_instrucao,pct_fund_incomp,pct_preto_pardo componentes
#'   brutos de outra fonte (sem fonte por setor no Censo 2022 — #238).
#' @param teto_renda teto de renda documentado (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão,
#'   instrução + saneamento: `c("analfabetismo", "saneamento")` — ver o cabeçalho
#'   do ficheiro).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_socioeconomico <- function(
    pct_analfabeto = NULL,
    pct_agua_sem_rede = NULL,
    pct_esgoto_inadequado = NULL,
    pct_lixo_inadequado = NULL,
    pct_sem_banheiro = NULL,
    renda = NULL, pct_sem_instrucao = NULL, pct_fund_incomp = NULL,
    pct_preto_pardo = NULL,
    teto_renda = IVET_TETO_RENDA,
    componentes = IVET_BLOCO_B_COMPONENTES) {
  comps <- ivet_bloco_socioeconomico_componentes(
    pct_analfabeto         = pct_analfabeto,
    pct_agua_sem_rede      = pct_agua_sem_rede,
    pct_esgoto_inadequado  = pct_esgoto_inadequado,
    pct_lixo_inadequado    = pct_lixo_inadequado,
    pct_sem_banheiro       = pct_sem_banheiro,
    renda                  = renda,
    pct_sem_instrucao      = pct_sem_instrucao,
    pct_fund_incomp        = pct_fund_incomp,
    pct_preto_pardo        = pct_preto_pardo,
    teto_renda             = teto_renda
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_socioeconomico: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
