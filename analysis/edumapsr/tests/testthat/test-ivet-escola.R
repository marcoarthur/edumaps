# testes da extração do bloco A (escola) do IVET — reconciliação B↔C (#137)
# (R/ivet-escola.R)

test_that("ivet_componente_score: inverte e normaliza pelo teto (B é 0–10)", {
  # score 0 (pior) -> vulnerabilidade máxima; 10 (melhor) -> 0
  expect_equal(ivet_componente_score(0), 1)
  expect_equal(ivet_componente_score(5), 0.5)
  expect_equal(ivet_componente_score(10), 0)
  # fora da escala -> clamp
  expect_equal(ivet_componente_score(12), 0)
  expect_equal(ivet_componente_score(-3), 1)
  # vazio/NA -> NA (nunca 0 — #154)
  expect_true(is.na(ivet_componente_score(NA)))
  expect_true(is.na(ivet_componente_score(NULL)))
  expect_true(is.na(ivet_componente_score("x")))
  # teto inválido
  expect_error(ivet_componente_score(1, teto = 0), "teto")
})

test_that("ivet_componente_indicador: inverte e clampa o sistema C (0–1)", {
  expect_equal(ivet_componente_indicador(0), 1)
  expect_equal(ivet_componente_indicador(0.25), 0.75)
  expect_equal(ivet_componente_indicador(1), 0)
  # `iqd` viola [0,1] no sistema C (razão aluno/docente) — é clampado
  expect_equal(ivet_componente_indicador(3), 0)
  expect_true(is.na(ivet_componente_indicador(NA)))
  expect_true(is.na(ivet_componente_indicador(NULL)))
})

test_that("ivet_bloco_escola_componentes devolve os 6 de B + os 4 de C", {
  comps <- ivet_bloco_escola_componentes(
    score_capacidade_atendimento = 10,
    score_infraestrutura = 8,
    score_capacitacao_docente = 0,
    score_diversidade_discente = 5,
    score_capacidade_gestora = NA,
    score_sustentabilidade = 3,
    iai = 0.2, itd = 1, ioc = 0.4, iqd = 3
  )
  expect_equal(
    names(comps),
    c(IVET_ESCOLA_COMPONENTES_B, IVET_ESCOLA_COMPONENTES_C)
  )
  # B: 1 - score/10
  expect_equal(unname(comps[["capacidade_atendimento"]]), 0)
  expect_equal(unname(comps[["infraestrutura"]]), 0.2)
  expect_equal(unname(comps[["capacitacao_docente"]]), 1)
  expect_equal(unname(comps[["diversidade_discente"]]), 0.5)
  expect_true(is.na(comps[["capacidade_gestora"]]))  # NA preservado
  expect_equal(unname(comps[["sustentabilidade"]]), 0.7)
  # C: 1 - indicador, clampado
  expect_equal(unname(comps[["acessibilidade_c"]]), 0.8)
  expect_equal(unname(comps[["tecnologia_c"]]), 0)
  expect_equal(unname(comps[["oferta_c"]]), 0.6)
  expect_equal(unname(comps[["qualificacao_docente_c"]]), 0)  # iqd=3 clampado
})

test_that("ivet_bloco_escola: default = média dos componentes de B (#154)", {
  # só infraestrutura (0.2) e sustentabilidade (0.7) disponíveis -> média
  expect_equal(
    ivet_bloco_escola(score_infraestrutura = 8, score_sustentabilidade = 3),
    (0.2 + 0.7) / 2
  )
  # todos os 6 no teto pior -> dimensão 1 (não NA)
  expect_equal(
    ivet_bloco_escola(
      score_capacidade_atendimento = 0, score_infraestrutura = 0,
      score_capacitacao_docente = 0, score_diversidade_discente = 0,
      score_capacidade_gestora = 0, score_sustentabilidade = 0
    ),
    1
  )
  # um score no máximo (10) e só -> componente 0, dimensão 0 (legítimo, ≠ NA)
  expect_equal(ivet_bloco_escola(score_infraestrutura = 10), 0)
})

test_that("bloco A sem componente é NA (não calculado), nunca 0", {
  expect_true(is.na(ivet_bloco_escola()))
  expect_true(is.na(ivet_bloco_escola(
    score_capacidade_atendimento = NA, score_infraestrutura = NA,
    score_capacitacao_docente = NA, score_diversidade_discente = NA,
    score_capacidade_gestora = NA, score_sustentabilidade = NA
  )))
})

test_that("reconciliação B↔C: default é B; C entra só por escolha explícita", {
  # contrato: o default são os componentes de B e nenhum de C
  expect_equal(IVET_BLOCO_A_COMPONENTES, IVET_ESCOLA_COMPONENTES_B)
  expect_length(intersect(IVET_BLOCO_A_COMPONENTES, IVET_ESCOLA_COMPONENTES_C), 0)

  # indicador de C sozinho NÃO entra no default -> dimensão NA
  expect_true(is.na(ivet_bloco_escola(iai = 0.2)))

  # escolhido explicitamente, entra
  expect_equal(
    ivet_bloco_escola(iai = 0.2, componentes = "acessibilidade_c"),
    0.8
  )
  # e pode compor com B
  expect_equal(
    ivet_bloco_escola(score_infraestrutura = 10, iai = 0.2,
                      componentes = c("infraestrutura", "acessibilidade_c")),
    (0 + 0.8) / 2
  )
  # iqd clampado quando pedido
  expect_equal(
    ivet_bloco_escola(iqd = 3, componentes = "qualificacao_docente_c"),
    0
  )
  expect_error(
    ivet_bloco_escola(score_infraestrutura = 5, componentes = "inexistente"),
    "componentes"
  )
})

test_that("teto da escala do sistema B é documentado (default 10)", {
  expect_equal(IVET_ESCOLA_TETO_SCORE, 10)
  expect_equal(
    ivet_bloco_escola(score_infraestrutura = IVET_ESCOLA_TETO_SCORE,
                      componentes = "infraestrutura"),
    0
  )
})
