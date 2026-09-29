# R/model/datasource/postgres_school_cluster_profile_source.R
#
# DataSource Postgres que COMPUTA os percentis por cluster do perfil
# (issue #107, Fase 2): p25/p50/p75/média + n por indicador, para cada
# `cluster_id` gravado em `clean.school_indicators`.
#
# O cálculo é o mesmo que o endpoint fazia a cada request para escolas
# com cluster persistido; aqui roda uma vez (batch, após a clusterização)
# e alimenta `analytics.school_cluster_profile`.
#
# `nu_ano_censo` entra como bind ($1).

#' SQL dos percentis por cluster
#'
#' @keywords internal
.profile_cluster_profile_sql <- function(schema_q, include_inactive, ano_expr = "$1") {
  pop_body <- .profile_pop_body(schema_q, include_inactive, ano_expr = ano_expr)

  sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT si.cluster_id::int AS cluster_id, count(*) AS n,
       %s
  FROM pop p
  JOIN %s.school_indicators si ON si.co_entidade = p.co_entidade
 WHERE si.cluster_id IS NOT NULL
 GROUP BY si.cluster_id
",
    pop_body,
    .profile_cluster_stat_cols(),
    schema_q
  )
}

#' Converte o resultado wide dos percentis em formato longo
#'
#' @keywords internal
.profile_cluster_profile_long <- function(wide) {
  inds <- PROFILE_INDICATORS
  empty <- data.frame(
    cluster_id = integer(0), indicador = character(0),
    p25 = numeric(0), p50 = numeric(0), p75 = numeric(0),
    media = numeric(0), n = integer(0), stringsAsFactors = FALSE
  )
  if (nrow(wide) == 0) {
    return(empty)
  }

  long <- do.call(rbind, lapply(seq_len(nrow(wide)), function(i) {
    data.frame(
      cluster_id = as.integer(wide$cluster_id[i]),
      indicador = inds,
      p25 = suppressWarnings(as.numeric(wide[i, paste0("p25_", inds)])),
      p50 = suppressWarnings(as.numeric(wide[i, paste0("p50_", inds)])),
      p75 = suppressWarnings(as.numeric(wide[i, paste0("p75_", inds)])),
      media = suppressWarnings(as.numeric(wide[i, paste0("media_", inds)])),
      n = as.integer(wide$n[i]),
      stringsAsFactors = FALSE
    )
  }))
  rownames(long) <- NULL
  long
}

#' Carrega os percentis por cluster a partir de uma fonte
#'
#' Generic S3.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros da implementação.
#'
#' @return data.frame longo (`cluster_id`, `indicador`, `p25`, `p50`,
#'   `p75`, `media`, `n`).
#'
#' @export
load_school_cluster_profile <- function(source, ...) {
  UseMethod("load_school_cluster_profile")
}

#' Carrega os percentis por cluster do Postgres
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
load_school_cluster_profile.postgres_source <- function(
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
    .profile_cluster_profile_sql(schema_q, include_inactive, ano_expr = "$1"),
    params = list(as.integer(nu_ano_censo))
  )

  .profile_cluster_profile_long(wide)
}