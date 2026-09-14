# R/analysis/city_summary.R
#
# Análise pura de resumo estatístico de um município (EDA).
#
# Contrato:
#
#   city_school_model
#            ↓
#   analyze_city_summary()
#            ↓
#      analysis_result
#
# Espelha o `compute_and_save_city_summary()` do script legado
# (backend/templates/rscripts/city/city_analytics.R): agrega estatísticas
# globais do município e a tabela de matrículas por nível/dependência.
# Os gráficos Plotly e a persistência em `analytics.city_school_analytics`
# ficam no Repository — aqui só a parte pura/estatística.

#' Calcula o resumo estatístico do município
#'
#' Quando `parameters$type` é "school_clusters" ou "score_distributions",
#' devolve um resultado no mesmo contrato dos stubs legados (SKIPPED),
#' já que essas análises ainda não são suportadas por dados.
#'
#' @param model objeto da classe `city_school_model`.
#' @param parameters lista com `type` (full_summary | school_clusters |
#'   score_distributions) e demais parâmetros.
#'
#' @return Objeto da classe `analysis_result`.
#'
#' @export
analyze_city_summary <- function(model, parameters = list()) {
  if (!inherits(model, "city_school_model")) {
    stop_invalid_parameter("analyze_city_summary requer um city_school_model")
  }

  data <- city_school_data(model)
  codigo_ibge <- city_codigo_ibge(model)
  type <- parameters$type %||% "full_summary"

  if (!type %in% c("full_summary", "school_clusters", "score_distributions")) {
    stop_invalid_parameter(sprintf("Tipo de análise desconhecido: %s", type))
  }

  if (type != "full_summary") {
    return(new_analysis_result(
      analysis = paste0("city_", type),
      parameters = parameters,
      data = data.frame(),
      metrics = list(
        status = "SKIPPED",
        message = "Análise reservada para extensão (SAEB/IDEB ou clustering por infraestrutura)",
        codigo_ibge = codigo_ibge
      ),
      metadata = list(codigo_ibge = codigo_ibge)
    ))
  }

  summary_stats <- list(
    total_escolas = nrow(data),
    total_matriculas = sum(data$qt_mat_bas, na.rm = TRUE),
    total_docentes = sum(data$qt_doc_bas, na.rm = TRUE),
    media_alunos_por_escola = round(mean(data$qt_mat_bas, na.rm = TRUE), 2),
    mediana_aluno_docente = stats::median(data$ratio_aluno_docente, na.rm = TRUE),
    distribuicao_dependencia = as.list(table(data$dependencia))
  )

  level_columns <- c(
    "Infantil" = "qt_mat_inf",
    "Fundamental" = "qt_mat_fund",
    "Médio" = "qt_mat_med"
  )

  enrollment_long <- do.call(rbind, lapply(names(level_columns), function(lvl) {
    data.frame(
      dependencia = data$dependencia,
      nivel = lvl,
      matriculas = data[[level_columns[[lvl]]]],
      stringsAsFactors = FALSE
    )
  }))

  df_levels <- stats::aggregate(
    matriculas ~ dependencia + nivel,
    data = enrollment_long,
    FUN = sum
  )

  new_analysis_result(
    analysis = "city_summary",
    parameters = parameters,
    data = data,
    metrics = summary_stats,
    tables = list(
      enrollment_by_level = df_levels
    ),
    metadata = list(
      codigo_ibge = codigo_ibge,
      value_label = "Matrículas",
      group_label = "Dependência"
    )
  )
}