# testes da extração do bloco E (segurança) do IVET (#137)
# (R/ivet-seguranca.R)

test_that("ivet_taxa_100k: taxa por 100 mil e ausência preservada (#154)", {
  expect_equal(ivet_taxa_100k(50, 100000), 50)
  expect_equal(ivet_taxa_100k(0, 100000), 0)
  expect_equal(ivet_taxa_100k(25, 100000), 25)
  # contagem 0 é um facto (0), não ausência
  expect_equal(ivet_taxa_100k(0, 50000), 0)
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_taxa_100k(NA, 100000)))
  expect_true(is.na(ivet_taxa_100k(NULL, 100000)))
  expect_true(is.na(ivet_taxa_100k("x", 100000)))
  # população inválida
  expect_true(is.na(ivet_taxa_100k(10, NA)))
  expect_true(is.na(ivet_taxa_100k(10, 0)))
  # célula suprimida -> NA, mesmo com contagem presente
  expect_true(is.na(ivet_taxa_100k(3, 100000, suprimido = TRUE)))
})

test_that("ivet_componente_taxa: clamp(0,1) pelo teto e preserva NA", {
  expect_equal(ivet_componente_taxa(25, teto = 50), 0.5)
  expect_equal(ivet_componente_taxa(50, teto = 50), 1)
  expect_equal(ivet_componente_taxa(200, teto = 50), 1)
  expect_equal(ivet_componente_taxa(-1, teto = 50), 0)
  expect_true(is.na(ivet_componente_taxa(NA, teto = 50)))
  expect_true(is.na(ivet_componente_taxa(NULL, teto = 50)))
  expect_error(ivet_componente_taxa(1, teto = 0), "teto")
})

test_that("ivet_componente_crime: contagem+população -> componente", {
  # 50 homicídios / 100 mil com teto 50 -> satura
  expect_equal(ivet_componente_crime(50, 100000, teto = 50), 1)
  # 25/100k / teto 50 -> 0.5
  expect_equal(ivet_componente_crime(25, 100000, teto = 50), 0.5)
  # sem crime registado -> 0
  expect_equal(ivet_componente_crime(0, 100000, teto = 50), 0)
  # célula suprimida -> NA (#154)
  expect_true(is.na(ivet_componente_crime(2, 100000, teto = 50, suprimido = TRUE)))
  expect_true(is.na(ivet_componente_crime(NA, 100000, teto = 50)))
})

test_that("ivet_bloco_seguranca_componentes devolve os três eventos", {
  comps <- ivet_bloco_seguranca_componentes(
    homicidio_doloso = 50, latrocinio = 5, lesao_corporal_seguida_de_morte = 5,
    populacao = 100000
  )
  expect_named(comps, c("homicidio_doloso", "latrocinio",
                        "lesao_corporal_seguida_de_morte"))
  expect_equal(comps[["homicidio_doloso"]], 1)
  expect_equal(comps[["latrocinio"]], 1)
  expect_equal(comps[["lesao_corporal_seguida_de_morte"]], 1)
})

test_that("bloco E: média dos componentes e ausência fora do denominador (#154)", {
  # homicídio 1 (50/100k=1), latrocínio 0 -> 0, lesão ausente -> NA
  # média = (1 + 0) / 2 = 0.5
  expect_equal(
    ivet_bloco_seguranca(
      homicidio_doloso = 50, latrocinio = 0, populacao = 100000
    ),
    0.5
  )
  # só homicídio disponível -> é ele próprio
  expect_equal(
    ivet_bloco_seguranca(homicidio_doloso = 25, populacao = 100000),
    0.5
  )
  # célula suprimida não penaliza (fica fora)
  expect_equal(
    ivet_bloco_seguranca(
      homicidio_doloso = 50, latrocinio = NA, populacao = 100000
    ),
    1
  )
})

test_that("bloco E: sem componente (sem população) -> NA, nunca 0", {
  expect_true(is.na(ivet_bloco_seguranca()))
  expect_true(is.na(ivet_bloco_seguranca(homicidio_doloso = 10)))
  expect_true(is.na(ivet_bloco_seguranca(
    homicidio_doloso = NA, latrocinio = NA,
    lesao_corporal_seguida_de_morte = NA, populacao = 100000
  )))
})

test_that("bloco E: componentes selecionáveis e tetos são parâmetros documentados", {
  expect_equal(IVET_BLOCO_E_COMPONENTES,
               c("homicidio_doloso", "latrocinio", "lesao_corporal_seguida_de_morte"))
  expect_equal(
    ivet_bloco_seguranca(
      homicidio_doloso = 50, populacao = 100000,
      componentes = "homicidio_doloso"
    ),
    1
  )
  # teto por componente é parâmetro
  expect_equal(
    ivet_bloco_seguranca(
      homicidio_doloso = 25, populacao = 100000,
      teto_homicidio_doloso = 25, componentes = "homicidio_doloso"
    ),
    1
  )
  expect_error(
    ivet_bloco_seguranca(homicidio_doloso = 1, populacao = 100000,
                         componentes = "inexistente"),
    "não corresponde"
  )
})
