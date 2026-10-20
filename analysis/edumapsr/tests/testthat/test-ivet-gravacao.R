# tests/testthat/test-ivet-gravacao.R
#
# Materialização do IVET (#296): mapeamento do painel para
# `analytics.ivet_escola`, SQL do upsert e o glue de gravação/refresh —
# tudo com conexões DBI falsas (nenhum teste toca no banco; a integração
# real acontece no deploy da change + job).
library(DBI)

# Painel mínimo no formato de `ivet_painel()`: uma linha publicável, uma
# não-publicável (bloco territorial ausente) e uma publicável com blocos
# parciais — para exercitar a semântica #154 (ausência vira NA, nunca 0).
painel_exemplo <- function() {
  dados <- data.frame(
    co_entidade = c(3500001, 3500002, 3500003),
    codigo_ibge = c("3500001", "3500002", "3500003"),
    ivet        = c(0.4, NA, 0.6),
    publicavel  = c(TRUE, FALSE, TRUE),
    stringsAsFactors = FALSE
  )
  for (l in unname(ivet_blocos())) {
    dados[[paste0("bloco_", l)]] <- c(0.5, NA, 0.7)
  }
  attr(dados, "formula") <- "ivet-v1.2-teste"
  attr(dados, "dataset_version") <- "lock-abc"
  attr(dados, "transform_version") <- "v9"
  dados
}

test_that("ivet_gravacao_tabela mapeia o painel para as colunas da tabela", {
  tab <- ivet_gravacao_tabela(
    painel_exemplo(),
    nu_ano_censo = 2025L, raio_m = 1000L,
    dt_snapshot = as.Date("2026-10-20")
  )
  expect_named(tab, c(
    "co_entidade", "nu_ano_censo", "raio_m", "ivet", "publicavel",
    "bloco_a", "bloco_b", "bloco_c", "bloco_d", "bloco_e", "bloco_f",
    "bloco_g", "formula", "dataset_version", "transform_version",
    "dt_snapshot"
  ))
  expect_equal(nrow(tab), 3)
  # bloco_A..G do painel viram bloco_a..g; NA preservado (#154)
  expect_equal(tab$bloco_a, c(0.5, NA, 0.7))
  expect_equal(tab$bloco_g, c(0.5, NA, 0.7))
  expect_equal(tab$ivet, c(0.4, NA, 0.6))
  expect_equal(tab$publicavel, c(TRUE, FALSE, TRUE))
  expect_equal(tab$nu_ano_censo, rep(2025L, 3))
  expect_equal(tab$raio_m, rep(1000L, 3))
  expect_equal(tab$formula, rep("ivet-v1.2-teste", 3))
  expect_equal(tab$dt_snapshot, rep(as.Date("2026-10-20"), 3))
})

test_that("proveniência ausente vira NA e sem lock a fórmula é a vigente", {
  p <- painel_exemplo()
  attr(p, "dataset_version") <- NULL
  attr(p, "transform_version") <- NULL
  attr(p, "formula") <- NULL
  tab <- ivet_gravacao_tabela(p)
  expect_true(all(is.na(tab$dataset_version)))
  expect_true(all(is.na(tab$transform_version)))
  # sem attr, a fórmula corrente do pacote entra na coluna (NOT NULL no banco)
  expect_equal(tab$formula, rep(ivet_versao(), 3))
})

test_that("ivet_gravacao_tabela valida as entradas", {
  expect_error(ivet_gravacao_tabela("x"), "data.frame")

  p <- painel_exemplo()
  p[["bloco_C"]] <- NULL
  expect_error(ivet_gravacao_tabela(p), "ausentes")

  p2 <- painel_exemplo()
  p2$publicavel[[1]] <- NA
  expect_error(ivet_gravacao_tabela(p2), "publicavel")

  expect_error(
    ivet_gravacao_tabela(painel_exemplo(), nu_ano_censo = NA), "nu_ano_censo"
  )
  expect_error(
    ivet_gravacao_tabela(painel_exemplo(), raio_m = 0), "raio_m"
  )
})

