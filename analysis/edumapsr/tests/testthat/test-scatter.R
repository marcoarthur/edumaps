test_that("analyze_scatter calcula n e correlação", {
  model <- fixture_scatter_model(30)
  result <- analyze_scatter(model)

  expect_equal(result$analysis, "scatter")
  expect_equal(result$metrics$n, 30)
  # x e y são correlacionados por construção na fixture (y = x + ruído pequeno)
  expect_true(result$metrics$correlation > 0.5)
})

test_that("analyze_scatter falha se faltar x_value ou y_value", {
  model_incompleto <- new_school_indicator_model(data.frame(x_value = 1:5))
  expect_error(analyze_scatter(model_incompleto), "requer")
})
