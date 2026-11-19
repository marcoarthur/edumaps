# tests/testthat/test-network-profile.R
#
# Testa a análise PURA do perfil da rede (issue #109). Sem banco.

test_that("analyze_network_profile devolve clusters e indicadores", {
  result <- analyze_network_profile(fixture_network_profile_model())

  expect_s3_class(result, "analysis_result")
  expect_equal(result$analysis, "network_profile")
  expect_true(all(c("clusters", "indicadores") %in% names(result$tables)))

  clusters <- result$tables$clusters
  expect_true(all(c("cluster_id", "cluster_label", "n", "indicador", "media") %in% names(clusters)))
  expect_equal(length(unique(clusters$cluster_id)), 2)

  indicadores <- result$tables$indicadores
  expect_true(all(c("indicador", "rede", "brasil", "variacao") %in% names(indicadores)))
  expect_true(all(indicadores$variacao == 0.1))
})

test_that("metrics resumem a rede", {
  result <- analyze_network_profile(fixture_network_profile_model())

  expect_equal(result$metrics$n_escolas, 30L)
  expect_equal(result$metrics$n_clusters, 2L)
  expect_equal(result$metrics$n_brasil, 180540L)
})

test_that("analyze_network_profile rejeita modelo de outra classe", {
  expect_error(
    analyze_network_profile(fixture_school_profile_model()),
    "network_profile_model"
  )
})

test_that(".network_clusters_long rotula os níveis do INSE e o sem INSE (#497)", {
  wide <- data.frame(
    cluster_id = c(3L, 5L, NA_integer_),
    n = c(10L, 4L, 3L),
    stringsAsFactors = FALSE
  )
  for (ind in PROFILE_INDICATORS) wide[[ind]] <- 0.5

  long <- .network_clusters_long(wide)

  expect_equal(nrow(long), 3 * length(PROFILE_INDICATORS))
  expect_setequal(unique(long$cluster_label), c("INSE Nível III", "INSE Nível V", "Sem INSE"))
  expect_false(any(grepl("cluster", long$cluster_label, ignore.case = TRUE)))
})

test_that("rótulo do grupo e da referência do Brasil (#497)", {
  expect_equal(.network_grupo_label(c(1, 8, NA, 9)),
               c("INSE Nível I", "INSE Nível VIII", "Sem INSE", "Sem INSE"))
  expect_equal(.network_referencia_rotulo(NA_integer_), "Brasil, todas as redes")
  expect_equal(.network_referencia_rotulo(3L), "Brasil, redes municipais")
  expect_equal(.network_referencia_rotulo(2L), "Brasil, redes estaduais")
  expect_equal(.network_referencia_rotulo(4L), "Brasil, escolas privadas")
  expect_match(NETWORK_GRUPO_CRITERIO, "INEP")
})

test_that("nível do INSE em SQL cobre os oito níveis do INEP", {
  sql <- .inse_nivel_sql("s.inse_classificacao")
  for (k in seq_along(INSE_NIVEIS)) {
    expect_true(grepl(sprintf("WHEN 'Nível %s' THEN %d", INSE_NIVEIS[k], k), sql, fixed = TRUE))
  }
})

test_that("run_analysis despacha network_profile via o registry", {
  result <- run_analysis("network_profile", fixture_network_profile_model())
  expect_equal(result$analysis, "network_profile")
})

# #479 (RP-02): cada média diz em quantas escolas se apoia.
test_that("n_com_valor sai das contagens n_<indicador> e fica NA sem elas", {
  inds <- PROFILE_INDICATORS
  wide <- as.data.frame(as.list(stats::setNames(rep(1, length(inds)), inds)))
  wide$cluster_id <- NA_integer_
  wide$n <- 10L
  for (ind in inds) wide[[paste0("n_", ind)]] <- 10L
  wide$n_ideb_observado <- 3L
  long <- .network_clusters_long(wide)
  expect_equal(long$n_com_valor[long$indicador == "ideb_observado"], 3L)
  expect_equal(long$n_com_valor[long$indicador == "prop_licenciatura"], 10L)

  mean_row <- wide
  ind_df <- .network_indicators_df(mean_row, stats::setNames(rep(1, length(inds)), inds))
  expect_equal(ind_df$n_com_valor[ind_df$indicador == "ideb_observado"], 3L)

  sem <- wide[, setdiff(names(wide), paste0("n_", inds))]
  expect_true(all(is.na(.network_clusters_long(sem)$n_com_valor)))
})

test_that("a consulta do perfil conta as escolas com valor por indicador", {
  sql <- .network_count_cols("p")
  expect_match(sql, "count(p.ideb_observado) AS n_ideb_observado", fixed = TRUE)
  expect_equal(length(strsplit(sql, ",")[[1]]), length(PROFILE_INDICATORS))
})

test_that("perfil da rede no banco: mesma rede no Brasil e grupos do INSE (#497)", {
  skip_if(Sys.getenv("PGDATABASE") == "", "sem banco (PGDATABASE)")
  con <- tryCatch(DBI::dbConnect(RPostgres::Postgres()), error = function(e) NULL)
  skip_if(is.null(con), "banco indisponível")
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  alvo <- DBI::dbGetQuery(con, "
    SELECT co_municipio, tp_dependencia FROM clean.censo_escolas
     WHERE nu_ano_censo = (SELECT max(nu_ano_censo) FROM clean.censo_escolas)
       AND tp_situacao_funcionamento = 1
     GROUP BY 1, 2 ORDER BY count(*) DESC, 1, 2 LIMIT 1")
  skip_if(nrow(alvo) == 0, "banco sem escolas")
  src <- structure(list(con = con), class = "postgres_source")

  todas <- load_network_profile(src, codigo_ibge = alvo$co_municipio[1])
  expect_equal(todas$metadata$referencia_escopo, "brasil")
  expect_equal(todas$metadata$referencia_rotulo, "Brasil, todas as redes")

  rede <- load_network_profile(src, codigo_ibge = alvo$co_municipio[1],
                               tp_dependencia = alvo$tp_dependencia[1])
  expect_equal(rede$metadata$referencia_escopo, "rede")
  expect_match(rede$metadata$referencia_rotulo, "^Brasil, ")
  expect_true(is.integer(rede$metadata$n_brasil) && !is.na(rede$metadata$n_brasil))
  expect_match(rede$metadata$grupo_criterio, "INEP")

  grupos <- unique(rede$clusters[, c("cluster_id", "cluster_label", "n")])
  expect_equal(sum(grupos$n), rede$metadata$n_escolas)
  expect_true(all(grepl("^(INSE Nível [IVX]+|Sem INSE)$", grupos$cluster_label)))
})
