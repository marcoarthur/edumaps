# R/ivet-escola.R
#
# Extração do bloco **A — escola** do IVET (#137, fatia C: reconciliação B↔C).
#
# O bloco A é lido do **sistema B canônico** (`clean.mv_escolas_scores`, escala
# 0–10, maior = melhor; §2.2/§3 da doc) e **invertido** para a direção do IVET
# (vulnerabilidade: maior = pior, §1/§4.1):
#
#   componente = 1 − clamp(score / 10, 0, 1)
#
# O **sistema C** (`EduMaps::Model::Indicator::School::*`, 0–1, maior = melhor;
# §2.3) é a **camada de análise** — legítima, mas NÃO o índice canônico (§3). A
# reconciliação B↔C fixa a relação entre os dois: B é a fonte do bloco A; C entra
# apenas como **refinamento opcional** (`*_c`, fora do default), para o analista
# que quiser o grão que B agrega — acessibilidade (`iai`), tecnologia (`itd`),
# oferta (`ioc`) e qualificação docente (`iqd`).
#
# Decisão de produto (2026-10-17, #137): a reconciliação vive **só no IVET**. Os
# consumidores de B (ranking, similaridade, cluster) NÃO são tocados por esta
# camada — o `clean.mv_escolas_scores` permanece intacto.
#
# Direção e normalização:
#
#   componente              bruto (score do sistema)          normalização
#   ----------------------  --------------------------------  --------------------
#   capacidade_atendimento  score_capacidade_atendimento 0–10  1 − clamp(s/10)
#   infraestrutura          score_infraestrutura         0–10  1 − clamp(s/10)
#   capacitacao_docente     score_capacitacao_docente    0–10  1 − clamp(s/10)
#   diversidade_discente    score_diversidade_discente   0–10  1 − clamp(s/10)
#   capacidade_gestora      score_capacidade_gestora     0–10  1 − clamp(s/10)
#   sustentabilidade        score_sustentabilidade       0–10  1 − clamp(s/10)
#   acessibilidade_c        iai (sistema C)              0–1   1 − clamp(x)
#   tecnologia_c            itd (sistema C)              0–1   1 − clamp(x)
#   oferta_c                ioc (sistema C)              0–1   1 − clamp(x)
#   qualificacao_docente_c  iqd (sistema C)              0–1   1 − clamp(x)†
#
#   † o `iqd` do sistema C viola `[0,1]` (razão aluno/docente crua, §2.3); aqui
#     é clampado — a correção fica registrada na camada que o consome.
#
# Vazio ≠ zero (#154): um score `NA` (escola inativa / sem dado) vira componente
# `NA` e fica **fora** do denominador (não penaliza a escola por falta de dado);
# sem nenhum componente a dimensão A é `NA` — nunca 0.

# Componentes do bloco A derivados do sistema B (canônico, §3).
IVET_ESCOLA_COMPONENTES_B <- c(
  "capacidade_atendimento", "infraestrutura", "capacitacao_docente",
  "diversidade_discente", "capacidade_gestora", "sustentabilidade"
)

# Componentes opcionais derivados do sistema C (camada de análise, §3). Fora do
# default: entram só por escolha explícita do analista (ver `componentes`).
IVET_ESCOLA_COMPONENTES_C <- c(
  "acessibilidade_c", "tecnologia_c", "oferta_c", "qualificacao_docente_c"
)

# Default do bloco A: **B apenas** — o sistema canônico (§3, reconciliação B↔C).
IVET_BLOCO_A_COMPONENTES <- IVET_ESCOLA_COMPONENTES_B

# Teto da escala do sistema B (os 6 scores são 0–10).
IVET_ESCOLA_TETO_SCORE <- 10

#' Componente do bloco A a partir de um score 0–10 do sistema B (canônico).
#'
#' O sistema B mede "quanto melhor, maior" numa escala 0–10; o IVET mede
#' **vulnerabilidade** ("quanto pior, maior"), logo o componente é invertido:
#' `1 − clamp(score / teto, 0, 1)`. Um score `NA` (escola inativa / sem dado)
#' devolve `NA` (nunca 0 — #154), para ficar fora do denominador da dimensão.
#'
#' @param score valor do score do sistema B (`clean.mv_escolas_scores`).
#' @param teto teto da escala do score (default 10, `IVET_ESCOLA_TETO_SCORE`).
#' @return numérico em `[0,1]` (maior = mais vulnerável), ou `NA` se `score` for
#'   vazio/não-numérico.
#' @export
ivet_componente_score <- function(score, teto = IVET_ESCOLA_TETO_SCORE) {
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_componente_score: 'teto' precisa ser > 0")
  }
  x <- suppressWarnings(as.numeric(score))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  1 - pmin(pmax(x / teto, 0), 1)
}

#' Componente opcional do bloco A a partir de um indicador 0–1 do sistema C.
#'
#' O sistema C já é `[0,1]` e "quanto melhor, maior"; o componente é invertido
#' para a direção do IVET e **clampado** — o que corrige o `iqd`, que devolve uma
#' razão aluno/docente crua `> 1` (§2.3). `NA` devolve `NA` (nunca 0 — #154).
#'
#' @param x indicador do sistema C (`iai`, `itd`, `ioc`, `iqd`), em `[0,1]`.
#' @return numérico em `[0,1]` (maior = mais vulnerável), ou `NA` se `x` for
#'   vazio/não-numérico.
#' @export
ivet_componente_indicador <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1 || !is.finite(x)) {
    return(NA_real_)
  }
  1 - pmin(pmax(x, 0), 1)
}

