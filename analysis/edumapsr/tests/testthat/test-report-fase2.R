# tests/testthat/test-report-fase2.R
#
# Temas da Fase 2 do Assistente de Relatório (#219) com ferramentas FALSAS
# (helper-report.R): ideb_escolas, infraestrutura_ideb, historico_escola e
# escolas_parecidas. Cobre catálogo/níveis, validação, seções e formatos,
# associações (limiares de p e sinal), tabela recolhida, `_destaque`, aviso
# `associacao`, posição da escola do gestor, pacote do LLM sem nomes de
# escolas de terceiros e degradação.

secao_ids <- function(r) vapply(r$secoes, `[[`, character(1), "id")
geo_ubatuba <- list(nivel = "municipio", codigo = "3555406")
geo_escola <- list(nivel = "escola", codigo = "35038751")
gestor <- list(cod_inep = "35038751")

# Captura o system prompt e o JSON de dados enviados ao LLM.
captura_llm <- function() {
  visto <- new.env()
  visto$fn <- function(system, prompt) {
    visto$system <- system
    visto$prompt <- prompt
    "[RESUMO]\nTexto.\n\n[LEITURA]\n- Item."
  }
  visto
}
dados_llm <- function(visto) {
  jsonlite::fromJSON(sub("^.*DADOS \\(JSON\\):\n", "", visto$prompt), simplifyVector = FALSE)
}

# ---------------------------------------------------------------------------
# Catálogo e validação

test_that("os temas da Fase 2 têm profundidade, níveis e opções do contrato", {
  tema <- function(id) Filter(function(t) t$id == id, report_temas()$temas)[[1]]
  expect_equal(tema("ideb_escolas")$profundidade, "profunda")
  expect_equal(tema("infraestrutura_ideb")$profundidade, "profunda")
  expect_equal(tema("historico_escola")$profundidade, "descritiva")
  expect_equal(tema("escolas_parecidas")$profundidade, "descritiva")

  expect_setequal(names(tema("ideb_escolas")$opcoes), c("etapa", "rede"))
  expect_false("publica" %in% unlist(tema("ideb_escolas")$opcoes$rede))
  expect_setequal(names(tema("infraestrutura_ideb")$opcoes), c("etapa", "rede"))
  # Regressão: "publica" é o padrão (primeiro valor) e não há "Privada".
  expect_equal(tema("infraestrutura_ideb")$opcoes$rede[[1]], "publica")
  expect_false("Privada" %in% unlist(tema("infraestrutura_ideb")$opcoes$rede))
  expect_length(tema("historico_escola")$opcoes, 0)
  expect_equal(names(tema("escolas_parecidas")$opcoes), "etapa")
})

test_that("tema da Fase 2 fora do nível é erro de cliente", {
  expect_error(fake_report(list(nivel = "uf", codigo = "SP"), "ideb_escolas"), class = "invalid_report_request")
  expect_error(fake_report(geo_ubatuba, "infraestrutura_ideb"), class = "invalid_report_request")
  expect_error(fake_report(geo_ubatuba, "historico_escola"), class = "invalid_report_request")
  expect_error(fake_report(list(nivel = "uf", codigo = "SP"), "escolas_parecidas"), class = "invalid_report_request")
})

test_that("opções inválidas dos temas da Fase 2 são erro de cliente", {
  expect_error(fake_report(geo_ubatuba, "ideb_escolas", opcoes = list(rede = "publica")),
               class = "invalid_report_request")
  expect_error(fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb", opcoes = list(rede = "Privada")),
               class = "invalid_report_request")
  expect_error(fake_report(geo_escola, "historico_escola", opcoes = list(etapa = "fundamental_i")),
               class = "invalid_report_request")
  expect_error(fake_report(geo_escola, "escolas_parecidas", opcoes = list(rede = "Municipal")),
               class = "invalid_report_request")
  # Escola de outro gestor: o recorte por escola só vale para a própria.
  expect_error(fake_report(list(nivel = "escola", codigo = "35000001"), "historico_escola", contexto = gestor),
               class = "invalid_report_request")
})

