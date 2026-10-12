# tests/testthat/test-report-roteiros.R
#
# Roteiros fixos por tema com ferramentas FALSAS do eduBR (helper-report.R):
# que ferramentas são chamadas e com que argumentos, como as respostas viram
# seções, fontes e avisos, e as lacunas da Fase 0 (município filtrado dentro
# da UF, fatias quando a resposta vem truncada, `colunas` no docentes_rede).

secao_ids <- function(r) vapply(r$secoes, `[[`, character(1), "id")

test_that("ideb_territorio no município filtra o código dentro da UF e compara com a UF", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "municipio", codigo = "3509502"), "ideb_territorio", tools = tools)

  expect_equal(r$recorte$nome, "Campinas")
  expect_equal(r$recorte$uf, "SP")
  expect_equal(r$titulo, "IDEB do território — Campinas (SP)")
  expect_equal(secao_ids(r)[[1]], "resumo")
  expect_equal(utils::tail(secao_ids(r), 1), "leitura")

  kpis <- report_secao(r, "kpis")
  expect_equal(kpis$itens[[1]]$valor, 6.1)
  expect_equal(kpis$itens[[1]]$formato, "decimal1")
  expect_equal(kpis$itens[[1]]$referencia, list(rotulo = "SP", valor = 6.2))

  # Nível município: sempre n = 1000 e a UF do código.
  calls <- fake_calls(tools, "ideb_agregado")
  muni <- Filter(function(c) identical(c$args$nivel, "municipio"), calls)
  expect_true(all(vapply(muni, function(c) identical(c$args$n, 1000L), logical(1))))
  expect_true(all(vapply(muni, function(c) identical(c$args$uf, "SP"), logical(1))))

  # por_rede veio truncado → refeito por rede (4 fatias); só as completas contam.
  por_rede <- Filter(function(c) isTRUE(c$args$por_rede) && identical(c$args$nivel, "municipio"), calls)
  expect_setequal(
    unlist(lapply(por_rede, `[[`, c("args", "rede"))),
    c("Municipal", "Estadual", "Federal", "Privada")
  )
  tab <- report_secao(r, "ideb_por_rede")
  expect_equal(tab$linhas$rede, c("Municipal", "Estadual"))
  expect_equal(tab$linhas$ideb_medio, c(6.1, 5.8))
  expect_equal(tab$linhas$ideb_referencia, c(6.3, 6.0))
  # A resposta truncada descartada não vira aviso.
  expect_false(any(vapply(r$avisos, `[[`, character(1), "tipo") == "truncado"))

  expect_equal(r$fontes[[1]]$ferramenta, "ideb_agregado")
  expect_equal(r$fontes[[1]]$edicao, "IDEB 2023 — Anos iniciais")
  expect_equal(r$fontes[[1]]$escopo, "municípios de SP")
})

test_that("ideb_territorio com rede não separa por rede e repassa a rede", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "ideb_territorio",
                   opcoes = list(rede = "Municipal", etapa = "fundamental_ii"), tools = tools)
  calls <- fake_calls(tools, "ideb_agregado")
  expect_true(all(vapply(calls, function(c) identical(c$args$rede, "Municipal"), logical(1))))
  expect_true(all(vapply(calls, function(c) identical(c$args$etapa, "fundamental_ii"), logical(1))))
  expect_false("ideb_por_rede" %in% secao_ids(r))
  # UF: gráfico comparativo das UFs da região e referência = região.
  graf <- report_secao(r, "grafico_comparativo")
  expect_equal(graf$grafico, "barras")
  expect_equal(graf$x$id, "sg_uf")
  expect_setequal(graf$dados$sg_uf, c("ES", "MG", "RJ", "SP"))
  expect_equal(report_secao(r, "kpis")$itens[[1]]$referencia$rotulo, "Sudeste")
})

test_that("ideb_territorio na região compara as cinco regiões", {
  r <- fake_report(list(nivel = "regiao", codigo = "NE"), "ideb_territorio")
  expect_equal(r$recorte$nome, "Região Nordeste")
  expect_null(r$recorte$uf)
  expect_equal(report_secao(r, "kpis")$itens[[1]]$valor, 5.5)
  expect_equal(nrow(report_secao(r, "grafico_comparativo")$dados), 5)
})

test_that("município inexistente na UF é erro de cliente", {
  expect_error(
    fake_report(list(nivel = "municipio", codigo = "3500000"), "ideb_territorio"),
    class = "invalid_report_request"
  )
})

