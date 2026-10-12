# R/report-sections.R
#
# Construtores das seções do ReportResult (contrato da onda 1, #219) e
# formatação PT-BR para os textos determinísticos.
#
# Tipos de seção: `texto` | `indicadores` | `tabela` | `grafico`
# (`grafico` ∈ `barras` | `linhas`). Formatos de valor: `texto`, `inteiro`,
# `decimal1`, `decimal2`, `percentual` (fração 0–1). As seções guardam
# data.frames; a View ([render_report_json()]) converte em linhas JSON.

#' Formatos de valor aceitos pelo contrato
#' @keywords internal
REPORT_FORMATOS <- c("texto", "inteiro", "decimal1", "decimal2", "percentual")

#' Arredonda um valor conforme o formato (apresentação, não análise)
#' @keywords internal
report_round <- function(x, formato) {
  if (!is.numeric(x)) {
    return(x)
  }
  switch(formato,
    inteiro = round(x),
    decimal1 = round(x, 2),
    decimal2 = round(x, 3),
    percentual = round(x, 4),
    x
  )
}

#' Coluna de tabela
#' @keywords internal
report_col <- function(id, rotulo, formato = "texto") {
  stopifnot(formato %in% REPORT_FORMATOS)
  list(id = id, rotulo = rotulo, formato = formato)
}

#' Seção de texto (markdown simples)
#' @keywords internal
report_section_text <- function(id, titulo, markdown) {
  list(id = id, tipo = "texto", titulo = titulo, markdown = markdown)
}

#' Item de indicador (KPI)
#'
#' @param referencia `NULL` ou `list(rotulo, valor)` (nível de comparação).
#' @keywords internal
report_kpi <- function(rotulo, valor, formato = "decimal1", referencia = NULL) {
  stopifnot(formato %in% REPORT_FORMATOS)
  item <- list(rotulo = rotulo, valor = report_round(report_scalar(valor), formato), formato = formato)
  if (!is.null(referencia) && !is.na(report_scalar(referencia$valor))) {
    item$referencia <- list(
      rotulo = referencia$rotulo,
      valor = report_round(report_scalar(referencia$valor), formato)
    )
  }
  item
}

#' Escalar seguro (primeiro valor ou NA)
#' @keywords internal
report_scalar <- function(x) {
  if (is.null(x) || !length(x)) NA else x[[1]]
}

#' Seção de indicadores (descarta itens sem valor)
#' @keywords internal
report_section_kpis <- function(id, titulo, itens) {
  itens <- Filter(function(i) !is.null(i) && !is.na(i$valor), itens)
  if (!length(itens)) {
    return(NULL)
  }
  list(id = id, tipo = "indicadores", titulo = titulo, itens = unname(itens))
}

#' Seção de tabela
#'
#' Mantém só as colunas declaradas e arredonda pelos formatos.
#'
#' @param colunas lista de [report_col()].
#' @param linhas data.frame com as colunas declaradas.
#' @keywords internal
report_section_table <- function(id, titulo, colunas, linhas, nota = NULL) {
  if (!is.data.frame(linhas) || !nrow(linhas)) {
    return(NULL)
  }
  ids <- vapply(colunas, `[[`, character(1), "id")
  for (c in setdiff(ids, names(linhas))) linhas[[c]] <- NA
  linhas <- linhas[, ids, drop = FALSE]
  for (col in colunas) {
    linhas[[col$id]] <- report_round(linhas[[col$id]], col$formato)
  }
  rownames(linhas) <- NULL
  sec <- list(id = id, tipo = "tabela", titulo = titulo, colunas = colunas, linhas = linhas)
  if (!is.null(nota)) sec$nota <- nota
  sec
}

