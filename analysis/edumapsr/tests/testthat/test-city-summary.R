fixture_city_model <- function() {
  new_city_school_model(
    data = data.frame(
      co_entidade = c("1", "2", "3"),
      no_entidade = c("E1", "E2", "E3"),
      tp_dependencia = c(1, 1, 2),
      tp_localizacao = c(1, 2, 1),
      qt_mat_bas = c(200, 150, 300),
      qt_mat_inf = c(100, 50, 100),
      qt_mat_fund = c(80, 90, 150),
      qt_mat_med = c(20, 10, 50),
      qt_doc_bas = c(20, 15, 30),
      dependencia = c("Federal", "Federal", "Estadual"),
      localizacao = c("Urbana", "Rural", "Urbana"),
      ratio_aluno_docente = c(10, 10, 10),
      stringsAsFactors = FALSE
    ),
    codigo_ibge = "3550308"
  )
}


test_that("full_summary calcula métricas globais", {
  model <- fixture_city_model()

  result <- analyze_city_summary(model, list(type = "full_summary"))

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "city_summary")
  expect_equal(result$metrics$total_escolas, 3)
  expect_equal(result$metrics$total_matriculas, 650)
  expect_equal(result$metrics$total_docentes, 65)
})

test_that("full_summary monta a tabela de matrículas por nível", {
  model <- fixture_city_model()

  result <- analyze_city_summary(model, list(type = "full_summary"))

  levels_tbl <- result$tables$enrollment_by_level
  expect_true(all(c("dependencia", "nivel", "matriculas") %in% names(levels_tbl)))

  infantil_total <- sum(levels_tbl$matriculas[levels_tbl$nivel == "Infantil"])
  expect_equal(infantil_total, 250)
})

test_that("análise sem dados rejeitada", {
  expect_error(
    analyze_city_summary("nao_um_modelo"),
    "city_school_model"
  )
})

test_that("tipos reservados devolvem SKIPPED no contrato legado", {
  model <- fixture_city_model()

  for (type in c("school_clusters", "score_distributions")) {
    result <- analyze_city_summary(model, list(type = type))

    expect_equal(result$analysis, paste0("city_", type))
    expect_equal(result$metrics$status, "SKIPPED")
  }
})

test_that("tipo desconhecido é erro do cliente", {
  model <- fixture_city_model()

  expect_error(
    analyze_city_summary(model, list(type = "analise_extra")),
    "Tipo de análise desconhecido"
  )
})