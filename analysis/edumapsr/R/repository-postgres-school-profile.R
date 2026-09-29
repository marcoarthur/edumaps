# R/repository/postgres_school_profile.R
#
# Repository PostgreSQL do "Perfil da Escola" (issue #105).
#
# Garante o schema/tabela (self-provisioning, como o
# repository-postgres-city-summary.R) e faz UPSERT por `co_entidade` em
# `analytics.school_profile`, guardando o payload serializado em JSONB.
# A análise é pura; persistência é efeito colateral isolado aqui.

SCHOOL_PROFILE_TABLE <- "school_profile"

#' Cria um repository PostgreSQL para o perfil da escola
#'
#' @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_school_profile_repository`.
#'
#' @export
postgres_school_profile_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_school_profile_repository"
  )
}

#' Persiste o perfil de uma escola
#'
#' Generic S3 para persistência de perfis de escola.
#'
#' @param repository objeto Repository.
#' @param result objeto da classe `analysis_result`.
#' @param ... parâmetros específicos da implementação.
#'
#' @return Lista com `persisted`, `co_entidade`, `nu_ano_censo`,
#'   `analysis` e `profile_table`.
#'
#' @export
persist_school_profile <- function(repository, result, ...) {
  UseMethod("persist_school_profile")
}

#' Persiste o perfil de uma escola no PostgreSQL
#'
#' Implementação de `persist_school_profile()` para
#' `postgres_school_profile_repository`. Serializa o resultado com
#' `auto_unbox = FALSE` para preservar o formato de ARRAY das tabelas
#' (`peers`, `flags`, `indicadores_comparados`), mesmo quando têm uma
#' única linha; `NA` vira `null`.
#'
#' @param repository objeto da classe
#'   `postgres_school_profile_repository`.
#' @param result objeto da classe `analysis_result`, produzido por
#'   `analyze_school_profile()`.
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `co_entidade`, `nu_ano_censo`,
#'   `analysis` e `profile_table`.
#'
#' @export
persist_school_profile.postgres_school_profile_repository <- function(
  repository,
  result,
  output_schema = "analytics",
  ...
) {
  if (!inherits(result, "analysis_result")) {
    stop("result deve ser um analysis_result")
  }

  if (!identical(result$analysis, "school_profile")) {
    stop("repository espera um resultado school_profile")
  }

  co_entidade <- result$metadata$co_entidade
  nu_ano_censo <- result$metadata$nu_ano_censo

  if (is.null(co_entidade) || is.na(co_entidade)) {
    stop("result sem co_entidade em metadata")
  }

  if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    stop("result sem nu_ano_censo em metadata")
  }

  con <- repository$con

  json_profile <- as.character(jsonlite::toJSON(
    render_json(result),
    auto_unbox = FALSE,
    na = "null",
    null = "null"
  ))

  .ensure_school_profile_table(con, output_schema)

  upsert_sql <- sprintf(
    "INSERT INTO %s.%s (co_entidade, nu_ano_censo, profile_data, updated_at)
     VALUES ($1, $2, $3::jsonb, NOW())
     ON CONFLICT (co_entidade) DO UPDATE SET
       nu_ano_censo = EXCLUDED.nu_ano_censo,
       profile_data = EXCLUDED.profile_data,
       updated_at = NOW();",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_TABLE)
  )

  DBI::dbExecute(
    con,
    upsert_sql,
    params = list(as.integer(co_entidade), as.integer(nu_ano_censo), json_profile)
  )

  list(
    persisted = TRUE,
    co_entidade = as.integer(co_entidade),
    nu_ano_censo = as.integer(nu_ano_censo),
    analysis = "school_profile",
    profile_table = paste0(output_schema, ".", SCHOOL_PROFILE_TABLE)
  )
}

#' Garante a tabela de perfil da escola (UPSERT)
#'
#' @keywords internal
.ensure_school_profile_table <- function(con, output_schema) {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, output_schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       co_entidade  BIGINT PRIMARY KEY,
       nu_ano_censo INTEGER NOT NULL,
       profile_data JSONB NOT NULL,
       updated_at   TIMESTAMPTZ DEFAULT now()
     );",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_TABLE)
  ))
}