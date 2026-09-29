# R/model/datasource/postgres_school_profile_reference_source.R
#
# DataSource Postgres que COMPUTA as referências comparativas do perfil
# (issue #107, Fase 2): médias por indicador para Brasil ('todas'), para
# cada rede (`tp_dependencia`) e para cada município, por ano do censo.
#
# É o mesmo cálculo que o endpoint fazia a cada request; aqui roda uma vez
# (batch) e alimenta `analytics.school_profile_reference`.
#
# `nu_ano_censo` entra como bind ($1); os nomes de indicador vêm do
# whitelist fechado `.profile_indicator_exprs()`.

#' SQL das referências comparativas (wide: 1 linha por escopo/chave)
#'
#' @keywords internal
.profile_reference_sql <- function(schema_q, include_inactive, ano_expr = "$1") {
  pop_body <- .profile_pop_body(schema_q, include_inactive, ano_expr = ano_expr)
  avg_cols <- .profile_avg_cols()

  sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT 'brasil' AS scope, 'todas' AS chave, count(*) AS n_escolas, %s
  FROM pop
UNION ALL
SELECT 'rede' AS scope, tp_dependencia::text AS chave, count(*) AS n_escolas, %s
  FROM pop GROUP BY tp_dependencia
UNION ALL
SELECT 'municipio' AS scope, co_municipio::text AS chave, count(*) AS n_escolas, %s
  FROM pop GROUP BY co_municipio
",
    pop_body,
    avg_cols, avg_cols, avg_cols
  )
}

#' Converte o resultado wide das referências em formato longo
#'
#' @keywords internal
.profile_reference_long <- function(wide) {
  inds <- PROFILE_INDICATORS
  empty <- data.frame(
    scope = character(0), chave = character(0), indicador = character(0),
    valor = numeric(0), n_escolas = integer(0), stringsAsFactors = FALSE
  )
  if (nrow(wide) == 0) {
    return(empty)
  }

  long <- do.call(rbind, lapply(seq_len(nrow(wide)), function(i) {
    data.frame(
      scope = as.character(wide$scope[i]),
      chave = as.character(wide$chave[i]),
      indicador = inds,
      valor = suppressWarnings(as.numeric(wide[i, inds])),
      n_escolas = as.integer(wide$n_escolas[i]),
      stringsAsFactors = FALSE
    )
  }))
  rownames(long) <- NULL
  long
}

#' Carrega as referências comparativas a partir de uma fonte
#'
#' Generic S3.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros da implementação.
#'
#' @return data.frame longo (`scope`, `chave`, `indicador`, `valor`,
#'   `n_escolas`).
#'
#' @export
load_school_profile_reference <- function(source, ...) {
  UseMethod("load_school_profile_reference")
}

#' Carrega as referências comparativas do Postgres
#'
#' @param source objeto da classe `postgres_source`.
#' @param nu_ano_censo ano do censo (`NULL` resolve o mais recente).
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas (default: `FALSE`).
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return data.frame longo.
#'
#' @export
load_school_profile_reference.postgres_source <- function(
  source,
  nu_ano_censo = NULL,
  schema = "clean",
  include_inactive = FALSE,
  ...
) {
  con <- source$con
  schema_q <- DBI::dbQuoteIdentifier(con, schema)

  DBI::dbExecute(con, "SET client_encoding = 'UTF8'")

  if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    nu_ano_censo <- resolve_censo_ano(con, schema)
  }

  wide <- DBI::dbGetQuery(
    con,
    .profile_reference_sql(schema_q, include_inactive, ano_expr = "$1"),
    params = list(as.integer(nu_ano_censo))
  )

  .profile_reference_long(wide)
}