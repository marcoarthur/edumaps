# tests/testthat/test-report-json.R
#
# Serialização do ReportResult conforme o contrato da onda 1 (#219), com as
# mesmas opções do serializador do endpoint `/report`.

roundtrip <- function(report) {
  jsonlite::fromJSON(edumapsAnalytics:::report_to_json(report), simplifyVector = FALSE)
}

check_section <- function(s) {
  expect_true(s$tipo %in% c("texto", "indicadores", "tabela", "grafico"))
  expect_true(is.character(s$id) && is.character(s$titulo))
  formatos <- c("texto", "inteiro", "decimal1", "decimal2", "percentual")
  if (s$tipo == "texto") {
    expect_true(is.character(s$markdown))
  }
  if (s$tipo == "indicadores") {
    expect_true(is.list(s$itens) && length(s$itens) > 0)
    for (it in s$itens) {
      expect_true(it$formato %in% formatos)
      expect_true(is.numeric(it$valor) || is.character(it$valor))
      if (!is.null(it$referencia)) expect_setequal(names(it$referencia), c("rotulo", "valor"))
    }
  }
  if (s$tipo == "tabela") {
    expect_true(is.list(s$colunas))
    ids <- vapply(s$colunas, `[[`, character(1), "id")
    for (c in s$colunas) expect_true(c$formato %in% formatos)
    expect_true(is.list(s$linhas) && length(s$linhas) > 0)
    for (l in s$linhas) expect_setequal(names(l), ids)
  }
  if (s$tipo == "grafico") {
    expect_true(s$grafico %in% c("barras", "linhas"))
    expect_setequal(names(s$x), c("id", "rotulo"))
    expect_true(is.list(s$series))
    ids <- c(s$x$id, vapply(s$series, `[[`, character(1), "id"))
    for (d in s$dados) expect_setequal(names(d), ids)
  }
}

check_report <- function(j) {
  expect_true(all(c("titulo", "gerado_em", "recorte", "tema", "secoes", "fontes", "avisos", "rastreio") %in% names(j)))
  expect_match(j$gerado_em, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
  expect_true(all(c("nivel", "codigo", "nome") %in% names(j$recorte)))
  expect_setequal(names(j$tema), c("id", "titulo"))
  expect_true(is.list(j$secoes))
  expect_equal(j$secoes[[1]]$id, "resumo")
  expect_equal(j$secoes[[length(j$secoes)]]$id, "leitura")
  for (s in j$secoes) check_section(s)
  expect_true(is.list(j$fontes))
  for (f in j$fontes) expect_setequal(names(f), c("ferramenta", "descricao", "edicao", "escopo", "n"))
  expect_true(is.list(j$avisos))
  for (a in j$avisos) expect_setequal(names(a), c("tipo", "mensagem"))
  expect_setequal(
    names(j$rastreio),
    c("provedor", "modelo", "llm", "versao_edubr", "chamadas", "duracao_ms")
  )
}

test_that("todos os temas serializam conforme o contrato", {
  casos <- list(
    list(list(nivel = "municipio", codigo = "3509502"), "ideb_territorio"),
    list(list(nivel = "uf", codigo = "SP"), "redes_territorio"),
    list(list(nivel = "regiao", codigo = "SE"), "docentes_territorio"),
    list(list(nivel = "uf", codigo = "SP"), "gestores_territorio"),
    list(list(nivel = "regiao", codigo = "SE"), "tendencia_ideb"),
    list(list(nivel = "escola", codigo = "35038751"), "minha_escola")
  )
  for (cs in casos) {
    j <- roundtrip(fake_report(cs[[1]], cs[[2]]))
    check_report(j)
    expect_equal(j$tema$id, cs[[2]])
  }
})

test_that("arrays continuam arrays com um único elemento e NA vira null", {
  r <- fake_report(list(nivel = "municipio", codigo = "3509502"), "ideb_territorio",
                   opcoes = list(rede = "Municipal"))
  json <- as.character(edumapsAnalytics:::report_to_json(r))
  j <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_true(is.list(j$fontes))
  expect_length(j$fontes, 1)
  expect_match(json, '"avisos":\\[')
  kpis <- Filter(function(s) s$id == "kpis", j$secoes)[[1]]
  expect_true(is.list(kpis$itens))
  # Escalares são escalares (não arrays de 1).
  expect_match(json, '"titulo":"IDEB do território — Campinas \\(SP\\)"')
  expect_match(json, '"n":\\d+')
})

test_that("valores ausentes em tabelas viram null", {
  r <- fake_report(list(nivel = "municipio", codigo = "3550308"), "redes_territorio")
  j <- roundtrip(r)
  redes <- Filter(function(s) s$id == "redes", j$secoes)[[1]]
  privada <- Filter(function(l) l$rede == "Privada", redes$linhas)[[1]]
  expect_null(privada$ideb_fund_i)
  expect_true("ideb_fund_i" %in% names(privada))
})

test_that("render_report_json recusa outro analysis_result", {
  res <- new_analysis_result("histogram", data = data.frame())
  expect_error(render_report_json(res), class = "invalid_parameter")
})

test_that("analyze_report devolve um analysis_result com as tabelas", {
  model <- new_report_request_model(list(nivel = "uf", codigo = "SP"), "redes_territorio")
  src <- edubr_source(tools = fake_edubr_tools())
  res <- analyze_report(model, src, config = fake_report_config())
  expect_s3_class(res, "analysis_result")
  expect_equal(res$analysis, "report")
  expect_true("redes" %in% names(res$tables))
  expect_equal(res$parameters$tema, "redes_territorio")
  expect_error(analyze_report(list(), src), class = "invalid_parameter")
})
