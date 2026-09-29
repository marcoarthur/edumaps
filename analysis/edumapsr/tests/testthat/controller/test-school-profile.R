test_that("run_analysis despacha school_profile via o registry", {
  model <- fixture_school_profile_model()
  result <- run_analysis("school_profile", model)
  expect_equal(result$analysis, "school_profile")
})

test_that("run_analysis recusa modelo semântico de outra classe para school_profile", {
  expect_error(
    run_analysis("school_profile", fixture_histogram_model()),
    "modelo semântico"
  )
})

test_that("run_analysis repassa parameters para o perfil", {
  model <- fixture_school_profile_model()
  result <- run_analysis(
    "school_profile", model,
    parameters = list(co_entidade = "23165669")
  )
  expect_equal(result$parameters$co_entidade, "23165669")
})
