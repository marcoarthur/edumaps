# R/ivet-saude.R
#
# Extração do bloco **D — saúde** do IVET (#137, entregável 3).
#
# Fonte: `analytics.acessibilidade_saude` (CNES + SISAB/PMMB; ver
# docs/analises/fontes/saude.md e a change `analytics_acessibilidade_saude_ubs`).
# A tabela tem UMA linha por escola, mas o bloco **mistura dois grãos**:
#
#   - `dist_min_km_ubs`          -> ESCOLA (distância esférica à UBS mais próxima)
#   - `n_ubs_municipio`          -> MUNICÍPIO (contagem de UBS ativas)
#   - `ativas_ff`, `equipe_esf`  -> MUNICÍPIO (equipes de atenção básica)
#   - `efetividade_vagas_aps`    -> MUNICÍPIO (ocupação das vagas do PMMB, %)
#   - `categoria_ivs`            -> MUNICÍPIO (categoria social do MS)
#
# Direção: o IVET mede **vulnerabilidade** (maior = pior). A **distância** mede
# "mais = pior" (pior acesso espacial) e entra direta; a **provisão** de atenção
# básica mede "mais = melhor" e é **invertida** (como a renda do bloco B e o
# bloco G):
#
#   componente                    bruto (tabela)                     normalização
#   ----------------------------  --------------------------------  ------------------------
#   distancia_ubs                 dist_min_km_ubs (km)              clamp(dist/teto)
#   cobertura_aps                 (ativas_ff + equipe_esf)/pop     1 - clamp(equipes10k/teto)
#   presenca_ubs (fora default)   n_ubs_municipio                  1 - clamp(ubs10k/teto)
#   efetividade_vagas_aps         efetividade_vagas_aps (%)         1 - clamp(x/teto)
#
#   taxa = contagem / populacao * 1e4            (ivet_taxa_10k)
#
# `cobertura_aps` **não é** a coluna homônima da tabela: apesar do nome, aquela
# coluna carrega a **população coberta do PMMB** (pessoas), que pode passar de
# 100% da população (máx medido 25.421/10k) — inútil como cobertura. Aqui a
# cobertura é a **razão de equipes por 10 mil habitantes**, conforme a ficha de
# saúde (`iv_saude_cobertura_aps`: `(Σ ativas_ff + equipe_esf) ÷ população ×
# 10.000`).
#
# `categoria_ivs` **não é usado**: é uma categoria de vulnerabilidade **social**
# do Ministério da Saúde — duplicaria o bloco B (socioeconômico) e não mede
# acesso a saúde. `presenca_ubs` fica **fora do default** por ser redundante com
# `cobertura_aps` (correlação bruta entre nº de UBS e equipes = 0,78 no dev);
# `efetividade_vagas_aps` fica fora por estar quase saturada (p50 = 98,8%,
# p90 = 100%) e ter direção ambígua.
#
# Vazio ≠ zero (#154): `dist_min_km_ubs` NULL (município sem UBS no CNES) vira
# componente `NA`, fora do denominador. `n_ubs_municipio = 0` é **zero real**
# (município sem UBS) e entra como provisão 0 -> componente 1.
#
# Denominadores: `clean.populacao_municipal` (snapshot), o mesmo do bloco E — a
# população por ano não existe no banco (ver §4.5.1 da doc).

# Tetos do bloco D. São **parâmetros de produto** (como o teto de renda do bloco
# B e os do E/G): mudá-los exige registro e nova versão da fórmula.
# Calibração (dev, `database.edumaps`, 2026-10-17):
#   - distância escola→UBS (escola): p50 = 0,54 km, p90 = 7,25 km, máx = 575 km;
#     teto 5 km é o limiar "acesso difícil (>5km)" da própria view (~13% das
#     escolas saturam).
#   - UBS por 10 mil hab (município): p50 = 4,48, p90 = 8,45 -> teto 8.
#   - equipes de APS por 10 mil hab (município): p50 = 3,30, p90 = 8,39 -> teto 8.
#   - efetividade das vagas do PMMB (%): p10 = 83,3, p50 = 98,8, p90 = 100 -> teto 100.
IVET_TETO_DISTANCIA_UBS_KM <- 5
IVET_TETO_COBERTURA_APS_POR_10K <- 8
IVET_TETO_PRESENCA_UBS_POR_10K <- 8
IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT <- 100

# Default do bloco D: acesso espacial (distância, grão escola) + provisão
# municipal de atenção básica (equipes por 10 mil hab). `presenca_ubs` e
# `efetividade_vagas_aps` ficam disponíveis ao analista, fora do default.
IVET_BLOCO_D_COMPONENTES <- c("distancia_ubs", "cobertura_aps")

