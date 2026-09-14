# tests/testthat/test-entity-source-filter.R
#
# Testa o suporte a `filter` (filtro por geotag/coluna) do
# `load_school_entities.postgres_entity_source()`.

library(DBI)

# Conexão DBI fake: captura o último SELECT emitido e devolve um sample
# fixo na consulta de schema (LIMIT 1).
setClass("MockCon", contains = "DBIConnection", slots = c(last_statement = "character"))
setMethod("dbQuoteIdentifier", "MockCon", function(conn, x, ...) {
  paste0('"', x, '"')
})
setMethod("dbQuoteLiteral", "MockCon", function(conn, x, ...) {
  if (is.character(x)) paste0("'", x, "'") else as.character(x)
})

mock_result_rows <- function(statement) {
  if (grepl("LIMIT 1", statement)) {
    data.frame(co_entidade = 1L, co_regiao = 1L, co_uf = 35L,
               co_municipio = 3550308L, qt_mat_bas = 500, qt_doc_bas = 30)
  } else {
    data.frame(
      co_entidade = c(1L, 2L),
      co_regiao = c(1L, 1L),
      co_uf = c(35L, 35L),
      co_municipio = c(3550308L, 3550308L),
      qt_mat_bas = c(500, 620),
      qt_doc_bas = c(30, 38)
    )
  }
}

mock_last_statement <- new.env(parent = emptyenv())
mock_last_statement$sql <- ""

setClass("MockResult", contains = "DBIResult",
         slots = c(rows = "data.frame", fetched = "logical"))
setMethod("dbFetch", "MockResult", function(res, n = -1L, ...) res@rows)
setMethod("dbClearResult", "MockResult", function(res, ...) invisible(TRUE))

setMethod("dbSendQuery", "MockCon", function(conn, statement, ...) {
  mock_last_statement$sql <- statement
  rows <- mock_result_rows(statement)
  new("MockResult", rows = rows, fetched = FALSE)
})

connect <- function() {
  new("MockCon", last_statement = "")
}

test_that("filter por geotag gera WHERE com colunas citadas", {
  con <- connect()
  source <- postgres_entity_source(con)

  model <- load_school_entities(
    source,
    schema = "clean",
    table_name = "censo_escolas",
    id_column = "co_entidade",
    features = c("qt_mat_bas", "qt_doc_bas"),
    filter = list(co_regiao = 1L, co_uf = 35L, co_municipio = 3550308L)
  )

  expect_s3_class(model, "school_cluster_model")
  expect_equal(model$metadata$schema, "clean")
  expect_equal(model$metadata$table_name, "censo_escolas")
  expect_equal(nrow(model$data), 2)
  expect_true(all(model$data$co_regiao == 1L))
  expect_true(all(model$data$co_uf == 35L))

  sql <- mock_last_statement$sql
  expect_false(grepl("LIMIT 1", sql))
  expect_match(sql, '"co_regiao" = 1', fixed = TRUE)
  expect_match(sql, '"co_uf" = 35', fixed = TRUE)
  expect_match(sql, 'WHERE', fixed = TRUE)
})

test_that("sem filter carrega a tabela inteira", {
  source <- postgres_entity_source(connect())

  model <- load_school_entities(
    source,
    schema = "clean",
    table_name = "censo_escolas",
    id_column = "co_entidade",
    features = c("qt_mat_bas", "qt_doc_bas")
  )

  expect_equal(nrow(model$data), 2)
})

test_that("filter com coluna inexistente gera erro de cliente", {
  source <- postgres_entity_source(connect())

  expect_error(
    load_school_entities(
      source,
      schema = "clean",
      table_name = "censo_escolas",
      id_column = "co_entidade",
      features = c("qt_mat_bas"),
      filter = list(coluna_inexistente = 1L)
    ),
    class = "edumaps_client_error"
  )
})

test_that("filter exige lista nomeada", {
  source <- postgres_entity_source(connect())

  expect_error(
    load_school_entities(
      source,
      schema = "clean",
      table_name = "censo_escolas",
      id_column = "co_entidade",
      features = c("qt_mat_bas"),
      filter = c(1L, 35L)
    ),
    class = "edumaps_client_error"
  )
})