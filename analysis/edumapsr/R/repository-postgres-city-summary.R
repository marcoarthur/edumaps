# R/repository/postgres_city_summary.R
#
# Repository PostgreSQL para resumo de cidade (EDA).
#
# É o equivalente em Repository do
# backend/templates/rscripts/city/city_analytics.R: garante o schema, cria
# `analytics.city_school_analytics` se não existir, monta os dois gráficos
# Plotly (matrículas por nível/dependência agregado + boxplot da relação
# aluno/docente) e faz o UPSERT por (codigo_ibge, analysis). A análise é
# pura (R/analysis/city_summary.R); gráficos e persistência são efeito
# colateral, isolados aqui.

CITY_ANALYTICS_TABLE <- "city_school_analytics"

#' Converte a estrutura Plotly em lista serializável
#'
#' @param p objeto plotly.
#'
#' @return Lista com `data` e `layout` prontas para JSON.
#'
#' @keywords internal
plotly_to_list <- function(p) {
  p_build <- plotly::plotly_build(p)
  p_build$x[c("data", "layout")]
}

#' Cria um repository PostgreSQL para resumo de cidade
#'
#' @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_city_repository`.
#'
#' @export
postgres_city_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_city_repository"
  )
}

#' Persiste um resumo de cidade
#'
#' Generic S3 para persistência de resumos de município.
#'
#' @param repository objeto Repository.
#' @param result objeto da classe `analysis_result`.
#' @param ... parâmetros específicos da implementação.
#'
#' @return O objeto `result`, invisivelmente.
#'
#' @export
persist_city_summary <- function(repository, result, ...) {
  UseMethod("persist_city_summary")
}

#' Persiste um resumo de cidade no PostgreSQL
#'
#' Implementação de `persist_city_summary()` para
#' `postgres_city_repository`. Resultados marcados com `status =
#' "SKIPPED"` (análises ainda sem suporte de dados) não são persistidos.
#'
#' @param repository objeto da classe `postgres_city_repository`.
#' @param result objeto da classe `analysis_result`, produzido por
#'   `analyze_city_summary()`.
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `codigo_ibge`, `analysis`,
#'   `records_processed` e, quando persistido, `summary_table`.
#'
#' @export
persist_city_summary.postgres_city_repository <- function(
  repository,
  result,
  output_schema = "analytics",
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }

  if (!identical(result$analysis, "city_summary")) {
    stop("repository espera um resultado city_summary")
  }

  codigo_ibge <- result$metadata$codigo_ibge

  if (identical(result$metrics$status, "SKIPPED")) {
    return(list(
      persisted = FALSE,
      status = "SKIPPED",
      codigo_ibge = codigo_ibge,
      analysis = result$analysis
    ))
  }

  con <- repository$con

  json_summary <- jsonlite::toJSON(result$metrics, auto_unbox = TRUE)
  json_charts <- jsonlite::toJSON(
    .build_city_charts(result$data, result$tables$enrollment_by_level),
    auto_unbox = TRUE
  )

  .ensure_city_table(con, output_schema)

  upsert_sql <- sprintf(
    "INSERT INTO %s.%s (codigo_ibge, analysis, summary_data, plotly_charts, updated_at)
     VALUES ($1, $2, $3::jsonb, $4::jsonb, NOW())
     ON CONFLICT (codigo_ibge, analysis) DO UPDATE SET
       summary_data = EXCLUDED.summary_data,
       plotly_charts = EXCLUDED.plotly_charts,
       updated_at = NOW();",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, CITY_ANALYTICS_TABLE)
  )

  DBI::dbExecute(
    con,
    upsert_sql,
    params = list(
      codigo_ibge,
      "full_summary",
      as.character(json_summary),
      as.character(json_charts)
    )
  )

  list(
    persisted = TRUE,
    codigo_ibge = codigo_ibge,
    analysis = "full_summary",
    records_processed = nrow(result$data),
    summary_table = paste0(output_schema, ".", CITY_ANALYTICS_TABLE)
  )
}

#' Monta os gráficos Plotly do resumo da cidade
#'
#' @keywords internal
.build_city_charts <- function(df_schools, df_levels) {
  p1 <- plotly::plot_ly(
    df_levels,
    x = ~dependencia,
    y = ~matriculas,
    color = ~nivel,
    type = "bar"
  )
  p1 <- plotly::layout(
    p1,
    barmode = "stack",
    title = list(text = "Matrículas por Nível de Ensino e Dependência Administrativa"),
    xaxis = list(title = "Dependência"),
    yaxis = list(title = "Total de Matrículas")
  )

  p2 <- plotly::plot_ly(
    df_schools,
    x = ~dependencia,
    y = ~ratio_aluno_docente,
    color = ~dependencia,
    type = "box"
  )
  p2 <- plotly::layout(
    p2,
    title = list(text = "Relação Aluno/Docente por Escola"),
    xaxis = list(title = "Dependência"),
    yaxis = list(title = "Alunos por Docente")
  )

  list(
    enrollment_by_level = plotly_to_list(p1),
    student_teacher_ratio = plotly_to_list(p2)
  )
}

#' Garante a tabela de resumo da cidade (UPSERT)
#'
#' @keywords internal
.ensure_city_table <- function(con, output_schema) {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, output_schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       codigo_ibge  VARCHAR(7) NOT NULL,
       analysis     VARCHAR(50) NOT NULL,
       summary_data JSONB NOT NULL,
       plotly_charts JSONB NOT NULL,
       updated_at   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY (codigo_ibge, analysis)
     );",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, CITY_ANALYTICS_TABLE)
  ))
}