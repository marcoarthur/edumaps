# tests/testthat/test-school-profile.R
#
# Testa a análise PURA do perfil da escola (issue #105). Sem banco: o
# modelo semântico é montado à mão por fixture_school_profile_model().

test_that("analyze_school_profile devolve as tabelas do contrato", {
  result <- analyze_school_profile(
    fixture_school_profile_model(),
    list(co_entidade = "23165669")
  )

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "school_profile")
  expect_true(all(
    c("indicadores_comparados", "cluster_resumo", "peers", "flags") %in%
      names(result$tables)
  ))
  expect_equal(nrow(result$tables$indicadores_comparados), 9)
  expect_equal(nrow(result$tables$cluster_resumo), 9)
  expect_equal(nrow(result$tables$peers), 2)
  expect_equal(result$metrics$cluster_size, 42L)
  expect_equal(result$metrics$n_peers, 2L)
})

test_that("sinal de atenção marca apenas o quartil inferior do cluster", {
  result <- analyze_school_profile(fixture_school_profile_model())
  cmp <- result$tables$indicadores_comparados

  esperados <- c("prop_efetivos", "prop_sem_especializacao")
  expect_setequal(cmp$indicador[cmp$atencao], esperados)
  expect_true(all(cmp$quartil_no_cluster[cmp$atencao] == 1L))

  expect_equal(nrow(result$tables$flags), 2)
  expect_setequal(result$tables$flags$indicador, esperados)
  expect_true(all(result$tables$flags$severidade == "media"))
})

test_that("a coluna `cluster` das comparações é a mediana (p50) do cluster", {
  result <- analyze_school_profile(fixture_school_profile_model())
  cmp <- result$tables$indicadores_comparados
  resumo <- result$tables$cluster_resumo

  merged <- merge(cmp, resumo, by = "indicador")
  expect_equal(merged$cluster, merged$p50)
})

test_that("escola sem cluster (quartis NA) não gera flags e serializa null", {
  model <- fixture_school_profile_model()
  model$data$cluster_p25 <- NA_real_
  model$data$cluster_p50 <- NA_real_
  model$data$cluster_p75 <- NA_real_
  model$data$cluster <- NA_real_

  result <- analyze_school_profile(model)
  cmp <- result$tables$indicadores_comparados

  expect_true(all(is.na(cmp$quartil_no_cluster)))
  expect_false(any(cmp$atencao))
  expect_equal(nrow(result$tables$flags), 0)

  json <- as.character(jsonlite::toJSON(
    render_json(result),
    auto_unbox = TRUE, na = "null", null = "null"
  ))
  expect_true(grepl('"quartil_no_cluster":null', json, fixed = TRUE))
})

test_that("escola com 1 aluno (indicadores NA) permanece válida", {
  model <- fixture_school_profile_model()
  model$data$escola[model$data$indicador == "ratio_aluno_docente"] <- NA_real_
  model$data$escola[model$data$indicador == "inse"] <- NA_real_

  result <- analyze_school_profile(model)
  cmp <- result$tables$indicadores_comparados

  expect_true(is.na(
    cmp$quartil_no_cluster[cmp$indicador == "ratio_aluno_docente"]
  ))
  expect_false(cmp$atencao[cmp$indicador == "ratio_aluno_docente"])

  json <- as.character(jsonlite::toJSON(
    render_json(result),
    auto_unbox = TRUE, na = "null", null = "null"
  ))
  expect_true(grepl("null", json, fixed = TRUE))
})

test_that("peers vazio vira tabela vazia serializável como array", {
  model <- fixture_school_profile_model()
  model$peers <- data.frame(
    co_entidade = character(0), no_entidade = character(0),
    similarity = numeric(0), ideb_observado = numeric(0),
    stringsAsFactors = FALSE
  )

  result <- analyze_school_profile(model)
  expect_equal(nrow(result$tables$peers), 0)

  json <- as.character(jsonlite::toJSON(
    render_json(result),
    auto_unbox = TRUE, na = "null", null = "null"
  ))
  expect_true(grepl('"peers":[]', json, fixed = TRUE))
})

test_that("analyze_school_profile rejeita modelo de outra classe", {
  expect_error(
    analyze_school_profile(fixture_histogram_model()),
    "school_profile_model"
  )
})
