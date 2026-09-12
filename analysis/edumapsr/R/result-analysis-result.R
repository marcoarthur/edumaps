# R/result/analysis_result.R
#
# Objeto de resultado analítico. Toda função em R/analysis/ retorna um
# destes — nunca um ggplot, nunca um JSON, nunca uma escrita em banco.
# "A análise não exporta nada": quem decide o formato de saída é a
# camada de View (R/view/), e quem decide onde persistir é a camada de
# Repository (R/repository/). Isso é o que permite o mesmo AnalysisResult
# virar Plotly, JSON, PDF, ou uma linha em analytics.chart_cache sem
# tocar no código da análise.

#' Constrói um AnalysisResult
#'
#' @param analysis nome da análise (deve bater com uma chave em `analysis_registry`)
#' @param parameters lista dos parâmetros usados para gerar este resultado
#' @param data data.frame com os dados já processados pela análise (o que
#'   a View vai precisar pra desenhar — não é o dataset de entrada inteiro)
#' @param metrics lista nomeada de métricas escalares (ex.: média, mediana, n)
#' @param tables lista nomeada de data.frames auxiliares (ex.: tabela por grupo)
#' @param plots lista nomeada de especificações de plot pré-computadas (raramente
#'   usado — normalmente a View constrói o plot sob demanda a partir de `data`)
#' @param metadata lista livre (rótulos de eixo, labels, unidades etc.)
#' @export
new_analysis_result <- function(analysis,
                                 parameters = list(),
                                 data,
                                 metrics = list(),
                                 tables = list(),
                                 plots = list(),
                                 metadata = list()) {
  stopifnot(is.character(analysis), length(analysis) == 1)

  structure(
    list(
      analysis = analysis,
      parameters = parameters,
      data = data,
      metrics = metrics,
      tables = tables,
      plots = plots,
      metadata = metadata
    ),
    class = "analysis_result"
  )
}

#' @export
print.analysis_result <- function(x, ...) {
  cat(sprintf("<analysis_result: %s>\n", x$analysis))
  cat(sprintf("  linhas de dado: %d\n", NROW(x$data)))
  if (length(x$metrics) > 0) {
    cat("  métricas:\n")
    for (name in names(x$metrics)) {
      cat(sprintf("    %s: %s\n", name, format(x$metrics[[name]])))
    }
  }
  invisible(x)
}
