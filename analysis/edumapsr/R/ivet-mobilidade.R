# R/ivet-mobilidade.R
#
# Extração do bloco **C — acesso/mobilidade** do IVET (#137, entregável 3).
#
# Fonte: `analytics.mobilidade_escola` (view por escola, uma linha por escola) e
# `clean.populacao_municipal` como denominador das taxas. O grão do bloco é o
# **município da escola** (a escola é o ponto de observação; §1).
#
# A dimensão central de C é o **acesso** — isócrona / distância-tempo. O acesso
# entrou por fases (decisão de produto, 2026-10-19 — #278):
#
#   1. **Cobertura vigente**: `acesso_isocrona` (15 min a pé) e
#      `acesso_auto_45min` (45 min de carro) cobrem as escolas com isócrona
#      carregada em `clean.isocrona_escolar` — Sudeste e Nordeste (#295,
#      ~98,7 mil escolas, Valhalla auto-hospedado). Fora dela os componentes
#      são `NA` e C segue lido como **exposição viária** (o que a fonte entrega).
#   2. Sul, Centro-Oeste e Norte, quando o roteamento rodar para essas regiões.
#
# Fora da cobertura os dois acessos continuam no **default**, mas só sinalizam
# nas escolas cobertas (#154: sem dado → `NA` → fora do denominador da
# dimensão — nunca 0).
#
# Direção: o IVET mede **vulnerabilidade** (maior = pior). Dois componentes
# entram **diretos** (mais sinistros / mais frota por habitante = mais
# exposição) e os dois de acesso entram **invertidos** (mais população
# alcançável = menos vulnerável — mesma convenção da renda no bloco B):
#
#   componente        bruto (tabela)                     normalização
#   ----------------  ---------------------------------  --------------------------
#   risco_sinistros   sinistros_12m (RENAEST)            clamp(taxa100k/500)
#   exposicao_frota   renavam_total_frota (RENAVAM)      clamp(frota_hab/1)
#   acesso_isocrona   Σ populacao_grade, 15 min a pé     1 − log_escala(pop)
#                     (clean.isocrona_escolar)
#   acesso_auto_45min Σ populacao_grade, 45 min carro    1 − log_escala(pop)
#                     (clean.isocrona_escolar)
#
#   log_escala(pop) = clamp((log10(pop+1) − log10(piso+1)) /
#                           (log10(teto+1) − log10(piso+1)))  (ivet_escala_log)
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

# Escala do acesso (ivet-v1.3, #295). A população alcançável é muito
# assimétrica (45 min de carro: p10 ≈ 23 mil, p50 ≈ 390 mil, p99 ≈ 19,3 mi) e a
# escala linear `1 − clamp(pop/teto)` saturava: 63% das escolas ficavam ≥ 0,95
# no acesso de carro (36% no a pé) e só as metropolitanas se diferenciavam. A
# escala é **logarítmica** entre um piso e um teto fixos — passar de mil para 10
# mil habitantes alcançáveis pesa o mesmo que de 1 mi para 10 mi. Medido nas
# 98.722 escolas do Sudeste e do Nordeste (CSVs da rodada 2 + ES/MG, 2026-11-10;
# nota técnica 186): com o log, ≥ 0,95 cai para 1,7% nos dois acessos e o dp
# fica em 0,22–0,23. Piso e teto são **parâmetros de produto** (mudá-los exige
# registro e nova versão da fórmula); não são percentis recalculados a cada
# carga, para o valor de uma escola não mudar quando outra região entra.

# 15 min a pé: piso 0 (escola sem população no entorno = pior acesso); teto
# 60.000 ≈ p99 (59.732). p50 = 6.829 → componente ≈ 0,20.
IVET_PISO_ACESSO_15MIN <- 0
IVET_TETO_ACESSO_15MIN <- 60000

# 45 min de carro: piso 500 ≈ p1 (365); teto 20.000.000 ≈ p99 (19,3 mi).
# p50 = 389.528 → componente ≈ 0,36.
IVET_PISO_ACESSO_45MIN <- 500
IVET_TETO_ACESSO_45MIN <- 20000000

# Default do bloco C: exposição viária + os dois acessos (só sinalizam nas
# escolas do piloto; as demais ficam `NA` — #154).
IVET_BLOCO_C_COMPONENTES <- c(
  "risco_sinistros", "exposicao_frota", "acesso_isocrona", "acesso_auto_45min"
)

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

