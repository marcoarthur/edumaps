# R/view/plotly.R
#
# Camada de View: constrói a especificação Plotly a partir de um
# AnalysisResult já calculado. Nunca recalcula estatística, nunca sabe de
# onde os dados vieram (Postgres, memória, Parquet — tanto faz). Dispatch
# fechado por `result$analysis` — mesma disciplina de "nunca despachar
# por string arbitrária avaliada como código" do resto do pacote.
#
# Chamadas sempre qualificadas com `::` (nada de library() dentro do
# pacote) — evita efeito colateral de anexar ggplot2/plotly ao search()
# de quem usa o pacote, e evita NOTE de "undefined global functions" no
# R CMD check.
#
#' @importFrom ggplot2 ggplot aes geom_histogram geom_point geom_boxplot labs theme_minimal theme

PLOTLY_BUILDERS <- list(
  histogram = function(result) {
    ggplot2::ggplot(result$data, ggplot2::aes(x = value)) +
      ggplot2::geom_histogram(bins = 20, fill = "#2F5D8A", color = "white") +
      ggplot2::labs(x = result$metadata$x_label %||% "Valor", y = "Frequência") +
      ggplot2::theme_minimal(base_family = "IBM Plex Sans")
  },
  scatter = function(result) {
    ggplot2::ggplot(result$data, ggplot2::aes(x = x_value, y = y_value)) +
      ggplot2::geom_point(color = "#2F5D8A", alpha = 0.7, size = 2) +
      ggplot2::labs(
        x = result$metadata$x_label %||% "X",
        y = result$metadata$y_label %||% "Y"
      ) +
      ggplot2::theme_minimal(base_family = "IBM Plex Sans")
  },
  boxplot = function(result) {
    ggplot2::ggplot(result$data, ggplot2::aes(x = group, y = value, fill = group)) +
      ggplot2::geom_boxplot(outlier.alpha = 0.5) +
      ggplot2::labs(
        x = result$metadata$group_label %||% "Grupo",
        y = result$metadata$value_label %||% "Valor"
      ) +
      ggplot2::theme_minimal(base_family = "IBM Plex Sans") +
      ggplot2::theme(legend.position = "none")
  }
)

#' Renderiza um AnalysisResult como especificação Plotly (data + layout)
#' @export
render_plotly <- function(result) {
  builder <- PLOTLY_BUILDERS[[result$analysis]]
  if (is.null(builder)) {
    stop(sprintf("Não existe renderer Plotly para a análise: %s", result$analysis))
  }

  plot <- builder(result)
  ggplotly_obj <- plotly::ggplotly(plot)

  jsonlite::fromJSON(
    plotly::plotly_json(ggplotly_obj, jsonedit = FALSE, pretty = FALSE),
    simplifyVector = FALSE
  )
}
