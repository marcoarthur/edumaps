# R/conditions.R
#
# Condições de erro tipadas. Antes, todo erro dentro de run_analysis()
# virava um `stop()` genérico, e o endpoint HTTP tratava qualquer erro
# como 400 — mas "análise desconhecida" (erro do cliente) e "bug dentro
# de analyze_histogram()" (erro interno) não deveriam ter o mesmo
# tratamento. O cliente não deveria receber detalhe de um erro interno
# (nem o 500 vazar stack trace), e um erro de validação não deveria
# virar 500.
#
# Toda condição criada aqui carrega a classe "edumaps_client_error" além
# da classe específica (invalid_analysis/invalid_parameter/
# invalid_dataset) — o adapter HTTP (inst/plumber/endpoints.R) captura
# "edumaps_client_error" pra responder 400 e deixa qualquer outro erro
# (não reconhecido, ou seja, um bug de verdade) virar 500.

new_client_error <- function(message, class) {
  structure(
    class = c(class, "edumaps_client_error", "error", "condition"),
    list(message = message, call = sys.call(-1))
  )
}

#' Nome de análise fora do analysis_registry
#' @export
stop_invalid_analysis <- function(message) {
  stop(new_client_error(message, "invalid_analysis"))
}

#' Parâmetro de chamada inválido (ex.: `model` não é um modelo semântico)
#' @export
stop_invalid_parameter <- function(message) {
  stop(new_client_error(message, "invalid_parameter"))
}

#' Modelo semântico carregado, mas sem os campos que a análise exige
#' @export
stop_invalid_dataset <- function(message) {
  stop(new_client_error(message, "invalid_dataset"))
}
