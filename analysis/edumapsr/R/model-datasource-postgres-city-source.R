# R/model/datasource/postgres_city_source.R
#
# DataSource Postgres para as escolas de um município.
#
# Implementa o método `load_city_schools()` para `postgres_source`, com a
# mesma consulta agregada do script legado
# (backend/templates/rscripts/city/city_analytics.R): censo_escolas
# LEFT JOIN censo_matriculas e censo_docentes por co_entidade + censo,
# filtrando por co_municipio. O código IBGE vai SEMPRE como parâmetro
# vinculado ($1), nunca interpolado.

CITY_SOURCE_PREFIX <- "edumaps:city"

#' Carrega um `CitySchoolModel` a partir de uma fonte
#'
#' Generic S3 para carregar o modelo semântico de cidade.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros específicos da implementação da fonte.
#'
#' @return Objeto da classe `city_school_model`.
#'
#' @export
load_city_schools <- function(source, ...) {
  UseMethod("load_city_schools")
}

#' Carrega um `CitySchoolModel` a partir do Postgres
#'
#' Implementação de `load_city_schools()` para `postgres_source`.
#'
#' @param source objeto da classe `postgres_source`.
#' @param codigo_ibge código IBGE do município (7 dígitos).
#' @param schema schema onde os dados do censo vivem (default: "clean").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `city_school_model`.
#'
#' @export
load_city_schools.postgres_source <- function(
  source,
  codigo_ibge,
  schema = "clean",
  ...
) {
  con <- source$con

  DBI::dbExecute(con, "SET client_encoding = 'UTF8'")

  quote <- function(x) DBI::dbQuoteIdentifier(con, x)

  sql <- sprintf("
    SELECT
      e.co_entidade,
      e.no_entidade,
      e.tp_dependencia,
      e.tp_localizacao,
      COALESCE(m.qt_mat_bas, 0)  AS qt_mat_bas,
      COALESCE(m.qt_mat_inf, 0)  AS qt_mat_inf,
      COALESCE(m.qt_mat_fund, 0) AS qt_mat_fund,
      COALESCE(m.qt_mat_med, 0)  AS qt_mat_med,
      COALESCE(d.qt_doc_bas, 0)  AS qt_doc_bas
    FROM %s.censo_escolas e
    LEFT JOIN %s.censo_matriculas m
      ON e.co_entidade = m.co_entidade AND e.nu_ano_censo = m.nu_ano_censo
    LEFT JOIN %s.censo_docentes d
      ON e.co_entidade = d.co_entidade AND e.nu_ano_censo = d.nu_ano_censo
    WHERE e.co_municipio = $1
  ", quote(schema), quote(schema), quote(schema))

  df_schools <- DBI::dbGetQuery(con, sql, params = list(codigo_ibge))

  if (nrow(df_schools) == 0) {
    stop_invalid_dataset(sprintf(
      "Nenhum dado encontrado para o código IBGE: %s",
      codigo_ibge
    ))
  }

  df_schools$dependencia <- vapply(df_schools$tp_dependencia, function(v) {
    switch(as.character(v),
      "1" = "Federal",
      "2" = "Estadual",
      "3" = "Municipal",
      "4" = "Privada",
      "Outra"
    )
  }, character(1))

  df_schools$localizacao <- vapply(df_schools$tp_localizacao, function(v) {
    switch(as.character(v),
      "1" = "Urbana",
      "2" = "Rural",
      "Desconhecida"
    )
  }, character(1))

  df_schools$ratio_aluno_docente <- ifelse(
    df_schools$qt_doc_bas > 0,
    round(df_schools$qt_mat_bas / df_schools$qt_doc_bas, 2),
    NA_real_
  )

  new_city_school_model(
    data = df_schools,
    codigo_ibge = codigo_ibge,
    metadata = list(schema = schema)
  )
}