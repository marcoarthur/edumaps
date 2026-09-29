# tests/testthat/test-school-evolution.R
#
# Testa a análise PURA da evolução da escola (issue #110) e o reshape do
# DataSource. Sem banco.

test_that("analyze_school_evolution devolve a série em data e o resumo", {
  result <- analyze_school_evolution(fixture_school_evolution_model())

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "school_evolution")
  expect_true(is.data.frame(result$data))
  expect_true(all(c("indicador", "ano", "etapa", "valor") %in% names(result$data)))
  expect_equal(nrow(result$data), 8)

  resumo <- result$tables$resumo
  expect_equal(nrow(resumo), 2) # 2 séries (ideb/fundamental_ii + saeb_media)
  expect_true(all(c("indicador", "n_anos", "variacao") %in% names(resumo)))
  ideb <- resumo[resumo$indicador == "ideb_observado", ]
  expect_equal(ideb$n_anos, 4)
  expect_equal(ideb$ano_min, 2017)
  expect_equal(ideb$ano_max, 2023)
})

test_that("metrics resumem a série", {
  result <- analyze_school_evolution(fixture_school_evolution_model())

  expect_equal(result$metrics$n_series, 8)
  expect_equal(result$metrics$n_indicadores, 2)
  expect_equal(result$metrics$ano_min, 2017)
  expect_equal(result$metrics$ano_max, 2023)
})

test_that("escola sem histórico devolve série vazia válida", {
  model <- new_school_evolution_model(
    data = data.frame(
      indicador = character(0), label = character(0), ano = integer(0),
      etapa = character(0), valor = numeric(0), stringsAsFactors = FALSE
    ),
    metadata = list(co_entidade = "23165669")
  )

  result <- analyze_school_evolution(model)

  expect_equal(nrow(result$data), 0)
  expect_equal(nrow(result$tables$resumo), 0)
  expect_true(is.na(result$metrics$ano_min))
})

test_that("analyze_school_evolution rejeita modelo de outra classe", {
  expect_error(
    analyze_school_evolution(fixture_school_profile_model()),
    "school_evolution_model"
  )
})

test_that(".school_evolution_bind monta a série longa e descarta NA", {
  ideb <- data.frame(
    ano = c(2021, 2023), etapa = c("fundamental_ii", "fundamental_ii"),
    ideb_observado = c(5.1, NA_real_), stringsAsFactors = FALSE
  )
  saeb <- data.frame(
    ano = c(2021, 2023), nota_mat = c(250, 255), nota_por = c(240, 245),
    nota_media = c(5.0, 5.2), stringsAsFactors = FALSE
  )

  long <- .school_evolution_bind(ideb, saeb)

  expect_setequal(unique(long$indicador), c("ideb_observado", "saeb_media", "saeb_matematica", "saeb_portugues"))
  # o ideb NA de 2023 é descartado
  ideb_rows <- long[long$indicador == "ideb_observado", ]
  expect_equal(nrow(ideb_rows), 1)
  expect_equal(ideb_rows$ano, 2021)
})

test_that("run_analysis despacha school_evolution via o registry", {
  result <- run_analysis("school_evolution", fixture_school_evolution_model())
  expect_equal(result$analysis, "school_evolution")
})
