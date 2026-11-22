# #477 (RQ-01): o bloco R "Refazer os seis índices no R" da ajuda da base de
# análise (docs/ajuda/comunidade/base-de-analise.md) tem de refazer cada
# índice a partir das partes. A #476 publicou uma expressão errada (o `!` do R
# vale menos que `*` e `+`) que nenhum teste rodava.
#
# A amostra (fixtures/base-indices-amostra.csv) é um recorte da base de
# análise (BA e MG, Censo 2025) com os casos de borda: parte racial vazia,
# privadas, escola sem matrícula, sem salas, sem docentes, sem resposta da
# alimentação, área verde ou plantio. Quando a fórmula dos índices mudar
# (versão nova), gere a amostra de novo a partir da base nova, com as mesmas
# colunas, e confira a versão abaixo.
#
# Fora do repositório (imagem analytic, sem docs/), o teste é pulado.

ajuda_base <- function() {
  testthat::test_path("..", "..", "..", "..", "docs", "ajuda", "comunidade", "base-de-analise.md")
}

bloco_refazer <- function(md) {
  ini <- which(md == "```r")
  fim <- which(md == "```")
  blocos <- lapply(ini, function(i) md[(i + 1):(min(fim[fim > i]) - 1)])
  Filter(function(b) any(grepl("refeito_", b, fixed = TRUE)), blocos)
}

test_that("o bloco R da ajuda refaz os seis índices da amostra da base", {
  arq <- ajuda_base()
  skip_if_not(file.exists(arq), "ajuda da base fora do alcance (sem docs/)")
  md <- readLines(arq, encoding = "UTF-8", warn = FALSE)
  blocos <- bloco_refazer(md)
  expect_length(blocos, 1)

  base <- utils::read.csv2(testthat::test_path("fixtures", "base-indices-amostra.csv"),
                           encoding = "UTF-8", check.names = FALSE, na.strings = "")
  expect_equal(unique(base$versao_indice), "indices-v7",
               info = "fórmula nova: gere a amostra de novo e atualize a versão aqui")
  eval(parse(text = blocos[[1]]))

  indices <- c("infraestrutura", "capacidade_atendimento", "capacitacao_docente",
               "diversidade_discente", "capacidade_gestora", "sustentabilidade")
  for (ind in indices) {
    refeito <- base[[paste0("refeito_", ind)]]
    indice  <- base[[paste0("indice_", ind)]]
    expect_false(is.null(refeito), info = paste("o bloco não cria refeito_", ind))
    tem <- !is.na(indice)
    expect_true(sum(tem) > 0, info = ind)
    dif <- abs(refeito[tem] - indice[tem])
    expect_true(all(!is.na(dif) & dif < 0.006),
                info = sprintf("%s: %d de %d escolas fora (dif. máx. %.3f)",
                               ind, sum(is.na(dif) | dif >= 0.006), sum(tem), max(dif, na.rm = TRUE)))
  }
})

test_that("o teste pega a expressão da #476 (precedência do !)", {
  base <- data.frame(p = c(NA, 1), q = c(1, NA))
  errado <- with(base, 0.7 + 0.2 * !is.na(p) + 0.1 * !is.na(q))
  certo  <- with(base, 0.7 + 0.2 * (!is.na(p)) + 0.1 * (!is.na(q)))
  expect_false(isTRUE(all.equal(errado, certo)))
})