test_that("o adapter usa as ferramentas sem persona e escolhe por nome (complemento B)", {
  nomes <- edumapsAnalytics:::report_tool_names()
  expect_true(all(c(
    "ideb", "regressao_escolas", "serie_ideb_escola", "scores_escola",
    "resumo_escola", "escolas_similares", "municipios", "ideb_agregado",
    "perfil_escola"
  ) %in% nomes))
  expect_equal(edumapsAnalytics:::report_limits()$max_amostra, 30000L)
  skip_if_not_installed("eduBR")
  src <- edubr_source(NULL)
  expect_setequal(names(src$tools), intersect(nomes, names(eduBR::ferramentas_edubr(NULL))))
  expect_equal(src$persona, "pesquisadora-educacional")
})

test_that("os preditores fixos existem nas covariáveis do eduBR", {
  skip_if_not_installed("eduBR")
  infra <- suppressWarnings(names(eduBR:::eduBR_infra_perfil()))
  expect_true(all(c("in_biblioteca", "in_internet", "in_laboratorio_informatica") %in% infra))
  expect_setequal(names(edumapsAnalytics:::REPORT_PREDITORES), c(
    "in_biblioteca", "in_internet", "in_laboratorio_informatica", "docentes", "matriculas"
  ))
})

# ---------------------------------------------------------------------------
# ideb_escolas

test_that("ideb_escolas lista as escolas do município ordenadas e com indicadores determinísticos", {
  tools <- fake_edubr_tools()
  r <- fake_report(geo_ubatuba, "ideb_escolas", tools = tools, contexto = gestor)

  expect_equal(r$titulo, "IDEB escola a escola — Ubatuba (SP)")
  expect_equal(secao_ids(r), c("resumo", "kpis", "escolas", "grafico_faixas", "leitura"))

  # Chamada: UF + NOME do município, edição 2023, n = 1000.
  call <- fake_calls(tools, "ideb")[[1]]$args
  expect_equal(call$uf, "SP")
  expect_equal(call$municipio, "Ubatuba")
  expect_equal(call$ano, 2023L)
  expect_equal(call$etapa, "fundamental_i")
  expect_equal(call$n, 1000L)

  tab <- report_secao(r, "escolas")
  # O homônimo de outro código IBGE ficou de fora.
  expect_false("ESCOLA DE OUTRO MUNICIPIO" %in% tab$linhas$escola)
  expect_equal(tab$linhas$ideb, c(7.1, 6.4, 5.9, 5.9, 4.2, 3.8, NA))
  # Empate divide a posição; escola sem nota fica no fim, sem posição.
  expect_equal(tab$linhas$posicao, c(1, 2, 3, 3, 5, 6, NA))
  expect_equal(tab$linhas$escola[[7]], "ESCOLA SEM NOTA EM")
  formatos <- vapply(tab$colunas, `[[`, character(1), "formato")
  expect_equal(formatos, c("inteiro", "texto", "texto", "decimal1"))
  # `_destaque` não é coluna declarada.
  expect_false("_destaque" %in% vapply(tab$colunas, `[[`, character(1), "id"))
  expect_null(tab$recolhida)

  kpis <- report_secao(r, "kpis")
  vals <- stats::setNames(lapply(kpis$itens, `[[`, "valor"), vapply(kpis$itens, `[[`, character(1), "rotulo"))
  expect_equal(vals[["Escolas com nota"]], 6)
  expect_equal(vals[["Mediana do IDEB"]], stats::median(c(7.1, 6.4, 5.9, 5.9, 4.2, 3.8)))
  expect_equal(vals[["Menor IDEB"]], 3.8)
  expect_equal(vals[["Maior IDEB"]], 7.1)
  expect_equal(vals[["Posição da sua escola"]], "3ª de 6")

  graf <- report_secao(r, "grafico_faixas")
  expect_equal(graf$grafico, "barras")
  expect_equal(graf$dados$faixa, c("Abaixo de 4,0", "4,0 a 4,9", "5,0 a 5,9", "6,0 a 6,9", "7,0 ou mais"))
  expect_equal(graf$dados$escolas, c(1, 1, 2, 1, 1))
  expect_equal(sum(graf$dados$escolas), 6)

  expect_equal(r$fontes[[1]]$ferramenta, "ideb")
  expect_equal(r$fontes[[1]]$edicao, "IDEB 2023 — Anos iniciais")
  expect_equal(r$fontes[[1]]$n, 7L)
})