#' Componentes do bloco A em `[0,1]` (maior = mais vulnerável), `NA` preservado.
#'
#' Recebe os seis scores do **sistema B canônico** (`clean.mv_escolas_scores`) e,
#' opcionalmente, indicadores do **sistema C** (camada de análise). Devolve todos
#' os componentes, já invertidos para a direção de vulnerabilidade do IVET, na
#' ordem: os 6 de B e depois os 4 de C.
#'
#' A reconciliação B↔C fixa B como fonte do bloco A (§3). Os componentes `*_c`
#' existem para o analista que precisa do grão que B agrega (`score_infraestrutura`
#' junta infraestrutura, pedagógico, acessibilidade e tecnologia) e **não** entram
#' no default — ver `ivet_bloco_escola()` e `IVET_BLOCO_A_COMPONENTES`.
#'
#' @param score_capacidade_atendimento,score_infraestrutura,score_capacitacao_docente,score_diversidade_discente,score_capacidade_gestora,score_sustentabilidade
#'   scores 0–10 do sistema B (`clean.mv_escolas_scores`).
#' @param iai,itd,ioc,iqd indicadores 0–1 do sistema C (acessibilidade,
#'   tecnologia, oferta, qualificação docente, na ordem do §2.3). O `iqd` é
#'   clampado (viola `[0,1]` no sistema C).
#' @param teto_score teto da escala do sistema B (default 10).
#' @return vetor nomeado com os 10 componentes (6 de B + 4 de C).
#' @export
ivet_bloco_escola_componentes <- function(
    score_capacidade_atendimento = NULL,
    score_infraestrutura = NULL,
    score_capacitacao_docente = NULL,
    score_diversidade_discente = NULL,
    score_capacidade_gestora = NULL,
    score_sustentabilidade = NULL,
    iai = NULL, itd = NULL, ioc = NULL, iqd = NULL,
    teto_score = IVET_ESCOLA_TETO_SCORE) {
  c(
    capacidade_atendimento = ivet_componente_score(score_capacidade_atendimento, teto_score),
    infraestrutura         = ivet_componente_score(score_infraestrutura, teto_score),
    capacitacao_docente    = ivet_componente_score(score_capacitacao_docente, teto_score),
    diversidade_discente   = ivet_componente_score(score_diversidade_discente, teto_score),
    capacidade_gestora     = ivet_componente_score(score_capacidade_gestora, teto_score),
    sustentabilidade       = ivet_componente_score(score_sustentabilidade, teto_score),
    acessibilidade_c       = ivet_componente_indicador(iai),
    tecnologia_c           = ivet_componente_indicador(itd),
    oferta_c               = ivet_componente_indicador(ioc),
    qualificacao_docente_c = ivet_componente_indicador(iqd)
  )
}

#' Dimensão **A (escola)** do IVET a partir dos scores do sistema canônico B.
#'
#' Reconciliação B↔C: por omissão a dimensão usa **só o sistema B** (os 6 scores
#' 0–10, invertidos para vulnerabilidade). Componente `NA` fica **fora** do
#' denominador (`ivet_agregar` — #154); sem nenhum componente, devolve `NA`
#' (dimensão não calculada), nunca 0.
#'
#' Os componentes do sistema C (`acessibilidade_c`, `tecnologia_c`, `oferta_c`,
#' `qualificacao_docente_c`) só entram se forem listados em `componentes`; o
#' default é `IVET_BLOCO_A_COMPONENTES` (B apenas).
#'
#' @param score_capacidade_atendimento,score_infraestrutura,score_capacitacao_docente,score_diversidade_discente,score_capacidade_gestora,score_sustentabilidade
#'   scores 0–10 do sistema B (`clean.mv_escolas_scores`).
#' @param iai,itd,ioc,iqd indicadores 0–1 do sistema C (opcionais; ver
#'   `ivet_bloco_escola_componentes`).
#' @param teto_score teto da escala do sistema B (default 10).
#' @param componentes quais componentes entram na dimensão (por omissão, só os de
#'   B — `IVET_BLOCO_A_COMPONENTES`).
#' @return a dimensão em `[0,1]`, ou `NA_real_` se nada estiver disponível.
#' @export
ivet_bloco_escola <- function(
    score_capacidade_atendimento = NULL,
    score_infraestrutura = NULL,
    score_capacitacao_docente = NULL,
    score_diversidade_discente = NULL,
    score_capacidade_gestora = NULL,
    score_sustentabilidade = NULL,
    iai = NULL, itd = NULL, ioc = NULL, iqd = NULL,
    teto_score = IVET_ESCOLA_TETO_SCORE,
    componentes = IVET_BLOCO_A_COMPONENTES) {
  comps <- ivet_bloco_escola_componentes(
    score_capacidade_atendimento = score_capacidade_atendimento,
    score_infraestrutura         = score_infraestrutura,
    score_capacitacao_docente    = score_capacitacao_docente,
    score_diversidade_discente   = score_diversidade_discente,
    score_capacidade_gestora     = score_capacidade_gestora,
    score_sustentabilidade       = score_sustentabilidade,
    iai = iai, itd = itd, ioc = ioc, iqd = iqd,
    teto_score = teto_score
  )

  selecionados <- intersect(componentes, names(comps))
  if (length(selecionados) == 0) {
    stop("ivet_bloco_escola: 'componentes' não corresponde a nenhum componente")
  }
  ivet_agregar(comps[selecionados])
}
