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
#
# Força locale UTF-8: em container com LANG=C, o R tenta transliterar strings
# p/ o encoding nativo e emite warnings "cannot be translated to UTF-8".

for (.loc in c("C.UTF-8", "C.utf8", "en_US.UTF-8", "pt_BR.UTF-8")) {
  ok <- tryCatch({
    Sys.setlocale("LC_ALL", .loc)
    TRUE
  }, warning = function(w) FALSE, error = function(e) FALSE)
  if (ok) break
}

if (requireNamespace("edumapsAnalytics", quietly = TRUE)) {
  # Anexa o pacote: os handlers do endpoint.R são avaliados no ambiente de
  # run.R (parent do Plumber), então as funções exportadas precisam estar na
  # search path — requireNamespace sozinho não anexa.
  library(edumapsAnalytics)
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
