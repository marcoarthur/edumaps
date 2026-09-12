# tests/testthat/test-analysis-result.R
#
# Até agora new_analysis_result() só era exercitado indiretamente, através
# de analyze_histogram()/scatter()/boxplot(). Este arquivo testa o
# construtor e o print() diretamente, como um contrato próprio — ele é o
# objeto que conecta análise, view e repository, então vale a pena travar
# seu formato explicitamente.

test_that("new_analysis_result() preenche todos os campos do contrato", {
  result <- new_analysis_result(
    analysis = "histogram",
    parameters = list(municipio_id = 123),
    data = data.frame(value = 1:3),
    metrics = list(n = 3, mean = 2),
    tables = list(resumo = data.frame(a = 1)),
    plots = list(),
    metadata = list(x_label = "Infraestrutura")
  )

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "histogram")
  expect_equal(result$parameters, list(municipio_id = 123))
  expect_equal(result$data, data.frame(value = 1:3))
  expect_equal(result$metrics, list(n = 3, mean = 2))
  expect_equal(result$tables$resumo, data.frame(a = 1))
  expect_equal(result$metadata, list(x_label = "Infraestrutura"))
})

test_that("new_analysis_result() usa listas vazias como padrão pra parameters/metrics/tables/plots/metadata", {
  result <- new_analysis_result(analysis = "histogram", data = data.frame(value = 1))

  expect_equal(result$parameters, list())
  expect_equal(result$metrics, list())
  expect_equal(result$tables, list())
  expect_equal(result$plots, list())
  expect_equal(result$metadata, list())
})

test_that("new_analysis_result() exige `analysis` como string única", {
  expect_error(new_analysis_result(analysis = c("a", "b"), data = data.frame()))
  expect_error(new_analysis_result(analysis = 123, data = data.frame()))
})

test_that("print.analysis_result() imprime o nome da análise e as métricas", {
  result <- new_analysis_result(
    analysis = "histogram",
    data = data.frame(value = 1:5),
    metrics = list(n = 5, mean = 3)
  )

  expect_output(print(result), "histogram")
  expect_output(print(result), "n: 5")
})

test_that("print.analysis_result() funciona mesmo sem métricas", {
  result <- new_analysis_result(analysis = "histogram", data = data.frame(value = 1:5))
  expect_output(print(result), "histogram")
})

test_that("print.analysis_result() devolve o objeto de forma invisível", {
  result <- new_analysis_result(analysis = "histogram", data = data.frame(value = 1:5))
  expect_invisible(print(result))
})