#' Taxa de um evento por 10 mil habitantes (contagem / população × 1e4).
#'
#' `NA` quando a contagem ou a população é vazia/não-numérica, ou quando a
#' população não é positiva. Espelha `ivet_taxa_100k()` do bloco E para o
#' denominador de 10 mil usado pela atenção básica.
#'
#' @param contagem contagem no município (`n_ubs_municipio`, `ativas_ff + equipe_esf`).
#' @param populacao população do município (denominador).
#' @return a taxa por 10 mil, ou `NA_real_`.
#' @export
ivet_taxa_10k <- function(contagem, populacao) {
  contagem <- suppressWarnings(as.numeric(contagem))
  populacao <- suppressWarnings(as.numeric(populacao))
  if (length(contagem) != 1 || length(populacao) != 1) {
    return(NA_real_)
  }
  if (!is.finite(contagem) || !is.finite(populacao) || populacao <= 0) {
    return(NA_real_)
  }
  contagem / populacao * 1e4
}

#' Componente de distância escola→UBS em `[0,1]` (maior = mais vulnerável).
#'
#' A distância mede "mais = pior" (acesso espacial), logo entra **direta**:
#' `clamp(dist / teto, 0, 1)`. `NA` devolve `NA` (nunca 0 — #154).
#'
#' @param dist_km distância à UBS mais próxima, em km (`dist_min_km_ubs`).
#' @param teto teto documentado (> 0) em km (default `IVET_TETO_DISTANCIA_UBS_KM`).
#' @return numérico em `[0,1]`, ou `NA` se `dist_km` for vazia/não-numérica.
#' @export
ivet_componente_distancia <- function(dist_km, teto = IVET_TETO_DISTANCIA_UBS_KM) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_distancia: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(dist_km))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  pmin(pmax(x / teto, 0), 1)
}

#' Componente de cobertura de atenção básica por 10 mil hab (maior = pior).
#'
#' A provisão mede "mais = melhor", logo é **invertida**:
#' `1 − clamp(((equipe_esf + ativas_ff) / população × 1e4) / teto)`. `NA`/vazio
#' devolve `NA` (nunca 0 — #154). Não usa a coluna `cobertura_aps` da tabela —
#' apesar do nome, ela é **população** do PMMB (pessoas), não cobertura.
#'
#' @param equipe_esf nº de equipes ESF no município.
#' @param ativas_ff nº de equipes de força de frente ativas no município.
#' @param populacao população do município (denominador).
#' @param teto teto documentado (> 0) em equipes por 10 mil
#'   (default `IVET_TETO_COBERTURA_APS_POR_10K`).
#' @return numérico em `[0,1]`, ou `NA`.
#' @export
ivet_componente_cobertura_aps <- function(
    equipe_esf, ativas_ff, populacao,
    teto = IVET_TETO_COBERTURA_APS_POR_10K) {
  if (is.null(equipe_esf) || is.null(ativas_ff)) {
    return(NA_real_)
  }
  equipes <- suppressWarnings(as.numeric(equipe_esf)) +
    suppressWarnings(as.numeric(ativas_ff))
  ivet_componente_investimento(ivet_taxa_10k(equipes, populacao), teto)
}

#' Componente de presença de UBS por 10 mil hab (maior = pior).
#'
#' Provisão "mais = melhor", estritamente: `1 − clamp((n_ubs / população × 1e4)
#' / teto)`. `NA` devolve `NA`; `n_ubs = 0` (município sem UBS) é **zero real** e
#' devolve componente `1` (vulnerabilidade máxima). Fora do default do bloco D
#' (redundante com `cobertura_aps`).
#'
#' @param n_ubs_municipio nº de UBS ativas no município (`n_ubs_municipio`).
#' @param populacao população do município (denominador).
#' @param teto teto documentado (> 0) em UBS por 10 mil
#'   (default `IVET_TETO_PRESENCA_UBS_POR_10K`).
#' @return numérico em `[0,1]`, ou `NA`.
#' @export
ivet_componente_presenca_ubs <- function(
    n_ubs_municipio, populacao,
    teto = IVET_TETO_PRESENCA_UBS_POR_10K) {
  ivet_componente_investimento(ivet_taxa_10k(n_ubs_municipio, populacao), teto)
}

#' Componente de efetividade das vagas do PMMB (maior = pior).
#'
#' Ocupação das vagas do Programa Mais Médicos (%): mais ocupadas = melhor
#' provisão, logo **invertida**: `1 − clamp(x / teto)`. `NA` devolve `NA`. Fora
#' do default (p50 = 98,8%, quase saturada; direção ambígua).
#'
#' @param efetividade_vagas_aps ocupação das vagas do PMMB (%).
#' @param teto teto documentado (> 0) em %
#'   (default `IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT`).
#' @return numérico em `[0,1]`, ou `NA`.
#' @export
ivet_componente_efetividade_aps <- function(
    efetividade_vagas_aps,
    teto = IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT) {
  ivet_componente_investimento(efetividade_vagas_aps, teto)
}