test_that("ideb_escolas: _destaque só na linha da escola do gestor e só como true", {
  r <- fake_report(geo_ubatuba, "ideb_escolas", contexto = gestor)
  linhas <- Filter(function(s) identical(s$id, "escolas"), r$secoes)[[1]]$linhas
  destacadas <- Filter(function(l) !is.null(l[["_destaque"]]), linhas)
  expect_length(destacadas, 1)
  expect_identical(destacadas[[1]][["_destaque"]], TRUE)
  expect_equal(destacadas[[1]]$escola, "ESCOLA DO GESTOR EE")
  json <- as.character(edumapsAnalytics:::report_to_json(r))
  expect_false(grepl('"_destaque":false', json, fixed = TRUE))
  expect_false(grepl("ocultar_llm", json, fixed = TRUE))
})

test_that("ideb_escolas sem a escola do gestor não tem destaque nem posição", {
  r <- fake_report(geo_ubatuba, "ideb_escolas", opcoes = list(rede = "Municipal"), contexto = gestor)
  rotulos <- vapply(report_secao(r, "kpis")$itens, `[[`, character(1), "rotulo")
  expect_false(any(grepl("Posição|Sua escola", rotulos)))
  linhas <- Filter(function(s) identical(s$id, "escolas"), r$secoes)[[1]]$linhas
  expect_true(all(vapply(linhas, function(l) is.null(l[["_destaque"]]), logical(1))))
  expect_true(all(report_secao(r, "escolas")$linhas$rede == "Municipal"))
  # Sem contexto (pedido sem cod_inep) também funciona.
  r2 <- fake_report(geo_ubatuba, "ideb_escolas")
  expect_false(any(grepl("Posição", vapply(report_secao(r2, "kpis")$itens, `[[`, character(1), "rotulo"))))
})

test_that("ideb_escolas refaz por rede quando a resposta vem truncada", {
  tools <- fake_edubr_tools()
  r <- fake_report(list(nivel = "municipio", codigo = "3509502"), "ideb_escolas", tools = tools)
  redes <- unlist(lapply(fake_calls(tools, "ideb"), function(c) c$args$rede))
  expect_setequal(redes, c("Municipal", "Estadual", "Federal", "Privada"))
  expect_false("TRUNCADA" %in% report_secao(r, "escolas")$linhas$escola)
  expect_false(any(vapply(r$avisos, `[[`, character(1), "tipo") == "truncado"))
})

test_that("ideb_escolas sem escolas degrada com aviso e sem seções de dados", {
  tools <- fake_edubr_tools()
  tools$ideb <- function(uf = NULL, municipio = NULL, etapa = NULL, rede = NULL, ano = NULL, n = NULL) {
    fake_sem_dados(list(uf = uf))
  }
  r <- fake_report(geo_ubatuba, "ideb_escolas", tools = tools)
  expect_equal(secao_ids(r), c("resumo", "leitura"))
  expect_true("sem_dados" %in% vapply(r$avisos, `[[`, character(1), "tipo"))
  expect_match(report_secao(r, "resumo")$markdown, "Não há dados")
})

