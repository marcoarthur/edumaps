# R/app/tasks.R
#
# Fachadas de compatibilidade com jobs batch — o que o documento de
# arquitetura chama de "compute_and_save_*() deixa de ser a unidade
# fundamental, passa a ser apenas uma fachada". Pensado pra uma futura
# task batch (Minion no lado Perl, ou um cron chamando `Rscript -e
# 'edumapsAnalytics::compute_and_save_school_chart(...)'`).
#
# O caminho HTTP ao vivo (inst/plumber/endpoints.R) NÃO usa isto — ele
# chama run_analysis()/render_plotly() diretamente e deixa o Perl gravar
# o cache, porque é lá que o cache_key e o whitelist de variáveis já são
# validados por requisição. Esta função é o exemplo de como uma análise
# batch fica no mesmo padrão, agora com PostgresSource + Repository.

#' Calcula um gráfico de indicador escolar e persiste no cache do Postgres
#'
#' @param con conexão DBI ativa
#' @param indicator_id ver INDICATOR_WHITELIST em postgres_source.R
#' @param chart_type "histogram" | "scatter" | "boxplot"
#' @param rede "todas" | "municipal" | "estadual" | "privada"
#' @param municipio_id inteiro ou NULL
#' @param feature nome da feature (coluna `feature` em analytics.chart_cache)
#' @param cache_key chave já calculada (mesmo esquema usado no lado Perl:
#'   SHA-256 de {feature, chart_type, variables, filters} canônico)
#' @export
compute_and_save_school_chart <- function(con, indicator_id, chart_type,
                                           rede = "todas", municipio_id = NULL,
                                           feature = "escola", cache_key) {
  source <- postgres_source(con)
  model <- load_dataset(source, indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)

  parameters <- list(indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)
  result <- run_analysis(chart_type, model, parameters)

  repository <- postgres_repository(con)
  persist_result(result, repository, feature = feature, cache_key = cache_key)

  invisible(result)
}
