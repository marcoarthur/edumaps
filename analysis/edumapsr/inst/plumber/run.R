# inst/plumber/run.R
#
# Entry point do serviço HTTP da camada analítica durante desenvolvimento.
#
# O script é executado a partir da raiz do pacote:
#
#   cd analysis/edumapsr
#   Rscript inst/plumber/run.R
#
# Por isso os caminhos abaixo são relativos à raiz do pacote.

devtools::load_all(".")

pr <- plumber::plumb("inst/plumber/endpoint.R")

pr <- plumber::pr_set_api_spec(
  pr,
  "inst/plumber/api.json"
)

pr$run(
  host = "0.0.0.0",
  port = as.integer(Sys.getenv("EDUMAPS_R_PORT", 8787))
)
