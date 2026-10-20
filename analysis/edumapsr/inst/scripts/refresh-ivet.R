#!/usr/bin/env Rscript
# inst/scripts/refresh-ivet.R
#
# Mede o IVET nacional e materializa em `analytics.ivet_escola` (#296).
# O caminho de produção é o job Minion `refresh_ivet` → endpoint Plumber
# `/ivet/refresh` → `ivet_refresh()`; este script é o equivalente CLI para
# execução manual/fora do serviço (mesmo formato de
# `medir-ivet-nacional.R`).
#
# Uso (na raiz do pacote, ou no host `analytic.edumaps`):
#
#   Rscript inst/scripts/refresh-ivet.R
#
# Variáveis de ambiente:
#   EDUMAPS_ANALYTICS_DB_SERVICE  serviço do ~/.pg_service.conf (default edumaps_local)
#   IVET_CENSO_ANO                ano do Censo Escolar (default 2025)
#   IVET_RAIO_M                   raio da área de influência, em m (default 1000)
#   IVET_DT_SNAPSHOT              Date da medição (default: hoje)

for (.loc in c("C.UTF-8", "C.utf8", "en_US.UTF-8", "pt_BR.UTF-8")) {
  ok <- tryCatch({
    Sys.setlocale("LC_ALL", .loc)
    TRUE
  }, warning = function(w) FALSE, error = function(e) FALSE)
  if (ok) break
}

if (!requireNamespace("edumapsAnalytics", quietly = TRUE)) {
  requireNamespace("devtools", quietly = TRUE)
  devtools::load_all(".")
}
suppressPackageStartupMessages(library(edumapsAnalytics))

censo_ano <- as.integer(Sys.getenv("IVET_CENSO_ANO", "2025"))
raio_m    <- as.integer(Sys.getenv("IVET_RAIO_M", "1000"))
snapshot  <- Sys.getenv("IVET_DT_SNAPSHOT", "")
dt_snapshot <- if (nzchar(snapshot)) as.Date(snapshot) else Sys.Date()

message(sprintf(
  "Refresh do IVET materializado (censo=%d, raio=%dm, snapshot=%s)...",
  censo_ano, raio_m, format(dt_snapshot)
))
r <- ivet_refresh(
  censo_ano = censo_ano, raio_m = raio_m, dt_snapshot = dt_snapshot
)

cat(sprintf("\n=== IVET %s — refresh materializado ===\n", r$formula))
cat(sprintf(
  "escolas: %d | publicáveis (C+D+E): %d (%.1f%%) | linhas gravadas: %d\n",
  r$n, r$n_publicavel, 100 * r$n_publicavel / max(r$n, 1), r$n_gravadas
))
cat(sprintf("snapshot: %s\n", format(r$dt_snapshot)))
