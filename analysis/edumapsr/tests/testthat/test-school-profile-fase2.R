# tests/testthat/test-school-profile-fase2.R
#
# Testa as partes puras da Fase 2 do Perfil da Escola (issue #107):
# reshape das referências/percentis (wide -> longo) e os construtores de
# SQL (bind de ano, sem interpolação de valores).

inds <- PROFILE_INDICATORS

test_that(".profile_reference_long monta 9 linhas por escopo/chave", {
  wide <- data.frame(
    scope = "brasil", chave = "todas", n_escolas = 100L,
    stringsAsFactors = FALSE
  )
  for (i in seq_along(inds)) wide[[inds[i]]] <- i / 10

  long <- .profile_reference_long(wide)

  expect_equal(nrow(long), length(inds))
  expect_equal(long$indicador, inds)
  expect_equal(long$valor, seq_along(inds) / 10)
  expect_equal(long$scope, rep("brasil", length(inds)))
  expect_equal(long$n_escolas, rep(100L, length(inds)))
  expect_true(all(c("scope", "chave", "indicador", "valor", "n_escolas") %in% names(long)))
})

test_that(".profile_reference_long devolve data.frame vazio tipado", {
  long <- .profile_reference_long(data.frame(scope = character(0)))
  expect_equal(nrow(long), 0)
  expect_true(all(c("scope", "chave", "indicador", "valor", "n_escolas") %in% names(long)))
})

test_that(".profile_cluster_profile_long monta 9 linhas por cluster", {
  wide <- data.frame(cluster_id = 3L, n = 42L, stringsAsFactors = FALSE)
  for (ind in inds) {
    wide[[paste0("p25_", ind)]] <- 0.1
    wide[[paste0("p50_", ind)]] <- 0.2
    wide[[paste0("p75_", ind)]] <- 0.3
    wide[[paste0("media_", ind)]] <- 0.25
  }

  long <- .profile_cluster_profile_long(wide)

  expect_equal(nrow(long), length(inds))
  expect_equal(long$cluster_id, rep(3L, length(inds)))
  expect_equal(long$indicador, inds)
  expect_true(all(long$p25 == 0.1))
  expect_true(all(long$media == 0.25))
  expect_true(all(long$n == 42L))
})

test_that("SQL das referências usa bind de ano e é set-based", {
  sql <- .profile_reference_sql('"clean"', FALSE, ano_expr = "$1")

  expect_true(grepl("nu_ano_censo = $1", sql, fixed = TRUE))
  expect_true(grepl("'brasil' AS scope", sql, fixed = TRUE))
  expect_true(grepl("GROUP BY tp_dependencia", sql, fixed = TRUE))
  expect_true(grepl("GROUP BY co_municipio", sql, fixed = TRUE))
})

test_that("SQL dos percentis agrupa por cluster e usa bind de ano", {
  sql <- .profile_cluster_profile_sql('"clean"', FALSE, ano_expr = "$1")

  expect_true(grepl("GROUP BY si.cluster_id", sql, fixed = TRUE))
  expect_true(grepl("percentile_cont(0.25)", sql, fixed = TRUE))
  expect_true(grepl("WHERE e.nu_ano_censo = $1", sql, fixed = TRUE))
})

test_that(".profile_drop_constant_features remove colunas sem variância", {
  df <- data.frame(
    a = c(1, 2, 3),
    b = c(5, 5, 5),
    c = c(NA_real_, 1, 2),
    stringsAsFactors = FALSE
  )

  expect_equal(.profile_drop_constant_features(df, c("a", "b", "c")), c("a", "c"))
  expect_equal(.profile_drop_constant_features(df, "b"), character(0))
  expect_equal(.profile_drop_constant_features(df, "a"), "a")
})
