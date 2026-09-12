test_that("render_plotly gera uma especificação com data e layout para histogram", {
  model <- fixture_histogram_model()
  result <- analyze_histogram(model)
  plotly_spec <- render_plotly(result)

  expect_true("data" %in% names(plotly_spec))
  expect_true("layout" %in% names(plotly_spec))
})

test_that("render_plotly funciona pros três tipos de gráfico", {
  histogram_result <- analyze_histogram(fixture_histogram_model())
  scatter_result <- analyze_scatter(fixture_scatter_model())
  boxplot_result <- analyze_boxplot(fixture_boxplot_model())

  expect_true("data" %in% names(render_plotly(histogram_result)))
  expect_true("data" %in% names(render_plotly(scatter_result)))
  expect_true("data" %in% names(render_plotly(boxplot_result)))
})

test_that("render_plotly falha para uma análise sem builder registrado", {
  fake_result <- new_analysis_result(analysis = "nao-existe", data = data.frame())
  expect_error(render_plotly(fake_result), "Não existe renderer")
})

test_that("render_json devolve métricas e metadata sem depender de plotly", {
  result <- analyze_histogram(fixture_histogram_model())
  json <- render_json(result)

  expect_equal(json$analysis, "histogram")
  expect_equal(json$metrics$n, 9)
  expect_equal(json$metadata$x_label, "Infraestrutura")
})
