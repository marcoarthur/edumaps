# R/analysis/boxplot.R

#' @export
analyze_boxplot <- function(model, parameters = list()) {
  value <- values(model)
  group <- groups(model)
  if (is.null(value) || is.null(group)) {
    stop("boxplot requer um SchoolIndicatorModel com value e group")
  }

  df <- data.frame(value = value, group = as.factor(group))

  summary_by_group <- stats::aggregate(
    value ~ group,
    data = df,
    FUN = function(v) c(n = length(v), median = stats::median(v), mean = mean(v))
  )

  new_analysis_result(
    analysis = "boxplot",
    parameters = parameters,
    data = df,
    tables = list(summary_by_group = summary_by_group),
    metrics = list(n = nrow(df), groups = nlevels(df$group)),
    metadata = list(
      value_label = indicator_label(model, "value"),
      group_label = indicator_label(model, "group")
    )
  )
}