#' Escala logarítmica do acesso em `[0,1]` (maior = mais acesso).
#'
#' `clamp((log10(pop+1) − log10(piso+1)) / (log10(teto+1) − log10(piso+1)))`.
#' O `+1` mantém a população 0 definida (vira 0, o pior acesso). `NA`/vazio
#' devolve `NA_real_` (#154).
#'
#' @param pop população alcançável (escalar).
#' @param piso,teto limites documentados, `0 <= piso < teto`.
#' @return numérico em `[0,1]`, ou `NA_real_`.
#' @export
ivet_escala_log <- function(pop, piso, teto) {
  if (is.null(teto) || length(teto) != 1 || !is.finite(teto) || teto <= 0) {
    stop("ivet_escala_log: 'teto' precisa ser > 0")
  }
  if (is.null(piso) || length(piso) != 1 || !is.finite(piso) || piso < 0 ||
      piso >= teto) {
    stop("ivet_escala_log: 'piso' precisa estar em [0, teto)")
  }
  pop <- suppressWarnings(as.numeric(pop))
  if (length(pop) != 1 || !is.finite(pop)) {
    return(NA_real_)
  }
  x <- (log10(max(pop, 0) + 1) - log10(piso + 1)) /
    (log10(teto + 1) - log10(piso + 1))
  pmin(pmax(x, 0), 1)
}

#' Componente de acesso a pé (maior = menos vulnerável, invertido).
#'
#' A população alcançável a pé em 15 minutos (`clean.isocrona_escolar`, grão
#' escola × célula H3) é o **acesso** do IVET (#278). Mais população ao redor
#' da escola = melhor acesso = **menos** vulnerabilidade, então entra
#' **invertida** — mesma convenção da renda no bloco B:
#' `1 − ivet_escala_log(pop, piso, teto)` (escala logarítmica, ivet-v1.3). `NA`/vazio devolve `NA` (nunca 0 — #154):
#' escola fora do piloto de isócrona não é penalizada por falta de dado.
#'
#' @param pop_acessivel_15min população total das células H3 da isócrona de
#'   15 min a pé (`Σ populacao_grade`, `clean.isocrona_escolar`). `NULL` —
#'   escola sem isócrona carregada.
#' @param teto teto documentado (> 0) em habitantes alcançáveis
#'   (default `IVET_TETO_ACESSO_15MIN`).
#' @param piso piso documentado (`0 <= piso < teto`) em habitantes alcançáveis
#'   (default `IVET_PISO_ACESSO_15MIN`).
#' @return numérico em `[0,1]`, ou `NA_real_` se a população não vier dada.
#' @export
ivet_componente_acesso_isocrona <- function(
    pop_acessivel_15min,
    teto = IVET_TETO_ACESSO_15MIN,
    piso = IVET_PISO_ACESSO_15MIN) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_acesso_isocrona: 'teto' precisa ser > 0")
  }
  # população 0 é dado real (escola na rota, mas sem população no entorno) —
  # vira o pior acesso possível, não `NA`
  1 - ivet_escala_log(pop_acessivel_15min, piso, teto)
}

#' Componente de acesso de carro a 45 min (maior = menos vulnerável, invertido).
#'
#' A população alcançável em **45 minutos de carro** (`clean.isocrona_escolar`,
#' costing `auto` do Valhalla) mede o **acesso regional** da escola: isolamento
#' geográfico = menos serviços e menor alcance = mais vulnerabilidade. Entra
#' **invertido** — mesma convenção do acesso a pé e da renda no bloco B:
#' `1 − ivet_escala_log(pop, piso, teto)` (escala logarítmica, ivet-v1.3). `NA`/vazio devolve `NA` (nunca 0 — #154).
#'
#' Viés de fronteira: o anel de 45 min cruza UFs; a expansão regional (#295,
#' setores e tiles da região inteira) o reduziu a poucas escolas na borda com
#' regiões ainda não carregadas.
#'
#' @param pop_acessivel_45min população total das células H3 da isócrona de
#'   45 min de carro (`Σ populacao_grade`, `clean.isocrona_escolar`). `NULL` —
#'   escola sem isócrona carregada.
#' @param teto teto documentado (> 0) em habitantes alcançáveis
#'   (default `IVET_TETO_ACESSO_45MIN`).
#' @param piso piso documentado (`0 <= piso < teto`) em habitantes alcançáveis
#'   (default `IVET_PISO_ACESSO_45MIN`).
#' @return numérico em `[0,1]`, ou `NA_real_` se a população não vier dada.
#' @export
ivet_componente_acesso_auto_45min <- function(
    pop_acessivel_45min,
    teto = IVET_TETO_ACESSO_45MIN,
    piso = IVET_PISO_ACESSO_45MIN) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_acesso_auto_45min: 'teto' precisa ser > 0")
  }
  # população 0 é dado real (escola na rota, mas sem população no entorno) —
  # vira o pior acesso possível, não `NA`
  1 - ivet_escala_log(pop_acessivel_45min, piso, teto)
}

