# testes da medição nacional do IVET (#137, entregável 3; R/ivet-nacional.R)
#
# `ivet_painel()` é pura (não toca no banco): a fonte da verdade aqui é um
# `data.frame` de entradas. `ivet_sql_escolas()` e `ivet_medir_nacional()` são
# testados com uma conexão DBI falsa (classe própria, para não colidir com a do
# test-entity-source-filter.R).

library(DBI)

# Uma escola com dado em todos os blocos. Valores escolhidos para dar blocos
# redondos onde possível (ver as asserções).
fixture_ivet_linha <- function() {
  data.frame(
    co_entidade = 1L,
    codigo_ibge = "3500001",
    populacao = 100000,
    # A — scores 0–10 (5/10 -> 0,5 em cada)
    score_capacidade_atendimento = 5, score_infraestrutura = 5,
    score_capacitacao_docente = 5, score_diversidade_discente = 5,
    score_capacidade_gestora = 5, score_sustentabilidade = 5,
    # B — 0,1 analfabetismo; renda = metade do teto (0,5); saneamento = 0,2
    pct_analfabeto = 0.1, pct_agua_sem_rede = 0.2,
    pct_esgoto_inadequado = 0.2, pct_lixo_inadequado = 0.2,
    pct_sem_banheiro = 0.2, renda_resp_media = 1212,
    pct_sem_instrucao = NA, pct_fund_incomp = NA, pct_preto_pardo = NA,
    # C — 250 sinistros/100 mil (teto 500) e 0,5 veíc/hab (teto 1)
    sinistros_12m = 250, renavam_total_frota = 50000,
    # D — 2,5 km (teto 5); 50 equipes/100 mil hab -> 5/10 mil (teto 8)
    dist_min_km_ubs = 2.5, n_ubs_municipio = 10,
    ativas_ff = 25, equipe_esf = 25, efetividade_vagas_aps = 90,
    # E — 25 homicídios/100 mil (teto 50); latrocínio/lesão = 0
    homicidio_doloso = 25, latrocinio = 0,
    lesao_corporal_seguida_de_morte = 0,
    # F — metade de cada teto (0,5); vegetação 0,5
    fogo_frequencia_media = IVET_TETO_FOGO / 2,
    solo_carbono_medio = IVET_TETO_CARBONO_SOLO / 2,
    fracao_vegetacao_natural = 0.5,
    # G — metade de cada teto -> 0,5
    fundeb_por_aluno = 5000, despesa_educ_por_aluno = 7500,
    autonomia_fiscal_pct = 25,
    stringsAsFactors = FALSE
  )
}

test_that("ivet_painel: escola completa é publicável e casa com ivet_v1", {
  p <- ivet_painel(fixture_ivet_linha())

  expect_equal(p$bloco_A, 0.5)
  expect_equal(p$bloco_B, mean(c(0.1, 0.5, 0.2)))          # analfabetismo+renda+saneamento
  expect_equal(p$bloco_C, 0.5)
  expect_equal(p$bloco_D, mean(c(0.5, 1 - 5 / 8)))         # distância + cobertura
  expect_equal(p$bloco_E, mean(c(0.5, 0, 0)))
  expect_equal(p$bloco_F, 0.5)
  expect_equal(p$bloco_G, 0.5)

  expect_true(p$publicavel)

  # O agregado é o mesmo que o núcleo versionado calcularia (guard contra drift).
  blocos <- c(
    escola = p$bloco_A, socioeconomico = p$bloco_B, mobilidade = p$bloco_C,
    saude = p$bloco_D, seguranca = p$bloco_E, meio_ambiente = p$bloco_F,
    recursos = p$bloco_G
  )
  expect_equal(p$ivet, ivet_v1(blocos)$ivet)
  expect_equal(attr(p, "formula"), ivet_versao())
})

test_that("ivet_painel: sem bloco territorial mínimo, ivet é NA (#154)", {
  d <- fixture_ivet_linha()
  d$sinistros_12m <- NA
  d$renavam_total_frota <- NA
  p <- ivet_painel(d)

  expect_false(p$publicavel)
  expect_true(is.na(p$bloco_C))
  expect_true(is.na(p$ivet))
  # o resto continua calculado (não penaliza por ausência)
  expect_equal(p$bloco_A, 0.5)
})

