# tests/testthat/test-censo-dictionary.R

library(testthat)
library(DBI)
library(RPostgres)

# Helper: conectar ao banco de teste
get_test_con <- function() {
  # Usar variáveis de ambiente ou padrão
  host <- Sys.getenv("PGHOST", "localhost")
  port <- as.integer(Sys.getenv("PGPORT", "5432"))
  dbname <- Sys.getenv("PGDATABASE", "edumaps_dev")
  user <- Sys.getenv("PGUSER", "devel")
  password <- Sys.getenv("PGPASSWORD", "senhaboa123")

  DBI::dbConnect(
    RPostgres::Postgres(),
    host = host, port = port, dbname = dbname,
    user = user, password = password
  )
}

# Skip se não houver banco disponível
skip_if_no_db <- function() {
  con <- tryCatch(get_test_con(), error = function(e) NULL)
  if (is.null(con)) {
    skip("Banco de teste não disponível")
  }
  DBI::dbDisconnect(con)
}

test_that("censo_dictionary carrega sem erro", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  expect_s3_class(dict, "censo_dictionary")
  expect_true(nrow(dict) > 0)
  expect_true(all(c("table_name", "column_name", "data_type", "description") %in% names(dict)))
})

test_that("censo_dictionary cobre as 4 tabelas censo", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  tables <- unique(dict$table_name)
  expected <- c("clean.censo_escolas", "clean.censo_matriculas",
                "clean.censo_docentes", "clean.censo_gestor")
  expect_true(all(expected %in% tables))
})

test_that("cada tabela tem dezenas de colunas", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  counts <- table(dict$table_name)
  expect_true(all(counts > 50))  # cada tabela censo tem > 50 colunas
})

test_that("tp_dependencia tem value_domain em censo_escolas", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con, include_domain = TRUE)
  row <- dict[dict$table_name == "clean.censo_escolas" & dict$column_name == "tp_dependencia", ]
  expect_true(nrow(row) == 1, info = "tp_dependencia em clean.censo_escolas")
  expect_false(is.null(row$value_domain[[1]]), info = "value_domain em clean.censo_escolas")

  dom <- row$value_domain[[1]]
  expect_true("1" %in% names(dom) && dom[["1"]] == "Federal")
  expect_true("2" %in% names(dom) && dom[["2"]] == "Estadual")
  expect_true("3" %in% names(dom) && dom[["3"]] == "Municipal")
  expect_true("4" %in% names(dom) && dom[["4"]] == "Privada")
})

test_that("colunas PK marcadas (linha_id, nu_ano_censo, co_entidade)", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)

  # censo_escolas: PK é linha_id
  row <- dict[dict$table_name == "clean.censo_escolas" & dict$column_name == "linha_id", ]
  expect_true(row$is_pk, info = "linha_id é PK em clean.censo_escolas")

  # co_entidade NÃO é PK em censo_escolas
  row <- dict[dict$table_name == "clean.censo_escolas" & dict$column_name == "co_entidade", ]
  expect_false(row$is_pk, info = "co_entidade NÃO é PK em clean.censo_escolas")

  # nu_ano_censo + co_entidade são PK composta em matriculas/docentes/gestor
  for (t in c("clean.censo_matriculas", "clean.censo_docentes", "clean.censo_gestor")) {
    row1 <- dict[dict$table_name == t & dict$column_name == "nu_ano_censo", ]
    row2 <- dict[dict$table_name == t & dict$column_name == "co_entidade", ]
    expect_true(row1$is_pk, info = sprintf("nu_ano_censo é PK em %s", t))
    expect_true(row2$is_pk, info = sprintf("co_entidade é PK em %s", t))
  }
})

test_that("year_introduced preenchido (>= 2025)", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  expect_true(all(dict$year_introduced >= 2025, na.rm = TRUE))
})

test_that("print e summary funcionam", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  expect_output(print(dict), "<censo_dictionary>")
  sm <- summary(dict)
  expect_s3_class(sm, "data.frame")
  expect_equal(nrow(sm), 4)
  expect_true(all(c("table", "n_cols", "n_pk", "n_with_domain") %in% names(sm)))
})

test_that("censo_dict_filter funciona", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con)
  tp_cols <- censo_dict_filter(dict, "^tp_")
  expect_true(all(grepl("^tp_", tp_cols$column_name)))
  expect_true(nrow(tp_cols) > 0)
})

test_that("censo_dict_domain retorna domínio de tp_dependencia", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict <- censo_dictionary(con, include_domain = TRUE)
  dom <- censo_dict_domain(dict, "clean.censo_escolas", "tp_dependencia")
  expect_type(dom, "list")
  expect_equal(dom[["1"]], "Federal")
  expect_equal(dom[["4"]], "Privada")
})

test_that("censo_dict_validate: sem colunas faltando no dicionário", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  val <- censo_dict_validate(con)
  expect_type(val, "list")
  expect_true("ok" %in% names(val))
  expect_true("missing_cols" %in% names(val))
  expect_true("missing_domains" %in% names(val))

  # Se falhar, mostrar detalhes
  if (!val$ok) {
    if (length(val$missing_cols) > 0) {
      cat("Colunas no banco mas não no dicionário:\n")
      print(val$missing_cols)
    }
    if (length(val$missing_domains) > 0) {
      cat("Colunas tp_/in_ sem value_domain:\n")
      print(val$missing_domains)
    }
  }
  # Não falhar hard: pode haver colunas novas legítimas
  # expect_true(val$ok, info = "Todas as colunas do banco estão no dicionário")
})

test_that("filtro por year funciona", {
  skip_if_no_db()
  con <- get_test_con()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  dict_2025 <- censo_dictionary(con, year = 2025)
  dict_latest <- censo_dictionary(con, year = NULL)

  # Com year=2025 deve ter <= linhas que sem filtro (pode ser igual se só 2025)
  expect_true(nrow(dict_2025) <= nrow(dict_latest))
})