test_that("ideb_escolas: o LLM não recebe nomes de escolas de terceiros, só a do gestor", {
  visto <- captura_llm()
  fake_report(geo_ubatuba, "ideb_escolas", provider = "gemini", llm = visto$fn, contexto = gestor)
  for (nome in c("ESCOLA ALFA EM", "ESCOLA BETA EM", "ESCOLA GAMA EE", "ESCOLA DELTA EM",
                 "ESCOLA SEM NOTA EM", "ESCOLA EPSILON EM")) {
    expect_false(grepl(nome, visto$prompt, fixed = TRUE), info = nome)
  }
  expect_true(grepl("ESCOLA DO GESTOR EE", visto$prompt, fixed = TRUE))
  dados <- dados_llm(visto)
  esc <- Filter(function(s) identical(s$id, "escolas"), dados$secoes)[[1]]
  sua <- Filter(function(l) isTRUE(l$sua_escola), esc$linhas)
  expect_length(sua, 1)
  expect_equal(sua[[1]]$escola, "ESCOLA DO GESTOR EE")
  # Campos internos e a marca `_destaque` crua não vão ao LLM.
  expect_false(grepl("_destaque", visto$prompt, fixed = TRUE))
  expect_false(grepl("ocultar_llm", visto$prompt, fixed = TRUE))
  # Prompt de tema profundo + regra dos nomes.
  expect_match(visto$system, "Associação NÃO é causa")
  expect_match(visto$system, "Cite o n")
  expect_match(visto$system, "julgamento de qualidade")
  expect_match(visto$system, "NÃO cite nomes de escolas")
  # O formato da resposta continua sendo o último bloco.
  expect_true(regexpr("Formato da resposta", visto$system) > regexpr("Temas aprofundados", visto$system))
})

test_that("a linha do gestor vai ao LLM mesmo além do teto de linhas", {
  tools <- fake_edubr_tools()
  tools$ideb <- function(uf = NULL, municipio = NULL, etapa = NULL, rede = NULL, ano = NULL, n = NULL) {
    dados <- lapply(1:30, function(i) list(
      id_escola = sprintf("350000%02d", i), co_municipio = 3555406L, no_escola = sprintf("TERCEIRA %02d", i),
      rede = "Municipal", ideb_observado = 9 - i / 10
    ))
    dados[[31]] <- list(id_escola = "35038751", co_municipio = 3555406L, no_escola = "ESCOLA DO GESTOR EE",
                        rede = "Estadual", ideb_observado = 3)
    fake_envelope(dados)
  }
  visto <- captura_llm()
  fake_report(geo_ubatuba, "ideb_escolas", provider = "gemini", llm = visto$fn, tools = tools, contexto = gestor)
  esc <- Filter(function(s) identical(s$id, "escolas"), dados_llm(visto)$secoes)[[1]]
  expect_length(esc$linhas, 21)
  expect_equal(esc$linhas_omitidas, 10)
  expect_true(isTRUE(esc$linhas[[21]]$sua_escola))
  expect_false(grepl("TERCEIRA", visto$prompt, fixed = TRUE))
})

# ---------------------------------------------------------------------------
# infraestrutura_ideb

test_that("infraestrutura_ideb chama a regressão com a especificação fixa", {
  tools <- fake_edubr_tools()
  fake_report(list(nivel = "uf", codigo = "BA"), "infraestrutura_ideb",
              opcoes = list(etapa = "fundamental_ii"), tools = tools)
  a <- fake_calls(tools, "regressao_escolas")[[1]]$args
  expect_equal(a$outcome, "ideb_fund_ii")
  expect_equal(unlist(a$predictors), c(
    "in_biblioteca", "in_internet", "in_laboratorio_informatica", "docentes", "matriculas"
  ))
  expect_equal(a$cuts, "localizacao")
  expect_equal(a$uf, "BA")
  expect_equal(a$rede, "publica")
  expect_equal(a$ano_ideb, 2023L)
  expect_true(a$ativas)
  expect_equal(a$modelo, "linear")

  desfechos <- c(fundamental_i = "ideb_fund_i", ensino_medio = "ideb_medio")
  for (et in names(desfechos)) {
    tools <- fake_edubr_tools()
    fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb",
                opcoes = list(etapa = et, rede = "Municipal"), tools = tools)
    a <- fake_calls(tools, "regressao_escolas")[[1]]$args
    expect_equal(a$outcome, desfechos[[et]])
    expect_equal(a$rede, "Municipal")
  }
})

