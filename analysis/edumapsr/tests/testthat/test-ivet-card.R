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

test_that("card: componentes do bloco A batem com o código (reconciliação B↔C)", {
  card <- ivet_card()
  comps <- ivet_bloco_escola_componentes()
  expect_setequal(names(card$bloco_a$componentes), names(comps))
  expect_equal(card$bloco_a$default, IVET_BLOCO_A_COMPONENTES)
  expect_true(all(card$bloco_a$default %in% names(card$bloco_a$componentes)))
  # os componentes do sistema C estão marcados como fora do default
  for (nm in IVET_ESCOLA_COMPONENTES_C) {
    expect_true(isTRUE(card$bloco_a$componentes[[nm]]$no_default), info = nm)
    expect_equal(card$bloco_a$componentes[[nm]]$sistema, "C", info = nm)
  }
})

test_that("card: componentes do bloco C batem com o código (acesso + exposição)", {
  card <- ivet_card()
  comps <- ivet_bloco_mobilidade_componentes()
  expect_setequal(names(card$bloco_c$componentes), names(comps))
  expect_equal(card$bloco_c$default, IVET_BLOCO_C_COMPONENTES)
  expect_equal(length(card$bloco_c$default), 4)  # 2 exposição + 2 acessos
  expect_true(all(card$bloco_c$default %in% names(card$bloco_c$componentes)))
  expect_equal(card$bloco_c$componentes$risco_sinistros$teto,
               IVET_TETO_SINISTROS_100K)
  expect_equal(card$bloco_c$componentes$exposicao_frota$teto,
               IVET_TETO_FROTA_POR_HAB)
  expect_equal(card$bloco_c$componentes$acesso_isocrona$teto,
               IVET_TETO_ACESSO_15MIN)
  expect_equal(card$bloco_c$componentes$acesso_auto_45min$teto,
               IVET_TETO_ACESSO_45MIN)
  # os dois acessos entram invertidos (mais população = menos vulnerável)
  expect_equal(card$bloco_c$componentes$acesso_isocrona$direcao, "-")
  expect_equal(card$bloco_c$componentes$acesso_auto_45min$direcao, "-")
  expect_false(isTRUE(card$bloco_c$componentes$acesso_isocrona$no_default))
  expect_false(isTRUE(card$bloco_c$componentes$acesso_auto_45min$no_default))
  # a cobertura (expansão nacional SP+RJ+NE) e o residual da borda ficam no card
  expect_match(card$bloco_c$componentes$acesso_auto_45min$cobertura, "expansao")
  expect_match(card$bloco_c$componentes$acesso_auto_45min$vies_nota, "MG<->BA")
})

test_that("card: componentes do bloco E batem com o código (segurança)", {
  card <- ivet_card()
  comps <- ivet_bloco_seguranca_componentes()
  expect_setequal(names(card$bloco_e$componentes), names(comps))
  expect_equal(card$bloco_e$default, IVET_BLOCO_E_COMPONENTES)
  expect_true(all(card$bloco_e$default %in% names(card$bloco_e$componentes)))
  expect_equal(card$bloco_e$componentes$homicidio_doloso$teto, IVET_TETO_HOMICIDIO_DOLOSO)
  expect_equal(card$bloco_e$componentes$latrocinio$teto, IVET_TETO_LATROCINIO)
  expect_equal(card$bloco_e$componentes$lesao_corporal_seguida_de_morte$teto,
               IVET_TETO_LESAO_CORPORAL_SEGUIDA_DE_MORTE)
})

test_that("card: componentes do bloco D batem com o código (saúde)", {
  card <- ivet_card()
  comps <- ivet_bloco_saude_componentes()
  expect_setequal(names(card$bloco_d$componentes), names(comps))
  expect_equal(card$bloco_d$default, IVET_BLOCO_D_COMPONENTES)
  expect_true(all(card$bloco_d$default %in% names(card$bloco_d$componentes)))
  expect_equal(card$bloco_d$componentes$distancia_ubs$teto, IVET_TETO_DISTANCIA_UBS_KM)
  expect_equal(card$bloco_d$componentes$cobertura_aps$teto,
               IVET_TETO_COBERTURA_APS_POR_10K)
  expect_equal(card$bloco_d$componentes$presenca_ubs$teto,
               IVET_TETO_PRESENCA_UBS_POR_10K)
  expect_equal(card$bloco_d$componentes$efetividade_vagas_aps$teto,
               IVET_TETO_EFETIVIDADE_VAGAS_APS_PCT)
  # presenca_ubs e efetividade ficam fora do default
  expect_true(isTRUE(card$bloco_d$componentes$presenca_ubs$no_default))
  expect_true(isTRUE(card$bloco_d$componentes$efetividade_vagas_aps$no_default))
})

test_that("card: componentes do bloco G batem com o código (recursos)", {
  card <- ivet_card()
  comps <- ivet_bloco_recursos_componentes()
  expect_setequal(names(card$bloco_g$componentes), names(comps))
  expect_equal(card$bloco_g$default, IVET_BLOCO_G_COMPONENTES)
  expect_true(all(card$bloco_g$default %in% names(card$bloco_g$componentes)))
  expect_equal(card$bloco_g$componentes$fundeb_por_aluno$teto, IVET_TETO_FUNDEB_POR_ALUNO)
  expect_equal(card$bloco_g$componentes$despesa_educ_por_aluno$teto,
               IVET_TETO_DESPESA_EDUC_POR_ALUNO)
  expect_equal(card$bloco_g$componentes$autonomia_fiscal_pct$teto,
               IVET_TETO_AUTONOMIA_FISCAL_PCT)
})

test_that("card: componentes do bloco F batem com o código (meio ambiente)", {
  card <- ivet_card()
  comps <- ivet_bloco_meio_ambiente_componentes()
  expect_setequal(names(card$bloco_f$componentes), names(comps))
  expect_equal(card$bloco_f$default, IVET_BLOCO_F_COMPONENTES)
  expect_true(all(card$bloco_f$default %in% names(card$bloco_f$componentes)))
  expect_equal(card$bloco_f$componentes$risco_fogo$teto, IVET_TETO_FOGO)
  expect_equal(card$bloco_f$componentes$carbono_solo$teto, IVET_TETO_CARBONO_SOLO)
})

test_that("card: proveniência cobre as duas chaves e a vigência", {
  card <- ivet_card()
  expect_match(card$proveniencia$dataset_version, "lock")
  expect_match(card$proveniencia$transform_version, "lock")
  expect_match(card$proveniencia$vigencia, "ivet_vigencia")
})