#' Componentes do bloco D em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os indicadores de `analytics.acessibilidade_saude` e a população do
#' município; devolve os quatro componentes na ordem `distancia_ubs`,
#' `cobertura_aps`, `presenca_ubs`, `efetividade_vagas_aps`. Vazio/`NA` vira
#' `NA` (#154): fica fora do denominador da dimensão, não penaliza o território
#' por falta de dado.
#'
#' @param dist_min_km_ubs distância da escola à UBS mais próxima (km).
#' @param n_ubs_municipio nº de UBS ativas no município.
#' @param ativas_ff nº de equipes de força de frente ativas no município.
#' @param equipe_esf nº de equipes ESF no município.
#' @param efetividade_vagas_aps ocupação das vagas do PMMB (%).
#' @param populacao população do município (denominador das razões por 10 mil).
#' @param teto_distancia_ubs_km,teto_cobertura_aps_por_10k,teto_presenca_ubs_por_10k,teto_efetividade_vagas_aps_pct
#'   tetos documentados (ver as constantes `IVET_TETO_*`).
#' @return vetor nomeado com os quatro componentes.
#' @export
ivet_bloco_saude_componentes <- function(
    dist_min_km_ubs = NULL,
    n_ubs_municipio = NULL,
    ativas_ff = NULL,
    equipe_esf = NULL,
    efetividade_vagas_aps = NULL,
    populacao = NULL,
    teto_distancia_ubs_km = IVET_TETO_DISTANCIA_UBS_KM,
    teto_cobertura_aps_por_10k = IVET_TETO_COBERTURA_APS_POR_10K,
    teto_presenca_ubs_por_10k = IVET_TETO_PRESENCA_UBS_POR_10K,
    teto_efetividade_vagas_aps_pct = IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT) {
  c(
    distancia_ubs = ivet_componente_distancia(
      dist_min_km_ubs, teto_distancia_ubs_km
    ),
    cobertura_aps = ivet_componente_cobertura_aps(
      equipe_esf, ativas_ff, populacao, teto_cobertura_aps_por_10k
    ),
    presenca_ubs = ivet_componente_presenca_ubs(
      n_ubs_municipio, populacao, teto_presenca_ubs_por_10k
    ),
    efetividade_vagas_aps = ivet_componente_efetividade_aps(
      efetividade_vagas_aps, teto_efetividade_vagas_aps_pct
    )
  )
}

#' Dimensão **D (saúde)** do IVET a partir dos indicadores de acesso/provisão.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. O default usa `distancia_ubs` + `cobertura_aps` — acesso
#' espacial (grão escola) e provisão municipal, sem duplicar o sinal
#' (`presenca_ubs` correlaciona 0,78 com `cobertura_aps`). Sem nenhum componente
#' disponível devolve `NA` (dimensão não calculada), nunca 0.
#'
#' @param dist_min_km_ubs,n_ubs_municipio,ativas_ff,equipe_esf,efetividade_vagas_aps,populacao
#'   indicadores de `analytics.acessibilidade_saude` (ver
#'   `ivet_bloco_saude_componentes`).
#' @param teto_distancia_ubs_km,teto_cobertura_aps_por_10k,teto_presenca_ubs_por_10k,teto_efetividade_vagas_aps_pct
#'   tetos documentados (> 0).
#' @param componentes quais componentes entram na dimensão (por omissão,
#'   `IVET_BLOCO_D_COMPONENTES`).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_saude <- function(
    dist_min_km_ubs = NULL,
    n_ubs_municipio = NULL,
    ativas_ff = NULL,
    equipe_esf = NULL,
    efetividade_vagas_aps = NULL,
    populacao = NULL,
    teto_distancia_ubs_km = IVET_TETO_DISTANCIA_UBS_KM,
    teto_cobertura_aps_por_10k = IVET_TETO_COBERTURA_APS_POR_10K,
    teto_presenca_ubs_por_10k = IVET_TETO_PRESENCA_UBS_POR_10K,
    teto_efetividade_vagas_aps_pct = IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT,
    componentes = IVET_BLOCO_D_COMPONENTES) {
  comps <- ivet_bloco_saude_componentes(
    dist_min_km_ubs = dist_min_km_ubs,
    n_ubs_municipio = n_ubs_municipio,
    ativas_ff = ativas_ff,
    equipe_esf = equipe_esf,
    efetividade_vagas_aps = efetividade_vagas_aps,
    populacao = populacao,
    teto_distancia_ubs_km = teto_distancia_ubs_km,
    teto_cobertura_aps_por_10k = teto_cobertura_aps_por_10k,
    teto_presenca_ubs_por_10k = teto_presenca_ubs_por_10k,
    teto_efetividade_vagas_aps_pct = teto_efetividade_vagas_aps_pct
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_saude: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
