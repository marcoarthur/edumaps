# tests/testthat/test-architecture.R
#
# Testes "de arquitetura": em vez de testar cada análise individualmente
# ("histogram funciona"), testam que TODA entrada do analysis_registry
# obedece ao mesmo contrato ("toda análise registrada funciona"). O valor
# disso cresce com o número de análises — hoje protege 3 entradas, mas é
# a mesma quantidade de código pra proteger 30.
#
#   analysis_registry
#          │
#          ├── fn existe e é função
#          ├── required existe e é character
#          └── view existe
#                   │
#                   ▼
#             fn(model, parameters) → analysis_result válido
#                   │
#                   ▼
#             export_result(result, view) → renderer funciona
#
# Se uma análise nova entrar no registry sem seguir o contrato (ex.:
# esqueceram de registrar `required`, ou a função não devolve um
# analysis_result), estes testes falham sem precisar escrever um teste
# específico pra ela.

# Fixture genérica: monta um school_indicator_model com exatamente as
# colunas que uma lista de `required` pede, com dados sintéticos válidos.
# Não depende das fixtures de cada análise (fixture_histogram_model etc.)
# de propósito — assim este arquivo não precisa mudar quando uma análise
# nova entrar no registry, só a análise nova precisa declarar `required`
# corretamente.
fixture_model_for_required <- function(required) {
  n <- 9
  data <- list()
  if ("value" %in% required) data$value <- c(5, 6, 7, 8, 9, 10, 4, 6, 8)
  if ("x" %in% required) data$x_value <- seq_len(n)
  if ("y" %in% required) data$y_value <- seq_len(n) * 2
  if ("group" %in% required) data$group <- rep(c("a", "b", "c"), length.out = n)

  new_school_indicator_model(data = as.data.frame(data), metadata = list())
}

test_that("toda entrada do analysis_registry tem fn/required/view no formato certo", {
  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]

    expect_true(is.function(entry$fn), info = sprintf("%s: fn deve ser uma função", name))
    expect_true(is.character(entry$required), info = sprintf("%s: required deve ser character", name))
    expect_true(
      is.character(entry$view) && length(entry$view) == 1,
      info = sprintf("%s: view deve ser uma string única", name)
    )
  }
})

test_that("todo campo em `required` corresponde a um accessor real do modelo semântico", {
  known_accessors <- c("value", "x", "y", "group")

  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]
    unknown_fields <- setdiff(entry$required, known_accessors)
    expect_true(
      length(unknown_fields) == 0,
      info = sprintf(
        "%s: required tem campo(s) sem accessor conhecido: %s",
        name, paste(unknown_fields, collapse = ", ")
      )
    )
  }
})

test_that("fn(model, parameters) de toda análise registrada devolve um analysis_result válido", {
  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]
    model <- fixture_model_for_required(entry$required)

    result <- entry$fn(model, list())

    expect_s3_class(result, "analysis_result")
    expect_equal(result$analysis, name)
    expect_true(is.list(result$metrics), info = sprintf("%s: metrics deveria ser lista", name))
    expect_true(is.data.frame(result$data), info = sprintf("%s: data deveria ser data.frame", name))
  }
})

test_that("run_analysis() aceita o fixture genérico pra toda análise registrada", {
  # roda via Controller (não direto por entry$fn) — cobre também a
  # validação de required fields do run_analysis, não só a análise em si.
  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]
    model <- fixture_model_for_required(entry$required)

    expect_no_error(run_analysis(name, model))
  }
})

test_that("toda análise registrada tem um renderer funcionando para o `view` declarado", {
  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]
    model <- fixture_model_for_required(entry$required)
    result <- run_analysis(name, model)

    rendered <- export_result(result, entry$view)

    if (entry$view == "plotly") {
      expect_true("data" %in% names(rendered), info = sprintf("%s: renderer plotly sem 'data'", name))
      expect_true("layout" %in% names(rendered), info = sprintf("%s: renderer plotly sem 'layout'", name))
    } else if (entry$view == "json") {
      expect_true(is.list(rendered), info = sprintf("%s: renderer json não devolveu lista", name))
    }
  }
})
