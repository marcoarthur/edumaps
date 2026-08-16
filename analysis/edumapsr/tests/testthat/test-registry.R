test_that("cada entrada do analysis_registry tem fn/required/view", {
  for (name in names(analysis_registry)) {
    entry <- analysis_registry[[name]]
    expect_true(is.function(entry$fn), info = name)
    expect_true(is.character(entry$required), info = name)
    expect_true(is.character(entry$view) && length(entry$view) == 1, info = name)
  }
})

test_that("required do histogram é `value`, do scatter é `x`/`y`, do boxplot é `value`/`group`", {
  expect_equal(analysis_registry$histogram$required, "value")
  expect_equal(analysis_registry$scatter$required, c("x", "y"))
  expect_equal(analysis_registry$boxplot$required, c("value", "group"))
})
