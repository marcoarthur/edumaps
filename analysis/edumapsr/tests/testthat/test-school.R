test_that("accessors do school_indicator_model leem as colunas certas", {
  model <- fixture_boxplot_model()

  expect_equal(sample_size(model), 9)
  expect_equal(length(unique(groups(model))), 3)
  expect_equal(indicator_label(model, "value"), "IDEB")
  expect_equal(indicator_label(model, "group"), "Rede")
})

test_that("indicator_label cai pro rótulo default quando a metadata não tem", {
  model <- new_school_indicator_model(data.frame(value = 1:3))
  expect_equal(indicator_label(model, "value"), "Valor")
  expect_equal(indicator_label(model, "group"), "Grupo")
})

test_that("values_x/values_y retornam NULL quando o model não tem essas colunas", {
  model <- fixture_histogram_model()
  expect_null(values_x(model))
  expect_null(values_y(model))
})
