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

#' Lê o perfil materializado de uma escola
#'
#' Devolve o payload persistido **apenas** quando o `nu_ano_censo` bate
#' com o ano pedido (nunca serve dado de outro censo). `NULL` quando não
#' há linha/tabela.
#'
#' @param repository objeto da classe
#'   `postgres_school_profile_repository`.
#' @param co_entidade código INEP da escola.
#' @param nu_ano_censo ano do censo corrente.
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `payload`, `nu_ano_censo` e `computed_at`, ou `NULL`.
#'
#' @export
read_school_profile_cache <- function(repository, co_entidade, nu_ano_censo, ...) {
  UseMethod("read_school_profile_cache")
}

#' @export
read_school_profile_cache.postgres_school_profile_repository <- function(
  repository,
  co_entidade,
  nu_ano_censo,
  output_schema = "analytics",
  ...
) {
  con <- repository$con

  table_ok <- tryCatch(
    DBI::dbGetQuery(
      con,
      "SELECT count(*) AS n FROM information_schema.tables
        WHERE table_schema = $1 AND table_name = $2",
      params = list(output_schema, SCHOOL_PROFILE_TABLE)
    )$n,
    error = function(e) 0
  )
  if (!isTRUE(table_ok > 0)) {
    return(NULL)
  }

  row <- tryCatch(
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT profile_data, nu_ano_censo, updated_at
           FROM %s.%s
          WHERE co_entidade = $1 AND nu_ano_censo = $2",
        DBI::dbQuoteIdentifier(con, output_schema),
        DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_TABLE)
      ),
      params = list(as.integer(co_entidade), as.integer(nu_ano_censo))
    ),
    error = function(e) data.frame()
  )

  if (nrow(row) == 0) {
    return(NULL)
  }

  payload <- jsonlite::fromJSON(row$profile_data[1], simplifyVector = FALSE)

  list(
    payload = payload,
    nu_ano_censo = as.integer(row$nu_ano_censo[1]),
    computed_at = as.character(row$updated_at[1])
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

  .ensure_school_profile_flat_view(con, output_schema)
}

#' Cria a view achatada do perfil (para o Assistente do Censo)
#'
#' Achata `indicadores_comparados` do payload em uma linha por
#' (escola, indicador), expondo colunas legíveis ao modelo NL->SQL
#' (issue #111). Leitura de `analytics.school_profile`.
#'
#' @keywords internal
.ensure_school_profile_flat_view <- function(con, output_schema) {
  view <- "school_profile_flat"
  q_schema <- DBI::dbQuoteIdentifier(con, output_schema)
  q_table <- DBI::dbQuoteIdentifier(con, SCHOOL_PROFILE_TABLE)
  q_view <- DBI::dbQuoteIdentifier(con, view)

  DBI::dbExecute(con, sprintf(
    "CREATE OR REPLACE VIEW %s.%s AS
     SELECT
       (sp.profile_data -> 'metadata' ->> 'co_entidade')::bigint  AS co_entidade,
       sp.profile_data -> 'metadata' ->> 'no_entidade'            AS no_entidade,
       (sp.profile_data -> 'metadata' ->> 'co_municipio')::int    AS co_municipio,
       sp.profile_data -> 'metadata' ->> 'no_municipio'           AS no_municipio,
       sp.profile_data -> 'metadata' ->> 'sg_uf'                  AS sg_uf,
       sp.nu_ano_censo                                            AS nu_ano_censo,
       (sp.profile_data -> 'metadata' ->> 'cluster_id')::int      AS cluster_id,
       sp.profile_data -> 'metadata' ->> 'cluster_label'          AS cluster_label,
       sp.profile_data -> 'metadata' ->> 'cluster_source'         AS cluster_source,
       ind.item ->> 'indicador'                                   AS indicador,
       ind.item ->> 'label'                                       AS indicador_label,
       (ind.item ->> 'escola')::double precision                  AS escola,
       (ind.item ->> 'municipio')::double precision               AS municipio,
       (ind.item ->> 'rede')::double precision                    AS rede,
       (ind.item ->> 'brasil')::double precision                  AS brasil,
       (ind.item ->> 'cluster')::double precision                 AS cluster,
       (ind.item ->> 'quartil_no_cluster')::int                   AS quartil_no_cluster,
       (ind.item ->> 'atencao')::boolean                          AS atencao,
       sp.updated_at                                              AS computed_at
     FROM %s.%s sp
     CROSS JOIN LATERAL jsonb_array_elements(
       COALESCE(sp.profile_data -> 'tables' -> 'indicadores_comparados', '[]'::jsonb)
     ) AS ind(item)",
    q_schema, q_view, q_schema, q_table
  ))

  # O Assistente lê com a role somente-leitura `edumaps_leitor`. Grants só
  # valem para objetos criados DEPOIS do `GRANT ALL TABLES`; garantimos o
  # SELECT nesta view (best-effort: a role pode não existir em todo banco).
  tryCatch(
    DBI::dbExecute(con, sprintf(
      "GRANT SELECT ON %s.%s TO edumaps_leitor",
      q_schema, q_view
    )),
    error = function(e) NULL
  )
}