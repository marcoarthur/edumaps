# R/repository/postgres_school_cluster_profile.R
#
# Repository PostgreSQL do PERFIL DE CLUSTER (issue #107, Fase 2).
#
# Os percentis (p25/p50/p75) e a média por indicador dentro de cada
# cluster mudam só quando a clusterização roda — não a cada request. Aqui
# são materializados em `analytics.school_cluster_profile` para o endpoint
# ler em vez de recalcular `percentile_cont` sobre o cluster.
#
# A chave é `cluster_id` (o `clean.school_indicators.cluster_id` é a
# atribuição corrente) e `nu_ano_censo`/`run_id` ficam como procedência;
# o leitor só usa a linha cujo ano bate com o censo corrente.

SCHOOL_CLUSTER_PROFILE_TABLE <- "school_cluster_profile"

#' Cria um repository PostgreSQL do perfil de cluster
#'
#' @param con conexão DBI ativa.
#'
#' @return Objeto S3 da classe `postgres_school_cluster_profile_repository`.
#'
#' @export
postgres_school_cluster_profile_repository <- function(con) {
  structure(
    list(con = con),
    class = "postgres_school_cluster_profile_repository"
  )
}

#' Persiste o perfil de cluster em lote
#'
#' Generic S3. `rows` é um data.frame longo com `cluster_id`,
#' `indicador`, `p25`, `p50`, `p75`, `media` e `n`.
#'
#' @param repository objeto Repository.
#' @param rows data.frame longo.
#' @param ... parâmetros específicos da implementação.
#'
#' @return Lista com `persisted`, `clusters`, `rows` e `table`.
#'
#' @export
persist_school_cluster_profile <- function(repository, rows, ...) {
  UseMethod("persist_school_cluster_profile")
}

#' Persiste o perfil de cluster no PostgreSQL (upsert em lote)
#'
#' @param repository objeto da classe
#'   `postgres_school_cluster_profile_repository`.
#' @param rows data.frame longo.
#' @param nu_ano_censo ano do censo de referência.
#' @param run_id identificador da execução batch (procedência).
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Lista com `persisted`, `clusters`, `rows` e `table`.
#'
#' @export
persist_school_cluster_profile.postgres_school_cluster_profile_repository <- function(
  repository,
  rows,
  nu_ano_censo,
  run_id = generate_run_id(),
  output_schema = "analytics",
  ...
) {
  if (!is.data.frame(rows)) {
    stop("rows deve ser um data.frame")
  }
  if (nrow(rows) == 0) {
    return(list(persisted = FALSE, clusters = 0L, rows = 0L))
  }

  expected <- c("cluster_id", "indicador", "p25", "p50", "p75", "media", "n")
  missing <- setdiff(expected, names(rows))
  if (length(missing) > 0) {
    stop(sprintf("rows sem colunas: %s", paste(missing, collapse = ", ")))
  }

  con <- repository$con
  .ensure_school_cluster_profile_table(con, output_schema)

  # UPSERT set-based via tabela temporária (COPY), como no repository de
  # referências — `dbExecute` com vetores não é suportado pelo RPostgres.
  tmp <- paste0("tmp_cluster_profile_", Sys.getpid())
  tmp_q <- DBI::dbQuoteIdentifier(con, tmp)
  DBI::dbWriteTable(
    con, tmp,
    rows[, c("cluster_id", "indicador", "p25", "p50", "p75", "media", "n")],
    temporary = TRUE, overwrite = TRUE
  )
  on.exit(
    tryCatch(DBI::dbExecute(con, sprintf("DROP TABLE IF EXISTS %s", tmp_q)), error = function(e) NULL),
    add = TRUE
  )

  upsert_sql <- sprintf(
    "INSERT INTO %s.%s (run_id, cluster_id, nu_ano_censo, indicador, p25, p50, p75, media, n, updated_at)
     SELECT $1, cluster_id, $2, indicador, p25, p50, p75, media, n, NOW()
       FROM %s
     ON CONFLICT (cluster_id, indicador) DO UPDATE SET
       run_id = EXCLUDED.run_id,
       nu_ano_censo = EXCLUDED.nu_ano_censo,
       p25 = EXCLUDED.p25,
       p50 = EXCLUDED.p50,
       p75 = EXCLUDED.p75,
       media = EXCLUDED.media,
       n = EXCLUDED.n,
       updated_at = NOW();",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_CLUSTER_PROFILE_TABLE),
    tmp_q
  )

  DBI::dbExecute(
    con,
    upsert_sql,
    params = list(as.character(run_id), as.integer(nu_ano_censo))
  )

  list(
    persisted = TRUE,
    clusters = length(unique(rows$cluster_id)),
    rows = nrow(rows),
    table = paste0(output_schema, ".", SCHOOL_CLUSTER_PROFILE_TABLE)
  )
}

#' Lê o perfil de um cluster
#'
#' @param repository objeto da classe
#'   `postgres_school_cluster_profile_repository`.
#' @param cluster_id id do cluster.
#' @param nu_ano_censo ano do censo (a leitura só usa o ano que bate).
#' @param output_schema schema onde a tabela vive (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return data.frame (`indicador`, `p25`, `p50`, `p75`, `media`, `n`,
#'   `run_id`) — vazio quando não há linha para o cluster/ano.
#'
#' @export
read_school_cluster_profile <- function(repository, cluster_id, nu_ano_censo, ...) {
  UseMethod("read_school_cluster_profile")
}

#' @export
read_school_cluster_profile.postgres_school_cluster_profile_repository <- function(
  repository,
  cluster_id,
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
      params = list(output_schema, SCHOOL_CLUSTER_PROFILE_TABLE)
    )$n,
    error = function(e) 0
  )
  if (!isTRUE(table_ok > 0)) {
    return(data.frame(
      indicador = character(0), p25 = numeric(0), p50 = numeric(0),
      p75 = numeric(0), media = numeric(0), n = integer(0),
      run_id = character(0), stringsAsFactors = FALSE
    ))
  }

  DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT indicador, p25, p50, p75, media, n, run_id
         FROM %s.%s
        WHERE cluster_id = $1 AND nu_ano_censo = $2",
      DBI::dbQuoteIdentifier(con, output_schema),
      DBI::dbQuoteIdentifier(con, SCHOOL_CLUSTER_PROFILE_TABLE)
    ),
    params = list(as.integer(cluster_id), as.integer(nu_ano_censo))
  )
}

#' Garante a tabela de perfil de cluster
#'
#' @keywords internal
.ensure_school_cluster_profile_table <- function(con, output_schema) {
  DBI::dbExecute(con, sprintf(
    "CREATE SCHEMA IF NOT EXISTS %s;",
    DBI::dbQuoteIdentifier(con, output_schema)
  ))

  DBI::dbExecute(con, sprintf(
    "CREATE TABLE IF NOT EXISTS %s.%s (
       cluster_id   INTEGER NOT NULL,
       indicador    TEXT NOT NULL,
       run_id       TEXT,
       nu_ano_censo INTEGER,
       p25          DOUBLE PRECISION,
       p50          DOUBLE PRECISION,
       p75          DOUBLE PRECISION,
       media        DOUBLE PRECISION,
       n            INTEGER,
       updated_at   TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (cluster_id, indicador)
     );",
    DBI::dbQuoteIdentifier(con, output_schema),
    DBI::dbQuoteIdentifier(con, SCHOOL_CLUSTER_PROFILE_TABLE)
  ))
}