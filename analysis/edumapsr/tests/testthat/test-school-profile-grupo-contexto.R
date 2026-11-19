# tests/testthat/test-school-profile-grupo-contexto.R
#
# #493 (RI-01, RI-02, RI-03): o grupo de referência do perfil é formado
# pelo CONTEXTO (rede, localização, porte, etapas, INSE), nunca pelo IDEB;
# o INSE não gera sinal; o N de cada indicador é o de escolas com o dado.

municipio_ficticio <- function() {
  base <- data.frame(
    co_entidade = sprintf("600493%02d", 1:8),
    no_entidade = paste("Escola", 1:8),
    tp_dependencia = c(3, 3, 3, 3, 4, 4, 2, 3),
    tp_localizacao = c(1, 1, 1, 1, 1, 1, 1, 2),
    ctx_matriculas = c(300, 310, 290, 305, 300, 900, 1500, 40),
    ctx_infantil = c(0, 0, 0, 0, 1, 1, 0, 1),
    ctx_ai = c(1, 1, 1, 1, 1, 1, 0, 1),
    ctx_af = c(0, 0, 0, 0, 0, 1, 1, 0),
    ctx_medio = c(0, 0, 0, 0, 0, 1, 1, 0),
    ctx_eja = 0,
    inse = c(4.5, 4.6, 4.4, NA, 5.8, 6.0, 4.9, 4.1),
    stringsAsFactors = FALSE
  )
  # IDEB muito diferente entre escolas do mesmo contexto (1 a 4)
  base$ideb_observado <- c(4.0, 6.5, 5.0, NA, NA, NA, 4.2, 4.8)
  for (col in setdiff(PROFILE_INDICATORS, c("ideb_observado", "inse"))) base[[col]] <- 0.5
  base$nota_media <- base$ideb_observado
  base
}

test_that("Gower de uma escola contra as outras: numérica, categórica e ausente", {
  alvo <- data.frame(x = 0, c = "a")
  outros <- data.frame(x = c(0, 10, NA), c = c("a", "b", "b"))
  d <- .profile_gower_um(alvo, outros, numericas = "x", categoricas = "c")
  expect_equal(d, c(0, 1, 1))  # a 3ª só compara a categórica
  d2 <- .profile_gower_um(alvo, outros, numericas = "x", categoricas = "c",
                          pesos = c(x = 3, c = 1))
  expect_equal(d2[2], 1)
  expect_equal(.profile_gower_um(alvo, data.frame(x = NA_real_, c = NA_character_),
                                 numericas = "x", categoricas = "c"), NA_real_)
})

test_that("o grupo é o contexto, não o IDEB (RI-01)", {
  f <- municipio_ficticio()
  g <- .school_profile_context_group(f, "60049301", k = 3)
  expect_equal(g$cluster_source, "contexto_municipio")
  expect_equal(g$cluster_size, 3L)
  # as três municipais urbanas de ~300 matrículas e só anos iniciais, com
  # IDEB 6,5, 5,0 e vazio: a de IDEB alto entra, porque o IDEB não decide.
  expect_equal(g$stats$ideb_observado$n, 2L)
  expect_equal(g$stats$ideb_observado$p50, mean(c(6.5, 5.0)))

  # trocar o IDEB de todo mundo não muda o grupo
  f2 <- f
  f2$ideb_observado <- rev(f2$ideb_observado)
  f2$nota_media <- f2$ideb_observado
  g2 <- .school_profile_context_group(f2, "60049301", k = 3)
  expect_equal(g2$cluster_size, g$cluster_size)
  expect_equal(g2$stats$inse$n, g$stats$inse$n)
  expect_equal(g2$stats$prop_licenciatura$n, 3L)
})

test_that("N de cada indicador é o de escolas do grupo com o dado (RI-03)", {
  g <- .school_profile_context_group(municipio_ficticio(), "60049301", k = 3)
  expect_equal(g$stats$prop_licenciatura$n, 3L)
  expect_equal(g$stats$ideb_observado$n, 2L)
  expect_equal(g$stats$inse$n, 2L)
})

test_that("município pequeno: o grupo é o município inteiro; sem a escola: vazio", {
  f <- municipio_ficticio()
  g <- .school_profile_context_group(f, "60049301", k = 30)
  expect_equal(g$cluster_size, nrow(f) - 1L)
  expect_match(g$cluster_label, "^7 escolas de contexto mais parecido")
  v <- .school_profile_context_group(f, "99999990", k = 30)
  expect_equal(v$cluster_size, 0L)
  expect_true(is.na(v$stats$ideb_observado$p50))
})

test_that("INSE não gera sinal de atenção (RI-02)", {
  model <- fixture_school_profile_model()
  i <- model$data$indicador == "inse"
  model$data$escola[i] <- 1
  model$data$cluster_p25[i] <- 4
  model$data$cluster_p50[i] <- 5
  model$data$cluster_p75[i] <- 6
  r <- analyze_school_profile(model)
  cmp <- r$tables$indicadores_comparados
  expect_equal(cmp$quartil_no_cluster[cmp$indicador == "inse"], 1L)
  expect_false(cmp$atencao[cmp$indicador == "inse"])
  expect_false("inse" %in% r$tables$flags$indicador)
  expect_false("inse" %in% .school_profile_flags_meta()$indicador)
})

test_that("regra 5 invalida o cache da regra 4 (#493)", {
  expect_gte(PROFILE_REGRA_SINAIS, 5L)
  expect_false(.profile_cache_regra_atual(list(metadata = list(regra_sinais = 4L))))
})
