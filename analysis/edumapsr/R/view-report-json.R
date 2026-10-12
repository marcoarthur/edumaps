# R/view-report-json.R
#
# View do Assistente de Relatório: `analysis_result` ("report") →
# ReportResult (lista pronta para JSON, contrato da onda 1, #219).
#
# Serializar com `auto_unbox = TRUE, na = "null", null = "null"` (o
# serializador do endpoint `/report`): arrays são sempre listas R (nunca
# vetores de comprimento 1, que o auto_unbox achataria) e data.frames viram
# listas de objetos (uma por linha).

#' Data.frame → lista de objetos (uma por linha), escalares JSON
#'
#' A marca `_destaque` (Fase 2) só sai nas linhas destacadas (`true`); nas
#' demais a chave é omitida.
#'
#' @keywords internal
report_json_rows <- function(df) {
  if (!is.data.frame(df) || !nrow(df)) {
    return(list())
  }
  lapply(seq_len(nrow(df)), function(i) {
    row <- lapply(names(df), function(col) {
      v <- df[[col]][[i]]
      if (is.factor(v)) v <- as.character(v)
      if (length(v) != 1L) NA else v
    })
    names(row) <- names(df)
    if (REPORT_DESTAQUE %in% names(row)) {
      if (isTRUE(row[[REPORT_DESTAQUE]])) {
        row[[REPORT_DESTAQUE]] <- TRUE
      } else {
        row[[REPORT_DESTAQUE]] <- NULL
      }
    }
    row
  })
}

#' Seção → objeto JSON do contrato
#' @keywords internal
report_json_section <- function(s) {
  # Campos internos (`.ocultar_llm`...) não fazem parte do contrato.
  out <- s[!startsWith(names(s), ".")]
  if (identical(s$tipo, "tabela")) {
    out$colunas <- unname(s$colunas)
    out$linhas <- report_json_rows(s$linhas)
  }
  if (identical(s$tipo, "grafico")) {
    out$series <- unname(s$series)
    out$dados <- report_json_rows(s$dados)
  }
  if (identical(s$tipo, "indicadores") || identical(s$tipo, "associacoes")) {
    out$itens <- unname(s$itens)
  }
  out
}

#' Renderiza o ReportResult
#'
#' @param result `analysis_result` de [analyze_report()].
#'
#' @return Lista com `titulo`, `gerado_em`, `recorte`, `assistente`
#'   (Fase 4), `tema`, `capitulos` (só no modo composto), `secoes` (as de
#'   capítulo levam `capitulo`), `fontes`, `avisos` e `rastreio`.
#'
#' @export
render_report_json <- function(result) {
  if (!inherits(result, "analysis_result") || !identical(result$analysis, "report")) {
    stop_invalid_parameter("render_report_json espera o analysis_result de analyze_report()")
  }
  m <- result$metadata
  recorte <- m$recorte[!vapply(m$recorte, is.null, logical(1))]
  out <- list(
    titulo = m$titulo,
    gerado_em = m$gerado_em,
    recorte = recorte,
    assistente = m$assistente,
    tema = m$tema
  )
  if (!is.null(m$capitulos)) {
    out$capitulos <- unname(m$capitulos)
  }
  c(out, list(
    secoes = unname(lapply(m$secoes, report_json_section)),
    fontes = unname(m$fontes),
    avisos = unname(m$avisos),
    rastreio = m$rastreio
  ))
}

#' Serializa um ReportResult em JSON (mesmas opções do endpoint)
#' @keywords internal
report_to_json <- function(x, pretty = FALSE) {
  jsonlite::toJSON(
    x, auto_unbox = TRUE, na = "null", null = "null", digits = NA,
    pretty = pretty
  )
}
