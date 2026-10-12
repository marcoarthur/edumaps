# tests/testthat/test-report-endpoint.R
#
# Endpoints Plumber do Assistente de Relatório (GET /report/temas e
# POST /report): status HTTP (200/400/500) e corpo JSON. O roteador é
# montado a partir de inst/plumber/endpoint.R num ambiente em que
# `run_report` usa as ferramentas falsas (sem banco e sem eduBR).

endpoint_file <- function() {
  f <- system.file("plumber/endpoint.R", package = "edumapsAnalytics")
  if (!nzchar(f)) f <- testthat::test_path("..", "..", "inst", "plumber", "endpoint.R")
  f
}

# Requisição Rook mínima (o que o httpuv entrega ao Plumber).
fake_rook_req <- function(verb, path, qs = "", body = "") {
  raw <- charToRaw(body)
  input <- new.env()
  input$read <- function(l = -1L) raw
  input$read_lines <- function(n = -1L) body
  input$rewind <- function() invisible(0)
  req <- new.env()
  req$REQUEST_METHOD <- verb
  req$PATH_INFO <- path
  req$QUERY_STRING <- qs
  req$HTTP_CONTENT_TYPE <- "application/json"
  req$CONTENT_TYPE <- "application/json"
  req$rook.input <- input
  req$rook.errors <- NULL
  req$HEADERS <- c("content-type" = "application/json")
  req
}

report_router <- function(fail = character()) {
  skip_if_not_installed("plumber")
  env <- new.env(parent = asNamespace("edumapsAnalytics"))
  env$run_report <- function(geotag, tema, opcoes = NULL, contexto = NULL, config = NULL) {
    edumapsAnalytics::run_report(
      geotag, tema, opcoes, contexto,
      config = list(provider = "mock"),
      tools = fake_edubr_tools(fail = fail)
    )
  }
  plumber::pr(endpoint_file(), envir = env)
}

body_text <- function(res_body) {
  if (is.raw(res_body)) rawToChar(res_body) else paste(res_body, collapse = "")
}

call_api <- function(pr, verb, path, qs = "", body = "") {
  out <- utils::capture.output(res <- pr$call(fake_rook_req(verb, path, qs, body)))
  list(
    status = res$status,
    body = jsonlite::fromJSON(body_text(res$body), simplifyVector = FALSE)
  )
}

test_that("GET /report/temas lista e filtra por nível", {
  pr <- report_router()
  r <- call_api(pr, "GET", "/report/temas")
  expect_equal(r$status, 200)
  expect_length(r$body$temas, 10)
  prof <- vapply(r$body$temas, `[[`, character(1), "profundidade")
  expect_setequal(unique(prof), c("descritiva", "profunda"))

  r <- call_api(pr, "GET", "/report/temas", qs = "nivel=escola")
  expect_equal(r$status, 200)
  expect_equal(r$body$temas[[1]]$id, "minha_escola")
  expect_equal(r$body$temas[[1]]$niveis, list("escola"))

  r <- call_api(pr, "GET", "/report/temas", qs = "nivel=bairro")
  expect_equal(r$status, 400)
  expect_equal(r$body$tipo, "invalid_request")
})

test_that("POST /report devolve o ReportResult (200)", {
  pr <- report_router()
  body <- '{"geotag":{"nivel":"uf","codigo":"SP"},"tema":"ideb_territorio","opcoes":{"etapa":"fundamental_i"},"contexto":{"cod_inep":"35038751"}}'
  r <- call_api(pr, "POST", "/report", body = body)
  expect_equal(r$status, 200)
  expect_equal(r$body$tema$id, "ideb_territorio")
  expect_equal(r$body$recorte$nome, "São Paulo")
  expect_equal(r$body$secoes[[1]]$id, "resumo")
  expect_true(is.list(r$body$fontes))
})

test_that("POST /report com pedido inválido responde 400", {
  pr <- report_router()
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"municipio","codigo":"3509502"},"tema":"gestores_territorio"}')
  expect_equal(r$status, 400)
  expect_match(r$body$error, "não está disponível")
  r <- call_api(pr, "POST", "/report", body = '{"tema":"ideb_territorio"}')
  expect_equal(r$status, 400)
})

test_that("POST /report com falha da fonte responde 500 sem detalhes", {
  pr <- report_router(fail = "ideb_agregado")
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"SP"},"tema":"ideb_territorio"}')
  expect_equal(r$status, 500)
  expect_equal(r$body$error, "Erro interno ao gerar o relatório")
  expect_equal(r$body$tipo, "internal")
})

test_that("POST /report dos temas da Fase 2 (associacoes, recolhida, _destaque)", {
  pr <- report_router()
  r <- call_api(pr, "POST", "/report",
                body = '{"geotag":{"nivel":"uf","codigo":"SP"},"tema":"infraestrutura_ideb","opcoes":{"etapa":"fundamental_i"}}')
  expect_equal(r$status, 200)
  tipos <- vapply(r$body$secoes, `[[`, character(1), "tipo")
  expect_true("associacoes" %in% tipos)
  coef <- Filter(function(s) identical(s$id, "coeficientes"), r$body$secoes)[[1]]
  expect_true(isTRUE(coef$recolhida))
  expect_true("associacao" %in% vapply(r$body$avisos, `[[`, character(1), "tipo"))

  r <- call_api(pr, "POST", "/report",
                body = '{"geotag":{"nivel":"municipio","codigo":"3555406"},"tema":"ideb_escolas","contexto":{"cod_inep":"35038751"}}')
  expect_equal(r$status, 200)
  esc <- Filter(function(s) identical(s$id, "escolas"), r$body$secoes)[[1]]
  dest <- Filter(function(l) isTRUE(l[["_destaque"]]), esc$linhas)
  expect_length(dest, 1)

  # Recorte grande demais para a regressão: 400 pedindo uma rede.
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"RJ"},"tema":"infraestrutura_ideb"}')
  expect_equal(r$status, 400)
  expect_match(r$body$error, "rede específica")
})