test_that("infraestrutura_ideb: associacoes seguem os limiares de p e o sinal", {
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb")
  expect_equal(secao_ids(r), c("resumo", "associacoes", "coeficientes", "metricas", "leitura"))
  s <- report_secao(r, "associacoes")
  expect_equal(s$tipo, "associacoes")
  expect_equal(s$titulo, "O que anda junto com o IDEB")
  expect_match(s$nota, "^Associação, não causa")
  item <- function(rot, corte) {
    Filter(function(i) i$rotulo == rot && identical(i$corte, corte), s$itens)[[1]]
  }
  # p = 0,0005, +  → maior/alta
  expect_equal(item("Biblioteca", "Urbana")[c("direcao", "seguranca")], list(direcao = "maior", seguranca = "alta"))
  # p = 0,03, −    → menor/media
  expect_equal(item("Internet", "Urbana")[c("direcao", "seguranca")], list(direcao = "menor", seguranca = "media"))
  # p = 0,40       → sem relação clara/baixa
  expect_equal(item("Laboratório de informática", "Urbana")[c("direcao", "seguranca")],
               list(direcao = "sem_relacao_clara", seguranca = "baixa"))
  # p = 0,05 exato → sem relação clara (p ≥ 0,05)
  expect_equal(item("Nº de professores", "Urbana")$direcao, "sem_relacao_clara")
  # p = 0,009, −   → menor/alta
  expect_equal(item("Nº de matrículas", "Urbana")[c("direcao", "seguranca")], list(direcao = "menor", seguranca = "alta"))
  # p = 0,012, +   → maior/media
  expect_equal(item("Nº de professores", "Rural")[c("direcao", "seguranca")], list(direcao = "maior", seguranca = "media"))
  # n do corte (métricas)
  expect_equal(item("Biblioteca", "Urbana")$n, 4228L)
  expect_equal(item("Biblioteca", "Rural")$n, 293L)
  # Sem o intercepto; 5 preditores × 2 cortes; o maior corte primeiro.
  expect_length(s$itens, 10)
  expect_false(any(vapply(s$itens, `[[`, character(1), "rotulo") == "(Intercept)"))
  expect_equal(s$itens[[1]]$corte, "Urbana")
  for (i in s$itens) {
    expect_true(i$direcao %in% c("maior", "menor", "sem_relacao_clara"))
    expect_true(i$seguranca %in% c("alta", "media", "baixa"))
  }
})

test_that("report_direcao e report_seguranca aplicam os limiares do contrato", {
  d <- edumapsAnalytics:::report_direcao
  g <- edumapsAnalytics:::report_seguranca
  expect_equal(d(c(1, -1, 1, -1, 1, 0, NA), c(0.001, 0.001, 0.049, 0.049, 0.05, 0.001, 0.001)),
               c("maior", "menor", "maior", "menor", "sem_relacao_clara", "sem_relacao_clara", "sem_relacao_clara"))
  expect_equal(d(1, NA), "sem_relacao_clara")
  expect_equal(g(c(0.0099, 0.01, 0.049, 0.05, 0.5, NA)), c("alta", "media", "media", "baixa", "baixa", "baixa"))
})

test_that("infraestrutura_ideb: tabelas técnicas recolhidas, formatos e aviso associacao", {
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb")
  coef <- report_secao(r, "coeficientes")
  expect_true(isTRUE(coef$recolhida))
  expect_equal(vapply(coef$colunas, `[[`, character(1), "id"),
               c("corte", "termo_txt", "estimativa_txt", "erro_txt", "p_txt"))
  expect_equal(nrow(coef$linhas), 12)
  expect_equal(coef$linhas$termo_txt[1:2], c("Constante", "Biblioteca"))
  expect_equal(coef$linhas$p_txt[1:3], c("< 0,001", "< 0,001", "0,030"))
  expect_equal(coef$linhas$estimativa_txt[coef$linhas$termo_txt == "Nº de matrículas" & coef$linhas$corte == "Urbana"], "-0,0004")

  met <- report_secao(r, "metricas")
  expect_true(isTRUE(met$recolhida))
  expect_equal(met$linhas$corte, c("Urbana", "Rural"))
  expect_equal(met$linhas$n, c(4228, 293))
  expect_equal(met$linhas$r2, c(0.044, 0.025))
  expect_equal(vapply(met$colunas, `[[`, character(1), "formato"), c("texto", "inteiro", "decimal2", "decimal2"))
  expect_match(met$nota, "4\\.521 de 13\\.435")

  tipos <- vapply(r$avisos, `[[`, character(1), "tipo")
  expect_equal(sum(tipos == "associacao"), 1)
  expect_true("aviso" %in% tipos) # linhas descartadas (do envelope)
  expect_equal(r$fontes[[1]]$ferramenta, "regressao_escolas")
  expect_equal(r$fontes[[1]]$n, 4521L)
  expect_match(r$fontes[[1]]$escopo, "redes públicas")
  expect_match(r$fontes[[1]]$edicao, "IDEB 2023")
  # O resumo determinístico (mock) descreve as associações em palavras.
  expect_match(report_secao(r, "resumo")$markdown, "associação, não causa")
  expect_match(report_secao(r, "resumo")$markdown, "Biblioteca \\(Urbana\\): IDEB maior \\(segurança alta; n = 4\\.228\\)")
})

