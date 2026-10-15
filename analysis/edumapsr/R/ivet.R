# R/ivet.R
#
# IVET v1.0 — núcleo reprodutível da fórmula do Índice de Vulnerabilidade
# Educacional Territorial (docs/analises/ivet.md §4, issue #137 entregável 3).
#
# O IVET é um índice TERRITORIAL: a escola é o ponto de observação, não a
# unidade medida (§1). A estrutura é fixada, de baixo para cima:
#
#   componente (bruto → [0,1]) → dimensão (média ponderada) → IVET (média
#   ponderada das dimensões)
#
# Regras (§4.1 e §4.3), todas explícitas e auditáveis:
#   - componente `undef`/`NA`/não-numérico → 0 (herdado do sistema C);
#   - binário `in_*`        → {0,1};
#   - proporção             → clamp(0,1);
#   - contagem              → clamp(0,1) pela razão contra um teto documentado
#                             (nunca crua — o defeito do `iqd` é uma contagem
#                             crua, §2.3);
#   - peso IGUAL entre dimensões disponíveis (W=1) — default reprodutível;
#   - dimensão ausente NÃO é 0: entra como `NA` e fica FORA do denominador
#     (não penaliza o território por falta de dado — §4.3 / #154);
#   - enquanto as dimensões territoriais mínimas (mobilidade, saúde, segurança
#     — blocos C–E, §4.2) não tiverem dado, o IVET agregado NÃO é publicado
#     como número: sai `NA`, e publica-se só o bloco escola.
#
# Este arquivo é o NÚCLEO (puro, sem banco): mesma entrada → mesma saída. A
# extração dos componentes das tabelas (reconciliar B/C em um só bloco escola)
# é decisão de produto registrada como follow-up (§6) e não vive aqui.
#
# Versão da fórmula: use `ivet_versao()` para carimbá-la no resultado.

#' Versão da fórmula do IVET implementada neste arquivo.
#' @export
ivet_versao <- function() "ivet-v1.0"

#' Nomes dos blocos (dimensões de topo) e o rótulo de cada um (§4.2).
#' @export
ivet_blocos <- function() {
  c(
    escola         = "A",
    socioeconomico = "B",
    mobilidade     = "C",
    saude          = "D",
    seguranca      = "E",
    meio_ambiente  = "F",
    recursos       = "G"
  )
}

# Blocos territoriais mínimos para o IVET agregado ser publicável (§4.3):
# mobilidade (C), saúde (D) e segurança (E). Enquanto faltar algum, o número
# agregado é `NA`.
ivet_blocos_territoriais_minimos <- function() c("mobilidade", "saude", "seguranca")

#' Normaliza um componente bruto para [0,1] (§4.1).
#'
#' @param x valor(es) bruto(s).
#' @param tipo `"binario"` (`in_*`), `"proporcao"` ou `"contagem"`.
#' @param teto teto documentado — obrigatório quando `tipo = "contagem"`.
#' @return numérico em [0,1]; `NA`/não-numérico vira `0`.
#' @export
ivet_normalizar <- function(x, tipo = c("binario", "proporcao", "contagem"), teto = NULL) {
  tipo <- match.arg(tipo)
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- 0

  if (tipo == "binario") {
    return(as.numeric(x != 0))
  }
  if (tipo == "proporcao") {
    return(pmin(pmax(x, 0), 1))
  }
  # contagem
  if (is.null(teto) || !is.finite(teto) || teto <= 0) {
    stop("ivet_normalizar: tipo='contagem' exige um teto > 0 documentado")
  }
  pmin(pmax(x / teto, 0), 1)
}

#' Dimensão = média ponderada dos componentes (§4.1, passo 2).
#'
#' `undef`/`NA`/não-numérico vira `0` (§4.1), logo um componente em falta não
#' "some" da dimensão — é 0. A ausência de toda uma dimensão é sinalizada no
#' nível de cima (`ivet_agregar`/`ivet_v1`), passando `NA` para ela.
#'
#' @param componentes vetor numérico (já normalizado a [0,1]).
#' @param pesos vetor de pesos; `NULL` = peso igual.
#' @return a média ponderada (numérico).
#' @export
ivet_dimensao <- function(componentes, pesos = NULL) {
  componentes <- suppressWarnings(as.numeric(componentes))
  componentes[!is.finite(componentes)] <- 0

  if (length(componentes) == 0) {
    stop("ivet_dimensao: sem componentes")
  }
  if (is.null(pesos)) {
    pesos <- rep(1, length(componentes))
  }
  if (length(pesos) != length(componentes)) {
    stop("ivet_dimensao: 'pesos' e 'componentes' têm tamanhos diferentes")
  }
  pesos <- suppressWarnings(as.numeric(pesos))
  if (any(!is.finite(pesos)) || sum(pesos) <= 0) {
    stop("ivet_dimensao: pesos inválidos (precisam somar > 0)")
  }
  sum(componentes * pesos) / sum(pesos)
}