test_that("ivet_painel: colunas em falta viram NA, nunca 0 (#154)", {
  d <- data.frame(co_entidade = 1L, codigo_ibge = "3500001")
  p <- ivet_painel(d)

  for (col in paste0("bloco_", unname(ivet_blocos()))) {
    expect_true(is.na(p[[col]]), info = col)
  }
  expect_false(p$publicavel)
  expect_true(is.na(p$ivet))
})

test_that("ivet_painel: preserva as colunas de entrada e aceita 0 linhas", {
  d <- fixture_ivet_linha()
  p <- ivet_painel(d)
  expect_true(all(names(d) %in% names(p)))
  expect_equal(nrow(p), 1L)

  vazio <- ivet_painel(d[0, ])
  expect_equal(nrow(vazio), 0L)
  expect_true("ivet" %in% names(vazio))
})

test_that("ivet_resumo_nacional: conta publicáveis e cobertura", {
  d <- rbind(fixture_ivet_linha(), fixture_ivet_linha())
  d$co_entidade <- c(1L, 2L)
  d$sinistros_12m[2] <- NA
  d$renavam_total_frota[2] <- NA
  p <- ivet_painel(d)

  r <- ivet_resumo_nacional(p)
  expect_equal(r$n, 2L)
  expect_equal(r$n_publicavel, 1L)
  expect_equal(unname(r$cobertura["mobilidade"]), 1)
  expect_equal(unname(r$cobertura["escola"]), 2)
  expect_true(is.finite(r$ivet["p50"]))
})

test_that("ivet_sql_escolas: cita as tabelas e medeia os anos de crime", {
  sql <- ivet_sql_escolas(censo_ano = 2025L, raio_m = 1000L, crime_anos = 2021:2023)

  expect_match(sql, "clean.mv_escolas_scores", fixed = TRUE)
  expect_match(sql, "clean.escola_entorno_socioeconomico", fixed = TRUE)
  expect_match(sql, "analytics.mobilidade_escola", fixed = TRUE)
  expect_match(sql, "analytics.acessibilidade_saude", fixed = TRUE)
  expect_match(sql, "clean.brazilcrime_municipio", fixed = TRUE)
  expect_match(sql, "clean.mapbiomas_escola_risco", fixed = TRUE)
  expect_match(sql, "clean.v_mapbiomas_escola_grupos", fixed = TRUE)
  expect_match(sql, "analytics.esforco_fiscal_educacao", fixed = TRUE)
  expect_match(sql, "ano IN (2021, 2022, 2023)", fixed = TRUE)
  expect_match(sql, "nu_ano_censo = $1", fixed = TRUE)
  expect_match(sql, "raio_m = $2", fixed = TRUE)

  expect_error(ivet_sql_escolas(crime_anos = c(2021L, NA)), "inteiros")
  expect_error(ivet_sql_escolas(crime_anos = integer(0)), "inteiros")
})

# Conexão DBI falsa: devolve um painel mínimo (só C+D+E, para o agregado ficar
# publicável) e captura o SQL emitido. Classes com nomes próprios para não
# colidir com as do test-entity-source-filter.R (que roda antes, em ordem
# alfabética).
setClass("MockIvetCon", contains = "DBIConnection")
setClass("MockIvetResult", contains = "DBIResult", slots = c(rows = "data.frame"))
mock_ivet_sql <- new.env(parent = emptyenv())
mock_ivet_sql$sql <- ""

setMethod("dbSendQuery", "MockIvetCon", function(conn, statement, ...) {
  mock_ivet_sql$sql <- statement
  rows <- data.frame(
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
  new("MockIvetResult", rows = rows)
})
setMethod("dbFetch", "MockIvetResult", function(res, n = -1L, ...) res@rows)
setMethod("dbHasCompleted", "MockIvetResult", function(res, ...) TRUE)
setMethod("dbClearResult", "MockIvetResult", function(res, ...) invisible(TRUE))

test_that("ivet_medir_nacional: roda o SQL e devolve o painel publicável", {
  p <- ivet_medir_nacional(con = new("MockIvetCon"))

  expect_match(mock_ivet_sql$sql, "clean.mv_escolas_scores", fixed = TRUE)
  expect_equal(nrow(p), 2L)
  expect_true(all(c("bloco_C", "bloco_D", "bloco_E") %in% names(p)))
  expect_true(all(p$publicavel))
  expect_true(all(is.finite(p$ivet)))
})
