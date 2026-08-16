# R/view/json.R
#
# Serialização "canônica" do AnalysisResult, sem gráfico — útil pra
# consumidores que só querem métricas/tabelas (ex.: um painel textual, ou
# auditoria/log). Não depende de render_plotly().

#' @export
render_json <- function(result) {
  list(
    analysis = result$analysis,
    parameters = result$parameters,
    metrics = result$metrics,
    metadata = result$metadata,
    tables = lapply(result$tables, function(t) as.list(as.data.frame(t)))
  )
}
