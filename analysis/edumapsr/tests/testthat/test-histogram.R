test_that("analyze_histogram calcula n, média e mediana corretamente", {
  model <- fixture_histogram_model(c(1, 2, 3, 4, 5))
  result <- analyze_histogram(model)

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "histogram")
  expect_equal(result$metrics$n, 5)
  expect_equal(result$metrics$mean, 3)
  expect_equal(result$metrics$median, 3)
  expect_equal(nrow(result$data), 5)
})

test_that("analyze_histogram usa o rótulo do modelo semântico", {
  model <- fixture_histogram_model()
  result <- analyze_histogram(model)
  expect_equal(result$metadata$x_label, "Infraestrutura")
})

test_that("analyze_histogram falha com mensagem clara se o model não tem `value`", {
  model_sem_value <- new_school_indicator_model(data.frame(x_value = 1:3))
  expect_error(analyze_histogram(model_sem_value), "requer")
})
