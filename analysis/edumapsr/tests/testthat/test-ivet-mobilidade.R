# testes da extração do bloco C (mobilidade) do IVET (#137, #278)
# (R/ivet-mobilidade.R)
#
# C combina exposição viária (sinistros RENAEST por 100 mil + frota RENAVAM por
# habitante, ambas diretas) e acesso a pé (população alcançável em 15 min da
# isócrona, invertido). O acesso é piloto no ES: fora dele o componente é NA.

test_that("ivet_componente_risco_sinistros: direta (mais sinistros = pior)", {
  expect_equal(ivet_componente_risco_sinistros(500, 100000, teto = 500), 1)
  expect_equal(ivet_componente_risco_sinistros(50, 10000, teto = 500), 1)
  expect_equal(ivet_componente_risco_sinistros(25, 10000, teto = 500), 0.5)
  expect_equal(ivet_componente_risco_sinistros(0, 10000, teto = 500), 0)   # zero real
  expect_equal(ivet_componente_risco_sinistros(999, 1000, teto = 500), 1)  # satura
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_risco_sinistros(NA, 10000)))
  expect_true(is.na(ivet_componente_risco_sinistros(NULL, 10000)))
  expect_true(is.na(ivet_componente_risco_sinistros("x", 10000)))
  expect_true(is.na(ivet_componente_risco_sinistros(10, 0)))               # população inválida
  expect_error(ivet_componente_risco_sinistros(10, 1000, teto = 0), "teto")
})

test_that("ivet_componente_exposicao_frota: direta (mais frota = pior)", {
  expect_equal(ivet_componente_exposicao_frota(5000, 10000, teto = 1), 0.5)
  expect_equal(ivet_componente_exposicao_frota(0, 10000, teto = 1), 0)      # zero real
  expect_equal(ivet_componente_exposicao_frota(10000, 10000, teto = 1), 1)
  expect_equal(ivet_componente_exposicao_frota(999999, 10000, teto = 1), 1) # satura
  # vazio/NA -> NA (#154)
  expect_true(is.na(ivet_componente_exposicao_frota(NA, 10000)))
  expect_true(is.na(ivet_componente_exposicao_frota(NULL, 10000)))
  expect_true(is.na(ivet_componente_exposicao_frota(1000, 0)))
  expect_error(ivet_componente_exposicao_frota(1000, 10000, teto = 0), "teto")
})

test_that("ivet_componente_acesso_isocrona: invertido (mais acesso = menos)", {
  # invertido: população no teto -> 0 (menos vulnerável); zero -> 1 (pior)
  expect_equal(ivet_componente_acesso_isocrona(50000, teto = 50000), 0)
  expect_equal(ivet_componente_acesso_isocrona(0, teto = 50000), 1)
  expect_equal(ivet_componente_acesso_isocrona(25000, teto = 50000), 0.5)
  expect_equal(ivet_componente_acesso_isocrona(999999, teto = 50000), 0) # satura
  expect_equal(ivet_componente_acesso_isocrona(-5, teto = 50000), 1)     # clamp
  # vazio/NA -> NA (#154): fora do piloto, sem penalidade
  expect_true(is.na(ivet_componente_acesso_isocrona(NA)))
  expect_true(is.na(ivet_componente_acesso_isocrona(NULL)))
  expect_true(is.na(ivet_componente_acesso_isocrona("x")))
  expect_error(ivet_componente_acesso_isocrona(1000, teto = 0), "teto")
})

test_that("ivet_bloco_mobilidade_componentes devolve os três componentes", {
  comps <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
    pop_acessivel_15min = 25000, teto_acesso_15min = 50000
  )
  expect_named(
    comps, c("risco_sinistros", "exposicao_frota", "acesso_isocrona")
  )
  expect_equal(comps[["risco_sinistros"]], 0.5)
  expect_equal(comps[["exposicao_frota"]], 0.5)
  expect_equal(comps[["acesso_isocrona"]], 0.5)      # 25 mil de teto 50 mil
  # fora do piloto: acesso NA, os demais intactos
  comps_np <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000
  )
  expect_true(is.na(comps_np[["acesso_isocrona"]]))
})

test_that("ivet_bloco_mobilidade: média das disponíveis, NA fora (#154)", {
  expect_equal(
    ivet_bloco_mobilidade(sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000),
    0.5
  )
  # só um componente presente: a dimensão usa só ele (NA fora do denominador)
  expect_equal(
    ivet_bloco_mobilidade(sinistros_12m = 25, renavam_total_frota = NULL, populacao = 10000),
    0.5
  )
  # nenhum componente -> NA (dimensão não calculada, nunca 0)
  expect_true(is.na(ivet_bloco_mobilidade(populacao = 10000)))
  # subconjunto explícito
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      componentes = "risco_sinistros"
    ),
    0.5
  )
  # com acesso (piloto): a dimensão passa a média dos três
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 25000, teto_acesso_15min = 50000
    ),
    0.5
  )
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 0, teto_acesso_15min = 50000
    ),
    mean(c(0.5, 0.5, 1))
  )
})

test_that("bloco C é o mínimo territorial que faltava e compõe o IVET agregado", {
  # C+D+E presentes -> agregado publicável (antes de C, era NA)
  blocos <- list(
    mobilidade = ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000
    ),
    saude = 0.4,
    seguranca = 0.6
  )
  ivet <- ivet_v1(blocos)
  expect_false(is.na(ivet$ivet))
  expect_true(ivet$publicavel)
  # sem mobilidade -> agregado NA
  expect_true(is.na(ivet_v1(list(saude = 0.4, seguranca = 0.6))$ivet))
})
