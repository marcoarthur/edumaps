# tests/testthat/test-report-catalog.R
#
# Catálogo de temas do Assistente de Relatório (#219): temas × níveis,
# visão pública de GET /report/temas e coerência com o eduBR real.

test_that("o catálogo tem os seis temas da fase 1 com os níveis do contrato", {
  temas <- report_temas()$temas
  ids <- vapply(temas, `[[`, character(1), "id")
  expect_setequal(ids, c(
    "ideb_territorio", "redes_territorio", "docentes_territorio",
    "gestores_territorio", "tendencia_ideb", "minha_escola"
  ))

  niveis <- stats::setNames(lapply(temas, function(t) unlist(t$niveis)), ids)
  expect_setequal(niveis$ideb_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$redes_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$docentes_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$gestores_territorio, c("uf", "regiao"))
  expect_equal(niveis$tendencia_ideb, "regiao")
  expect_equal(niveis$minha_escola, "escola")
})

test_that("report_temas filtra por nível", {
  ids <- function(nivel) vapply(report_temas(nivel)$temas, `[[`, character(1), "id")
  expect_setequal(ids("municipio"), c("ideb_territorio", "redes_territorio", "docentes_territorio"))
  expect_setequal(ids("uf"), c("ideb_territorio", "redes_territorio", "docentes_territorio", "gestores_territorio"))
  expect_setequal(ids("regiao"), c(
    "ideb_territorio", "redes_territorio", "docentes_territorio",
    "gestores_territorio", "tendencia_ideb"
  ))
  expect_equal(ids("escola"), "minha_escola")
  # Vazio vale como "todos".
  expect_length(report_temas("")$temas, 6)
})

test_that("nível inválido em report_temas é erro de cliente", {
  expect_error(report_temas("bairro"), class = "edumaps_client_error")
  expect_error(report_temas("bairro"), class = "invalid_report_request")
})

test_that("cada tema público tem os campos do contrato e opções como arrays", {
  for (t in report_temas()$temas) {
    expect_setequal(names(t), c("id", "titulo", "descricao", "niveis", "profundidade", "opcoes"))
    expect_equal(t$profundidade, "descritiva")
    expect_true(is.list(t$niveis))
    expect_true(all(names(t$opcoes) %in% c("etapa", "rede")))
    for (o in t$opcoes) expect_true(is.list(o))
  }
  tema <- function(id) Filter(function(t) t$id == id, report_temas()$temas)[[1]]
  # A primeira etapa é o padrão (fundamental_i).
  expect_equal(tema("ideb_territorio")$opcoes$etapa[[1]], "fundamental_i")
  # IDEB não aceita "publica"; as ferramentas do Censo aceitam.
  expect_false("publica" %in% unlist(tema("ideb_territorio")$opcoes$rede))
  expect_true("publica" %in% unlist(tema("redes_territorio")$opcoes$rede))
  expect_length(tema("minha_escola")$opcoes, 0)
})

test_that("o JSON de /report/temas tem arrays mesmo com um único valor", {
  json <- edumapsAnalytics:::report_to_json(report_temas("escola"))
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_true(is.list(parsed$temas[[1]]$niveis))
  expect_equal(parsed$temas[[1]]$niveis[[1]], "escola")
  # Tema sem opções serializa objeto vazio, não array.
  expect_match(as.character(json), '"opcoes":\\{\\}')
})

test_that("as ferramentas do catálogo existem na persona do eduBR real", {
  skip_if_not_installed("eduBR")
  reais <- eduBR::ferramentas_edubr(NULL, persona = "pesquisadora-educacional")
  usadas <- unique(unlist(lapply(edumapsAnalytics:::report_catalog(), `[[`, "ferramentas")))
  expect_true(all(c(usadas, "municipios") %in% names(reais)))
})
