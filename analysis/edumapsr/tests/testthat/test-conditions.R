test_that("stop_invalid_analysis sinaliza invalid_analysis e edumaps_client_error", {
  expect_error(stop_invalid_analysis("x"), class = "invalid_analysis")
  expect_error(stop_invalid_analysis("x"), class = "edumaps_client_error")
})

test_that("stop_invalid_parameter sinaliza invalid_parameter", {
  expect_error(stop_invalid_parameter("x"), class = "invalid_parameter")
})

test_that("stop_invalid_dataset sinaliza invalid_dataset", {
  expect_error(stop_invalid_dataset("x"), class = "invalid_dataset")
})

test_that("run_analysis falha com invalid_analysis para nome fora do registry", {
  model <- fixture_histogram_model()
  expect_error(run_analysis("nao-existe", model), class = "invalid_analysis")
})

test_that("run_analysis falha com invalid_parameter quando não recebe um modelo semântico", {
  expect_error(run_analysis("histogram", data.frame(value = 1:5)), class = "invalid_parameter")
})

test_that("run_analysis falha com invalid_dataset quando o model não tem os campos exigidos", {
  model_sem_group <- new_school_indicator_model(data.frame(value = 1:5))
  expect_error(run_analysis("boxplot", model_sem_group), class = "invalid_dataset")
})

test_that("run_analysis passa quando o model tem todos os campos exigidos", {
  model <- fixture_boxplot_model()
  expect_no_error(run_analysis("boxplot", model))
})
