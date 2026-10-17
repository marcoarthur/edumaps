# testes da extração do bloco D (saúde) do IVET (#137)
# (R/ivet-saude.R)

test_that("ivet_taxa_10k: razão por 10 mil e ausência", {
  expect_equal(ivet_taxa_10k(50, 10000), 50)
  expect_equal(ivet_taxa_10k(0, 1000), 0)          # zero real
  expect_true(is.na(ivet_taxa_10k(NA, 1000)))
  expect_true(is.na(ivet_taxa_10k(5, 0)))          # população não positiva
  expect_true(is.na(ivet_taxa_10k(NULL, 1000)))
})

test_that("ivet_componente_distancia: direta (mais longe = pior), NA preservado", {
  expect_equal(ivet_componente_distancia(0), 0)
  expect_equal(ivet_componente_distancia(2.5, teto = 5), 0.5)
  expect_equal(ivet_componente_distancia(5, teto = 5), 1)
  expect_equal(ivet_componente_distancia(99, teto = 5), 1)     # satura
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_distancia(NA)))
  expect_true(is.na(ivet_componente_distancia(NULL)))
  expect_true(is.na(ivet_componente_distancia("x")))
  expect_error(ivet_componente_distancia(1, teto = 0), "teto")
})

test_that("ivet_componente_cobertura_aps: inverte (mais provisão = menos vulnerável)", {
  # população 10 mil -> equipes por 10 mil = nº de equipes
  expect_equal(ivet_componente_cobertura_aps(4, 0, 10000, teto = 8), 0.5)
  expect_equal(ivet_componente_cobertura_aps(0, 0, 10000, teto = 8), 1)
  expect_equal(ivet_componente_cobertura_aps(8, 0, 10000, teto = 8), 0)
  expect_equal(ivet_componente_cobertura_aps(0, 16, 10000, teto = 8), 0)  # satura
  # ativas_ff soma com equipe_esf
  expect_equal(ivet_componente_cobertura_aps(2, 2, 10000, teto = 8), 0.5)
  # vazio/NA -> NA (#154)
  expect_true(is.na(ivet_componente_cobertura_aps(NULL, 2, 10000)))
  expect_true(is.na(ivet_componente_cobertura_aps(NA, 2, 10000)))
  expect_true(is.na(ivet_componente_cobertura_aps(2, 2, 0)))
})

test_that("ivet_componente_presenca_ubs: zero real vira vulnerabilidade máxima", {
  expect_equal(ivet_componente_presenca_ubs(4, 10000, teto = 8), 0.5)
  expect_equal(ivet_componente_presenca_ubs(0, 10000, teto = 8), 1)  # zero real
  expect_equal(ivet_componente_presenca_ubs(8, 10000, teto = 8), 0)
  expect_true(is.na(ivet_componente_presenca_ubs(NA, 10000)))
  expect_true(is.na(ivet_componente_presenca_ubs(4, 0)))
})

test_that("ivet_componente_efetividade_aps: inverte a ocupação das vagas", {
  expect_equal(ivet_componente_efetividade_aps(100), 0)
  expect_equal(ivet_componente_efetividade_aps(50), 0.5)
  expect_equal(ivet_componente_efetividade_aps(0), 1)
  expect_true(is.na(ivet_componente_efetividade_aps(NA)))
})

test_that("ivet_bloco_saude_componentes devolve os quatro indicadores", {
  comps <- ivet_bloco_saude_componentes(
    dist_min_km_ubs = 2.5, n_ubs_municipio = 4, ativas_ff = 0,
    equipe_esf = 4, efetividade_vagas_aps = 50, populacao = 10000
  )
  expect_named(comps, c("distancia_ubs", "cobertura_aps", "presenca_ubs",
                        "efetividade_vagas_aps"))
  expect_equal(comps[["distancia_ubs"]], 0.5)
  expect_equal(comps[["cobertura_aps"]], 0.5)
  expect_equal(comps[["presenca_ubs"]], 0.5)
  expect_equal(comps[["efetividade_vagas_aps"]], 0.5)
})

test_that("bloco D default: distancia_ubs + cobertura_aps (média dos disponíveis)", {
  expect_equal(IVET_BLOCO_D_COMPONENTES, c("distancia_ubs", "cobertura_aps"))
  expect_false("presenca_ubs" %in% IVET_BLOCO_D_COMPONENTES)
  expect_false("efetividade_vagas_aps" %in% IVET_BLOCO_D_COMPONENTES)

  # (0.5 + 0.5) / 2 = 0.5
  expect_equal(
    ivet_bloco_saude(
      dist_min_km_ubs = 2.5, ativas_ff = 0, equipe_esf = 4, populacao = 10000
    ),
    0.5
  )
  # só distância disponível (na distância = teto) -> 1
  expect_equal(ivet_bloco_saude(dist_min_km_ubs = 5), 1)
})

test_that("bloco D sem nenhum componente: dimensão NA (não calculada), nunca 0", {
  expect_true(is.na(ivet_bloco_saude()))
  expect_true(is.na(ivet_bloco_saude(dist_min_km_ubs = NA, ativas_ff = NA)))
})

test_that("bloco D: componentes selecionáveis e tetos documentados", {
  # presenca_ubs com município sem UBS (zero real) -> vulnerabilidade máxima
  expect_equal(
    ivet_bloco_saude(n_ubs_municipio = 0, populacao = 10000,
                     componentes = "presenca_ubs"),
    1
  )
  expect_equal(
    ivet_bloco_saude(dist_min_km_ubs = 2.5, teto_distancia_ubs_km = 5,
                     componentes = "distancia_ubs"),
    0.5
  )
  expect_error(
    ivet_bloco_saude(dist_min_km_ubs = 1, componentes = "inexistente"),
    "não corresponde"
  )
})
