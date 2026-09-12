# inst/plumber/endpoints.R
#
# Camada HTTP do Controller.
#
# A especificação OpenAPI da API está em api.json e é carregada pelo
# entrypoint do Plumber. Este arquivo contém apenas os endpoints.

#* @post /chart
function(req, res) {
  payload <- req$body

  tryCatch(
    {
      source <- memory_source(
        payload$data,
        metadata = payload$variables %||% list()
      )

      model <- load_dataset(source)

      result <- run_analysis(
        payload$chart_type,
        model,
        payload$variables %||% list()
      )

      export_result(result, "plotly")
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /chart: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao gerar o gráfico")
    }
  )
}

#* @post /similarity
function(req, res) {
  payload <- req$body
  variables <- payload$variables %||% list()

  tryCatch(
    {
      source <- memory_similarity_source(
        rows = payload$data,
        entity_id = variables$entity_id %||% "school_id",
        features = variables$features,
        metadata = variables
      )

      model <- load_similarity_dataset(source)

      result <- run_similarity(
        model,
        parameters = variables
      )

      export_result(result, "json")
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /similarity: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao calcular similaridade")
    }
  )
}

#* @get /health
function() {
  list(status = "ok")
}
