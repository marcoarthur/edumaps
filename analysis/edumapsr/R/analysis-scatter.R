# R/analysis/scatter.R

#' @export
analyze_scatter <- function(model, parameters = list()) {
  x <- values_x(model)
  y <- values_y(model)
  if (is.null(x) || is.null(y)) {
    stop("scatter requer um SchoolIndicatorModel com x_value e y_value")
  }

  correlation <- if (length(x) >= 2) stats::cor(x, y, use = "complete.obs") else NA_real_

  new_analysis_result(
    analysis = "scatter",
    parameters = parameters,
    data = data.frame(x_value = x, y_value = y),
    metrics = list(n = length(x), correlation = correlation),
    metadata = list(
      x_label = indicator_label(model, "x"),
      y_label = indicator_label(model, "y")
    )
  )
}
