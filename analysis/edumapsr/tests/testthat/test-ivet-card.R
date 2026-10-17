# Testes de contrato do card do IVET (#137, entregável 5).
#
# O card é uma descrição legível por máquina da fórmula; se ele divergir do
# código, este teste falha. Assim o card não vira slide desatualizado.

test_that("ivet_card lê o card instalado com o pacote", {
  card <- ivet_card()
  expect_type(card, "list")
  expect_true(nzchar(card$formula))
})

test_that("ivet_card exige um arquivo existente", {
  expect_error(ivet_card(tempfile()), "não encontrado")
})

test_that("card: fórmula vigente confere com ivet_versao()", {
  expect_equal(ivet_card()$formula, ivet_versao())
})

test_that("card: blocos e blocos territoriais mínimos conferem com o código", {
  card <- ivet_card()
  expect_equal(unlist(card$blocos, use.names = TRUE), ivet_blocos())
  expect_setequal(card$blocos_territoriais_minimos, ivet_blocos_territoriais_minimos())
})

test_that("card: componentes do bloco B batem com o código", {
  card <- ivet_card()
  comps <- ivet_bloco_socioeconomico_componentes()
  expect_setequal(names(card$bloco_b$componentes), names(comps))
})

test_that("card: default do bloco B e teto de renda batem com o código", {
  card <- ivet_card()
  expect_equal(card$bloco_b$default, IVET_BLOCO_B_COMPONENTES)
  expect_true(all(card$bloco_b$default %in% names(card$bloco_b$componentes)))
  expect_equal(card$bloco_b$componentes$renda$teto, IVET_TETO_RENDA)

  # os 3 componentes fora do default estão marcados como tal
  for (nm in c("sem_instrucao", "fund_incomp", "preto_pardo")) {
    expect_true(isTRUE(card$bloco_b$componentes[[nm]]$no_default), info = nm)
  }
})

test_that("card: subcomponentes de saneamento batem com o código", {
  card <- ivet_card()
  expect_setequal(card$bloco_b$componentes$saneamento$subcomponentes,
                  IVET_SANEAMENTO_COMPONENTES)
})

test_that("card: proveniência cobre as duas chaves e a vigência", {
  card <- ivet_card()
  expect_match(card$proveniencia$dataset_version, "lock")
  expect_match(card$proveniencia$transform_version, "lock")
  expect_match(card$proveniencia$vigencia, "ivet_vigencia")
})
