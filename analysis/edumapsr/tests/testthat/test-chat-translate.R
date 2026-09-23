test_that("chat_provider_url garante o sufijo /v1", {
  expect_equal(edumapsAnalytics:::chat_provider_url("http://localhost:11434"), "http://localhost:11434/v1")
  expect_equal(edumapsAnalytics:::chat_provider_url("http://localhost:11434/"), "http://localhost:11434/v1")
  expect_equal(edumapsAnalytics:::chat_provider_url("http://x/v1"), "http://x/v1")
})

test_that("chat_validate_sql aceita SELECT somente leitura em clean./analytics.", {
  boas <- c(
    "SELECT * FROM clean.censo_escolas LIMIT 10",
    "select count(*) as n from analytics.mv_municipios_consolidado where co_municipio = 3550308",
    "SELECT a.no_entidade, count(b.co_entidade) FROM clean.censo_escolas a JOIN clean.censo_matriculas b USING (co_entidade) GROUP BY a.no_entidade"
  )
  for (sql in boas) {
    expect_true(edumapsAnalytics:::chat_validate_sql(sql), info = sql)
  }
})

test_that("chat_validate_sql bloqueia multi-statement, nao-SELECT e destrutivos", {
  ruins <- c(
    "", "  ", NULL,
    "SELECT 1; DROP TABLE x",
    "DELETE FROM clean.censo_escolas",
    "INSERT INTO clean.censo_escolas (a) VALUES (1)",
    "UPDATE clean.censo_escolas SET a = 1",
    "DROP TABLE clean.censo_escolas",
    "SELECT * FROM staging.censo_escolas",
    "SELECT * FROM public.pg_settings",
    "SELECT * FROM information_schema.tables",
    "SELECT * FROM gestores",
    "VACUUM clean.censo_escolas",
    "EXPLAIN SELECT * FROM clean.censo_escolas",
    "COPY clean.censo_escolas TO '...'",
    "SELECT pg_terminate_backend(1)"
  )
  for (sql in ruins) {
    expect_false(edumapsAnalytics:::chat_validate_sql(sql), info = sql)
  }
})

test_that("chat_origem extrai tabelas de FROM/JOIN", {
  sql <- paste(
    "SELECT a.no_entidade, b.total",
    "FROM clean.censo_escolas a",
    "JOIN analytics.mv_rede_escolas b ON b.co_entidade = a.co_entidade"
  )
  origens <- edumapsAnalytics:::chat_origem(sql)
  expect_setequal(origens, c("clean.censo_escolas", "analytics.mv_rede_escolas"))
})

test_that("chat_origem devolve vazio quando no ha FROM/JOIN", {
  expect_length(edumapsAnalytics:::chat_origem("SELECT 1"), 0)
  expect_length(edumapsAnalytics:::chat_origem(""), 0)
})

test_that("chat_redact remove colunas PII do resultado", {
  glossario <- edumapsAnalytics:::chat_glossary()
  df <- data.frame(
    no_entidade = "ESCOLA X",
    nome_gestor = "Fulano",
    nu_telefone = "11999999999",
    co_municipio = "3550308",
    stringsAsFactors = FALSE
  )

  limpo <- edumapsAnalytics:::chat_redact(df, glossario)
  expect_false("nome_gestor" %in% names(limpo))
  expect_false("nu_telefone" %in% names(limpo))
  expect_true("no_entidade" %in% names(limpo))
  expect_true("co_municipio" %in% names(limpo))
})

test_that("chat_redact tolera resultado vazio", {
  glossario <- edumapsAnalytics:::chat_glossary()
  expect_null(edumapsAnalytics:::chat_redact(NULL, glossario))
  vazio <- data.frame(a = integer())
  expect_equal(edumapsAnalytics:::chat_redact(vazio, glossario), vazio)
})

test_that("chat_redact remove colunas geometricas (pq_geometry)", {
  glossario <- edumapsAnalytics:::chat_glossary()
  df <- data.frame(no_entidade = "ESCOLA X", stringsAsFactors = FALSE)
  df$geometry <- structure(list("POINT(0 0)"), class = "pq_geometry")

  limpo <- edumapsAnalytics:::chat_redact(df, glossario)
  expect_false("geometry" %in% names(limpo))
  expect_true("no_entidade" %in% names(limpo))

  df2 <- data.frame(no_entidade = "ESCOLA X", geom = "POINT(0 0)", stringsAsFactors = FALSE)
  limpo2 <- edumapsAnalytics:::chat_redact(df2, glossario)
  expect_false("geom" %in% names(limpo2))
})

test_that("chat_invalid e chat_provider_failed sinalizam classes corretas", {
  expect_error(edumapsAnalytics:::chat_invalid("msg"), class = "invalid_pergunta")
  expect_error(edumapsAnalytics:::chat_invalid("msg"), class = "edumaps_client_error")
  expect_error(edumapsAnalytics:::chat_provider_failed("msg"), class = "chat_provider_error")
})

test_that("chat_extract_sql extrai de bloco ```sql e de SELECT solto", {
  expect_equal(
    edumapsAnalytics:::chat_extract_sql("bla\n```sql\nSELECT 1\n```\nfim"),
    "SELECT 1"
  )
  expect_equal(
    edumapsAnalytics:::chat_extract_sql("```sql\nSELECT 1;\n```"),
    "SELECT 1"
  )
  expect_equal(
    edumapsAnalytics:::chat_extract_sql("Claro: SELECT a FROM clean.x"),
    "SELECT a FROM clean.x"
  )
  expect_null(edumapsAnalytics:::chat_extract_sql("desculpe, não sei"))
})

test_that("ask_censo valida a pergunta antes de abrir conexo", {
  expect_error(ask_censo(NULL), class = "invalid_pergunta")
  expect_error(ask_censo(""), class = "invalid_pergunta")
  expect_error(ask_censo(paste(rep("a", 501), collapse = "")), class = "invalid_pergunta")
  expect_error(ask_censo(123), class = "invalid_pergunta")
})