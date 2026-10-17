# testes da extração do bloco G (recursos) do IVET (#137)
# (R/ivet-recursos.R)

test_that("ivet_componente_investimento: inverte e normaliza pelo teto", {
  # valor 0 -> vulnerabilidade máxima; valor = teto -> 0; acima -> 0
  expect_equal(ivet_componente_investimento(0, teto = 10000), 1)
  expect_equal(ivet_componente_investimento(5000, teto = 10000), 0.5)
  expect_equal(ivet_componente_investimento(10000, teto = 10000), 0)
  expect_equal(ivet_componente_investimento(99999, teto = 10000), 0)
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_investimento(NA, teto = 10000)))
  expect_true(is.na(ivet_componente_investimento(NULL, teto = 10000)))
  expect_true(is.na(ivet_componente_investimento("x", teto = 10000)))
  # teto inválido
  expect_error(ivet_componente_investimento(1, teto = 0), "teto")
})

test_that("ivet_bloco_recursos_componentes devolve os três indicadores", {
  comps <- ivet_bloco_recursos_componentes(
    fundeb_por_aluno = 5000, despesa_educ_por_aluno = 7500,
    autonomia_fiscal_pct = 25
  )
  expect_named(comps, c("fundeb_por_aluno", "despesa_educ_por_aluno",
                        "autonomia_fiscal_pct"))
  expect_equal(comps[["fundeb_por_aluno"]], 0.5)
  expect_equal(comps[["despesa_educ_por_aluno"]], 0.5)
  expect_equal(comps[["autonomia_fiscal_pct"]], 0.5)
})

test_that("bloco G: média dos componentes e ausência fora do denominador (#154)", {
  # fundeb teto -> 0; despesa 0 -> 1; autonomia ausente -> NA
  # média = (0 + 1) / 2 = 0.5
  expect_equal(
    ivet_bloco_recursos(
      fundeb_por_aluno = 10000, despesa_educ_por_aluno = 0
    ),
    0.5
  )
  # só autonomia disponível (50% = teto) -> 0
  expect_equal(
    ivet_bloco_recursos(autonomia_fiscal_pct = 50),
    0
  )
})

test_that("bloco G sem nenhum componente: dimensão NA (não calculada), nunca 0", {
  expect_true(is.na(ivet_bloco_recursos()))
  expect_true(is.na(ivet_bloco_recursos(
    fundeb_por_aluno = NA, despesa_educ_por_aluno = NA,
    autonomia_fiscal_pct = NA
  )))
})

test_that("bloco G: componentes selecionáveis e tetos documentados", {
  expect_equal(IVET_BLOCO_G_COMPONENTES,
               c("fundeb_por_aluno", "despesa_educ_por_aluno",
                 "autonomia_fiscal_pct"))
  # teto é parâmetro: fundeb 5000 com teto 5000 -> 0
  expect_equal(
    ivet_bloco_recursos(fundeb_por_aluno = 5000,
                        teto_fundeb_por_aluno = 5000,
                        componentes = "fundeb_por_aluno"),
    0
  )
  expect_error(
    ivet_bloco_recursos(fundeb_por_aluno = 1, componentes = "inexistente"),
    "não corresponde"
  )
})