#' Componentes do bloco C em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os indicadores de `analytics.mobilidade_escola`, a população do
#' município e as populações alcançáveis (pé e carro); devolve os quatro
#' componentes na ordem `risco_sinistros`, `exposicao_frota`, `acesso_isocrona`,
#' `acesso_auto_45min`. Vazio/`NA` vira `NA` (#154): fica fora do denominador da
#' dimensão, não penaliza o território por falta de dado.
#'
#' @param sinistros_12m sinistros de trânsito em 12 meses (RENAEST).
#' @param renavam_total_frota frota total do município (RENAVAM).
#' @param populacao população do município (denominador).
#' @param pop_acessivel_15min população alcançável a pé em 15 min
#'   (`clean.isocrona_escolar`; `NULL` fora do piloto — #278).
#' @param pop_acessivel_45min população alcançável de carro em 45 min
#'   (`clean.isocrona_escolar`; `NULL` fora do piloto — #278).
#' @param teto_sinistros_100k,teto_frota_por_hab,teto_acesso_15min,teto_acesso_45min
#'   tetos documentados (> 0).
#' @param piso_acesso_15min,piso_acesso_45min pisos da escala logarítmica dos
#'   acessos (`0 <= piso < teto`).
#' @return vetor nomeado com os quatro componentes.
#' @export
ivet_bloco_mobilidade_componentes <- function(
    sinistros_12m = NULL,
    renavam_total_frota = NULL,
    populacao = NULL,
    pop_acessivel_15min = NULL,
    pop_acessivel_45min = NULL,
    teto_sinistros_100k = IVET_TETO_SINISTROS_100K,
    teto_frota_por_hab = IVET_TETO_FROTA_POR_HAB,
    teto_acesso_15min = IVET_TETO_ACESSO_15MIN,
    teto_acesso_45min = IVET_TETO_ACESSO_45MIN,
    piso_acesso_15min = IVET_PISO_ACESSO_15MIN,
    piso_acesso_45min = IVET_PISO_ACESSO_45MIN) {
  c(
    risco_sinistros = ivet_componente_risco_sinistros(
      sinistros_12m, populacao, teto_sinistros_100k
    ),
    exposicao_frota = ivet_componente_exposicao_frota(
      renavam_total_frota, populacao, teto_frota_por_hab
    ),
    acesso_isocrona = ivet_componente_acesso_isocrona(
      pop_acessivel_15min, teto_acesso_15min, piso_acesso_15min
    ),
    acesso_auto_45min = ivet_componente_acesso_auto_45min(
      pop_acessivel_45min, teto_acesso_45min, piso_acesso_45min
    )
  )
}

#' Dimensão **C (acesso/mobilidade)** do IVET.
#'
#' Média dos componentes disponíveis (`NA` fora do denominador — #154), maior =
#' mais vulnerável. Com o piloto de isócrona (#278), C combina **exposição
#' viária** (sinistros RENAEST + frota RENAVAM), **acesso a pé** (15 min) e
#' **acesso regional de carro** (45 min) nas escolas cobertas; fora do piloto
#' segue sendo só o proxy de exposição. Sem nenhum componente disponível
#' devolve `NA` (dimensão não calculada), nunca 0.
#'
#' @param sinistros_12m,renavam_total_frota,populacao indicadores de
#'   `analytics.mobilidade_escola` e a população do município.
#' @param pop_acessivel_15min população alcançável a pé em 15 min
#'   (`clean.isocrona_escolar`; `NULL` fora do piloto — #278).
#' @param pop_acessivel_45min população alcançável de carro em 45 min
#'   (`clean.isocrona_escolar`; `NULL` fora do piloto — #278).
#' @param teto_sinistros_100k,teto_frota_por_hab,teto_acesso_15min,teto_acesso_45min
#'   tetos documentados (> 0).
#' @param piso_acesso_15min,piso_acesso_45min pisos da escala logarítmica dos
#'   acessos (`0 <= piso < teto`).
#' @param componentes quais componentes entram na dimensão (por omissão,
#'   `IVET_BLOCO_C_COMPONENTES`).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_mobilidade <- function(
    sinistros_12m = NULL,
    renavam_total_frota = NULL,
    populacao = NULL,
    pop_acessivel_15min = NULL,
    pop_acessivel_45min = NULL,
    teto_sinistros_100k = IVET_TETO_SINISTROS_100K,
    teto_frota_por_hab = IVET_TETO_FROTA_POR_HAB,
    teto_acesso_15min = IVET_TETO_ACESSO_15MIN,
    teto_acesso_45min = IVET_TETO_ACESSO_45MIN,
    piso_acesso_15min = IVET_PISO_ACESSO_15MIN,
    piso_acesso_45min = IVET_PISO_ACESSO_45MIN,
    componentes = IVET_BLOCO_C_COMPONENTES) {
  comps <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = sinistros_12m,
    renavam_total_frota = renavam_total_frota,
    populacao = populacao,
    pop_acessivel_15min = pop_acessivel_15min,
    pop_acessivel_45min = pop_acessivel_45min,
    teto_sinistros_100k = teto_sinistros_100k,
    teto_frota_por_hab = teto_frota_por_hab,
    teto_acesso_15min = teto_acesso_15min,
    teto_acesso_45min = teto_acesso_45min,
    piso_acesso_15min = piso_acesso_15min,
    piso_acesso_45min = piso_acesso_45min
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    return(NA_real_)
  }
  ivet_agregar(comps[selecionados])
}
