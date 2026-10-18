#!/usr/bin/env Rscript
# inst/scripts/medir-ivet-nacional.R
#
# Mede o IVET `ivet-v1.2` nacional e imprime um resumo. NÃO materializa nada no
# banco — o IVET não é materializado (decisão de projeto; ver
# docs/analises/ivet.md §3): o painel é calculado em memória a partir das
# entradas dos blocos.
#
# Uso (na raiz do pacote, ou no host `analytic.edumaps`):
#
#   Rscript inst/scripts/medir-ivet-nacional.R
#
# Variáveis de ambiente:
#   EDUMAPS_ANALYTICS_DB_SERVICE  serviço do ~/.pg_service.conf (default edumaps_local)
#   IVET_CENSO_ANO                ano do Censo Escolar (default 2025)
#   IVET_RAIO_M                   raio da área de influência, em m (default 1000)
#   IVET_SAIDA                    caminho do CSV do painel (opcional)

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

message(sprintf("Medindo o IVET nacional (censo=%d, raio=%dm)...", censo_ano, raio_m))
painel <- ivet_medir_nacional(censo_ano = censo_ano, raio_m = raio_m)

saida <- Sys.getenv("IVET_SAIDA", "")
if (nzchar(saida)) {
  utils::write.csv(painel, saida, row.names = FALSE)
  message(sprintf("Painel gravado em %s (%d linhas).", saida, nrow(painel)))
}

r <- ivet_resumo_nacional(painel)
cat(sprintf("\n=== IVET %s — nacional ===\n", attr(painel, "formula")))
cat(sprintf(
  "escolas: %d | publicáveis (C+D+E): %d (%.1f%%)\n",
  r$n, r$n_publicavel, 100 * r$n_publicavel / max(r$n, 1)
))
cat("\ncobertura por bloco (não-NA):\n")
print(r$cobertura)
cat("\nIVET (publicáveis):\n")
print(round(r$ivet, 4))
