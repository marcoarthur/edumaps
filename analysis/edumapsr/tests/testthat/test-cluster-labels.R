# tests/testthat/test-cluster-labels.R
#
# Descrição em linguagem natural dos clusters (R/cluster-labels.R + integração
# em analyze_cluster). Cobre a gradação por nº de clusters, polaridade das
# features, fallback inteiro e o rótulo de ruído (dbscan).

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

test_that(".label_scale devolve a gradação certa por nº de clusters", {
  expect_null(edumapsAnalytics:::.label_scale(1))
  expect_equal(edumapsAnalytics:::.label_scale(2), c("baixa", "alta"))
  expect_equal(edumapsAnalytics:::.label_scale(3), c("baixa", "média", "alta"))
  expect_equal(
    edumapsAnalytics:::.label_scale(4),
    c("muito baixa", "baixa", "alta", "muito alta")
  )
  expect_equal(
    edumapsAnalytics:::.label_scale(5),
    c("muito baixa", "baixa", "média", "alta", "muito alta")
  )
  expect_null(edumapsAnalytics:::.label_scale(6)) # excessivo -> fallback inteiro
})

test_that(".label_scale respeita o gênero masculino", {
  expect_equal(edumapsAnalytics:::.label_scale(3, "m"), c("baixo", "médio", "alto"))
  expect_equal(edumapsAnalytics:::.label_scale(2, "m"), c("baixo", "alto"))
})

test_that(".cluster_scores aplica a polaridade das features", {
  means <- rbind(
    c(qt_mat_bas = 100, qt_doc_bas = 10),
    c(qt_mat_bas = 500, qt_doc_bas = 50)
  )
  rownames(means) <- c("1", "2")

  positive <- edumapsAnalytics:::.cluster_scores(
    means, c("qt_mat_bas", "qt_doc_bas"),
    directions = c(qt_mat_bas = 1, qt_doc_bas = 1)
  )
  expect_gt(positive[["2"]], positive[["1"]])

  # invertendo a polaridade, a ordem inverte
  negative <- edumapsAnalytics:::.cluster_scores(
    means, c("qt_mat_bas", "qt_doc_bas"),
    directions = c(qt_mat_bas = -1, qt_doc_bas = -1)
  )
  expect_gt(negative[["1"]], negative[["2"]])
})

test_that(".cluster_labels marca ruído e ordena por score", {
  labels <- edumapsAnalytics:::.cluster_labels(
    cluster_ids = c(0, 1, 2),
    scores = c(`1` = 0.2, `2` = 0.8),
    concept = "qualidade de infraestrutura",
    gender = "f"
  )

  expect_equal(labels$cluster_id, c(0, 1, 2))
  expect_equal(labels$cluster_label[labels$cluster_id == 0], "Ruído")
  expect_true(is.na(labels$cluster_rank[labels$cluster_id == 0]))
  expect_equal(labels$cluster_label[labels$cluster_id == 1], "Baixa qualidade de infraestrutura")
  expect_equal(labels$cluster_label[labels$cluster_id == 2], "Alta qualidade de infraestrutura")
})

test_that("analyze_cluster rotula 3 clusters como baixa/média/alta", {
  model <- fixture_cluster_model()
  result <- analyze_cluster(model, list(
    algorithm = "kmeans", clusters = 3,
    labeling = list(
      concept = "qualidade de infraestrutura",
      gender = "f",
      directions = c(qt_mat_bas = 1, qt_doc_bas = 1)
    )
  ))

  expect_true("cluster_label" %in% names(result$data))
  expect_true("cluster_rank" %in% names(result$data))
  expect_true("cluster_label" %in% names(result$tables$clusters))
  expect_true("cluster_rank" %in% names(result$tables$clusters))

  ranks <- result$tables$clusters$cluster_rank
  expect_setequal(ranks, 1:3)
  expect_equal(
    sort(result$tables$clusters$cluster_label),
    c("Alta qualidade de infraestrutura", "Baixa qualidade de infraestrutura", "Média qualidade de infraestrutura")
  )
})

test_that("analyze_cluster rotula 4 clusters com gradação diferente", {
  model <- fixture_cluster_model()
  result <- analyze_cluster(model, list(
    algorithm = "kmeans", clusters = 4,
    labeling = list(
      concept = "qualidade de infraestrutura",
      gender = "f",
      directions = c(qt_mat_bas = 1, qt_doc_bas = 1)
    )
  ))

  labels <- result$tables$clusters$cluster_label
  expect_setequal(labels, c(
    "Muito baixa qualidade de infraestrutura",
    "Baixa qualidade de infraestrutura",
    "Alta qualidade de infraestrutura",
    "Muito alta qualidade de infraestrutura"
  ))
  expect_setequal(result$tables$clusters$cluster_rank, 1:4)
})

test_that("analyze_cluster usa fallback inteiro com 6+ clusters", {
  model <- fixture_cluster_model()
  result <- analyze_cluster(model, list(
    algorithm = "kmeans", clusters = 6,
    labeling = list(
      concept = "qualidade de infraestrutura",
      gender = "f",
      directions = c(qt_mat_bas = 1, qt_doc_bas = 1)
    )
  ))

  labels <- result$tables$clusters$cluster_label
  expect_setequal(labels, paste0("Cluster ", 1:6))
  expect_setequal(result$tables$clusters$cluster_rank, 1:6)
})

test_that("analyze_cluster sem conceito cai no fallback inteiro", {
  model <- fixture_cluster_model()
  result <- analyze_cluster(model, list(algorithm = "kmeans", clusters = 4))

  expect_true(all(grepl("^Cluster [0-9]+$", result$tables$clusters$cluster_label)))
  expect_setequal(result$tables$clusters$cluster_rank, 1:4)
})

test_that("analyze_cluster rotula em masculino para desempenho", {
  model <- fixture_cluster_model()
  result <- analyze_cluster(model, list(
    algorithm = "kmeans", clusters = 3,
    labeling = list(
      concept = "desempenho dos alunos",
      gender = "m",
      directions = c(qt_mat_bas = 1, qt_doc_bas = 1)
    )
  ))

  expect_setequal(result$tables$clusters$cluster_label, c(
    "Baixo desempenho dos alunos",
    "Médio desempenho dos alunos",
    "Alto desempenho dos alunos"
  ))
})
