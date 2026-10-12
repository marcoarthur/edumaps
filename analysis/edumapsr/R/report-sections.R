# R/report-sections.R
#
# Construtores das seções do ReportResult (contrato da onda 1, #219) e
# formatação PT-BR para os textos determinísticos.
#
# Tipos de seção: `texto` | `indicadores` | `tabela` | `grafico`
# (`grafico` ∈ `barras` | `linhas`) e, na Fase 2, `associacoes` (leitura
# simplificada de uma regressão). Extensões da Fase 2 (opcionais e
# retrocompatíveis): tabela `recolhida` (detalhes técnicos) e linha com
# `_destaque` (ex.: a escola do gestor).
#
# Campos de seção que começam com ponto (ex.: `.ocultar_llm`) são INTERNOS:
# orientam o pacote de dados do LLM e nunca saem no JSON. Formatos de valor: `texto`, `inteiro`,
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

#' Coluna de linha destacada (não é coluna declarada da tabela)
#' @keywords internal
REPORT_DESTAQUE <- "_destaque"

#' Seção de tabela
#'
#' Mantém só as colunas declaradas (mais a marca `_destaque`, se houver) e
#' arredonda pelos formatos.
#'
#' @param colunas lista de [report_col()].
#' @param linhas data.frame com as colunas declaradas; uma coluna lógica
#'   `_destaque` marca as linhas a realçar (sai no JSON só quando `TRUE`).
#' @param recolhida `TRUE` = detalhes técnicos (o frontend mostra dentro de
#'   "Ver detalhes técnicos").
#' @param ocultar_llm colunas que NÃO vão ao LLM (ex.: nomes de escolas de
#'   terceiros), exceto nas linhas com `_destaque`. Campo interno.
#' @keywords internal
report_section_table <- function(id, titulo, colunas, linhas, nota = NULL,
                                 recolhida = FALSE, ocultar_llm = NULL) {
  if (!is.data.frame(linhas) || !nrow(linhas)) {
    return(NULL)
  }
  ids <- vapply(colunas, `[[`, character(1), "id")
  for (c in setdiff(ids, names(linhas))) linhas[[c]] <- NA
  manter <- c(ids, intersect(REPORT_DESTAQUE, names(linhas)))
  linhas <- linhas[, manter, drop = FALSE]
  for (col in colunas) {
    linhas[[col$id]] <- report_round(linhas[[col$id]], col$formato)
  }
  if (REPORT_DESTAQUE %in% names(linhas)) {
    linhas[[REPORT_DESTAQUE]] <- linhas[[REPORT_DESTAQUE]] %in% TRUE
  }
  rownames(linhas) <- NULL
  sec <- list(id = id, tipo = "tabela", titulo = titulo, colunas = colunas, linhas = linhas)
  if (!is.null(nota)) sec$nota <- nota
  if (isTRUE(recolhida)) sec$recolhida <- TRUE
  if (length(ocultar_llm)) sec$.ocultar_llm <- ocultar_llm
  sec
}

#' Direções aceitas na seção `associacoes`
#' @keywords internal
REPORT_DIRECOES <- c("maior", "menor", "sem_relacao_clara")

#' Seguranças aceitas na seção `associacoes`
#' @keywords internal
REPORT_SEGURANCAS <- c("alta", "media", "baixa")

#' Direção de uma associação (contrato da Fase 2)
#'
#' Sinal da estimativa; `sem_relacao_clara` quando p ≥ 0,05 (ou sem p).
#'
#' @keywords internal
report_direcao <- function(estimativa, p_valor) {
  ifelse(
    is.na(p_valor) | is.na(estimativa) | p_valor >= 0.05 | estimativa == 0,
    "sem_relacao_clara",
    ifelse(estimativa > 0, "maior", "menor")
  )
}

#' Segurança de uma associação: `alta` (p < 0,01), `media` (p < 0,05) ou
#' `baixa`
#' @keywords internal
report_seguranca <- function(p_valor) {
  ifelse(
    !is.na(p_valor) & p_valor < 0.01, "alta",
    ifelse(!is.na(p_valor) & p_valor < 0.05, "media", "baixa")
  )
}

#' Item da seção `associacoes`
#'
#' @param corte valor do corte (ex.: "Urbana") ou `NULL`.
#' @keywords internal
report_associacao <- function(rotulo, direcao, seguranca, n, corte = NULL) {
  stopifnot(direcao %in% REPORT_DIRECOES, seguranca %in% REPORT_SEGURANCAS)
  item <- list(rotulo = rotulo)
  if (!is.null(corte) && !is.na(corte)) item$corte <- as.character(corte)
  item$direcao <- direcao
  item$seguranca <- seguranca
  item$n <- as.integer(n)
  item
}

#' Seção `associacoes` (leitura simplificada de uma regressão)
#' @keywords internal
report_section_associacoes <- function(id, titulo, itens, nota = NULL) {
  itens <- Filter(Negate(is.null), itens)
  if (!length(itens)) {
    return(NULL)
  }
  sec <- list(id = id, tipo = "associacoes", titulo = titulo, itens = unname(itens))
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

#' Formata em PT-BR com algarismos significativos (tabelas técnicas)
#'
#' Para estimativas e erros de regressão, cujas ordens de grandeza variam
#' muito (0,0004 por matrícula; 0,3 por biblioteca): texto, não número.
#'
#' @keywords internal
report_format_signif <- function(x, digits = 3L) {
  vapply(x, function(v) {
    if (is.na(v)) {
      return(NA_character_)
    }
    out <- formatC(signif(v, digits), format = "fg", digits = digits,
                   big.mark = ".", decimal.mark = ",")
    trimws(out)
  }, character(1), USE.NAMES = FALSE)
}

#' Formata um p-valor em PT-BR ("< 0,001", "0,034")
#' @keywords internal
report_format_p <- function(p) {
  vapply(p, function(v) {
    if (is.na(v)) {
      return(NA_character_)
    }
    if (v < 0.001) {
      return("< 0,001")
    }
    formatC(v, format = "f", digits = 3, decimal.mark = ",")
  }, character(1), USE.NAMES = FALSE)
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
