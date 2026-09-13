# R/utils.R
#
# Utilitários internos compartilhados. `%||%` estava duplicado em três
# arquivos (result-analysis-result.R, model-semantic-school-indicator-
# model.R, view-plotly.R) — aproveitei a correção de estrutura pra
# consolidar num só lugar.
`%||%` <- function(a, b) if (is.null(a) || identical(a, "")) b else a

#' Gera um identificador único de execução baseado em timestamp
#'
#' @return string no formato "run_<epoch>"
#' @export
generate_run_id <- function() {
  paste0("run_", as.integer(Sys.time()))
}