test_that("infraestrutura_ideb: recorte grande demais é erro de cliente pedindo uma rede", {
  expect_error(
    fake_report(list(nivel = "uf", codigo = "RJ"), "infraestrutura_ideb"),
    "rede específica", class = "invalid_report_request"
  )
})

test_that("infraestrutura_ideb sem dados degrada com aviso associacao e sem_dados", {
  r <- fake_report(list(nivel = "uf", codigo = "AC"), "infraestrutura_ideb")
  expect_equal(secao_ids(r), c("resumo", "leitura"))
  tipos <- vapply(r$avisos, `[[`, character(1), "tipo")
  expect_true(all(c("associacao", "sem_dados") %in% tipos))
})

test_that("infraestrutura_ideb: o LLM recebe as associações e as regras de tema profundo", {
  visto <- captura_llm()
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb", provider = "gemini", llm = visto$fn)
  dados <- dados_llm(visto)
  assoc <- Filter(function(s) identical(s$tipo, "associacoes"), dados$secoes)[[1]]
  expect_length(assoc$itens, 10)
  expect_equal(assoc$itens[[1]]$direcao, "maior")
  expect_true(any(vapply(dados$avisos, function(a) identical(a$tipo, "associacao"), logical(1))))
  expect_match(visto$system, "Associação NÃO é causa")
  # Sem lista de escolas: sem a regra de nomes.
  expect_false(grepl("NÃO cite nomes de escolas", visto$system, fixed = TRUE))
  expect_false(grepl("regressao_escolas", visto$prompt, fixed = TRUE))
  expect_equal(r$rastreio$llm, "ok")
})

test_that("temas descritivos não recebem o complemento de tema profundo", {
  visto <- captura_llm()
  fake_report(list(nivel = "uf", codigo = "SP"), "ideb_territorio", provider = "gemini", llm = visto$fn)
  expect_false(grepl("Temas aprofundados", visto$system, fixed = TRUE))
  expect_false(grepl("NÃO cite nomes de escolas", visto$system, fixed = TRUE))
})

test_that("falha do LLM num tema profundo mantém as seções de dados", {
  llm <- function(system, prompt) stop("timeout")
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb", provider = "gemini", llm = llm)
  expect_equal(r$rastreio$llm, "indisponivel")
  expect_true("associacoes" %in% secao_ids(r))
  expect_true("llm" %in% vapply(r$avisos, `[[`, character(1), "tipo"))
  expect_match(report_secao(r, "resumo")$markdown, "Biblioteca")
})

# ---------------------------------------------------------------------------
# historico_escola