#' IVET = média ponderada das dimensões DISPONÍVEIS (§4.3).
#'
#' Dimensões `NA` ficam fora do numerador E do denominador (não penalizam).
#'
#' @param dimensoes vetor numérico de dimensões de topo (pode ter `NA`).
#' @param pesos vetor de pesos; `NULL` = peso igual entre as disponíveis.
#' @return o IVET em [0,1], ou `NA` se nenhuma dimensão estiver disponível.
#' @export
ivet_agregar <- function(dimensoes, pesos = NULL) {
  dimensoes <- suppressWarnings(as.numeric(dimensoes))
  if (length(dimensoes) == 0) {
    return(NA_real_)
  }
  if (is.null(pesos)) {
    pesos <- rep(1, length(dimensoes))
  }
  if (length(pesos) != length(dimensoes)) {
    stop("ivet_agregar: 'pesos' e 'dimensoes' têm tamanhos diferentes")
  }
  pesos <- suppressWarnings(as.numeric(pesos))

  disp <- is.finite(dimensoes)
  if (!any(disp)) {
    return(NA_real_)
  }
  sum(dimensoes[disp] * pesos[disp]) / sum(pesos[disp])
}

#' Fórmula completa: blocos → resultado versionado do IVET (§4.2/§4.3).
#'
#' @param blocos lista/vetor nomeado com valores em [0,1] por bloco
#'   (`names` em `names(ivet_blocos())`; ver `ivet_blocos()`). Bloco ausente =
#'   `NA` (ou simplesmente não informado).
#' @param dataset_version chave de conteúdo dos datasets de entrada (ver
#'   `docs/analises/versionamento_datasets.md`, #135). `NA` se desconhecida.
#' @param lock_path caminho do `datasets.lock.json`; se informado e
#'   `dataset_version` for `NA`, a versão é lida do lockfile
#'   (`ivet_dataset_version()`).
#' @return lista com o IVET, o bloco escola, o que foi publicado e a
#'   proveniência.
#' @export
ivet_v1 <- function(blocos, dataset_version = NA_character_, lock_path = NULL) {
  nomes <- names(blocos)
  valores <- suppressWarnings(as.numeric(unlist(blocos, use.names = FALSE)))
  names(valores) <- nomes

  if (is.null(nomes) || any(!nzchar(nomes))) {
    stop("ivet_v1: 'blocos' precisa ser nomeado (ex.: c(escola=0.7, saude=NA))")
  }

  disponiveis <- names(valores)[is.finite(valores)]
  territoriais_faltando <- setdiff(ivet_blocos_territoriais_minimos(), disponiveis)
  publicavel <- length(territoriais_faltando) == 0

  if (is.na(dataset_version) && !is.null(lock_path)) {
    dataset_version <- ivet_dataset_version(lock_path)
  }

  list(
    formula                = ivet_versao(),
    ivet                   = if (publicavel) ivet_agregar(valores) else NA_real_,
    bloco_escola           = if ("escola" %in% nomes) unname(valores[["escola"]]) else NA_real_,
    publicavel             = publicavel,
    dimensoes_disponiveis  = disponiveis,
    territoriais_faltando  = territoriais_faltando,
    dataset_version        = dataset_version,
    computado_em           = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
}

#' Lê a chave de conteúdo (`dataset_version`) do lockfile de datasets (#135).
#'
#' @param lock_path caminho do `datasets.lock.json`. Se `NULL`, usa a variável
#'   de ambiente `EDUMAPS_DATASETS_LOCK`.
#' @return a string `dataset_version`.
#' @export
ivet_dataset_version <- function(lock_path = NULL) {
  if (is.null(lock_path)) {
    lock_path <- Sys.getenv("EDUMAPS_DATASETS_LOCK", unset = "")
  }
  if (!nzchar(lock_path) || !file.exists(lock_path)) {
    stop("ivet_dataset_version: lockfile não encontrado (",
         if (nzchar(lock_path)) lock_path else "EDUMAPS_DATASETS_LOCK não definido",
         ")")
  }
  lock <- jsonlite::fromJSON(lock_path)
  if (is.null(lock$dataset_version) || !nzchar(lock$dataset_version)) {
    stop("ivet_dataset_version: lockfile sem 'dataset_version'")
  }
  lock$dataset_version
}
