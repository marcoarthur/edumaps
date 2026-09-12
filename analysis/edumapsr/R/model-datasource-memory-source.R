# R/model/datasource/memory_source.R
#
# DataSource "em memória": os dados já chegaram prontos, tipicamente via
# HTTP — extraídos e validados pelo Perl com SQL parametrizado contra um
# whitelist de colunas/indicadores (ver EduMaps::Model::Chart::School no
# lado Perl). Esta é a fonte usada pelo endpoint /chart ao vivo.
#
# Decisão de segurança deliberada: neste caminho o R NUNCA executa SQL —
# ele nem precisa ter credencial de banco. Uma requisição HTTP arbitrária
# nunca chega a construir uma query. Para pipelines batch/offline (jobs
# agendados, não uma requisição de um visitante do site), ver
# postgres_source.R — ali uma conexão direta ao banco é um risco
# aceitável, porque a query é fixa/paramétrica e não depende de input
# externo por requisição.

#' Generic: carrega um SchoolIndicatorModel a partir de uma fonte
#' @export
load_school_indicator <- function(source, ...) UseMethod("load_school_indicator")

#' Cria uma fonte de dados em memória a partir de um payload já extraído
#'
#' @param rows lista de listas (ou data.frame) — uma linha por observação,
#'   já no formato que o modelo semântico espera (`value`, `x_value`/
#'   `y_value`, ou `value`/`group`, dependendo da análise)
#' @param metadata lista livre de metadados (rótulos, labels de eixo etc.)
#' @export
memory_source <- function(rows, metadata = list()) {
  structure(list(rows = rows, metadata = metadata), class = c("memory_source", "data_source"))
}

#' @export
load_school_indicator.memory_source <- function(source, ...) {
  new_school_indicator_model(
    data = as.data.frame(source$rows),
    metadata = source$metadata
  )
}