test_that("historico_escola: gráfico de linhas, scores e tabela da série", {
  tools <- fake_edubr_tools()
  r <- fake_report(geo_escola, "historico_escola", tools = tools, contexto = gestor)
  expect_equal(r$recorte$nome, "ESCOLA DO GESTOR EE")
  expect_equal(r$recorte$municipio, "Ubatuba")
  expect_equal(r$titulo, "Histórico da minha escola — ESCOLA DO GESTOR EE — Ubatuba (SP)")
  expect_equal(secao_ids(r), c("resumo", "kpis_ideb", "grafico_ideb", "serie", "scores", "leitura"))
  expect_setequal(vapply(fake_calls(tools), `[[`, character(1), "tool"),
                  c("resumo_escola", "serie_ideb_escola", "scores_escola"))

  graf <- report_secao(r, "grafico_ideb")
  expect_equal(graf$grafico, "linhas")
  expect_equal(graf$x$id, "ano")
  # Etapa sem nenhuma nota (fundamental_i) não vira série.
  expect_equal(vapply(graf$series, `[[`, character(1), "id"), c("fundamental_ii", "ensino_medio"))
  expect_equal(graf$dados$ano, c(2019, 2021, 2023))
  expect_equal(graf$dados$fundamental_ii, c(4.6, 4.8, 4.5))
  expect_equal(graf$formato, "decimal1")

  serie <- report_secao(r, "serie")
  # Edição sem IDEB nem nota (ensino médio 2019) não aparece.
  expect_equal(nrow(serie$linhas), 5)
  expect_equal(serie$linhas$etapa_txt[[1]], "Anos finais")
  expect_equal(vapply(serie$colunas, `[[`, character(1), "formato"), c("texto", "texto", "decimal1", "decimal2"))

  scores <- report_secao(r, "scores")
  expect_equal(scores$titulo, "Scores da escola (0 a 10, Censo 2025)")
  expect_length(scores$itens, 6)
  expect_equal(scores$itens[[1]]$rotulo, "Infraestrutura")
  expect_equal(scores$itens[[1]]$valor, 6.94)
  expect_true(all(vapply(scores$itens, `[[`, character(1), "formato") == "decimal1"))

  kpis <- report_secao(r, "kpis_ideb")
  expect_equal(vapply(kpis$itens, `[[`, character(1), "rotulo"), c(
    "IDEB anos finais (2023)", "Variação anos finais desde a edição anterior", "IDEB ensino médio (2023)"
  ))
  expect_equal(kpis$itens[[2]]$valor, -0.3)
  expect_setequal(vapply(r$fontes, `[[`, character(1), "ferramenta"), c("serie_ideb_escola", "scores_escola"))
})

test_that("historico_escola com INEP inexistente é erro de cliente", {
  expect_error(fake_report(list(nivel = "escola", codigo = "11111111"), "historico_escola"),
               class = "invalid_report_request")
})

test_that("historico_escola sem série nem scores degrada com avisos", {
  tools <- fake_edubr_tools()
  tools$serie_ideb_escola <- function(escola_id = NULL, etapa = NULL) fake_sem_dados()
  tools$scores_escola <- function(escola_id = NULL) fake_sem_dados()
  r <- fake_report(geo_escola, "historico_escola", tools = tools)
  expect_equal(secao_ids(r), c("resumo", "kpis_ideb", "leitura"))
  avisos <- vapply(r$avisos, `[[`, character(1), "mensagem")
  expect_true(any(grepl("não tem IDEB", avisos)))
  expect_true(any(grepl("scores", avisos)))
})

test_that("falha de conexão numa ferramenta da escola é erro da fonte (500)", {
  expect_error(
    fake_report(geo_escola, "historico_escola", tools = fake_edubr_tools(fail = "scores_escola")),
    class = "report_source_error"
  )
})

# ---------------------------------------------------------------------------
# escolas_parecidas

test_that("escolas_parecidas: pede 20 linhas, públicas, uma linha por escola e similaridade", {
  tools <- fake_edubr_tools()
  r <- fake_report(geo_escola, "escolas_parecidas", tools = tools, contexto = gestor)
  a <- fake_calls(tools, "escolas_similares")[[1]]$args
  expect_equal(a$n, 20L)  # 20 linhas (escola × etapa) → até 10 escolas distintas
  expect_true(a$publica)
  expect_null(a$etapa)
  expect_equal(secao_ids(r), c("resumo", "kpis", "escolas", "leitura"))

  tab <- report_secao(r, "escolas")
  expect_equal(tab$linhas$escola, c("VIZINHA UM", "VIZINHA DOIS", "VIZINHA TRES"))
  expect_equal(tab$linhas$etapas[[1]], "Anos finais, Ensino médio")
  expect_equal(tab$linhas$distancia[[1]], 2.441)
  expect_equal(vapply(tab$colunas, `[[`, character(1), "id"),
               c("escola", "municipio", "uf", "rede", "etapas", "distancia"))

  kpis <- report_secao(r, "kpis")
  vals <- vapply(kpis$itens, function(i) i$valor, numeric(1))
  expect_equal(vals, c(3, 1, 2, 2))
  expect_equal(r$fontes[[1]]$ferramenta, "escolas_similares")
  expect_equal(r$fontes[[1]]$n, 3L)
})