test_that("redes_territorio fatia por rede quando a UF passa do teto", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "municipio", codigo = "3550308"), "redes_territorio", tools = tools)
  calls <- fake_calls(tools, "redes_municipio")
  expect_equal(calls[[1]]$args$n, 1000L)
  expect_null(calls[[1]]$args$rede)
  expect_setequal(
    unlist(lapply(calls[-1], `[[`, c("args", "rede"))),
    c("Municipal", "Estadual", "Federal", "Privada")
  )
  tab <- report_secao(r, "redes")
  expect_equal(tab$linhas$rede, c("Municipal", "Estadual", "Privada"))
  expect_equal(tab$linhas$total_escolas, c(1000, 500, 750))
  expect_equal(tab$linhas$perc_superior, c(0.9, 0.9, 0.9))
  # IDEB da rede no município (só no nível município).
  expect_equal(tab$linhas$ideb_fund_i[[1]], 6.1)
  ids_col <- vapply(tab$colunas, `[[`, character(1), "id")
  expect_true("ideb_fund_i" %in% ids_col)
  kpis <- report_secao(r, "kpis")
  expect_equal(kpis$itens[[1]]$valor, 2250)
})

test_that("redes_territorio na região percorre as UFs e soma por UF", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "regiao", codigo = "S"), "redes_territorio",
                   opcoes = list(rede = "Municipal"), tools = tools)
  calls <- fake_calls(tools, "redes_municipio")
  expect_setequal(vapply(calls, `[[`, character(1), c("args", "uf")), c("PR", "SC", "RS"))
  expect_true(all(vapply(calls, function(c) identical(c$args$rede, "Municipal"), logical(1))))
  por_uf <- report_secao(r, "redes_por_uf")
  expect_equal(por_uf$linhas$sg_uf, c("PR", "SC", "RS"))
  expect_false("ideb_fund_i" %in% vapply(report_secao(r, "redes")$colunas, `[[`, character(1), "id"))
})

test_that("redes 'publica' fatia só pelas três redes públicas", {
  tools <- fake_edubr_tools()
  fake_report(list(nivel = "uf", codigo = "SP"), "redes_territorio",
              opcoes = list(rede = "publica"), tools = tools)
  calls <- fake_calls(tools, "redes_municipio")
  expect_setequal(
    unlist(lapply(calls[-1], `[[`, c("args", "rede"))),
    c("Municipal", "Estadual", "Federal")
  )
})

test_that("docentes_territorio sempre pede `colunas` e fatia rede × localização no município", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "municipio", codigo = "3509502"), "docentes_territorio", tools = tools)
  calls <- fake_calls(tools, "docentes_rede")
  expect_true(all(vapply(calls, function(c) length(c$args$colunas) > 0, logical(1))))
  locs <- unlist(lapply(calls, `[[`, c("args", "localizacao")))
  expect_true(all(c("urbana", "rural") %in% locs))
  # Referência no nível de cima.
  expect_true(any(vapply(calls, function(c) identical(c$args$nivel, "uf"), logical(1))))

  kpis <- report_secao(r, "kpis")
  # 3 redes × 2 localizações × 100 professores no fake.
  expect_equal(kpis$itens[[1]]$valor, 600)
  expect_equal(kpis$itens[[2]]$formato, "percentual")
  expect_equal(kpis$itens[[2]]$valor, 0.5)
  expect_equal(kpis$itens[[2]]$referencia$rotulo, "SP")
  tab <- report_secao(r, "docentes_por_rede")
  expect_equal(tab$linhas$rede, c("Municipal", "Estadual", "Privada"))
  expect_equal(tab$linhas$qt_doc_bas, c(200, 200, 200))
})

test_that("docentes_territorio na região compara com o Brasil", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "regiao", codigo = "N"), "docentes_territorio", tools = tools)
  niveis <- vapply(fake_calls(tools, "docentes_rede"), `[[`, character(1), c("args", "nivel"))
  expect_setequal(niveis, c("regiao", "brasil"))
  expect_equal(report_secao(r, "kpis")$itens[[2]]$referencia$rotulo, "Brasil")
})

test_that("gestores_territorio compara a UF com a região", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "uf", codigo = "BA"), "gestores_territorio", tools = tools)
  cortes <- vapply(fake_calls(tools, "perfil_gestor"), `[[`, character(1), c("args", "corte"))
  expect_equal(cortes, c("uf", "regiao"))
  tab <- report_secao(r, "perfil_modal")
  expect_equal(tab$linhas$categoria_modal, c("Feminino", "Superior"))
  expect_equal(tab$linhas$ref_prop, c(0.8, 0.9))
  kpis <- report_secao(r, "kpis")
  expect_equal(kpis$itens[[1]]$valor, 1000)
  expect_equal(kpis$itens[[1]]$referencia$rotulo, "Nordeste")
})

test_that("tendencia_ideb monta a série por edição e a tabela de tendência", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "regiao", codigo = "SE"), "tendencia_ideb", tools = tools)
  serie <- report_secao(r, "grafico_serie")
  expect_equal(serie$grafico, "linhas")
  expect_equal(serie$dados$ano, seq(2005L, 2023L, by = 2L))
  expect_equal(vapply(serie$series, `[[`, character(1), "id"), c("N", "NE", "SE", "S", "CO"))
  kpis <- report_secao(r, "kpis")
  rotulos <- vapply(kpis$itens, `[[`, character(1), "rotulo")
  expect_true("Variação média por ano (tendência linear)" %in% rotulos)
  expect_equal(kpis$itens[[which(rotulos == "IDEB médio 2023")]]$valor, 6.3)
  tab <- report_secao(r, "tendencia_regioes")
  expect_equal(nrow(tab$linhas), 5)
  expect_equal(unique(tab$linhas$periodo), "2005–2023")
  expect_length(fake_calls(tools, "ideb_agregado"), 10)
})

