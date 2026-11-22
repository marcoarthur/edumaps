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

test_that("sinal de atenção segue o sentido do indicador (#421)", {
  result <- analyze_school_profile(fixture_school_profile_model())
  cmp <- result$tables$indicadores_comparados

  # prop_efetivos (maior é melhor): Q1 e abaixo da mediana -> atenção.
  # ratio_aluno_docente (menor é melhor): Q4 e acima da mediana -> atenção.
  # prop_sem_especializacao (menor é melhor): Q1 = poucos sem formação continuada,
  # é BOM -> sem atenção (a regra v1 marcava).
  esperados <- c("prop_efetivos", "ratio_aluno_docente")
  expect_setequal(cmp$indicador[cmp$atencao], esperados)
  expect_equal(cmp$quartil_no_cluster[cmp$indicador == "prop_sem_especializacao"], 1L)
  expect_false(cmp$atencao[cmp$indicador == "prop_sem_especializacao"])
  expect_equal(cmp$quartil_no_cluster[cmp$indicador == "ratio_aluno_docente"], 4L)

  expect_equal(
    cmp$direcao[match(c("prop_sem_especializacao", "ratio_aluno_docente", "ideb_observado"), cmp$indicador)],
    c("menor", "menor", "maior")
  )

  expect_equal(nrow(result$tables$flags), 2)
  expect_setequal(result$tables$flags$indicador, esperados)
  expect_true(all(result$tables$flags$severidade == "media"))
  expect_equal(result$metadata$regra_sinais, PROFILE_REGRA_SINAIS)
})

test_that("empate com a mediana não gera sinal (doutorado 0% x 0%) (#421)", {
  model <- fixture_school_profile_model()
  i <- model$data$indicador == "prop_doutorado"
  model$data$escola[i] <- 0
  model$data$cluster_p25[i] <- 0
  model$data$cluster_p50[i] <- 0
  model$data$cluster_p75[i] <- 0.02

  cmp <- analyze_school_profile(model)$tables$indicadores_comparados
  expect_equal(cmp$quartil_no_cluster[cmp$indicador == "prop_doutorado"], 1L)
  expect_false(cmp$atencao[cmp$indicador == "prop_doutorado"])
})

test_that("cache com regra de sinais anterior não é servido (#421)", {
  expect_false(.profile_cache_regra_atual(list(metadata = list())))
  expect_false(.profile_cache_regra_atual(list(metadata = list(regra_sinais = 1L))))
  expect_true(.profile_cache_regra_atual(list(metadata = list(regra_sinais = PROFILE_REGRA_SINAIS))))
})

test_that("cache da versão 2 (antes do rótulo do IDEB) não é servido (#431)", {
  expect_gte(PROFILE_REGRA_SINAIS, 3L)
  expect_false(.profile_cache_regra_atual(list(metadata = list(regra_sinais = 2L))))
})

test_that("IDEB e nota SAEB dizem a edição e a etapa da escola (#431)", {
  model <- fixture_school_profile_model()
  sem <- analyze_school_profile(model)$tables$indicadores_comparados
  expect_equal(sem$label[sem$indicador == "ideb_observado"], "IDEB observado")

  model$metadata$ideb_etapa <- "fundamental_i"
  model$metadata$ideb_ano <- 2023L
  cmp <- analyze_school_profile(model)$tables$indicadores_comparados
  expect_equal(
    cmp$label[cmp$indicador == "ideb_observado"],
    "IDEB observado 2023, anos iniciais"
  )
  expect_match(cmp$label[cmp$indicador == "nota_media"], "2023, anos iniciais$")
  expect_equal(cmp$label[cmp$indicador == "inse"], unname(PROFILE_LABELS[["inse"]]))
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

test_that("sem especialização é sem formação continuada no rótulo e no sinal (#522)", {
  expect_equal(unname(PROFILE_LABELS["prop_sem_especializacao"]), "Docentes sem formação continuada")
  meta <- .school_profile_flags_meta()
  textos <- meta$mensagem
  expect_false(any(grepl("especializa", textos, ignore.case = TRUE)))
  expect_true(any(grepl("sem formação continuada \\(80h ou mais\\)", textos)))
  expect_gte(PROFILE_REGRA_SINAIS, 7L)
  expect_false(.profile_cache_regra_atual(list(metadata = list(regra_sinais = 6L))))
})