test_that("ivet_gravacao_sql faz upsert por snapshot e atualiza calculado_em", {
  sql <- ivet_gravacao_sql()
  expect_match(sql, "INSERT INTO analytics.ivet_escola", fixed = TRUE)
  expect_match(sql, "FROM tmp_ivet_escola", fixed = TRUE)
  expect_match(sql, paste0(
    "ON CONFLICT (co_entidade, nu_ano_censo, raio_m, dt_snapshot)"
  ), fixed = TRUE)
  expect_match(sql, "calculado_em = now()", fixed = TRUE)
  expect_match(sql, "ivet = EXCLUDED.ivet", fixed = TRUE)
  expect_match(sql, "bloco_g = EXCLUDED.bloco_g", fixed = TRUE)
  # dt_snapshot é o aldo do conflito: não entra no SET
  expect_no_match(sql, "dt_snapshot = EXCLUDED.dt_snapshot", fixed = TRUE)

  # tabela/staging parametrizáveis (mesmo formato)
  sql2 <- ivet_gravacao_sql(tabela = "outra.tabela", staging = "tmp_x")
  expect_match(sql2, "INSERT INTO outra.tabela", fixed = TRUE)
  expect_match(sql2, "FROM tmp_x", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# Conexão DBI falsa para o glue de gravação: captura o dataframe da staging,
# o SQL executado e a limpeza. Nomes de classe próprios para não colidir com
# os mocks de test-ivet-nacional.R.
# ---------------------------------------------------------------------------
setClass("MockGravCon", contains = "DBIConnection")
mock_grav <- new.env(parent = emptyenv())
mock_grav$tabela <- NULL
mock_grav$sql <- ""
mock_grav$removidas <- character(0)

# Assinatura explícita nas DUAS posições: sem ela, o default de
# DBIConnection##character do DBI vence o dispatch e o mock é ignorado.
setMethod("dbWriteTable", "MockGravCon", function(conn, name, value, ...) {
  mock_grav$tabela <- value
  TRUE
})
setMethod(
  "dbExecute",
  signature(conn = "MockGravCon", statement = "character"),
  function(conn, statement, ...) {
    mock_grav$sql <- statement
    nrow(mock_grav$tabela)
  }
)
setMethod("dbRemoveTable", "MockGravCon", function(conn, name, ...) {
  mock_grav$removidas <- c(mock_grav$removidas, name)
  TRUE
})

test_that("ivet_gravar_painel sobe staging, executa o upsert e limpa", {
  mock_grav$tabela <- NULL
  mock_grav$sql <- ""
  mock_grav$removidas <- character(0)

  con <- new("MockGravCon")
  n <- ivet_gravar_painel(
    con, painel_exemplo(), dt_snapshot = as.Date("2026-10-20")
  )
  expect_equal(n, 3)
  expect_s3_class(mock_grav$tabela, "data.frame")
  expect_equal(mock_grav$tabela$dt_snapshot[[1]], as.Date("2026-10-20"))
  expect_match(mock_grav$sql, "ON CONFLICT", fixed = TRUE)
  expect_equal(mock_grav$removidas, "tmp_ivet_escola") # on.exit limpou
})

# ---------------------------------------------------------------------------
# Refresh completo (medir + gravar) com conexão falsa que responde à
# extração do ivet_sql_escolas() e aos mocks de gravação acima.
# ---------------------------------------------------------------------------
setClass("MockRefreshCon", contains = "DBIConnection")
mock_refresh <- new.env(parent = emptyenv())
mock_refresh$gravada <- NULL

setMethod(
  "dbGetQuery",
  signature(conn = "MockRefreshCon", statement = "character"),
  function(conn, statement, ...) {
    data.frame(
      co_entidade = 1:2,
      codigo_ibge = c("3500001", "3500002"),
      populacao = c(100000, 100000),
      sinistros_12m = c(250, 500),
      renavam_total_frota = c(50000, 100000),
      dist_min_km_ubs = c(2.5, 5),
      n_ubs_municipio = c(10, 10),
      ativas_ff = c(25, 50),
      equipe_esf = c(25, 50),
      homicidio_doloso = c(25, 50),
      latrocinio = c(0, 5),
      lesao_corporal_seguida_de_morte = c(0, 5),
      stringsAsFactors = FALSE
    )
  }
)
setMethod("dbWriteTable", "MockRefreshCon", function(conn, name, value, ...) {
  mock_refresh$gravada <- value
  TRUE
})
setMethod(
  "dbExecute",
  signature(conn = "MockRefreshCon", statement = "character"),
  function(conn, statement, ...) {
    nrow(mock_refresh$gravada)
  }
)
setMethod("dbRemoveTable", "MockRefreshCon", function(conn, name, ...) TRUE)

test_that("ivet_refresh mede, grava e devolve o resumo", {
  mock_refresh$gravada <- NULL
  con <- new("MockRefreshCon")

  r <- withVisible(ivet_refresh(
    con, censo_ano = 2025L, raio_m = 1000L,
    dt_snapshot = as.Date("2026-10-20")
  ))
  expect_false(r$visible) # invisível, como todo resumo de job
  r <- r$value
  expect_equal(r$n, 2)
  expect_equal(r$n_publicavel, 2) # C+D+E presentes nas duas linhas
  expect_equal(r$n_gravadas, 2)
  expect_equal(r$dt_snapshot, as.Date("2026-10-20"))
  expect_match(r$formula, "^ivet-v")
  # o que foi para a staging é o painel medido, na ordem certa
  expect_equal(mock_refresh$gravada$co_entidade, c(1, 2))
  expect_true(all(mock_refresh$gravada$publicavel))
})
