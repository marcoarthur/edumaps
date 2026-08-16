test_that("run_analysis despacha para a análise certa via o registry", {
  model <- fixture_histogram_model()
  result <- run_analysis("histogram", model)
  expect_equal(result$analysis, "histogram")
})

test_that("run_analysis falha para um nome de análise fora do whitelist", {
  model <- fixture_histogram_model()
  expect_error(run_analysis("nao-existe", model), "desconhecida")
})

test_that("run_analysis exige um modelo semântico, não um data.frame cru", {
  expect_error(
    run_analysis("histogram", data.frame(value = 1:5)),
    "modelo semântico"
  )
})

test_that("run_analysis repassa parameters pra análise sem modificar", {
  model <- fixture_histogram_model()
  result <- run_analysis("histogram", model, parameters = list(municipio_id = 3550308))
  expect_equal(result$parameters$municipio_id, 3550308)
})
