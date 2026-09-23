test_that("chat_chart_tipo_valid reconhece apenas tipos suportados", {
  expect_true(all(edumapsAnalytics:::chat_chart_tipo_valid(c("barra", "linha", "pizza"))))
  expect_false(edumapsAnalytics:::chat_chart_tipo_valid("scatter"))
  expect_false(edumapsAnalytics:::chat_chart_tipo_valid(""))
  expect_false(edumapsAnalytics:::chat_chart_tipo_valid(NULL))
})

test_that("chat_chart_plotly_json monta {data, layout} para barra", {
  df <- data.frame(escola = c("A", "B", "C"), mat = c(10, 20, 30))
  g <- edumapsAnalytics:::chat_chart_plotly_json(df, "barra", "escola", "mat", "Matr\u00edculas")
  expect_type(g, "list")
  expect_equal(g$data[[1]]$type, "bar")
  expect_equal(g$data[[1]]$x, c("A", "B", "C"))
  expect_equal(g$layout$title$text, "Matr\u00edculas")
  expect_equal(g$layout$xaxis$title, "escola")
  expect_equal(g$layout$yaxis$title, "mat")
})

test_that("chat_chart_plotly_json monta linha e pizza", {
  df <- data.frame(ano = c(2019, 2020, 2021), nota = c(5, 6, 7))
  linha <- edumapsAnalytics:::chat_chart_plotly_json(df, "linha", "ano", "nota", "Nota")
  expect_equal(linha$data[[1]]$mode, "lines+markers")
  expect_equal(linha$data[[1]]$type, "scatter")

  pizza <- edumapsAnalytics:::chat_chart_plotly_json(df, "pizza", "ano", "nota", "Distribui\u00e7\u00e3o")
  expect_equal(pizza$data[[1]]$type, "pie")
  expect_equal(pizza$data[[1]]$labels, df$ano)
  expect_null(pizza$layout$yaxis$title)
})

test_that("chat_chart_plotly_json devolve NULL para config invalida", {
  df <- data.frame(escola = c("A", "B"), mat = c(1, 2))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(df, "scatter", "escola", "mat"))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(df, "barra", "inexistente", "mat"))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(df, "barra", "escola", "inexistente"))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(data.frame(), "barra", "escola", "mat"))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(NULL, "barra", "escola", "mat"))
  expect_null(edumapsAnalytics:::chat_chart_plotly_json(df, "barra", "escola", "escola"))
})