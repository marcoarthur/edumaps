# tests/testthat/test-report-request.R
#
# Modelo semântico do pedido (report_request_model): validação do recorte,
# do tema × nível e das opções. Toda falha é erro de cliente (400).

expect_invalid <- function(expr) {
  expect_error(expr, class = "invalid_report_request")
}

test_that("recorte de município deriva UF e região do código IBGE", {
  m <- new_report_request_model(list(nivel = "municipio", codigo = "3509502"), "ideb_territorio")
  expect_s3_class(m, "report_request_model")
  expect_equal(m$uf, "SP")
  expect_equal(m$regiao, "SE")
  expect_equal(m$opcoes$etapa, "fundamental_i")
  expect_null(m$opcoes$rede)
})

test_that("código numérico vindo do JSON é aceito", {
  m <- new_report_request_model(list(nivel = "municipio", codigo = 2927408), "redes_territorio")
  expect_equal(m$codigo, "2927408")
  expect_equal(m$uf, "BA")
  expect_equal(m$regiao, "NE")
})

test_that("UF e região são validadas", {
  m <- new_report_request_model(list(nivel = "uf", codigo = "MG"), "gestores_territorio")
  expect_equal(m$regiao, "SE")
  m <- new_report_request_model(list(nivel = "regiao", codigo = "CO"), "tendencia_ideb")
  expect_equal(m$regiao, "CO")

  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "sp"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "XX"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "regiao", codigo = "Sudeste"), "ideb_territorio"))
})

test_that("geotag malformado é 400", {
  expect_invalid(new_report_request_model(NULL, "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "municipio"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "bairro", codigo = "1"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "municipio", codigo = "350950"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "municipio", codigo = "9909502"), "ideb_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "escola", codigo = "3503875"), "minha_escola"))
})

test_that("tema desconhecido ou fora do nível é 400", {
  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "SP"), "inse"))
  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "SP"), NULL))
  expect_invalid(new_report_request_model(list(nivel = "municipio", codigo = "3509502"), "gestores_territorio"))
  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "SP"), "tendencia_ideb"))
  expect_invalid(new_report_request_model(list(nivel = "uf", codigo = "SP"), "minha_escola"))
})

test_that("opções são validadas contra o tema", {
  g <- list(nivel = "uf", codigo = "SP")
  m <- new_report_request_model(g, "ideb_territorio", list(etapa = "ensino_medio", rede = "Estadual"))
  expect_equal(m$opcoes, list(etapa = "ensino_medio", rede = "Estadual"))

  expect_invalid(new_report_request_model(g, "ideb_territorio", list(etapa = "infantil")))
  expect_invalid(new_report_request_model(g, "ideb_territorio", list(rede = "municipal")))
  # "publica" não vale para o IDEB, mas vale para as redes.
  expect_invalid(new_report_request_model(g, "ideb_territorio", list(rede = "publica")))
  m <- new_report_request_model(g, "redes_territorio", list(rede = "publica"))
  expect_equal(m$opcoes$rede, "publica")
  # Opção que o tema não aceita.
  expect_invalid(new_report_request_model(g, "redes_territorio", list(etapa = "fundamental_i")))
  expect_invalid(new_report_request_model(g, "ideb_territorio", list(ano = 2021)))
  expect_invalid(new_report_request_model(
    list(nivel = "escola", codigo = "35038751"), "minha_escola", list(rede = "Estadual")
  ))
  # Valores nulos/vazios valem como não informados.
  m <- new_report_request_model(g, "ideb_territorio", list(rede = NULL, etapa = ""))
  expect_equal(m$opcoes$etapa, "fundamental_i")
})

test_that("recorte por escola só vale para a escola do contexto", {
  g <- list(nivel = "escola", codigo = "35038751")
  expect_s3_class(
    new_report_request_model(g, "minha_escola", contexto = list(cod_inep = 35038751)),
    "report_request_model"
  )
  expect_invalid(new_report_request_model(g, "minha_escola", contexto = list(cod_inep = "35000000")))
})

test_that("erros do pedido são edumaps_client_error (400 no endpoint)", {
  expect_error(
    new_report_request_model(list(nivel = "uf", codigo = "ZZ"), "ideb_territorio"),
    class = "edumaps_client_error"
  )
})
