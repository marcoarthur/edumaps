# tests/testthat/test-report-writer.R
#
# Redação das seções de texto: mock determinístico, LLM injetado (só redige
# a partir dos dados), degradação quando o LLM falha e saneamento do
# markdown.

geo_sp <- list(nivel = "uf", codigo = "SP")

test_that("provider mock gera resumo determinístico e a leitura padrão", {
  r1 <- fake_report(geo_sp, "ideb_territorio")
  r2 <- fake_report(geo_sp, "ideb_territorio")
  resumo <- report_secao(r1, "resumo")
  expect_equal(resumo$tipo, "texto")
  expect_equal(resumo$titulo, "Resumo")
  expect_match(resumo$markdown, "Modo demonstração")
  expect_match(resumo$markdown, "IDEB médio 2023: \\*\\*6,2\\*\\* \\(Sudeste: 6,3\\)")
  expect_equal(resumo$markdown, report_secao(r2, "resumo")$markdown)
  expect_match(report_secao(r1, "leitura")$markdown, "IDEB vai de 0 a 10")
  expect_equal(r1$rastreio$llm, "ok")
  expect_equal(r1$rastreio$modelo, "mock")
})

test_that("o LLM recebe persona + complemento e os dados estruturados", {
  visto <- new.env()
  llm <- function(system, prompt) {
    visto$system <- system
    visto$prompt <- prompt
    "[RESUMO]\nO IDEB de SP foi **6,2** em 2023.\n\n[LEITURA]\n- Média simples das escolas."
  }
  r <- fake_report(geo_sp, "ideb_territorio", provider = "gemini", llm = llm)
  expect_equal(report_secao(r, "resumo")$markdown, "O IDEB de SP foi **6,2** em 2023.")
  expect_equal(report_secao(r, "leitura")$markdown, "- Média simples das escolas.")
  expect_equal(r$rastreio$llm, "ok")
  expect_equal(r$rastreio$provedor, "gemini")
  expect_equal(r$rastreio$modelo, "modelo-teste")

  expect_match(visto$system, "GESTOR ESCOLAR")
  expect_match(visto$system, "Não faça contas próprias")
  expect_match(visto$system, "Não afirme causa")
  if (requireNamespace("eduBR", quietly = TRUE)) {
    expect_true(startsWith(visto$system, eduBR::prompt_persona("pesquisadora-educacional")))
  }
  expect_match(visto$prompt, "DADOS \\(JSON\\)")
  dados <- jsonlite::fromJSON(sub("^.*DADOS \\(JSON\\):\n", "", visto$prompt), simplifyVector = FALSE)
  expect_equal(dados$recorte$codigo, "SP")
  expect_true(length(dados$fontes) >= 1)
  # O LLM não recebe seções de texto (só dados).
  tipos <- vapply(dados$secoes, `[[`, character(1), "tipo")
  expect_false("texto" %in% tipos)
})

test_that("o LLM vê números arredondados pelo formato e sem nome de ferramenta", {
  visto <- new.env()
  llm <- function(system, prompt) { visto$prompt <- prompt; "[RESUMO]\nok\n\n[LEITURA]\n- ok" }
  fake_report(geo_sp, "ideb_territorio", provider = "gemini", llm = llm)
  expect_match(visto$prompt, "vírgula decimal|DADOS")
  dados <- jsonlite::fromJSON(sub("^.*DADOS \\(JSON\\):\n", "", visto$prompt), simplifyVector = FALSE)
  # fontes sem o nome interno da ferramenta
  expect_true(all(vapply(dados$fontes, function(f) is.null(f$ferramenta), logical(1))))
  expect_false(grepl("ideb_agregado", visto$prompt, fixed = TRUE))
  # valores decimal1 com no máximo uma casa
  kpis <- Filter(function(s) identical(s$tipo, "indicadores"), dados$secoes)
  for (k in kpis) for (it in k$itens) {
    if (identical(it$formato, "decimal1") && is.numeric(it$valor)) {
      expect_equal(it$valor, round(it$valor, 1))
    }
  }
})

