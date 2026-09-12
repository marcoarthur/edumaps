fixture_similarity_model <- function() {
  new_school_similarity_model(
    data = data.frame(
      school_id = c(1, 2, 3),
      infrastructure = c(10, 10, 0),
      capacity = c(10, 8, 0),
      diversity = c(10, 9, 0)
    ),
    entity_id = "school_id",
    features = c(
      "infrastructure",
      "capacity",
      "diversity"
    )
  )
}


test_that("Gower similarity produz pares", {
  model <- fixture_similarity_model()

  result <- analyze_gower_similarity(model)

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "gower_similarity")

  expect_equal(result$metrics$n_entities, 3)
  expect_equal(result$metrics$n_features, 3)
  expect_equal(result$metrics$n_pairs, 3)

  expect_true(
    all(result$data$similarity >= 0) &&
      all(result$data$similarity <= 1)
  )
})


test_that("Gower similarity é simétrica e gera cada par uma vez", {
  model <- fixture_similarity_model()

  result <- analyze_gower_similarity(model)

  pairs <- result$data

  expect_equal(
    nrow(pairs),
    choose(3, 2)
  )

  expect_false(
    any(pairs$entity_id_a == pairs$entity_id_b)
  )
})


test_that("similaridade de entidade idêntica é 1", {
  model <- new_school_similarity_model(
    data = data.frame(
      school_id = c(1, 2),
      infrastructure = c(10, 10),
      capacity = c(5, 5),
      diversity = c(8, 8)
    ),
    entity_id = "school_id",
    features = c(
      "infrastructure",
      "capacity",
      "diversity"
    )
  )

  result <- analyze_gower_similarity(model)

  expect_equal(
    result$data$similarity,
    1
  )

  expect_equal(
    result$data$distance,
    0
  )
})


test_that("análise exige pelo menos duas entidades", {
  model <- new_school_similarity_model(
    data = data.frame(
      school_id = 1,
      infrastructure = 10
    ),
    entity_id = "school_id",
    features = "infrastructure"
  )

  expect_error(
    analyze_gower_similarity(model),
    "pelo menos duas"
  )
})