#' Seção de gráfico
#'
#' @param grafico `"barras"` ou `"linhas"`.
#' @param x `list(id, rotulo)`.
#' @param series lista de `list(id, rotulo)`.
#' @param dados data.frame com a coluna `x$id` e uma coluna por série.
#' @keywords internal
report_section_chart <- function(id, titulo, grafico, x, series, dados, formato = NULL) {
  stopifnot(grafico %in% c("barras", "linhas"))
  if (!is.data.frame(dados) || !nrow(dados)) {
    return(NULL)
  }
  ids <- c(x$id, vapply(series, `[[`, character(1), "id"))
  for (c in setdiff(ids, names(dados))) dados[[c]] <- NA
  dados <- dados[, ids, drop = FALSE]
  # Série sem nenhum valor não entra no gráfico.
  vazias <- vapply(series, function(s) all(is.na(dados[[s$id]])), logical(1))
  if (all(vazias)) {
    return(NULL)
  }
  series <- series[!vazias]
  dados <- dados[, c(x$id, vapply(series, `[[`, character(1), "id")), drop = FALSE]
  if (!is.null(formato)) {
    for (s in series) dados[[s$id]] <- report_round(dados[[s$id]], formato)
  }
  rownames(dados) <- NULL
  sec <- list(
    id = id, tipo = "grafico", grafico = grafico, titulo = titulo,
    x = x, series = series, dados = dados
  )
  if (!is.null(formato)) sec$formato <- formato
  sec
}

#' Fonte de dados de um relatório
#' @keywords internal
report_fonte <- function(ferramenta, descricao, edicao, escopo, n) {
  list(
    ferramenta = ferramenta,
    descricao = descricao,
    edicao = edicao,
    escopo = escopo,
    n = as.integer(n)
  )
}

#' Formata um valor em PT-BR conforme o formato (textos determinísticos)
#' @keywords internal
report_format_value <- function(valor, formato) {
  if (is.null(valor) || length(valor) != 1L || is.na(valor)) {
    return("—")
  }
  if (!is.numeric(valor)) {
    return(as.character(valor))
  }
  num <- function(v, d) {
    formatC(v, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
  }
  switch(formato,
    inteiro = num(round(valor), 0),
    decimal1 = num(valor, 1),
    decimal2 = num(valor, 2),
    percentual = paste0(num(valor * 100, 1), "%"),
    as.character(valor)
  )
}

#' Rótulos de etapa do IDEB
#' @keywords internal
report_etapa_label <- function(etapa) {
  switch(etapa %||% "",
    fundamental_i = "anos iniciais do ensino fundamental",
    fundamental_ii = "anos finais do ensino fundamental",
    ensino_medio = "ensino médio",
    "todas as etapas"
  )
}

#' Rótulo curto de etapa
#' @keywords internal
report_etapa_short <- function(etapa) {
  switch(etapa %||% "",
    fundamental_i = "Anos iniciais",
    fundamental_ii = "Anos finais",
    ensino_medio = "Ensino médio",
    "Todas"
  )
}

#' Rótulo de rede para textos ("rede municipal", "redes públicas"...)
#' @keywords internal
report_rede_label <- function(rede) {
  if (is.null(rede)) {
    return("todas as redes")
  }
  if (identical(rede, "publica")) {
    return("redes públicas")
  }
  paste("rede", tolower(rede))
}

#' Acumulador de fontes e avisos de um roteiro
#' @keywords internal
report_acc <- function() {
  acc <- new.env(parent = emptyenv())
  acc$fontes <- list()
  acc$avisos <- list()
  acc
}

#' Registra uma fonte no acumulador
#' @keywords internal
report_add_fonte <- function(acc, fonte) {
  acc$fontes[[length(acc$fontes) + 1L]] <- fonte
  invisible(acc)
}

#' Registra avisos no acumulador (sem repetir mensagens)
#' @keywords internal
report_add_avisos <- function(acc, avisos) {
  for (a in avisos) {
    msgs <- vapply(acc$avisos, `[[`, character(1), "mensagem")
    if (!a$mensagem %in% msgs) {
      acc$avisos[[length(acc$avisos) + 1L]] <- a
    }
  }
  invisible(acc)
}