test_that("report_round_formato arredonda conforme o formato", {
  expect_equal(report_round_formato(5.94, "decimal1"), 5.9)
  expect_equal(report_round_formato(5.946, "decimal2"), 5.95)
  expect_equal(report_round_formato(21.4, "inteiro"), 21)
  expect_equal(report_round_formato("Municipal", "texto"), "Municipal")
  expect_equal(report_round_formato(0.12345, "percentual"), 0.123)
  expect_equal(report_round_formato(3.14159, NULL), 3.14159)
})

test_that("falha do LLM não derruba o relatório (degradação)", {
  llm <- function(system, prompt) stop("HTTP 503")
  r <- suppressMessages(capture.output(
    rel <- fake_report(geo_sp, "ideb_territorio", provider = "openai", llm = llm)
  ))
  expect_equal(rel$rastreio$llm, "indisponivel")
  tipos <- vapply(rel$avisos, `[[`, character(1), "tipo")
  expect_true("llm" %in% tipos)
  # Seções de dados presentes; resumo determinístico (sem "Modo demonstração").
  ids <- vapply(rel$secoes, `[[`, character(1), "id")
  expect_true(all(c("resumo", "kpis", "leitura") %in% ids))
  expect_match(report_secao(rel, "resumo")$markdown, "Principais números")
  expect_false(grepl("Modo demonstração", report_secao(rel, "resumo")$markdown))
})

test_that("resposta vazia do LLM também degrada", {
  r <- fake_report(geo_sp, "ideb_territorio", provider = "ollama", llm = function(s, p) "   ")
  expect_equal(r$rastreio$llm, "indisponivel")
})

test_that("resposta sem marcadores vira resumo e a leitura fica a padrão", {
  r <- fake_report(geo_sp, "ideb_territorio", provider = "ollama",
                   llm = function(s, p) "Texto corrido sem marcadores.")
  expect_equal(report_secao(r, "resumo")$markdown, "Texto corrido sem marcadores.")
  expect_match(report_secao(r, "leitura")$markdown, "IDEB vai de 0 a 10")
  expect_equal(r$rastreio$llm, "ok")
})

test_that("report_parse_llm aceita marcadores e títulos", {
  p <- edumapsAnalytics:::report_parse_llm("## Resumo\nA.\n\n## Como ler\n- B")
  expect_equal(p$resumo, "A.")
  expect_equal(p$leitura, "- B")
  p <- edumapsAnalytics:::report_parse_llm("[RESUMO] A em linha.\n[LEITURA] - B")
  expect_equal(p$resumo, "A em linha.")
  expect_equal(p$leitura, "- B")
})

test_that("o markdown do LLM é reduzido ao subconjunto seguro", {
  s <- edumapsAnalytics:::report_sanitize_markdown(paste(
    "<b>Olá</b> [site](http://x.y) ![img](http://x/y.png)",
    "# Título",
    "```r\nprint(1)\n```",
    sep = "\n"
  ))
  expect_false(grepl("<|http|```|!\\[", s))
  expect_match(s, "Olá site")
  expect_match(s, "## Título")
  longo <- edumapsAnalytics:::report_sanitize_markdown(strrep("a", 5000))
  expect_lte(nchar(longo), 3001)
})

test_that("sem dados o LLM não é chamado", {
  chamado <- FALSE
  llm <- function(s, p) {
    chamado <<- TRUE
    "x"
  }
  tools <- fake_edubr_tools()
  tools$perfil_gestor <- function(corte = "rede", unidade = "gestor", rede = NULL, uf = NULL,
                                  regiao = NULL, localizacao = NULL, n = NULL) {
    fake_sem_dados()
  }
  r <- fake_report(geo_sp, "gestores_territorio", provider = "gemini", llm = llm, tools = tools)
  expect_false(chamado)
  expect_match(report_secao(r, "resumo")$markdown, "Não há dados")
  expect_true("sem_dados" %in% vapply(r$avisos, `[[`, character(1), "tipo"))
})
