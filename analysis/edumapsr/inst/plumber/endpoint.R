# inst/plumber/endpoints.R
#
# Camada HTTP do Controller.
#
# A especificação OpenAPI da API está em api.json e é carregada pelo
# entrypoint do Plumber. Este arquivo contém apenas os endpoints.

# Operador null-default (rlang). Definido localmente para o runtime não
# depender de rlang no container analytic.
`%||%` <- function(x, y) if (is.null(x)) y else x

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

#* @post /cluster
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "staging"
  output_schema <- payload$output_schema %||% "analytics"

  tryCatch(
    {
      con <- analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_entity_source(con)

      model <- load_cluster_dataset(
        source,
        schema = schema,
        table_name = payload$table_name,
        id_column = payload$id_column,
        features = payload$features %||% NULL
      )

      result <- run_cluster(
        model,
        parameters = payload$parameters %||% list()
      )

      persisted <- persist_cluster_result(
        result,
        postgres_cluster_repository(con),
        schema = schema,
        table_name = payload$table_name,
        id_column = payload$id_column,
        output_schema = output_schema
      )

      body <- export_result(result, "json")
      body$persisted <- persisted
      body
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /cluster: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao computar o clustering")
    }
  )
}

#* @post /summary
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"

  tryCatch(
    {
      con <- analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_source(con)

      model <- load_city_dataset(
        source,
        codigo_ibge = payload$codigo_ibge,
        schema = schema
      )

      result <- run_city_summary(
        model,
        parameters = payload$parameters %||% list()
      )

      persisted <- persist_city_summary_result(
        result,
        postgres_city_repository(con),
        output_schema = output_schema
      )

      body <- export_result(result, "json")
      body$persisted <- persisted
      body
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /summary: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao gerar o resumo da cidade")
    }
  )
}

#* @post /similarity/db
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "staging"
  output_schema <- payload$output_schema %||% "analytics"
  target_table <- payload$target_table %||% "censo_escolas"

  tryCatch(
    {
      con <- analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_source(con)
      id_column <- payload$id_column %||% "co_entidade"

      model <- load_similarity_dataset(
        source,
        schema = schema,
        table_name = payload$table_name %||% target_table,
        id_column = id_column,
        features = payload$features %||% NULL
      )

      result <- run_similarity(
        model,
        parameters = payload$variables %||% list()
      )

      persisted <- persist_similarity_pairs_result(
        result,
        postgres_similarity_repository(con),
        target_table = paste0(schema, ".", payload$table_name %||% target_table),
        metric = "gower",
        id_column = id_column,
        params = payload$variables %||% list(),
        output_schema = output_schema
      )

      body <- export_result(result, "json")
      body$persisted <- persisted
      body
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /similarity/db: %s\n",
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
