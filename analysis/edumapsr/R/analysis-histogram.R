# R/analysis/histogram.R
#
# Análise pura: recebe um SchoolIndicatorModel (nunca um data.frame cru,
# nunca uma conexão de banco) e devolve um AnalysisResult. Quem decide se
# isso vira um gráfico Plotly, um JSON ou um PDF é a camada de View
# (R/view/), não esta função — por isso ela é trivial de testar sem
# banco, sem HTTP, sem ggplot (ver tests/testthat/test-analysis-histogram.R).

#' @export
analyze_histogram <- function(model, parameters = list()) {
  x <- values(model)
  if (is.null(x) || length(x) == 0) {
    stop("histogram requer um SchoolIndicatorModel com valores em `value`")
  }

  new_analysis_result(
    analysis = "histogram",
    parameters = parameters,
    data = data.frame(value = x),
    metrics = list(
      n = length(x),
      mean = mean(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      min = suppressWarnings(min(x, na.rm = TRUE)),
      max = suppressWarnings(max(x, na.rm = TRUE))
    ),
    metadata = list(x_label = indicator_label(model, "value"))
  )
}