test_that("tendencia_ideb do ensino médio avisa as edições sem dados", {
  r <- fake_report(list(nivel = "regiao", codigo = "SE"), "tendencia_ideb",
                   opcoes = list(etapa = "ensino_medio"))
  serie <- report_secao(r, "grafico_serie")
  expect_equal(serie$dados$ano, c(2017L, 2019L, 2021L, 2023L))
  msgs <- vapply(r$avisos, `[[`, character(1), "mensagem")
  expect_true(any(grepl("Edições sem IDEB", msgs)))
})

test_that("minha_escola usa perfil_escola e o contexto da escola", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "escola", codigo = "35038751"), "minha_escola",
                   tools = tools, contexto = list(cod_inep = "35038751"))
  expect_equal(fake_calls(tools, "perfil_escola")[[1]]$args, list(escola_id = "35038751"))
  expect_equal(r$recorte$nome, "EE EXEMPLO")
  expect_equal(r$recorte$uf, "SP")
  expect_equal(r$titulo, "Minha escola diante do município e do estado — EE EXEMPLO — Ubatuba (SP)")
  infra <- report_secao(r, "infraestrutura")
  expect_equal(infra$linhas$escola_txt, c("Sim", "Não"))
  expect_equal(infra$linhas$municipio, c(0.62, 0.5))
  ideb <- report_secao(r, "ideb")
  expect_equal(ideb$linhas$ofertada_txt, "Sim")
  kpis <- report_secao(r, "kpis")
  expect_equal(kpis$itens[[1]]$valor, 5.1)
  expect_equal(kpis$itens[[1]]$referencia$valor, 4.8)
  expect_match(r$fontes[[1]]$edicao, "IDEB 2023")
})

test_that("escola inexistente é erro de cliente", {
  expect_error(
    fake_report(list(nivel = "escola", codigo = "99999999"), "minha_escola"),
    class = "invalid_report_request"
  )
})

test_that("falha de conexão no eduBR é erro interno (500), não de cliente", {
  tools <- fake_edubr_tools(fail = "ideb_agregado")
  err <- expect_error(
    fake_report(list(nivel = "uf", codigo = "SP"), "ideb_territorio", tools = tools),
    class = "report_source_error"
  )
  expect_false(inherits(err, "edumaps_client_error"))
})

test_that("sem eduBR e sem ferramentas injetadas o relatório é erro de cliente", {
  local_mocked_bindings(edubr_available = function() FALSE)
  expect_error(
    run_report(list(nivel = "uf", codigo = "SP"), "ideb_territorio",
               config = fake_report_config()),
    class = "edubr_unavailable"
  )
  expect_error(edubr_source(NULL), class = "edumaps_client_error")
})

test_that("rastreio conta as chamadas às ferramentas", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "gestores_territorio", tools = tools)
  expect_equal(r$rastreio$chamadas, length(fake_calls(tools)))
  expect_equal(r$rastreio$provedor, "mock")
  expect_true(is.numeric(r$rastreio$duracao_ms))
})

test_that("os argumentos usados pelos roteiros existem nas ferramentas reais do eduBR", {
  skip_if_not_installed("eduBR")
  reais <- eduBR::ferramentas_edubr(NULL, persona = "pesquisadora-educacional")
  tools <- fake_edubr_tools()
  casos <- list(
    list(list(nivel = "municipio", codigo = "3509502"), "ideb_territorio", NULL),
    list(list(nivel = "uf", codigo = "SP"), "ideb_territorio", NULL),
    list(list(nivel = "regiao", codigo = "SE"), "ideb_territorio", NULL),
    list(list(nivel = "municipio", codigo = "3509502"), "redes_territorio", NULL),
    list(list(nivel = "regiao", codigo = "S"), "redes_territorio", NULL),
    list(list(nivel = "municipio", codigo = "3509502"), "docentes_territorio", NULL),
    list(list(nivel = "regiao", codigo = "N"), "docentes_territorio", list(rede = "publica")),
    list(list(nivel = "uf", codigo = "SP"), "gestores_territorio", NULL),
    list(list(nivel = "regiao", codigo = "NE"), "gestores_territorio", NULL),
    list(list(nivel = "regiao", codigo = "SE"), "tendencia_ideb", NULL),
    list(list(nivel = "escola", codigo = "35038751"), "minha_escola", NULL)
  )
  for (cs in casos) fake_report(cs[[1]], cs[[2]], opcoes = cs[[3]], tools = tools)
  for (call in fake_calls(tools)) {
    formais <- names(formals(reais[[call$tool]]))
    expect_true(
      all(names(call$args) %in% formais),
      info = sprintf("%s(%s)", call$tool, paste(names(call$args), collapse = ", "))
    )
  }
})
