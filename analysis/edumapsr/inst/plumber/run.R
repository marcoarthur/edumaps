# inst/plumber/run.R
#
# Entry point do serviço HTTP da camada analítica.
#
# O script é executado a partir da raiz do pacote:
#
#   cd analysis/edumapsr
#   Rscript inst/plumber/run.R
#
# Ele prefere rodar a partir do pacote instalado (R CMD INSTALL). Em
# desenvolvimento, quando o pacote ainda não está instalado, usa
# devtools::load_all como fallback.

if (requireNamespace("edumapsAnalytics", quietly = TRUE)) {
  endpoint <- system.file("plumber/endpoint.R", package = "edumapsAnalytics")
  api_spec <- system.file("plumber/api.json", package = "edumapsAnalytics")
} else {
  requireNamespace("devtools", quietly = TRUE)
  devtools::load_all(".")
  endpoint <- "inst/plumber/endpoint.R"
  api_spec <- "inst/plumber/api.json"
}

pr <- plumber::plumb(endpoint)

pr <- plumber::pr_set_api_spec(pr, api_spec)

pr$run(
  host = "0.0.0.0",
  port = as.integer(Sys.getenv("EDUMAPS_R_PORT", 8787))
)
