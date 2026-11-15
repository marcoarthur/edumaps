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

test_that("linhas com NA nas features são removidas sem quebrar kmeans", {
  model <- fixture_cluster_model()
  # injeta NA em 2 escolas (1 em cada feature) — como no Censo, onde nem toda
  # escola preenche todos os campos.
  model$data[c(1, 2), c("qt_mat_bas", "qt_doc_bas")] <- NA

  expect_warning(
    result <- analyze_cluster(model, list(algorithm = "kmeans", clusters = 4)),
    "Linhas sem dados completos removidas: 2"
  )

  expect_equal(result$metrics$n_entities, 38)
  expect_equal(result$metrics$n_clusters, 4)
  expect_false(anyNA(result$data$cluster_id))
  # entidades preservam a ordem relativa (as 2 primeiras, sem dados, saem)
  expect_equal(
    result$data[["co_entidade"]],
    cluster_entity_ids(model)[-(1:2)]
  )
})

test_that("feature sem variância é removida das features efetivas", {
  data <- data.frame(
    school_id = sprintf("s%02d", seq_len(20)),
    x = runif(20),
    y = 7,             # constante: nenhuma variância
    z = rnorm(20)
  )
  model <- new_school_cluster_model(
    data = data,
    entity_id = "school_id",
    features = c("x", "y", "z")
  )

  expect_warning(
    result <- analyze_cluster(model, list(algorithm = "kmeans", clusters = 3)),
    "Features sem variância removidas: y"
  )

  expect_equal(result$metadata$features, c("x", "z"))
  expect_equal(result$metrics$n_features, 2)
  expect_equal(result$metrics$n_entities, 20)
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
test_that("universo conta o recorte, as incompletas por indicador e as agrupadas (#427)", {
  model <- fixture_cluster_model()
  model$data$qt_mat_bas[c(1, 2)] <- NA
  model$data$qt_doc_bas[c(2, 3)] <- NA

  result <- suppressWarnings(analyze_cluster(model, list(algorithm = "kmeans", clusters = 3)))
  u <- result$metadata$universo

  expect_equal(u$n_recorte, 40)
  expect_equal(u$n_incompletas, 3)
  expect_equal(u$n_agrupadas, 37)
  expect_equal(u$sem_dado, list(qt_mat_bas = 2, qt_doc_bas = 2))
  expect_length(u$features_sem_variancia, 0)

  valores <- attr(result, "valores")
  expect_equal(nrow(valores), 37)
  expect_setequal(names(valores), c("co_entidade", "qt_mat_bas", "qt_doc_bas"))
  expect_false(any(valores$co_entidade %in% c("ESC01", "ESC02", "ESC03")))
  # valores na unidade original (não escalados)
  expect_gt(min(valores$qt_mat_bas), 100)
})

test_that("execução guardada grava atribuições com valores e mescla o universo (#427)", {
  con <- tryCatch(
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = Sys.getenv("PGHOST", "localhost"),
      port = as.integer(Sys.getenv("PGPORT", "5432")),
      dbname = Sys.getenv("PGDATABASE", "edumaps_dev"),
      user = Sys.getenv("PGUSER", "devel"),
      password = Sys.getenv("PGPASSWORD", "senhaboa123")
    ),
    error = function(e) NULL
  )
  if (is.null(con)) skip("Banco de teste não disponível")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  if (is.na(DBI::dbGetQuery(con, "SELECT to_regclass('analytics.cluster_execucoes')::text AS t")$t)) {
    skip("analytics.cluster_execucoes ausente")
  }

  run_id <- "run_teste_r_427"
  DBI::dbExecute(con, "DELETE FROM analytics.cluster_execucoes WHERE run_id = $1", params = list(run_id))
  on.exit(DBI::dbExecute(con, "DELETE FROM analytics.cluster_execucoes WHERE run_id = $1", params = list(run_id)), add = TRUE, after = FALSE)
  DBI::dbExecute(con,
    "INSERT INTO analytics.cluster_execucoes (run_id, universo) VALUES ($1, '{\"n_inativas\": 5}')",
    params = list(run_id))

  model <- fixture_cluster_model()
  model$data$co_entidade <- as.character(60002700 + seq_len(nrow(model$data)))
  model$data$qt_doc_bas[1] <- NA
  result <- suppressWarnings(analyze_cluster(model, list(algorithm = "kmeans", clusters = 3)))

  n <- .write_cluster_execucao(con, "analytics", run_id, "co_entidade", result$data,
    valores = attr(result, "valores"), universo = result$metadata$universo)
  expect_equal(n, 39L)

  linha <- DBI::dbGetQuery(con,
    "SELECT valores->>'qt_mat_bas' AS mat, cluster_id FROM analytics.cluster_atribuicoes
      WHERE run_id = $1 AND co_entidade = 60002702", params = list(run_id))
  expect_equal(nrow(linha), 1)
  expect_gt(as.numeric(linha$mat), 100)

  u <- jsonlite::fromJSON(DBI::dbGetQuery(con,
    "SELECT universo::text AS u FROM analytics.cluster_execucoes WHERE run_id = $1",
    params = list(run_id))$u)
  expect_equal(u$n_inativas, 5)
  expect_equal(u$n_recorte, 40)
  expect_equal(u$n_agrupadas, 39)
  expect_equal(u$sem_dado$qt_doc_bas, 1)
})
