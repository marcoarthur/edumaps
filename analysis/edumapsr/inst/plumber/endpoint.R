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
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_entity_source(con)

      model <- load_cluster_dataset(
        source,
        schema = schema,
        table_name = payload$table_name,
        id_column = payload$id_column,
        features = payload$features %||% NULL,
        filter = payload$filter %||% NULL
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
      con <- edumapsAnalytics:::analytics_db_connection()
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
      con <- edumapsAnalytics:::analytics_db_connection()
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

#* @post /ask
function(req, res) {
  payload <- req$body

  tryCatch(
    ask_censo(
      pergunta = payload$pergunta %||% NULL,
      contexto = payload$contexto %||% list(),
      config   = payload$config %||% NULL
    ),
    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e), tipo = "invalid_request")
    },
    chat_provider_error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] provedor LLM indisponível em /ask: %s\n",
        conditionMessage(e)
      ))
      res$status <- 502
      list(error = "Falha ao conversar com o modelo de linguagem", tipo = "provider")
    },
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /ask: %s\n",
        conditionMessage(e)
      ))
      res$status <- 500
      list(error = "Erro interno ao processar a pergunta", tipo = "internal")
    }
  )
}

#* @post /school_profile
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"
  co_entidade <- as.character(payload$co_entidade %||% "")

  # Serializador explícito: garante escalares como `cached`/`computed_at`
  # mesmo quando o payload vem do cache (round-trip JSON perde os marcadores
  # `unbox`); arrays (listas) permanecem arrays.
  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_source(con)

      # Read-through: perfil materializado que bate o ano do censo é
      # devolvido sem recomputar (a menos que `refresh = true`).
      if (!isTRUE(payload$refresh) && grepl("^[0-9]{8}$", co_entidade)) {
        ano <- edumapsAnalytics:::resolve_censo_ano(con, schema)
        cached <- read_school_profile_cache(
          postgres_school_profile_repository(con),
          co_entidade,
          ano,
          output_schema = output_schema
        )
        if (!is.null(cached)) {
          body <- cached$payload
          body$metadata$cached <- jsonlite::unbox(TRUE)
          body$metadata$computed_at <- jsonlite::unbox(cached$computed_at)
          return(body)
        }
      }

      model <- load_school_profile_dataset(
        source,
        co_entidade = co_entidade,
        schema = schema,
        include_inactive = isTRUE(payload$include_inactive),
        clusters = payload$clusters %||% 4,
        similarity_threshold = payload$similarity_threshold %||% 0.3,
        output_schema = output_schema
      )

      result <- run_school_profile(
        model,
        parameters = list(co_entidade = co_entidade)
      )

      body <- export_result(result, "json")
      body$metadata$cached <- jsonlite::unbox(FALSE)
      body$metadata$computed_at <- jsonlite::unbox(format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"))

      if (isTRUE(payload$persist)) {
        persisted <- persist_school_profile_result(
          result,
          postgres_school_profile_repository(con),
          output_schema = output_schema
        )
        body$persisted <- persisted
      }

      body
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /school_profile: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao gerar o perfil da escola")
    }
  )
}

#* @post /school_profile/reference
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"

  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      compute_and_save_school_profile_reference(
        con,
        nu_ano_censo = payload$nu_ano_censo,
        schema = schema,
        include_inactive = isTRUE(payload$include_inactive),
        output_schema = output_schema
      )
    },
    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /school_profile/reference: %s\n",
        conditionMessage(e)
      ))
      res$status <- 500
      list(error = "Erro interno ao materializar as referências do perfil")
    }
  )
}

#* @post /school_profile/cluster
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"

  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      compute_and_save_school_cluster_profile(
        con,
        nu_ano_censo = payload$nu_ano_censo,
        schema = schema,
        include_inactive = isTRUE(payload$include_inactive),
        output_schema = output_schema
      )
    },
    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /school_profile/cluster: %s\n",
        conditionMessage(e)
      ))
      res$status <- 500
      list(error = "Erro interno ao materializar os percentis de cluster")
    }
  )
}

#* @post /school_profile/batch
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"

  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      compute_and_save_school_profiles(
        con,
        scope = payload$scope %||% "pending",
        co_municipio = payload$co_municipio,
        sg_uf = payload$sg_uf,
        limit = payload$limit %||% 500,
        schema = schema,
        output_schema = output_schema
      )
    },
    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /school_profile/batch: %s\n",
        conditionMessage(e)
      ))
      res$status <- 500
      list(error = "Erro interno ao materializar o perfil das escolas")
    }
  )
}

#* @post /school_evolution
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"

  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_source(con)

      model <- load_school_evolution_dataset(
        source,
        co_entidade = payload$co_entidade,
        schema = schema
      )

      result <- run_school_evolution(
        model,
        parameters = list(co_entidade = payload$co_entidade)
      )

      export_result(result, "json")
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /school_evolution: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao gerar a evolução da escola")
    }
  )
}

#* @post /network_profile
function(req, res) {
  payload <- req$body
  schema <- payload$schema %||% "clean"
  output_schema <- payload$output_schema %||% "analytics"

  res$serializer <- plumber::serializer_json(auto_unbox = TRUE, na = "null", null = "null")

  tryCatch(
    {
      con <- edumapsAnalytics:::analytics_db_connection()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      source <- postgres_source(con)

      model <- load_network_profile_dataset(
        source,
        codigo_ibge = payload$codigo_ibge,
        tp_dependencia = payload$tp_dependencia,
        schema = schema,
        output_schema = output_schema
      )

      result <- run_network_profile(
        model,
        parameters = list(
          codigo_ibge = payload$codigo_ibge,
          tp_dependencia = payload$tp_dependencia
        )
      )

      export_result(result, "json")
    },

    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },

    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] erro interno em /network_profile: %s\n",
        conditionMessage(e)
      ))

      res$status <- 500
      list(error = "Erro interno ao gerar o perfil da rede")
    }
  )
}

#* @get /health
function() {
  list(status = "ok")
}
