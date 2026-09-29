# R/analysis/network_profile.R
#
# Análise pura do PERFIL DA REDE (issue #109, roadmap do #105).
#
# Contrato:
#
#   network_profile_model
#            ↓
#   analyze_network_profile()
#            ↓
#      analysis_result
#
# Recebe do DataSource a distribuição por cluster e os indicadores da rede
# vs. Brasil; só reorganiza e resume. Não faz I/O.

#' Monta a análise do perfil da rede
#'
#' @param model objeto da classe `network_profile_model`.
#' @param parameters lista de parâmetros da execução (preservada).
#'
#' @return Objeto da classe `analysis_result`, com `tables$clusters`
#'   (longo por cluster/indicador) e `tables$indicadores` (rede vs. Brasil).
#'
#' @export
analyze_network_profile <- function(model, parameters = list()) {
  if (!inherits(model, "network_profile_model")) {
    stop_invalid_parameter("analyze_network_profile requer um network_profile_model")
  }

  clusters <- network_clusters(model)
  indicadores <- network_indicators(model)

  metrics <- list(
    n_escolas = model$metadata$n_escolas,
    n_clusters = model$metadata$n_clusters,
    n_brasil = model$metadata$n_brasil,
    n_indicadores = nrow(indicadores)
  )

  new_analysis_result(
    analysis = "network_profile",
    parameters = parameters,
    data = data.frame(),
    metrics = metrics,
    tables = list(
      clusters = clusters,
      indicadores = indicadores
    ),
    metadata = model$metadata
  )
}