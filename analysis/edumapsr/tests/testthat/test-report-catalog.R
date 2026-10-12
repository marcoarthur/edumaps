# tests/testthat/test-report-catalog.R
#
# Catálogo de temas do Assistente de Relatório (#219): temas × níveis,
# visão pública de GET /report/temas e coerência com o eduBR real.

test_that("o catálogo tem os temas das fases 1 e 2 com os níveis do contrato", {
  temas <- report_temas()$temas
  ids <- vapply(temas, `[[`, character(1), "id")
  expect_setequal(ids, c(
    "ideb_territorio", "redes_territorio", "docentes_territorio",
    "gestores_territorio", "tendencia_ideb", "minha_escola",
    "ideb_escolas", "infraestrutura_ideb", "historico_escola", "escolas_parecidas"
  ))

  niveis <- stats::setNames(lapply(temas, function(t) unlist(t$niveis)), ids)
  expect_setequal(niveis$ideb_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$redes_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$docentes_territorio, c("municipio", "uf", "regiao"))
  expect_setequal(niveis$gestores_territorio, c("uf", "regiao"))
  expect_equal(niveis$tendencia_ideb, "regiao")
  expect_equal(niveis$minha_escola, "escola")
  expect_equal(niveis$ideb_escolas, "municipio")
  expect_equal(niveis$infraestrutura_ideb, "uf")
  expect_equal(niveis$historico_escola, "escola")
  expect_equal(niveis$escolas_parecidas, "escola")
})

test_that("report_temas filtra por nível", {
  ids <- function(nivel) vapply(report_temas(nivel)$temas, `[[`, character(1), "id")
  expect_setequal(ids("municipio"), c("ideb_territorio", "redes_territorio", "docentes_territorio", "ideb_escolas"))
  expect_setequal(ids("uf"), c(
    "ideb_territorio", "redes_territorio", "docentes_territorio", "gestores_territorio",
    "infraestrutura_ideb"
  ))
  expect_setequal(ids("regiao"), c(
    "ideb_territorio", "redes_territorio", "docentes_territorio",
    "gestores_territorio", "tendencia_ideb"
  ))
  expect_setequal(ids("escola"), c("minha_escola", "historico_escola", "escolas_parecidas"))
  # Vazio vale como "todos".
  expect_length(report_temas("")$temas, 10)
})

test_that("nível inválido em report_temas é erro de cliente", {
  expect_error(report_temas("bairro"), class = "edumaps_client_error")
  expect_error(report_temas("bairro"), class = "invalid_report_request")
})

test_that("cada tema público tem os campos do contrato e opções como arrays", {
  for (t in report_temas()$temas) {
    expect_setequal(names(t), c("id", "titulo", "descricao", "niveis", "profundidade", "opcoes", "padroes"))
    # padrão só para opção existente
    expect_true(all(names(t$padroes) %in% names(t$opcoes)))
    expect_true(t$profundidade %in% c("descritiva", "profunda"))
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
  # Padrões expostos: etapa com padrão nos temas de IDEB; livre em escolas_parecidas.
  expect_equal(tema("ideb_territorio")$padroes$etapa, "fundamental_i")
  expect_equal(tema("infraestrutura_ideb")$padroes$rede, "publica")
  expect_null(tema("escolas_parecidas")$padroes$etapa)
  expect_true("etapa" %in% names(tema("escolas_parecidas")$opcoes))
})

test_that("o JSON de /report/temas tem arrays mesmo com um único valor", {
  json <- edumapsAnalytics:::report_to_json(report_temas("escola"))
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_true(is.list(parsed$temas[[1]]$niveis))
  expect_equal(parsed$temas[[1]]$niveis[[1]], "escola")
  # escolas_parecidas tem uma única opção (etapa): continua array.
  ep <- Filter(function(t) t$id == "escolas_parecidas", parsed$temas)[[1]]
  expect_true(is.list(ep$opcoes$etapa))
  # Tema sem opções serializa objeto vazio, não array.
  expect_match(as.character(json), '"opcoes":\\{\\}')
})

test_that("as ferramentas do catálogo existem no eduBR real (complemento B: sem persona)", {
  skip_if_not_installed("eduBR")
  reais <- eduBR::ferramentas_edubr(NULL, persona = NULL)
  usadas <- edumapsAnalytics:::report_tool_names()
  expect_true(all(c("municipios", "resumo_escola", "regressao_escolas", "ideb") %in% usadas))
  expect_true(all(usadas %in% names(reais)))
  # As ferramentas da escola NÃO são da persona pesquisadora: por isso o
  # adapter monta sem persona.
  pesq <- names(eduBR::ferramentas_edubr(NULL, persona = "pesquisadora-educacional"))
  expect_false(all(c("serie_ideb_escola", "escolas_similares") %in% pesq))
})

test_that("os argumentos usados pelos roteiros da Fase 2 existem nas ferramentas reais", {
  skip_if_not_installed("eduBR")
  reais <- eduBR::ferramentas_edubr(NULL, persona = NULL)
  args_de <- function(tool) names(formals(reais[[tool]]))
  expect_true(all(c("uf", "municipio", "etapa", "rede", "ano", "n") %in% args_de("ideb")))
  expect_true(all(c("outcome", "predictors", "cuts", "uf", "rede", "ano", "ano_ideb", "ativas", "modelo")
                  %in% args_de("regressao_escolas")))
  expect_true(all(c("escola_id", "n", "etapa", "publica") %in% args_de("escolas_similares")))
  expect_true("escola_id" %in% args_de("serie_ideb_escola"))
  expect_true("escola_id" %in% args_de("scores_escola"))
  expect_true("escola_id" %in% args_de("resumo_escola"))
})
