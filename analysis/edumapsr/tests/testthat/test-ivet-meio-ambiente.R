# testes da extração do bloco F (meio ambiente) do IVET (#137, #278)
# (R/ivet-meio-ambiente.R)
#
# Componentes: fogo (MapBiomas Fogo, direto), vegetação natural (MapBiomas
# Coleção 11, invertida) e carbono do solo (invertido). Tetos provisórios.

test_that("ivet_componente_risco_fogo: direto (mais fogo = pior)", {
  expect_equal(ivet_componente_risco_fogo(1, teto = 1), 1)
  expect_equal(ivet_componente_risco_fogo(0.5, teto = 1), 0.5)
  expect_equal(ivet_componente_risco_fogo(0, teto = 1), 0)   # zero real
  expect_equal(ivet_componente_risco_fogo(99, teto = 1), 1)  # satura
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_risco_fogo(NA)))
  expect_true(is.na(ivet_componente_risco_fogo(NULL)))
  expect_true(is.na(ivet_componente_risco_fogo("x")))
  expect_error(ivet_componente_risco_fogo(0.5, teto = 0), "teto")
})

test_that("ivet_componente_vegetacao_natural: invertida (mais vegetação = melhor)", {
  expect_equal(ivet_componente_vegetacao_natural(0), 1)   # sem vegetação = pior
  expect_equal(ivet_componente_vegetacao_natural(0.5), 0.5)
  expect_equal(ivet_componente_vegetacao_natural(1), 0)   # toda vegetação = melhor
  expect_equal(ivet_componente_vegetacao_natural(2), 0)   # clamp
  expect_equal(ivet_componente_vegetacao_natural(-1), 1)  # clamp
  # vazio/NA -> NA (#154)
  expect_true(is.na(ivet_componente_vegetacao_natural(NA)))
  expect_true(is.na(ivet_componente_vegetacao_natural(NULL)))
})

test_that("ivet_componente_carbono_solo: invertida (mais carbono = melhor)", {
  expect_equal(ivet_componente_carbono_solo(500, teto = 500), 0)
  expect_equal(ivet_componente_carbono_solo(250, teto = 500), 0.5)
  expect_equal(ivet_componente_carbono_solo(0, teto = 500), 1)
  expect_equal(ivet_componente_carbono_solo(9999, teto = 500), 0)  # satura em 0
  expect_equal(ivet_componente_carbono_solo(-170, teto = 500), 1)  # nodata satura
  # vazio/NA -> NA (#154)
  expect_true(is.na(ivet_componente_carbono_solo(NA)))
  expect_true(is.na(ivet_componente_carbono_solo(NULL)))
  expect_error(ivet_componente_carbono_solo(200, teto = 0), "teto")
})

test_that("ivet_bloco_meio_ambiente_componentes devolve os três indicadores", {
  comps <- ivet_bloco_meio_ambiente_componentes(
    fogo_frequencia_media = 0.5,
    fracao_vegetacao_natural = 0.5,
    solo_carbono_medio = 250
  )
  expect_named(comps, c("risco_fogo", "vegetacao_natural", "carbono_solo"))
  expect_equal(unname(comps), c(0.5, 0.5, 0.5))
})

test_that("ivet_bloco_meio_ambiente: média das disponíveis, NA fora (#154)", {
  expect_equal(
    ivet_bloco_meio_ambiente(
      fogo_frequencia_media = 0.5,
      fracao_vegetacao_natural = 0.5,
      solo_carbono_medio = 250
    ),
    0.5
  )
  # só fogo+solo (vegetação ausente, ex.: fora do ES hoje) -> média dos dois
  expect_equal(
    ivet_bloco_meio_ambiente(fogo_frequencia_media = 0.2, solo_carbono_medio = 250),
    0.35
  )
  # nenhum componente -> NA (dimensão não calculada, nunca 0)
  expect_true(is.na(ivet_bloco_meio_ambiente()))
  # subconjunto explícito
  expect_equal(
    ivet_bloco_meio_ambiente(fogo_frequencia_media = 0.5, componentes = "risco_fogo"),
    0.5
  )
})

test_that("bloco F entra no agregado como dimensão disponível (não é mínimo)", {
  blocos <- list(
    mobilidade = 0.2, saude = 0.4, seguranca = 0.6,
    meio_ambiente = ivet_bloco_meio_ambiente(fogo_frequencia_media = 0.5)
  )
  ivet <- ivet_v1(blocos)
  expect_true(ivet$publicavel)                       # C+D+E já bastam
  expect_equal(ivet$ivet, mean(c(0.2, 0.4, 0.6, 0.5)))  # F entra na média
  # sem F, o agregado é a média dos três mínimos (F não é obrigatório)
  expect_equal(
    ivet_v1(list(mobilidade = 0.2, saude = 0.4, seguranca = 0.6))$ivet,
    mean(c(0.2, 0.4, 0.6))
  )
})
