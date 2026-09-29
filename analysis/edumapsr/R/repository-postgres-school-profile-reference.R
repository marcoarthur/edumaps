# R/repository/postgres_school_profile_reference.R
#
# Repository PostgreSQL das REFERÊNCIAS COMPARATIVAS do Perfil da Escola
# (issue #107, Fase 2).
#
# As médias de município/rede/Brasil mudam só quando o Censo (ano) muda —
# não a cada request. Aqui elas são materializadas em
# `analytics.school_profile_reference`, para o endpoint ler em vez de
# varrer a população de 214k escolas.
#
# Self-provisioning (padrão `repository-postgres-school-profile.R`).

SCHOOL_PROFILE_REFERENCE_TABLE <- "school_profile_reference"

#' Cria um repository PostgreSQL para as referências do perfil
#'
#' @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_school_profile_reference_repository`.
#'
#' @export
postgres_school_profile_reference_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_school_profile_reference_repository"
  )
}

#' Persiste as referências comparativas em lote
#'
#' Generic S3. `rows` é um data.frame longo com `scope`, `chave`,
#' `indicador`, `valor` e `n_escolas`.
#'
#' @param repository objeto Repository.
#' @param rows data.frame longo.
#' @param ... parâmetros específicos da implementação.
#'
#' @return Lista com `persisted`, `nu_ano_censo`, `rows` e `table`.
#'
#' @export
persist_school_profile_reference <- function(repository, rows, ...) {
  UseMethod("persist_school_profile_reference")
}

#' Persiste as referências comparativas no PostgreSQL (upsert em lote)
#'
#' Implementação de `persist_school_profile_reference()` para
#' `postgres_school_profile_reference_repository`. Usa `unnest` de
#' arrays para um UPSERT set-based (sem N round-trips), com bind de
#' todos os valores.
#'
#' @param repository objeto da classe
#'   `postgres_school_profile_reference_repository`.
#' @param rows data.frame longo (`scope`, `chave`, `indicador`, `valor`,
#'   `n_escolas`).
#' @param nu_ano_censo ano do censo das referências.
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `nu_ano_censo`, `rows` e `table`.
#'
#' @export
persist_school_profile_reference.postgres_school_profile_reference_repository <- function(
  repository,
  rows,
  nu_ano_censo,
  output_schema = "analytics",
  ...
) {
  if (!is.data.frame(rows)) {
    stop("rows deve ser um data.frame")
  }
  if (nrow(rows) == 0) {
    return(list(persisted = FALSE, nu_ano_censo = as.integer(nu_ano_censo), rows = 0L))
  }

  expected <- c("scope", "chave", "indicador", "valor", "n_escolas")
  missing <- setdiff(expected, names(rows))
  if (length(missing) > 0) {
    stop(sprintf("rows sem colunas: %s", paste(missing, collapse = ", ")))
  }

  con <- repository$con
  .ensure_school_profile_reference_table(con, output_schema)

  # UPSERT set-based: materializa as linhas numa tabela temporária (COPY) e
  # insere a partir dela. `dbExecute` com `unnest` não funciona porque o
  # RPostgres exige parâmetro escalar (não vetorial).
  tmp <- paste0("tmp_profile_ref_", Sys.getpid())
  tmp_q <- DBI::dbQuoteIdentifier(con, tmp)
  DBI::dbWriteTable(
    con, tmp,
    rows[, c("scope", "chave", "indicador", "valor", "n_escolas")],
    temporary = TRUE, overwrite = TRUE
  )
  on.exit(
    tryCatch(DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", tmp_q)), error = function(e) NULL),
    add = TRUE
  )

  upsert_sql <- sprintf(
    "INSERT INTO %s.%s (nu_ano_censo, scope, chave, indicador, valor, n_escolas, updated_at)
     SELECT $1, scope, chave, indicador, valor, n_escolas, NOW()
       FROM %s
     ON CONFLICT (nu_ano_censo, scope, chave, indicador) DO UPDATE SET
       valor = EXCLUDED.valor,
       n_escolas = EXCLUDED.n_escolas,
       updated_at = NOW();",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_REFERENCE_TABLE),
    tmp_q
  )

  DBI::dbExecute(con, upsert_sql, params = list(as.integer(nu_ano_censo)))

  list(
    persisted = TRUE,
    nu_ano_censo = as.integer(nu_ano_censo),
    rows = nrow(rows),
    table = paste0(output_schema, ".", SCHOOL_PROFILE_REFERENCE_TABLE)
  )
}

#' Lê as referências comparativas de um ano
#'
#' @param repository objeto da classe
#'   `postgres_school_profile_reference_repository`.
#' @param nu_ano_censo ano do censo.
#' @param scopes vetor de escopos (`brasil`, `rede`, `municipio`) ou
#'   `NULL` para todos.
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return data.frame (`scope`, `chave`, `indicador`, `valor`,
#'   `n_escolas`) — vazio quando a tabela ainda não existe.
#'
#' @export
read_school_profile_reference <- function(repository, nu_ano_censo, scopes = NULL, ...) {
  UseMethod("read_school_profile_reference")
}

#' @export
read_school_profile_reference.postgres_school_profile_reference_repository <- function(
  repository,
  nu_ano_censo,
  scopes = NULL,
  output_schema = "analytics",
  ...
) {
  con <- repository$con

  table_ok <- tryCatch(
    DBI::dbGetQuery(
      con,
      "SELECT count(*) AS n FROM information_schema.tables
        WHERE table_schema = $1 AND table_name = $2",
      params = list(output_schema, SCHOOL_PROFILE_REFERENCE_TABLE)
    )$n,
    error = function(e) 0
  )
  if (!isTRUE(table_ok > 0)) {
    return(data.frame(
      scope = character(0), chave = character(0), indicador = character(0),
      valor = numeric(0), n_escolas = integer(0), stringsAsFactors = FALSE
    ))
  }

  sql <- sprintf(
    "SELECT scope, chave, indicador, valor, n_escolas
       FROM %s.%s
      WHERE nu_ano_censo = $1",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_REFERENCE_TABLE)
  )

  if (!is.null(scopes) && length(scopes) > 0) {
    sql <- paste0(sql, " AND scope = ANY(string_to_array($2, ','))")
    params <- list(as.integer(nu_ano_censo), paste(scopes, collapse = ","))
  } else {
    params <- list(as.integer(nu_ano_censo))
  }

  DBI::dbGetQuery(con, sql, params = params)
}

#' Garante a tabela de referências do perfil
#'
#' @keywords internal
.ensure_school_profile_reference_table <- function(con, output_schema) {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, output_schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       nu_ano_censo INTEGER NOT NULL,
       scope        TEXT NOT NULL,
       chave        TEXT NOT NULL,
       indicador    TEXT NOT NULL,
       valor        DOUBLE PRECISION,
       n_escolas    INTEGER,
       updated_at   TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (nu_ano_censo, scope, chave, indicador)
     );",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_REFERENCE_TABLE)
  ))
}