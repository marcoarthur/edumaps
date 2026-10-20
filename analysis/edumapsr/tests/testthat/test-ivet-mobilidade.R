# testes da extração do bloco C (mobilidade) do IVET (#137, #278)
# (R/ivet-mobilidade.R)
#
# C combina exposição viária (sinistros RENAEST por 100 mil + frota RENAVAM por
# habitante, ambas diretas) e os dois acessos da isócrona (população alcançável
# a pé em 15 min e de carro em 45 min, ambos invertidos). Os acessos são
# piloto no ES: fora dele os componentes são NA (#154).

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

test_that("ivet_componente_acesso_auto_45min: invertido (mais acesso = menos)", {
  # mesma convenção do acesso a pé: população no teto -> 0; zero -> 1 (pior)
  expect_equal(ivet_componente_acesso_auto_45min(1750000), 0)
  expect_equal(ivet_componente_acesso_auto_45min(0), 1)
  expect_equal(ivet_componente_acesso_auto_45min(875000), 0.5)
  expect_equal(ivet_componente_acesso_auto_45min(99999999), 0) # satura
  expect_equal(ivet_componente_acesso_auto_45min(-5), 1)       # clamp
  expect_equal(
    ivet_componente_acesso_auto_45min(875000, teto = 1750000), 0.5
  )
  # vazio/NA -> NA (#154): fora do piloto, sem penalidade
  expect_true(is.na(ivet_componente_acesso_auto_45min(NA)))
  expect_true(is.na(ivet_componente_acesso_auto_45min(NULL)))
  expect_true(is.na(ivet_componente_acesso_auto_45min("x")))
  expect_error(ivet_componente_acesso_auto_45min(1000, teto = 0), "teto")
})

test_that("tetos do acesso batem com os p99 do piloto do ES (#278)", {
  expect_equal(IVET_TETO_ACESSO_15MIN, 40000)      # p99 medido: 40.590
  expect_equal(IVET_TETO_ACESSO_45MIN, 1750000)    # p99 medido: 1.765.458
})

test_that("ivet_bloco_mobilidade_componentes devolve os quatro componentes", {
  comps <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
    pop_acessivel_15min = 25000, teto_acesso_15min = 50000,
    pop_acessivel_45min = 875000, teto_acesso_45min = 1750000
  )
  expect_named(
    comps,
    c(
      "risco_sinistros", "exposicao_frota", "acesso_isocrona",
      "acesso_auto_45min"
    )
  )
  expect_equal(comps[["risco_sinistros"]], 0.5)
  expect_equal(comps[["exposicao_frota"]], 0.5)
  expect_equal(comps[["acesso_isocrona"]], 0.5)       # 25 mil de teto 50 mil
  expect_equal(comps[["acesso_auto_45min"]], 0.5)     # 875 mil de teto 1,75 mi
  # fora do piloto: acessos NA, os demais intactos
  comps_np <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000
  )
  expect_true(is.na(comps_np[["acesso_isocrona"]]))
  expect_true(is.na(comps_np[["acesso_auto_45min"]]))
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
  # com os DOIS acessos (piloto completo): a dimensão média dos quatro
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 25000, teto_acesso_15min = 50000,
      pop_acessivel_45min = 0, teto_acesso_45min = 1750000
    ),
    mean(c(0.5, 0.5, 0.5, 1))
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
