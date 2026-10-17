# R/ivet-card.R
#
# Card do IVET (#137, entregável 5): a ficha do índice no MESMO lugar do código,
# não num slide. Fonte legível por máquina em `inst/ivet-card.yml`, com um teste
# de contrato (`tests/testthat/test-ivet-card.R`) que garante que o card e a
# implementação não divergem.

#' Card do IVET: ficha legível por máquina do índice (#137).
#'
#' Lê `inst/ivet-card.yml` — fórmula vigente, decisão de leitura, blocos,
#' componentes do bloco B, sub-bloco saneamento, teto de renda, proveniência e
#' critério de vigência — e devolve a estrutura como lista.
#'
#' O card é **contratual**: `test-ivet-card.R` falha se ele divergir de
#' `ivet_versao()`, `ivet_blocos()`, `ivet_blocos_territoriais_minimos()`,
#' `ivet_bloco_socioeconomico_componentes()` ou `IVET_TETO_RENDA`. Ou seja, o
#' card não descreve uma fórmula que o código não implementa.
#'
#' @param path caminho do YAML. `NULL` (default) usa o card instalado com o
#'   pacote (`system.file("ivet-card.yml", package = "edumapsAnalytics")`).
#' @return lista com o conteúdo do card.
#' @export
ivet_card <- function(path = NULL) {
  if (is.null(path)) {
    path <- system.file("ivet-card.yml", package = "edumapsAnalytics")
  }
  if (!nzchar(path) || !file.exists(path)) {
    stop("ivet_card: card do IVET não encontrado (",
         if (nzchar(path)) path else "inst/ivet-card.yml não instalado",
         ")")
  }
  yaml::read_yaml(path)
}
