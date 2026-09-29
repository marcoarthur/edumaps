# R/analysis/school_evolution.R
#
# Análise pura da EVOLUÇÃO da escola (issue #110, roadmap do #105).
#
# Contrato:
#
#   school_evolution_model
#            ↓
#   analyze_school_evolution()
#            ↓
#      analysis_result
#
# A série longa vai em `data` (uma linha por indicador/ano/etapa) e o
# resumo por série (nº de anos, primeiro/último valor e variação) em
# `tables$resumo`. Não faz I/O e não conhece SQL.

#' Resume cada série (indicador + etapa) da evolução
#'
#' @keywords internal
.school_evolution_resumo <- function(serie) {
  empty <- data.frame(
    indicador = character(0), label = character(0), etapa = character(0),
    n_anos = integer(0), ano_min = integer(0), ano_max = integer(0),
    primeiro_valor = numeric(0), ultimo_valor = numeric(0),
    variacao = numeric(0), stringsAsFactors = FALSE
  )
  if (nrow(serie) == 0) {
    return(empty)
  }

  key <- paste(serie$indicador, ifelse(is.na(serie$etapa), "", serie$etapa), sep = "|")
  groups <- split(seq_len(nrow(serie)), key)

  resumo <- do.call(rbind, lapply(groups, function(idx) {
    d <- serie[idx, , drop = FALSE]
    d <- d[!is.na(d$valor), , drop = FALSE]
    if (nrow(d) == 0) {
      return(NULL)
    }
    d <- d[order(d$ano), , drop = FALSE]
    data.frame(
      indicador = d$indicador[1],
      label = d$label[1],
      etapa = d$etapa[1],
      n_anos = nrow(d),
      ano_min = min(d$ano),
      ano_max = max(d$ano),
      primeiro_valor = d$valor[1],
      ultimo_valor = d$valor[nrow(d)],
      variacao = d$valor[nrow(d)] - d$valor[1],
      stringsAsFactors = FALSE
    )
  }))

  rownames(resumo) <- NULL
  resumo
}

#' Monta a análise de evolução da escola
#'
#' @param model objeto da classe `school_evolution_model`.
#' @param parameters lista de parâmetros da execução (preservada).
#'
#' @return Objeto da classe `analysis_result`; a série longa em `data` e o
#'   resumo por série em `tables$resumo`.
#'
#' @export
analyze_school_evolution <- function(model, parameters = list()) {
  if (!inherits(model, "school_evolution_model")) {
    stop_invalid_parameter("analyze_school_evolution requer um school_evolution_model")
  }

  serie <- evolution_data(model)

  metrics <- list(
    n_series = nrow(serie),
    n_indicadores = length(unique(serie$indicador)),
    n_etapas = length(unique(stats::na.omit(serie$etapa))),
    ano_min = if (nrow(serie) > 0) min(serie$ano) else NA_integer_,
    ano_max = if (nrow(serie) > 0) max(serie$ano) else NA_integer_
  )

  new_analysis_result(
    analysis = "school_evolution",
    parameters = parameters,
    data = serie,
    metrics = metrics,
    tables = list(resumo = .school_evolution_resumo(serie)),
    metadata = model$metadata
  )
}