test_that("escolas_parecidas repassa a etapa e recusa etapa que a escola não oferta", {
  tools <- fake_edubr_tools()
  r <- fake_report(geo_escola, "escolas_parecidas", opcoes = list(etapa = "ensino_medio"), tools = tools)
  expect_equal(fake_calls(tools, "escolas_similares")[[1]]$args$etapa, "ensino_medio")
  expect_equal(report_secao(r, "escolas")$linhas$escola, c("VIZINHA UM", "VIZINHA TRES"))
  expect_error(
    fake_report(geo_escola, "escolas_parecidas", opcoes = list(etapa = "fundamental_i")),
    "não oferta", class = "invalid_report_request"
  )
})

test_that("escolas_parecidas: o LLM não recebe os nomes das escolas parecidas", {
  visto <- captura_llm()
  fake_report(geo_escola, "escolas_parecidas", provider = "gemini", llm = visto$fn, contexto = gestor)
  for (nome in c("VIZINHA UM", "VIZINHA DOIS", "VIZINHA TRES")) {
    expect_false(grepl(nome, visto$prompt, fixed = TRUE), info = nome)
  }
  esc <- Filter(function(s) identical(s$id, "escolas"), dados_llm(visto)$secoes)[[1]]
  expect_equal(esc$linhas[[1]]$municipio, "Pereira Barreto")
  expect_match(visto$system, "NÃO cite nomes de escolas")
  # Tema descritivo: sem o bloco de tema profundo.
  expect_false(grepl("Temas aprofundados", visto$system, fixed = TRUE))
})

test_that("escolas_parecidas sem vizinhas degrada com aviso", {
  tools <- fake_edubr_tools()
  tools$escolas_similares <- function(escola_id = NULL, n = 5L, etapa = NULL, publica = TRUE) fake_sem_dados()
  r <- fake_report(geo_escola, "escolas_parecidas", tools = tools)
  expect_equal(secao_ids(r), c("resumo", "leitura"))
  expect_true("sem_dados" %in% vapply(r$avisos, `[[`, character(1), "tipo"))
})

# ---------------------------------------------------------------------------
# Construtores e JSON

test_that("report_section_table aceita recolhida e _destaque sem quebrar a Fase 1", {
  df <- data.frame(a = c("x", "y"), v = c(1.234, 2), stringsAsFactors = FALSE)
  s1 <- edumapsAnalytics:::report_section_table("t", "T", list(report_col("a", "A"), report_col("v", "V", "decimal1")), df)
  expect_null(s1$recolhida)
  expect_equal(names(s1$linhas), c("a", "v"))
  df[["_destaque"]] <- c(FALSE, TRUE)
  s2 <- edumapsAnalytics:::report_section_table("t", "T", list(report_col("a", "A")), df, recolhida = TRUE, ocultar_llm = "a")
  expect_true(s2$recolhida)
  j <- edumapsAnalytics:::report_json_section(s2)
  expect_null(j[[".ocultar_llm"]])
  expect_null(j$linhas[[1]][["_destaque"]])
  expect_true(j$linhas[[2]][["_destaque"]])
})

test_that("a seção associacoes serializa no formato do contrato", {
  r <- fake_report(list(nivel = "uf", codigo = "SP"), "infraestrutura_ideb")
  json <- edumapsAnalytics:::report_to_json(r)
  parsed <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  s <- Filter(function(s) identical(s$id, "associacoes"), parsed$secoes)[[1]]
  expect_setequal(names(s), c("id", "tipo", "titulo", "itens", "nota"))
  expect_setequal(names(s$itens[[1]]), c("rotulo", "corte", "direcao", "seguranca", "n"))
  expect_true(is.list(s$itens))
  coef <- Filter(function(s) identical(s$id, "coeficientes"), parsed$secoes)[[1]]
  expect_true(isTRUE(coef$recolhida))
})
