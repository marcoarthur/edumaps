# R/chat-plotly.R
#
# Construção da especificação Plotly (data + layout) para o Assistente do
# Censo, a partir do resultado SQL do chat (data.frame) e da configuração de
# gráfico registrada pelo modelo (tipo, coluna x, coluna y, título).
#
# O JSON é montado à mão (sem plotly::ggplotly) para ser determinístico e
# leve: quem consome é o plotly.js no frontend, que espera exatamente
# `{data: [...], layout: {...}}`.

CHAT_CHART_TYPES <- c("barra", "linha", "pizza")

#' Valida a configuração de gráfico do chat
#'
#' @param chart lista com tipo, x, y, titulo.
#' @keywords internal
chat_chart_tipo_valid <- function(tipo) {
  if (is.null(tipo) || length(tipo) == 0) return(FALSE)
  ifelse(is.na(tipo), FALSE, tipo %in% CHAT_CHART_TYPES)
}

#' Especificação Plotly para um gráfico do chat
#'
#' Constrói a lista `{data, layout}` pronta para serialização JSON. Devolve
#' NULL quando o gráfico não pode ser montado (tipo desconhecido ou coluna
#' inexistente no resultado) — nesse caso o chat responde sem gráfico.
#'
#' @param resultados data.frame com as linhas do resultado da consulta.
#' @param tipo tipo do gráfico: "barra", "linha" ou "pizza".
#' @param x nome da coluna do eixo x (ou rótulos/categorias).
#' @param y nome da coluna de valores (ou counts, na pizza).
#' @param titulo título do gráfico.
#' @keywords internal
chat_chart_plotly_json <- function(resultados, tipo, x, y, titulo = NULL) {
  if (!chat_chart_tipo_valid(tipo)) {
    return(NULL)
  }
  if (is.null(resultados) || nrow(resultados) == 0) {
    return(NULL)
  }
  if (!(x %in% names(resultados))) {
    return(NULL)
  }
  if (!(y %in% names(resultados))) {
    return(NULL)
  }

  valores_x <- resultados[[x]]
  valores_y <- suppressWarnings(as.numeric(resultados[[y]]))
  if (all(is.na(valores_y))) {
    return(NULL)
  }

  dados <- switch(tipo,
    barra = list(list(
      x = valores_x, y = valores_y,
      type = "bar"
    )),
    linha = list(list(
      x = valores_x, y = valores_y,
      type = "scatter", mode = "lines+markers"
    )),
    pizza = list(list(
      labels = valores_x, values = valores_y,
      type = "pie", hole = 0.3
    ))
  )

  rotulo_y <- if (tipo == "pizza") NULL else y
  layout <- list(
    title = list(text = titulo %||% "", font = list(size = 14)),
    xaxis = list(title = x),
    yaxis = list(title = rotulo_y)
  )

  list(data = dados, layout = layout)
}