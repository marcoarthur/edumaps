# testes da extração do bloco B (socioeconômico) do IVET (#137)
# (R/ivet-socioeconomico.R)

test_that("ivet_componente_renda: inverte e normaliza pelo teto", {
  # renda 0 -> vulnerabilidade máxima; renda = teto -> 0; acima -> 0
  expect_equal(ivet_componente_renda(0, teto = 2000), 1)
  expect_equal(ivet_componente_renda(1000, teto = 2000), 0.5)
  expect_equal(ivet_componente_renda(2000, teto = 2000), 0)
  expect_equal(ivet_componente_renda(9999, teto = 2000), 0)
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_renda(NA, teto = 2000)))
  expect_true(is.na(ivet_componente_renda(NULL, teto = 2000)))
  expect_true(is.na(ivet_componente_renda("x", teto = 2000)))
  # teto inválido
  expect_error(ivet_componente_renda(1, teto = 0), "teto")
})

test_that("ivet_componente_proporcao: clamp(0,1) e preserva NA", {
  expect_equal(ivet_componente_proporcao(0.3), 0.3)
  expect_equal(ivet_componente_proporcao(1.5), 1)
  expect_equal(ivet_componente_proporcao(-0.2), 0)
  expect_true(is.na(ivet_componente_proporcao(NA)))
  expect_true(is.na(ivet_componente_proporcao(NULL)))
})

test_that("ivet_bloco_socioeconomico_componentes devolve os quatro componentes", {
  comps <- ivet_bloco_socioeconomico_componentes(
    renda = 1212, pct_sem_instrucao = 0.2, pct_fund_incomp = 0.4, pct_preto_pardo = 0.6,
    teto_renda = 2424
  )
  expect_named(comps, c("renda", "sem_instrucao", "fund_incomp", "preto_pardo"))
  expect_equal(comps[["renda"]], 0.5)
  expect_equal(comps[["sem_instrucao"]], 0.2)
  expect_equal(comps[["fund_incomp"]], 0.4)
  expect_equal(comps[["preto_pardo"]], 0.6)
})

test_that("ivet_bloco_socioeconomico: dimensão = média dos componentes por omissão", {
  # renda 1212/2424 -> 0.5; sem 0.2; fund 0.4; média = 1.1/3
  expect_equal(
    ivet_bloco_socioeconomico(renda = 1212, pct_sem_instrucao = 0.2, pct_fund_incomp = 0.4,
                              teto_renda = 2424),
    1.1 / 3
  )
})

test_that("#154: componente ausente fica fora do denominador, não vira 0", {
  # renda ausente: média só das duas proporções (0.2, 0.4) = 0.3 (não 0.2)
  expect_equal(
    ivet_bloco_socioeconomico(renda = NA, pct_sem_instrucao = 0.2, pct_fund_incomp = 0.4),
    0.3
  )
  # uma só disponível: é ela própria
  expect_equal(
    ivet_bloco_socioeconomico(renda = NA, pct_sem_instrucao = NA, pct_fund_incomp = 0.4),
    0.4
  )
})

test_that("sem nenhum componente: dimensão NA (não calculada), nunca 0", {
  expect_true(is.na(ivet_bloco_socioeconomico(renda = NA, pct_sem_instrucao = NA,
                                              pct_fund_incomp = NA)))
  expect_true(is.na(ivet_bloco_socioeconomico()))

  # cobertura 0 (sem setor com dado) => colunas NULL no banco => NA aqui
  expect_true(is.na(ivet_bloco_socioeconomico(
    renda = NA, pct_sem_instrucao = NA, pct_fund_incomp = NA, pct_preto_pardo = NA
  )))
})

test_that("componentes selecionáveis (inclui equidade, fora por omissão)", {
  # preto/pardo fora por omissão
  expect_equal(
    ivet_bloco_socioeconomico(renda = 1212, pct_sem_instrucao = 0.2, pct_fund_incomp = 0.4,
                              pct_preto_pardo = 0.6, teto_renda = 2424),
    1.1 / 3
  )
  # incluído explicitamente
  expect_equal(
    ivet_bloco_socioeconomico(renda = 1212, pct_sem_instrucao = 0.2, pct_fund_incomp = 0.4,
                              pct_preto_pardo = 0.6, teto_renda = 2424,
                              componentes = c("renda", "sem_instrucao", "fund_incomp",
                                              "preto_pardo")),
    1.7 / 4
  )
  # só equidade
  expect_equal(
    ivet_bloco_socioeconomico(pct_preto_pardo = 0.6, componentes = "preto_pardo"),
    0.6
  )
  expect_error(
    ivet_bloco_socioeconomico(renda = 1, componentes = "inexistente"),
    "componentes"
  )
})

test_that("teto de renda é parâmetro documentado (default IVET_TETO_RENDA)", {
  # default = 2 salários mínimos de jul/2022
  expect_equal(IVET_TETO_RENDA, 2 * 1212)
  expect_equal(
    ivet_bloco_socioeconomico(renda = IVET_TETO_RENDA, pct_sem_instrucao = 0,
                              pct_fund_incomp = 0),
    0
  )
})
