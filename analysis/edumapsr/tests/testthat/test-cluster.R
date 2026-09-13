fixture_cluster_model <- function(n_per_group = 10) {
  set.seed(42)
  groups <- lapply(seq_len(4), function(g) {
    data.frame(
      co_entidade = sprintf("ESC%02d", seq_len(n_per_group) + (g - 1) * n_per_group),
      qt_mat_bas = rnorm(n_per_group, mean = g * 500, sd = 20),
      qt_doc_bas = rnorm(n_per_group, mean = g * 30, sd = 3),
      stringsAsFactors = FALSE
    )
  })
  new_school_cluster_model(
    data = do.call(rbind, groups),
    entity_id = "co_entidade",
    features = c("qt_mat_bas", "qt_doc_bas")
  )
}


test_that("kmeans agrupa dados bem separados", {
  model <- fixture_cluster_model()

  result <- analyze_cluster(model, list(algorithm = "kmeans", clusters = 4))

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "cluster_kmeans")
  expect_equal(result$metrics$n_entities, 40)
  expect_equal(result$metrics$n_clusters, 4)
  expect_equal(result$metrics$n_noise, 0)

  expect_true(all(result$data$cluster_id %in% c(1, 2, 3, 4)))
  expect_equal(nrow(result$tables$clusters), 4)
  expect_true(all(!result$tables$clusters$is_noise))
  expect_true(all(result$tables$clusters$cluster_size > 0))
})

test_that("kmeans preserva a ordem e os ids das entidades", {
  model <- fixture_cluster_model()

  result <- analyze_cluster(model, list(algorithm = "kmeans", clusters = 4))

  expect_equal(
    result$data[["co_entidade"]],
    cluster_entity_ids(model)
  )
})

test_that("dbscan marca ruído com cluster 0", {
  set.seed(42)
  cluster_a <- data.frame(
    school_id = sprintf("a%02d", seq_len(8)),
    x = rnorm(8, mean = 0, sd = 0.1),
    y = rnorm(8, mean = 0, sd = 0.1)
  )
  cluster_b <- data.frame(
    school_id = sprintf("b%02d", seq_len(8)),
    x = rnorm(8, mean = 5, sd = 0.1),
    y = rnorm(8, mean = 5, sd = 0.1)
  )
  outliers <- data.frame(
    school_id = c("out1", "out2"),
    x = c(12, 20),
    y = c(12, 20)
  )
  data <- rbind(cluster_a, cluster_b, outliers)
  data$school_id <- as.character(data$school_id)

  model <- new_school_cluster_model(
    data = data,
    entity_id = "school_id",
    features = c("x", "y")
  )

  result <- analyze_cluster(model, list(algorithm = "dbscan", eps = 0.5, min_pts = 4))

  expect_equal(result$analysis, "cluster_dbscan")
  expect_true(any(result$data$cluster_id == 0))
  expect_equal(result$metrics$n_noise, 2)
  expect_true(all(
    result$data$cluster_id[result$data[["school_id"]] %in% c("out1", "out2")] == 0
  ))
})

test_that("gmm agrupa dados bem separados", {
  model <- fixture_cluster_model()

  result <- analyze_cluster(model, list(algorithm = "gmm", clusters = 4))

  expect_equal(result$analysis, "cluster_gmm")
  expect_equal(result$metrics$n_clusters, 4)
  expect_true(all(result$data$cluster_id %in% 1:4))
})

test_that("spectral agrupa dados bem separados", {
  model <- fixture_cluster_model()

  result <- analyze_cluster(model, list(algorithm = "spectral", clusters = 4))

  expect_equal(result$analysis, "cluster_spectral")
  expect_equal(result$metrics$n_clusters, 4)
})

test_that("algoritmo desconhecido é erro do cliente", {
  model <- fixture_cluster_model()

  expect_error(
    analyze_cluster(model, list(algorithm = "hierarquico")),
    "Algoritmo de cluster desconhecido"
  )
})

test_that("k fora do intervalo [2,10] é erro do cliente", {
  model <- fixture_cluster_model()

  expect_error(
    analyze_cluster(model, list(algorithm = "kmeans", clusters = 1)),
    "clusters deve estar entre 2 e 10"
  )
})

test_that("eps inválido é erro do cliente", {
  model <- fixture_cluster_model()

  expect_error(
    analyze_cluster(model, list(algorithm = "dbscan", eps = -1)),
    "eps deve ser maior que zero"
  )
})

test_that("cluster requer ao menos duas entidades", {
  model <- new_school_cluster_model(
    data = data.frame(
      school_id = "unic",
      x = 10,
      y = 20
    ),
    entity_id = "school_id",
    features = c("x", "y")
  )

  expect_error(
    analyze_cluster(model, list(algorithm = "kmeans", clusters = 2)),
    "pelo menos duas"
  )
})

test_that("cluster requer features numéricas", {
  model <- new_school_cluster_model(
    data = data.frame(
      school_id = c("a", "b"),
      rede = c("municipal", "estadual")
    ),
    entity_id = "school_id",
    features = NULL
  )

  expect_error(
    analyze_cluster(model, list(algorithm = "kmeans", clusters = 2)),
    "cluster requer pelo menos uma feature numérica"
  )
})

test_that("IDs duplicados são rejeitados", {
  model <- new_school_cluster_model(
    data = data.frame(
      school_id = c("dup", "dup"),
      x = c(10, 20),
      y = c(20, 30)
    ),
    entity_id = "school_id",
    features = c("x", "y")
  )

  expect_error(
    analyze_cluster(model, list(algorithm = "kmeans", clusters = 2)),
    "IDs das entidades devem ser únicos"
  )
})

test_that("resultado dbscan pode ter clusters_df vazio (tudo ruído)", {
  set.seed(1)
  data <- data.frame(
    school_id = as.character(seq_len(20)),
    x = runif(20, 0, 100),
    y = runif(20, 0, 100)
  )

  model <- new_school_cluster_model(
    data = data,
    entity_id = "school_id",
    features = c("x", "y")
  )

  result <- analyze_cluster(model, list(algorithm = "dbscan", eps = 0.05, min_pts = 20))

  expect_equal(result$metrics$n_clusters, 0)
  expect_equal(nrow(result$tables$clusters), 0)
  expect_equal(result$metrics$n_noise, 20)
})