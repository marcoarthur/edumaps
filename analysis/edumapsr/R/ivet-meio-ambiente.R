# R/ivet-meio-ambiente.R
#
# Extração do bloco **F — meio ambiente** do IVET (#137, entregável 3; #278).
#
# O bloco tem duas metades já extraídas:
#   - **cobertura do solo** (#255): `clean.v_mapbiomas_escola_grupos.fracao`,
#     grupo `vegetacao_natural` — raster MapBiomas Coleção 11 (ano 2024);
#   - **exposição a risco** (#278): `clean.mapbiomas_escola_risco`
#     (`fogo_frequencia_media`, `solo_carbono_medio`) — MapBiomas Fogo
#     (1985–2020) e Carbono Orgânico do Solo.
#
# Direção: o IVET mede **vulnerabilidade** (maior = pior). O **fogo** entra
# DIRETO; a **vegetação natural** e o **carbono do solo** entram INVERTIDOS
# (mais = melhor, como a renda do bloco B):
#
#   componente         bruto (tabela)                               normalização
#   -----------------  -------------------------------------------  --------------------
#   risco_fogo         mapbiomas_escola_risco.fogo_frequencia_media clamp(freq / teto)
#   vegetacao_natural  v_mapbiomas_escola_grupos.fracao (grupo)     1 - clamp(fracao)
#   carbono_solo       mapbiomas_escola_risco.solo_carbono_medio    1 - clamp(c / teto)
#
# Vazio ≠ zero (#154): sem o dado, o componente é `NA` e fica FORA do
# denominador da dimensão — nunca 0.
#
# ✅ TETOS CALIBRADOS (p99 nacional). A corrida nacional do F (#278) fechou em
# 2026-10-19: `clean.mapbiomas_escola_risco` cobre **156.816 escolas** (censo
# 2025, raio 1000 m, ano 2020), **pendentes = 0**. Tetos = **p99** da amostra:
#   fogo   p50 = 0,006 · p90 = 0,320 · p99 = 2,463   · máx 16,345
#   carbono p50 = 233,6 · p90 = 485,7 · p99 = 705,98  · máx 2.833,8 tC/ha
# (690 linhas com carbono < 0 — artefato de nodata — saturam no pior caso;
# follow-up em aberto.) Ver ivet-coeficientes.md §5.
#
# ⚠️ COBERTURA DESIGUAL. A cobertura do solo (#255) hoje só cobre o **ES**
# (2.967 escolas, ano 2024) e a exposição a risco (#278) cobre o **país**
# (156.816 escolas, ano 2020); as duas metades não coexistem escola a escola.
# Como cada componente ausente cai fora (#154), o bloco degrada para fogo+solo
# onde a vegetação não existe.

# Tetos CALIBRADOS (p99 nacional, ver acima). Parâmetros de produto.
IVET_TETO_FOGO <- 2.463
IVET_TETO_CARBONO_SOLO <- 705.98

# Default do bloco F: as duas metades extraídas (fogo + vegetação + solo).
IVET_BLOCO_F_COMPONENTES <- c("risco_fogo", "vegetacao_natural", "carbono_solo")

#' Componente de risco de fogo no entorno da escola (maior = pior).
#'
#' A frequência média de fogo do MapBiomas (1985–2020) mede "mais = pior" e
#' entra **direta**: `clamp(freq / teto, 0, 1)`. `NA`/vazio devolve `NA`
#' (nunca 0 — #154).
#'
#' @param fogo_frequencia_media frequência média de fogo
#'   (`clean.mapbiomas_escola_risco.fogo_frequencia_media`, MapBiomas Fogo).
#' @param teto teto documentado (> 0, p99 nacional) em frequência de fogo
#'   (default `IVET_TETO_FOGO`).
#' @return numérico em `[0,1]`, ou `NA_real_`.
#' @export
ivet_componente_risco_fogo <- function(
    fogo_frequencia_media,
    teto = IVET_TETO_FOGO) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_risco_fogo: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(fogo_frequencia_media))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(x / teto, 0), 1)
}

