# R/ivet-seguranca.R
#
# Extração do bloco **E — segurança** do IVET (#137, entregável 3; fatia E/G).
#
# Fonte: `clean.brazilcrime_municipio` (SINESP, via pacote R BrazilCrime; #126).
# Grão município × ano, com **supressão de célula pequena** (valores 1..4 são
# ocultados pela fonte — `supressao_celula_pequena`). A escola é o **ponto de
# observação**; o município onde ela está entra como o território observado (§1).
#
# Direção: o IVET mede **vulnerabilidade** (quanto maior, pior). O componente é a
# **taxa por 100 mil habitantes** do evento, normalizada por um teto documentado
# (§4.1: contagem nunca entra crua — o defeito do `iqd` é uma contagem crua):
#
#   componente                      bruto (tabela)                normalização
#   ------------------------------  ----------------------------  ----------------
#   homicidio_doloso                homicidio_doloso (contagem)   clamp(taxa/50)
#   latrocinio                      latrocinio (contagem)         clamp(taxa/5)
#   lesao_corporal_seguida_de_morte lesao_..._morte (contagem)    clamp(taxa/5)
#
#   taxa = contagem / populacao * 1e5            (ivet_taxa_100k)
#
# Vazio ≠ zero (#154): a célula suprimida (contagem 1..4, ocultada) **não é 0** —
# é ausência, e vira componente `NA`, ficando FORA do denominador da dimensão. Uma
# contagem `0` publicada pela fonte é **0 real** (nenhum crime registrado), e isso
# é o que mantém "sem crime" distinto de "número ocultado" (#154). Na tabela, a
# supressão já vem codificada como `NULL` na coluna de contagem; `ivet_taxa_100k()`
# também aceita `suprimido = TRUE` para explicitar a regra quando o chamador tem o
# sinal por célula.
#
# Denominador populacional: as taxas usam a população do município. A população
# **por ano** não existe hoje no banco (`clean.v_ibge_municipio_ano.populacao` está
# 100% `NULL`); a extração usa `clean.populacao_municipal` (snapshot) como
# denominador, documentado — ver §4.5.1 da doc.

# Tetos das taxas por 100 mil habitantes. São **parâmetros de produto** (como o
# teto de renda do bloco B): mudá-los exige registro e nova versão da fórmula.
# Calibração (dev, `database.edumaps`, média municipal 2021–2023): homicídio
# doloso p90 ≈ 46/100k (p99 ≈ 103) -> teto 50 satura o topo ~10%; latrocínio e
# lesão seguida de morte são eventos raros (p90 = 0, máx ≈ 27 e ≈ 93) -> teto 5
# satura só o extremo.
IVET_TETO_HOMICIDIO_DOLOSO <- 50
IVET_TETO_LATROCINIO <- 5
IVET_TETO_LESAO_CORPORAL_SEGUIDA_DE_MORTE <- 5

# Default do bloco E: os três eventos violentos letais disponíveis na fonte.
IVET_BLOCO_E_COMPONENTES <- c(
  "homicidio_doloso", "latrocinio", "lesao_corporal_seguida_de_morte"
)

#' Taxa de um evento por 100 mil habitantes (contagem / população × 1e5).
#'
#' `NA` quando a contagem ou a população é vazia/não-numérica, quando a população
#' não é positiva, ou quando `suprimido = TRUE` (célula ocultada pela fonte — não
#' é 0, é ausência; #154).
#'
#' @param contagem contagem do evento no município-ano (`clean.brazilcrime_municipio`).
#' @param populacao população do município (denominador).
#' @param suprimido `TRUE` se a célula foi suprimida pela fonte (célula 1..4).
#' @return a taxa por 100 mil, ou `NA_real_`.
#' @export
ivet_taxa_100k <- function(contagem, populacao, suprimido = FALSE) {
  if (isTRUE(suprimido)) {
    return(NA_real_)
  }
  n <- suppressWarnings(as.numeric(contagem))
  pop <- suppressWarnings(as.numeric(populacao))
  if (length(n) != 1 || !is.finite(n)) {
    return(NA_real_)
  }
  if (length(pop) != 1 || !is.finite(pop) || pop <= 0) {
    return(NA_real_)
  }
  n / pop * 1e5
}

#' Componente de taxa → vulnerabilidade em `[0,1]` (maior = pior).
#'
#' A taxa deve estar em unidades de **por 100 mil** (`ivet_taxa_100k`). Normaliza
#' por um teto documentado: `clamp(taxa / teto, 0, 1)`. Vazio/`NA` devolve `NA`
#' (nunca 0 — #154).
#'
#' @param taxa taxa por 100 mil.
#' @param teto teto documentado (> 0) em por 100 mil.
#' @return numérico em `[0,1]`, ou `NA` se `taxa` for vazia/não-numérica.
#' @export
ivet_componente_taxa <- function(taxa, teto) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_taxa: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(taxa))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(x / teto, 0), 1)
}

