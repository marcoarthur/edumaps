test_that("chat_glossary carrega o YAML curdo", {
  glossario <- edumapsAnalytics:::chat_glossary()
  expect_type(glossario, "list")
  expect_true("tabelas" %in% names(glossario))
  expect_true("colunas" %in% names(glossario))
  expect_true("conexoes" %in% names(glossario))
  expect_true("termos" %in% names(glossario))
  expect_true("ocultar" %in% names(glossario))
})

test_that("whitelist do glossrio s so tabelas clean./analytics. e no expoe dados sensveis", {
  glossario <- edumapsAnalytics:::chat_glossary()
  tabelas <- edumapsAnalytics:::chat_tables(glossario)

  expect_gt(nrow(tabelas), 0)
  expect_true(all(tabelas$schema %in% edumapsAnalytics:::CHAT_ALLOWED_SCHEMAS))

  nms <- paste(tabelas$schema, tabelas$tabela, sep = ".")
  sensiveis <- c(
    "gestores", "sessoes", "contatos", "inventario",
    "clustering_metadata", "similarity_pairs", "city_school_analytics",
    "minion_jobs", "minion_workers"
  )
  for (s in sensiveis) {
    expect_false(any(grepl(paste0("\\.", s, "$"), nms)),
      info = paste("tabela sensvel no glossrio:", s)
    )
  }
})

test_that("chat_curated_columns devolve uma linha por coluna curada", {
  glossario <- edumapsAnalytics:::chat_glossary()
  curadas <- edumapsAnalytics:::chat_curated_columns(glossario)
  expect_gt(nrow(curadas), 0)
  expect_true(all(curadas$schema %in% edumapsAnalytics:::CHAT_ALLOWED_SCHEMAS))
  expect_false(anyNA(curadas$descricao))
})

test_that("chat_dictionary_text monta o bloco do prompt com tabelas, chaves e restries", {
  glossario <- edumapsAnalytics:::chat_glossary()
  dicionario <- data.frame(
    schema_table_col = c(
      "clean.censo_escolas.no_entidade",
      "clean.censo_escolas.co_municipio"
    ),
    coluna = c("no_entidade", "co_municipio"),
    tipo = c("text", "text"),
    descricao = c("Nome da escola", "C\u00f3digo IBGE do munic\u00edpio"),
    descricao_tabela = c("Escolas do Censo Escolar", "Escolas do Censo Escolar"),
    chave = c("co_entidade", "co_entidade"),
    schema_table = c("clean.censo_escolas", "clean.censo_escolas"),
    stringsAsFactors = FALSE
  )

  texto <- edumapsAnalytics:::chat_dictionary_text(dicionario, glossario)
  texto_unido <- paste(texto, collapse = "\n")

  expect_match(texto_unido, "DICION\u00c1RIO DE DADOS")
  expect_match(texto_unido, "### clean.censo_escolas")
  expect_match(texto_unido, "(chave: co_entidade)")
  expect_match(texto_unido, "no_entidade")
  expect_match(texto_unido, "COMO AS TABELAS SE CONECTAM")
  expect_match(texto_unido, "GLOSS\u00c1RIO EDUCACIONAL")
  expect_match(texto_unido, "CODIFICA\u00c7\u00d5ES")
  expect_match(texto_unido, "RESTRI\u00c7\u00d5ES DE PRIVACIDADE")
})

test_that("chat_dictionary_text limita colunas por tabela e avisa o modelo", {
  glossario <- edumapsAnalytics:::chat_glossary()
  dicionario <- data.frame(
    schema_table_col = sprintf("clean.censo_escolas.col_%02d", 1:30),
    coluna = sprintf("col_%02d", 1:30),
    tipo = rep("integer", 30),
    descricao = rep("x", 30),
    descricao_tabela = rep("t", 30),
    chave = rep("co_entidade", 30),
    schema_table = rep("clean.censo_escolas", 30),
    stringsAsFactors = FALSE
  )
  texto <- paste(edumapsAnalytics:::chat_dictionary_text(dicionario, glossario), collapse = "\n")
  cap <- edumapsAnalytics:::CHAT_MAX_COLUNAS_POR_TABELA
  expect_match(texto, "col_01")
  expect_match(texto, sprintf("col_%02d", cap))
  expect_false(grepl(sprintf("col_%02d", cap + 1), texto, fixed = TRUE))
  expect_match(texto, "use SELECT \\* para ver")
})

test_that("chat_glossary_path acha o dicionario.yml instalado ou em inst/", {
  p <- edumapsAnalytics:::chat_glossary_path()
  expect_true(file.exists(p))
})

test_that("chat_tables trata glossrio sem tabelas", {
  vazio <- edumapsAnalytics:::chat_tables(list(colunas = list()))
  expect_equal(nrow(vazio), 0)
  expect_equal(names(vazio), c("schema", "tabela", "descricao", "chave"))
})