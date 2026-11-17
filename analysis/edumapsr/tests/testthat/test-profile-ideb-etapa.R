# tests/testthat/test-profile-ideb-etapa.R
#
# #483 (RN-01): IDEB e nota SAEB comparados na MESMA etapa no perfil da
# escola e no da rede. Os testes de banco rodam contra o banco de fixtures
# do CI (PG* do ambiente) e se pulam sem ele.

con_ou_skip <- function() {
  con <- tryCatch(
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = Sys.getenv("PGHOST", "localhost"),
      port = as.integer(Sys.getenv("PGPORT", "5432")),
      dbname = Sys.getenv("PGDATABASE", "edumaps_dev"),
      user = Sys.getenv("PGUSER", "devel"),
      password = Sys.getenv("PGPASSWORD", "senhaboa123")
    ),
    error = function(e) NULL
  )
  if (is.null(con)) skip("Banco de teste não disponível")
  con
}

test_that(".ideb_etapa_valida aceita só as três etapas", {
  expect_equal(.ideb_etapa_valida("fundamental_ii"), "fundamental_ii")
  expect_null(.ideb_etapa_valida("fundamental_ii'; DROP TABLE x; --"))
  expect_null(.ideb_etapa_valida(NA))
  expect_null(.ideb_etapa_valida(NULL))
})

test_that(".profile_pop_body filtra a etapa só quando pedida", {
  sem <- .profile_pop_body('"clean"', FALSE)
  com <- .profile_pop_body('"clean"', FALSE, ideb_etapa = "ensino_medio")
  expect_false(grepl("i.etapa =", sem, fixed = TRUE))
  expect_match(com, "AND i.etapa = 'ensino_medio'", fixed = TRUE)
  expect_false(grepl("i.etapa =", .profile_pop_body('"clean"', FALSE, ideb_etapa = "x'--"), fixed = TRUE))
})

test_that("as médias por etapa batem com a planilha do IDEB (banco)", {
  con <- con_ou_skip()
  on.exit(DBI::dbDisconnect(con))
  sq <- DBI::dbQuoteIdentifier(con, "clean")
  ano <- resolve_censo_ano(con, "clean")
  ed <- DBI::dbGetQuery(con, "SELECT max(ano) AS a FROM clean.ideb_notas_escolas")$a
  skip_if(is.na(ed), "sem IDEB no banco")
  for (et in names(IDEB_ETAPAS)) {
    s <- .profile_ideb_etapa_stats(con, sq, FALSE, ano, et, "brasil")
    ref <- DBI::dbGetQuery(con, "
      SELECT avg(x) AS m, count(x) AS n FROM (
        SELECT DISTINCT ON (i.id_escola) i.ideb_observado AS x
          FROM clean.ideb_notas_escolas i
          JOIN clean.censo_escolas e ON e.co_entidade = i.id_escola AND e.nu_ano_censo = $1
                                    AND e.tp_situacao_funcionamento = 1
         WHERE i.ano = $2 AND i.etapa = $3
         ORDER BY i.id_escola, i.nota_media DESC NULLS LAST) t",
      params = list(as.integer(ano), as.integer(ed), et))
    expect_equal(s$ideb$n, as.integer(ref$n), info = et)
    if (ref$n > 0) expect_equal(s$ideb$media, as.numeric(ref$m), tolerance = 1e-9, info = et)
  }
  vazio <- .profile_ideb_etapa_stats(con, sq, FALSE, ano, "quarta_serie", "brasil")
  expect_true(is.na(vazio$ideb$media))
})
