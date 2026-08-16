# R/app/application.R
#
# Fachada funcional (não OO — combina melhor com o ecossistema R e deixa
# tudo testável como função pura, seguindo a preferência do documento de
# arquitetura). É o que um script/endpoint chama do início ao fim:
#
#   model  <- load_dataset(source, ...)
#   result <- run_analysis(name, model, parameters)
#   export_result(result, "json")
#   persist_result(result, repository)

#' Carrega um SchoolIndicatorModel a partir de qualquer DataSource
#' (memory_source, postgres_source, ou uma futura parquet_source/csv_source)
#' @export
load_dataset <- function(source, ...) load_school_indicator(source, ...)

#' Renderiza um AnalysisResult no formato pedido
#' @param format "plotly" ou "json"
#' @export
export_result <- function(result, format = c("plotly", "json")) {
  format <- match.arg(format)
  switch(format,
    plotly = render_plotly(result),
    json = render_json(result)
  )
}

#' Persiste um AnalysisResult usando um Repository
#' @export
persist_result <- function(result, repository, ...) {
  persist(repository, result, ...)
}
