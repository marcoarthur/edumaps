# tests/testthat/test-network-profile.R
#
# Testa a análise PURA do perfil da rede (issue #109). Sem banco.

test_that("analyze_network_profile devolve clusters e indicadores", {
  result <- analyze_network_profile(fixture_network_profile_model())

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "network_profile")
  expect_true(all(c("clusters", "indicadores") %in% names(result$tables)))

  clusters <- result$tables$clusters
  expect_true(all(c("cluster_id", "cluster_label", "n", "indicador", "media") %in% names(clusters)))
  expect_equal(length(unique(clusters$cluster_id)), 2)

  indicadores <- result$tables$indicadores
  expect_true(all(c("indicador", "rede", "brasil", "variacao") %in% names(indicadores)))
  expect_true(all(indicadores$variacao == 0.1))
})

test_that("metrics resumem a rede", {
  result <- analyze_network_profile(fixture_network_profile_model())

  expect_equal(result$metrics$n_escolas, 30L)
  expect_equal(result$metrics$n_clusters, 2L)
  expect_equal(result$metrics$n_brasil, 180540L)
})

test_that("analyze_network_profile rejeita modelo de outra classe", {
  expect_error(
    analyze_network_profile(fixture_school_profile_model()),
    "network_profile_model"
  )
})

test_that(".network_clusters_long rotula cluster sem label e sem cluster", {
  wide <- data.frame(
    cluster_id = c(1L, NA_integer_),
    n = c(10L, 3L),
    stringsAsFactors = FALSE
  )
  for (ind in PROFILE_INDICATORS) wide[[ind]] <- 0.5
  labels <- data.frame(cluster_id = integer(0), cluster_label = character(0))

  long <- .network_clusters_long(wide, labels)

  expect_equal(nrow(long), 2 * length(PROFILE_INDICATORS))
  expect_true("Sem cluster" %in% long$cluster_label)
  expect_true("Cluster 1" %in% long$cluster_label)
})

test_that("run_analysis despacha network_profile via o registry", {
  result <- run_analysis("network_profile", fixture_network_profile_model())
  expect_equal(result$analysis, "network_profile")
})

# #479 (RP-02): cada média diz em quantas escolas se apoia.
test_that("n_com_valor sai das contagens n_<indicador> e fica NA sem elas", {
  inds <- PROFILE_INDICATORS
  wide <- as.data.frame(as.list(stats::setNames(rep(1, length(inds)), inds)))
  wide$cluster_id <- NA_integer_
  wide$n <- 10L
  for (ind in inds) wide[[paste0("n_", ind)]] <- 10L
  wide$n_ideb_observado <- 3L
  long <- .network_clusters_long(wide, data.frame(cluster_id = integer(0), cluster_label = character(0)))
  expect_equal(long$n_com_valor[long$indicador == "ideb_observado"], 3L)
  expect_equal(long$n_com_valor[long$indicador == "prop_licenciatura"], 10L)

  mean_row <- wide
  ind_df <- .network_indicators_df(mean_row, stats::setNames(rep(1, length(inds)), inds))
  expect_equal(ind_df$n_com_valor[ind_df$indicador == "ideb_observado"], 3L)

  sem <- wide[, setdiff(names(wide), paste0("n_", inds))]
  expect_true(all(is.na(.network_clusters_long(sem, data.frame(cluster_id = integer(0), cluster_label = character(0)))$n_com_valor)))
})

test_that("a consulta do perfil conta as escolas com valor por indicador", {
  sql <- .network_count_cols("p")
  expect_match(sql, "count(p.ideb_observado) AS n_ideb_observado", fixed = TRUE)
  expect_equal(length(strsplit(sql, ",")[[1]]), length(PROFILE_INDICATORS))
})
