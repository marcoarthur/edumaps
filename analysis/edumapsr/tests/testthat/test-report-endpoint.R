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
  env$run_report <- function(geotag, tema, opcoes = NULL, contexto = NULL, config = NULL,
                             assistente = NULL) {
    edumapsAnalytics::run_report(
      geotag, tema, opcoes, contexto,
      config = list(provider = "mock"),
      tools = fake_edubr_tools(fail = fail),
      assistente = assistente
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

# --- Fase 4: assistentes ------------------------------------------------------

test_that("GET /report/assistentes lista os assistentes do pacote", {
  pr <- report_router()
  r <- call_api(pr, "GET", "/report/assistentes")
  expect_equal(r$status, 200)
  ids <- vapply(r$body$assistentes, `[[`, character(1), "id")
  expect_equal(ids, c("relatorio", "eda_municipio"))
  rel <- r$body$assistentes[[1]]
  expect_equal(rel$modo, "tema")
  expect_length(rel$temas, 10)
  expect_equal(rel$opcoes, structure(list(), names = character(0)))
  eda <- r$body$assistentes[[2]]
  expect_equal(eda$modo, "composto")
  expect_equal(eda$niveis, list("municipio"))
  expect_equal(eda$publico, list("gestor"))
  expect_equal(eda$padroes$etapa, "fundamental_i")
  expect_equal(eda$capitulos[[1]], list(id = "redes_territorio", tema = "redes_territorio", titulo = "Redes de ensino"))
  expect_true(isTRUE(eda$capitulos[[5]]$opcional))

  r <- call_api(pr, "GET", "/report/assistentes", qs = "publico=pesquisador")
  expect_equal(r$status, 200)
  expect_length(r$body$assistentes, 0)
})

test_that("GET /report/temas?assistente", {
  pr <- report_router()
  r <- call_api(pr, "GET", "/report/temas", qs = "assistente=relatorio&nivel=municipio")
  expect_equal(r$status, 200)
  expect_length(r$body$temas, 4)
  r <- call_api(pr, "GET", "/report/temas", qs = "assistente=eda_municipio&nivel=municipio")
  expect_equal(r$status, 200)
  expect_equal(vapply(r$body$temas, `[[`, character(1), "id"),
               c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas"))
  r <- call_api(pr, "GET", "/report/temas", qs = "assistente=nao_existe")
  expect_equal(r$status, 400)
  expect_match(r$body$error, "Assistente desconhecido")
})

test_that("POST /report com assistente (tema e composto)", {
  pr <- report_router()
  # padrão = relatorio, com `assistente` no resultado
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"SP"},"tema":"ideb_territorio"}')
  expect_equal(r$status, 200)
  expect_equal(r$body$assistente, list(id = "relatorio", titulo = "Relatório por tema", modo = "tema"))
  expect_null(r$body$capitulos)

  body <- '{"geotag":{"nivel":"municipio","codigo":"3555406"},"assistente":"eda_municipio","tema":"ignorado","opcoes":{"etapa":"fundamental_ii"},"contexto":{"cod_inep":"35038751"}}'
  r <- call_api(pr, "POST", "/report", body = body)
  expect_equal(r$status, 200)
  expect_equal(r$body$tema, list(id = "eda_municipio", titulo = "EDA do município"))
  expect_equal(r$body$assistente$modo, "composto")
  caps <- vapply(r$body$capitulos, `[[`, character(1), "id")
  expect_true("ideb_escolas" %in% caps)
  expect_true("minha_escola" %in% caps)
  expect_equal(r$body$secoes[[1]]$id, "resumo")
  expect_null(r$body$secoes[[1]]$capitulo)
  meio <- r$body$secoes[-c(1, length(r$body$secoes))]
  expect_true(all(vapply(meio, function(s) s$capitulo %in% caps, logical(1))))
  # `capitulos` é sempre lista JSON (mesmo com um capítulo)
  expect_true(is.list(r$body$capitulos))

  # Campinas: capítulos territoriais, sem a escola (em Ubatuba)
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"municipio","codigo":"3509502"},"assistente":"eda_municipio","contexto":{"cod_inep":"35038751"}}')
  expect_equal(r$status, 200)
  expect_equal(vapply(r$body$capitulos, `[[`, character(1), "id"),
               c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas"))

  # nível fora do assistente, assistente desconhecido → 400
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"SP"},"assistente":"eda_municipio"}')
  expect_equal(r$status, 400)
  expect_match(r$body$error, "não está disponível para o nível uf")
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"SP"},"tema":"ideb_territorio","assistente":"xyz"}')
  expect_equal(r$status, 400)
})

test_that("POST /report composto: todos os capítulos sem fonte → 500; um capítulo → aviso", {
  pr <- report_router(fail = "municipios")
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"municipio","codigo":"3509502"},"assistente":"eda_municipio"}')
  expect_equal(r$status, 500)
  expect_equal(r$body$tipo, "internal")

  pr <- report_router(fail = "redes_municipio")
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"municipio","codigo":"3509502"},"assistente":"eda_municipio"}')
  expect_equal(r$status, 200)
  tipos <- vapply(r$body$avisos, `[[`, character(1), "tipo")
  expect_true("capitulo" %in% tipos)
  expect_false("redes_territorio" %in% vapply(r$body$capitulos, `[[`, character(1), "id"))
})

test_that("POST /report com o terceiro assistente (só YAML de teste)", {
  old <- options(edumapsAnalytics.assistentes_dirs = testthat::test_path("assistentes"))
  on.exit(options(old), add = TRUE)
  pr <- report_router()
  r <- call_api(pr, "GET", "/report/assistentes")
  expect_true("panorama_uf" %in% vapply(r$body$assistentes, `[[`, character(1), "id"))
  r <- call_api(pr, "POST", "/report", body = '{"geotag":{"nivel":"uf","codigo":"SP"},"assistente":"panorama_uf","contexto":{"cod_inep":"35038751"}}')
  expect_equal(r$status, 200)
  expect_equal(r$body$assistente$id, "panorama_uf")
  expect_length(r$body$capitulos, 4)
})
