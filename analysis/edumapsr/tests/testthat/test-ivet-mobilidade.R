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

test_that("ivet_escala_log: log10 entre piso e teto, com clamp", {
  expect_equal(ivet_escala_log(0, piso = 0, teto = 99), 0)
  expect_equal(ivet_escala_log(99, piso = 0, teto = 99), 1)
  expect_equal(ivet_escala_log(9, piso = 0, teto = 99), 0.5)      # log10(10)/log10(100)
  expect_equal(ivet_escala_log(1e9, piso = 0, teto = 99), 1)      # satura no teto
  expect_equal(ivet_escala_log(-5, piso = 0, teto = 99), 0)       # negativo vira 0
  expect_equal(ivet_escala_log(9, piso = 9, teto = 999), 0)       # abaixo/no piso
  expect_equal(ivet_escala_log(99, piso = 9, teto = 999), 0.5)    # meio em log
  expect_true(is.na(ivet_escala_log(NA, 0, 99)))
  expect_true(is.na(ivet_escala_log(NULL, 0, 99)))
  expect_true(is.na(ivet_escala_log("x", 0, 99)))
  expect_error(ivet_escala_log(1, piso = 0, teto = 0), "teto")
  expect_error(ivet_escala_log(1, piso = 99, teto = 99), "piso")
  expect_error(ivet_escala_log(1, piso = -1, teto = 99), "piso")
})

test_that("ivet_componente_acesso_isocrona: invertido, escala log", {
  # mais população alcançável = menos vulnerável
  expect_equal(ivet_componente_acesso_isocrona(0), 1)
  expect_equal(ivet_componente_acesso_isocrona(IVET_TETO_ACESSO_15MIN), 0)
  expect_equal(ivet_componente_acesso_isocrona(999999), 0)        # satura
  expect_equal(ivet_componente_acesso_isocrona(-5), 1)            # clamp
  expect_equal(ivet_componente_acesso_isocrona(9, teto = 99, piso = 0), 0.5)
  # mediana medida (6.829 hab) cai perto de 0,2, não de 0,9 como no linear
  expect_equal(ivet_componente_acesso_isocrona(6829), 0.1975, tolerance = 1e-3)
  # vazio != zero (#154)
  expect_true(is.na(ivet_componente_acesso_isocrona(NA)))
  expect_true(is.na(ivet_componente_acesso_isocrona(NULL)))
  expect_true(is.na(ivet_componente_acesso_isocrona("x")))
  expect_error(ivet_componente_acesso_isocrona(1000, teto = 0), "teto")
})

test_that("ivet_componente_acesso_auto_45min: invertido, escala log", {
  expect_equal(ivet_componente_acesso_auto_45min(IVET_TETO_ACESSO_45MIN), 0)
  expect_equal(ivet_componente_acesso_auto_45min(0), 1)
  expect_equal(ivet_componente_acesso_auto_45min(IVET_PISO_ACESSO_45MIN), 1) # no piso
  expect_equal(ivet_componente_acesso_auto_45min(999999999), 0)  # satura
  expect_equal(ivet_componente_acesso_auto_45min(-5), 1)         # clamp
  # mediana medida (389.528 hab) perto de 0,37, não de 0,98 como no linear
  expect_equal(ivet_componente_acesso_auto_45min(389528), 0.372, tolerance = 1e-3)
  expect_true(is.na(ivet_componente_acesso_auto_45min(NA)))
  expect_true(is.na(ivet_componente_acesso_auto_45min(NULL)))
  expect_true(is.na(ivet_componente_acesso_auto_45min("x")))
  expect_error(ivet_componente_acesso_auto_45min(1000, teto = 0), "teto")
  expect_error(ivet_componente_acesso_auto_45min(1000, teto = 100), "piso")
})

test_that("piso e teto do acesso batem com a medição de 98.722 escolas (#295)", {
  expect_equal(IVET_PISO_ACESSO_15MIN, 0)          # sem população = pior acesso
  expect_equal(IVET_TETO_ACESSO_15MIN, 60000)      # p99 = 59.732
  expect_equal(IVET_PISO_ACESSO_45MIN, 500)        # p1 = 365
  expect_equal(IVET_TETO_ACESSO_45MIN, 20000000)   # p99 = 19,3 mi
})

test_that("ivet_bloco_mobilidade_componentes devolve os quatro componentes", {
  comps <- ivet_bloco_mobilidade_componentes(
    sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
    pop_acessivel_15min = 9, teto_acesso_15min = 99, piso_acesso_15min = 0,
    pop_acessivel_45min = 99, teto_acesso_45min = 999, piso_acesso_45min = 9
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
  expect_equal(comps[["acesso_isocrona"]], 0.5)     # meio do log entre 0 e 99
  expect_equal(comps[["acesso_auto_45min"]], 0.5)   # meio do log entre 9 e 999
  # fora da cobertura: acessos NA, os demais intactos
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
  # com acesso: a dimensão passa a média dos três (9 hab = meio do log 0..99)
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 9, teto_acesso_15min = 99
    ),
    0.5
  )
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 0, teto_acesso_15min = 65000
    ),
    mean(c(0.5, 0.5, 1))
  )
  # com os DOIS acessos: a dimensão média dos quatro
  expect_equal(
    ivet_bloco_mobilidade(
      sinistros_12m = 25, renavam_total_frota = 5000, populacao = 10000,
      pop_acessivel_15min = 9, teto_acesso_15min = 99,
      pop_acessivel_45min = 0, teto_acesso_45min = 20000000
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