#' Componente de vegetação natural no entorno da escola (maior = melhor).
#'
#' A fração de vegetação natural (MapBiomas Coleção 11) mede "mais = melhor" e
#' é **invertida** para vulnerabilidade: `1 - clamp(fracao, 0, 1)`. `NA`/vazio
#' devolve `NA` (nunca 0 — #154).
#'
#' @param fracao_vegetacao_natural fração da área de influência coberta por
#'   vegetação natural (`clean.v_mapbiomas_escola_grupos.fracao`, grupo
#'   `vegetacao_natural`).
#' @return numérico em `[0,1]`, ou `NA_real_`.
#' @export
ivet_componente_vegetacao_natural <- function(fracao_vegetacao_natural) {
  x <- suppressWarnings(as.numeric(fracao_vegetacao_natural))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(1 - x, 0), 1)
}

#' Componente de carbono orgânico do solo no entorno da escola (maior = melhor).
#'
#' O carbono médio do solo (MapBiomas, tC/ha) mede "mais = melhor" e é
#' **invertido**: `1 - clamp(carbono / teto, 0, 1)`. `NA`/vazio devolve `NA`
#' (nunca 0 — #154).
#'
#' ⚠️ O carbono do solo varia naturalmente por bioma; o valor bruto negativo
#' (artefato de nodata) satura em 1 (follow-up em aberto).
#'
#' @param solo_carbono_medio carbono orgânico médio do solo em tC/ha
#'   (`clean.mapbiomas_escola_risco.solo_carbono_medio`).
#' @param teto teto documentado (> 0, p99 nacional) em tC/ha
#'   (default `IVET_TETO_CARBONO_SOLO`).
#' @return numérico em `[0,1]`, ou `NA_real_`.
#' @export
ivet_componente_carbono_solo <- function(
    solo_carbono_medio,
    teto = IVET_TETO_CARBONO_SOLO) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_carbono_solo: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(solo_carbono_medio))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(1 - x / teto, 0), 1)
}

#' Componentes do bloco F em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os indicadores das duas fontes do F e devolve os três componentes na
#' ordem `risco_fogo`, `vegetacao_natural`, `carbono_solo`. Vazio/`NA` vira
#' `NA` (#154): fica fora do denominador da dimensão.
#'
#' @param fogo_frequencia_media frequência média de fogo (MapBiomas Fogo).
#' @param fracao_vegetacao_natural fração de vegetação natural (MapBiomas
#'   Coleção 11).
#' @param solo_carbono_medio carbono orgânico médio do solo (tC/ha).
#' @param teto_fogo,teto_carbono_solo tetos documentados (> 0, p99 nacional).
#' @return vetor nomeado com os três componentes.
#' @export
ivet_bloco_meio_ambiente_componentes <- function(
    fogo_frequencia_media = NULL,
    fracao_vegetacao_natural = NULL,
    solo_carbono_medio = NULL,
    teto_fogo = IVET_TETO_FOGO,
    teto_carbono_solo = IVET_TETO_CARBONO_SOLO) {
  c(
    risco_fogo = ivet_componente_risco_fogo(fogo_frequencia_media, teto_fogo),
    vegetacao_natural = ivet_componente_vegetacao_natural(fracao_vegetacao_natural),
    carbono_solo = ivet_componente_carbono_solo(solo_carbono_medio, teto_carbono_solo)
  )
}

#' Dimensão **F (meio ambiente)** do IVET.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Sem nenhum componente disponível devolve `NA` (dimensão não
#' calculada), nunca 0.
#'
#' @param fogo_frequencia_media,fracao_vegetacao_natural,solo_carbono_medio
#'   indicadores das fontes do bloco F.
#' @param teto_fogo,teto_carbono_solo tetos documentados (> 0, p99 nacional).
#' @param componentes quais componentes entram na dimensão (por omissão,
#'   `IVET_BLOCO_F_COMPONENTES`).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_meio_ambiente <- function(
    fogo_frequencia_media = NULL,
    fracao_vegetacao_natural = NULL,
    solo_carbono_medio = NULL,
    teto_fogo = IVET_TETO_FOGO,
    teto_carbono_solo = IVET_TETO_CARBONO_SOLO,
    componentes = IVET_BLOCO_F_COMPONENTES) {
  comps <- ivet_bloco_meio_ambiente_componentes(
    fogo_frequencia_media = fogo_frequencia_media,
    fracao_vegetacao_natural = fracao_vegetacao_natural,
    solo_carbono_medio = solo_carbono_medio,
    teto_fogo = teto_fogo,
    teto_carbono_solo = teto_carbono_solo
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    return(NA_real_)
  }
  ivet_agregar(comps[selecionados])
}
