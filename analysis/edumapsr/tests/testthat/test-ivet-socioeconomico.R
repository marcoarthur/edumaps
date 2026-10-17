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

test_that("ivet_bloco_socioeconomico_componentes devolve os componentes e o sub-bloco saneamento", {
  comps <- ivet_bloco_socioeconomico_componentes(
    pct_analfabeto = 0.2,
    pct_agua_sem_rede = 0.1, pct_esgoto_inadequado = 0.3,
    pct_lixo_inadequado = 0.5, pct_sem_banheiro = 0.7
  )
  expect_named(comps, c("analfabetismo", "renda", "sem_instrucao", "fund_incomp",
                        "agua_sem_rede", "esgoto_inadequado", "lixo_inadequado",
                        "sem_banheiro", "saneamento", "preto_pardo"))
  expect_equal(comps[["analfabetismo"]], 0.2)
  expect_equal(comps[["agua_sem_rede"]], 0.1)
  expect_equal(comps[["sem_banheiro"]], 0.7)
  # saneamento = média dos 4 (0.1 + 0.3 + 0.5 + 0.7) / 4 = 0.4
  expect_equal(comps[["saneamento"]], 0.4)
})

test_that("saneamento ignora sub-indicador ausente (#154) e só é NA se todos faltarem", {
  # um só presente -> é ele próprio
  comps <- ivet_bloco_socioeconomico_componentes(pct_agua_sem_rede = 0.4)
  expect_equal(comps[["saneamento"]], 0.4)
  # nenhum presente -> NA (não 0)
  comps0 <- ivet_bloco_socioeconomico_componentes()
  expect_true(is.na(comps0[["saneamento"]]))
})

test_that("ivet_bloco_socioeconomico: default (v1.2) = média de analfabetismo + renda + saneamento", {
  # analfabetismo 0.2; saneamento = (0.1+0.3+0.5+0.7)/4 = 0.4; média = 0.3
  # (sem renda informada, o componente renda é NA e fica fora — #154)
  expect_equal(
    ivet_bloco_socioeconomico(
      pct_analfabeto = 0.2,
      pct_agua_sem_rede = 0.1, pct_esgoto_inadequado = 0.3,
      pct_lixo_inadequado = 0.5, pct_sem_banheiro = 0.7
    ),
    0.3
  )
  # a renda PASSOU a entrar no default (v1.2): renda 0 -> componente 1
  # média de analfabetismo (0.2) e renda (1) = 0.6
  expect_equal(
    ivet_bloco_socioeconomico(pct_analfabeto = 0.2, renda = 0),
    0.6
  )
})

test_that("#154: componente ausente fica fora do denominador, não vira 0", {
  # só analfabetismo (saneamento sem fonte) -> é ele próprio
  expect_equal(
    ivet_bloco_socioeconomico(pct_analfabeto = 0.2),
    0.2
  )
  # analfabetismo + parte do saneamento (água) -> média dos dois
  expect_equal(
    ivet_bloco_socioeconomico(pct_analfabeto = 0.2, pct_agua_sem_rede = 0.4),
    0.3
  )
  # saneamento inteiro presente, analfabetismo ausente -> é o saneamento
  expect_equal(
    ivet_bloco_socioeconomico(
      pct_agua_sem_rede = 0.4, pct_esgoto_inadequado = 0.4,
      pct_lixo_inadequado = 0.4, pct_sem_banheiro = 0.4
    ),
    0.4
  )
})

test_that("sem nenhum componente: dimensão NA (não calculada), nunca 0", {
  expect_true(is.na(ivet_bloco_socioeconomico()))
  # cobertura 0 (sem setor com dado) => colunas NULL no banco => NA aqui
  expect_true(is.na(ivet_bloco_socioeconomico(
    pct_analfabeto = NA, pct_agua_sem_rede = NA, pct_esgoto_inadequado = NA,
    pct_lixo_inadequado = NA, pct_sem_banheiro = NA
  )))
})

test_that("componentes selecionáveis (inclui equidade, fora por omissão)", {
  # preto/pardo fora por omissão (default = analfabetismo + saneamento)
  expect_equal(
    ivet_bloco_socioeconomico(pct_analfabeto = 0.2, pct_agua_sem_rede = 0.4,
                              pct_esgoto_inadequado = 0.4, pct_lixo_inadequado = 0.4,
                              pct_sem_banheiro = 0.4, pct_preto_pardo = 0.6),
    0.3
  )
  # incluído explicitamente
  expect_equal(
    ivet_bloco_socioeconomico(pct_analfabeto = 0.2, pct_agua_sem_rede = 0.4,
                              pct_esgoto_inadequado = 0.4, pct_lixo_inadequado = 0.4,
                              pct_sem_banheiro = 0.4, pct_preto_pardo = 0.6,
                              componentes = c("analfabetismo", "saneamento", "preto_pardo")),
    (0.2 + 0.4 + 0.6) / 3
  )
  # só equidade
  expect_equal(
    ivet_bloco_socioeconomico(pct_preto_pardo = 0.6, componentes = "preto_pardo"),
    0.6
  )
  # renda do responsável ainda calculável isoladamente
  expect_equal(
    ivet_bloco_socioeconomico(renda = 1212, teto_renda = 2424, componentes = "renda"),
    0.5
  )
  expect_error(
    ivet_bloco_socioeconomico(pct_analfabeto = 1, componentes = "inexistente"),
    "componentes"
  )
})

test_that("teto de renda é parâmetro documentado (default IVET_TETO_RENDA)", {
  # default = 2 salários mínimos de jul/2022
  expect_equal(IVET_TETO_RENDA, 2 * 1212)
  expect_equal(
    ivet_bloco_socioeconomico(renda = IVET_TETO_RENDA, componentes = "renda"),
    0
  )
})
