# inst/plumber/run.R
#
# Sobe o pacote edumapsAnalytics como serviço HTTP persistente (systemd/
# supervisor) — continua sendo um processo de longa duração, não um
# `Rscript` por requisição (ver decisão de arquitetura sobre overhead de
# inicialização do R, de uma discussão anterior).
#
# Uso: Rscript inst/plumber/run.R
# Requer devtools (ou pkgload) e here instalados: install.packages(c("devtools", "here"))

devtools::load_all(here::here()) # carrega o pacote a partir do código-fonte em desenvolvimento
# em produção, prefira instalar o pacote de verdade e trocar a linha
# acima por: library(edumapsAnalytics)

pr <- plumber::plumb(here::here("inst", "plumber", "endpoints.R"))
pr$run(host = "0.0.0.0", port = as.integer(Sys.getenv("EDUMAPS_R_PORT", 8787)))