#' Componente de crime a partir da contagem e da população.
#'
#' Atalho bruto → componente: `ivet_componente_taxa(ivet_taxa_100k(...), teto)`.
#' Célula suprimida (`suprimido = TRUE`) ou sem contagem/população vira `NA`
#' (nunca 0 — #154).
#'
#' @param contagem contagem do evento no município-ano.
#' @param populacao população do município (denominador).
#' @param teto teto documentado da taxa por 100 mil (> 0).
#' @param suprimido `TRUE` se a célula foi suprimida pela fonte (célula 1..4).
#' @return numérico em `[0,1]`, ou `NA`.
#' @export
ivet_componente_crime <- function(contagem, populacao, teto, suprimido = FALSE) {
  ivet_componente_taxa(ivet_taxa_100k(contagem, populacao, suprimido), teto)
}

#' Componentes do bloco E em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe as três contagens de `clean.brazilcrime_municipio` e a população do
#' município; devolve a taxa por 100 mil normalizada pelo teto de cada evento.
#' Célula suprimida (`NULL`/`NA` na contagem) vira `NA` (#154): fica fora do
#' denominador da dimensão, não penaliza o território por falta de dado.
#'
#' @param homicidio_doloso contagem de homicídios dolosos no município-ano.
#' @param latrocinio contagem de roubos seguidos de morte no município-ano.
#' @param lesao_corporal_seguida_de_morte contagem de lesões seguidas de morte.
#' @param populacao população do município (denominador das taxas).
#' @param teto_homicidio_doloso,teto_latrocinio,teto_lesao_corporal_seguida_de_morte
#'   tetos das taxas por 100 mil (ver as constantes `IVET_TETO_*`).
#' @return vetor nomeado, na ordem `homicidio_doloso`, `latrocinio`,
#'   `lesao_corporal_seguida_de_morte`.
#' @export
ivet_bloco_seguranca_componentes <- function(
    homicidio_doloso = NULL,
    latrocinio = NULL,
    lesao_corporal_seguida_de_morte = NULL,
    populacao = NULL,
    teto_homicidio_doloso = IVET_TETO_HOMICIDIO_DOLOSO,
    teto_latrocinio = IVET_TETO_LATROCINIO,
    teto_lesao_corporal_seguida_de_morte = IVET_TETO_LESAO_CORPORAL_SEGUIDA_DE_MORTE) {
  c(
    homicidio_doloso = ivet_componente_crime(
      homicidio_doloso, populacao, teto_homicidio_doloso
    ),
    latrocinio = ivet_componente_crime(
      latrocinio, populacao, teto_latrocinio
    ),
    lesao_corporal_seguida_de_morte = ivet_componente_crime(
      lesao_corporal_seguida_de_morte, populacao,
      teto_lesao_corporal_seguida_de_morte
    )
  )
}

#' Dimensão **E (segurança)** do IVET a partir das contagens municipais.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Sem nenhum componente disponível devolve `NA` (dimensão não
#' calculada), nunca 0.
#'
#' @param homicidio_doloso,latrocinio,lesao_corporal_seguida_de_morte contagens
#'   do município-ano (`clean.brazilcrime_municipio`).
#' @param populacao população do município (denominador das taxas).
#' @param teto_homicidio_doloso,teto_latrocinio,teto_lesao_corporal_seguida_de_morte
#'   tetos das taxas por 100 mil (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão, os três).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_seguranca <- function(
    homicidio_doloso = NULL,
    latrocinio = NULL,
    lesao_corporal_seguida_de_morte = NULL,
    populacao = NULL,
    teto_homicidio_doloso = IVET_TETO_HOMICIDIO_DOLOSO,
    teto_latrocinio = IVET_TETO_LATROCINIO,
    teto_lesao_corporal_seguida_de_morte = IVET_TETO_LESAO_CORPORAL_SEGUIDA_DE_MORTE,
    componentes = IVET_BLOCO_E_COMPONENTES) {
  comps <- ivet_bloco_seguranca_componentes(
    homicidio_doloso = homicidio_doloso,
    latrocinio = latrocinio,
    lesao_corporal_seguida_de_morte = lesao_corporal_seguida_de_morte,
    populacao = populacao,
    teto_homicidio_doloso = teto_homicidio_doloso,
    teto_latrocinio = teto_latrocinio,
    teto_lesao_corporal_seguida_de_morte = teto_lesao_corporal_seguida_de_morte
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_seguranca: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
