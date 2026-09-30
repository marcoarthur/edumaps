# R/censo-dictionary.R
#
# Dicionário de dados canônico do Censo Escolar — interface R
# Lê clean.censo_data_dictionary e expõe como data.frame tipado.

#' Dicionário do Censo Escolar
#'
#' Consulta a tabela canônica `clean.censo_data_dictionary` e devolve um
#' `data.frame` com metadados de todas as colunas das tabelas do Censo
#' ingeridas (`censo_escolas`, `censo_matriculas`, `censo_docentes`,
#' `censo_gestor`).
#'
#' @param con Conexão DBI (read-only) ao Postgres.
#' @param tables Vetor de nomes de tabela (ex.: `c("clean.censo_escolas",
#'   "clean.censo_matriculas")`). Se `NULL`, retorna todas as 4 tabelas censo.
#' @param year Ano de referência para filtrar (`year_introduced <= year` E
#'   `(year_deprecated IS NULL OR year_deprecated > year)`). Se `NULL`,
#'   retorna a versão mais recente de cada coluna (maior `year_introduced`
#'   não deprecada).
#' @param include_domain Se `TRUE` (padrão), inclui a coluna `value_domain`
#'   (JSONB parseado como lista). Se `FALSE`, remove para economizar memória.
#' @param include_provenance Se `TRUE`, inclui `source_url`, `source_license`,
#'   `retrieved_at`. Padrão `FALSE` (metadados sensíveis).
#'
#' @return `data.frame` com colunas:
#'   \itemize{
#'     \item `table_name`, `column_name`, `data_type`, `description`
#'     \item `value_domain` (lista nomeada `codigo -> label` ou `NULL`)
#'     \item `year_introduced`, `year_changed`, `year_deprecated`
#'     \item `is_pk`, `is_fk`, `fk_target_table`, `fk_target_column`
#'     \item `source_file`, `source_url` (opcional), `source_license` (opcional)
#'     \item `retrieved_at` (opcional), `notes`
#'   }
#'
#' @export
censo_dictionary <- function(con,
                             tables = NULL,
                             year = NULL,
                             include_domain = TRUE,
                             include_provenance = FALSE) {

  stopifnot(inherits(con, "DBIConnection"))

  base_tables <- c("clean.censo_escolas", "clean.censo_matriculas",
                   "clean.censo_docentes", "clean.censo_gestor")
  tables <- tables %||% base_tables

  # Validar tabelas
  invalid <- setdiff(tables, base_tables)
  if (length(invalid) > 0) {
    stop("Tabelas não reconhecidas: ", paste(invalid, collapse = ", "),
         ". Válidas: ", paste(base_tables, collapse = ", "))
  }

  where_tables <- paste(sprintf("'%s'", tables), collapse = ", ")

  # Query base
  sql <- sprintf("
    SELECT
      table_name,
      column_name,
      data_type,
      description,
      value_domain,
      year_introduced,
      year_changed,
      year_deprecated,
      is_pk,
      is_fk,
      fk_target_table,
      fk_target_column,
      source_file,
      source_url,
      source_license,
      retrieved_at,
      notes
    FROM clean.censo_data_dictionary
    WHERE table_name IN (%s)
  ", where_tables)

  # Filtro de ano
  if (!is.null(year)) {
    stopifnot(is.numeric(year), length(year) == 1, year >= 1995, year <= 2100)
    sql <- paste0(sql, "
      AND year_introduced <= ", year, "
      AND (year_deprecated IS NULL OR year_deprecated > ", year, ")
    ")
  } else {
    # Versão mais recente por (table, column): maior year_introduced não deprecado
    sql <- paste0(sql, "
      AND (year_deprecated IS NULL OR year_deprecated > (
        SELECT COALESCE(MAX(year_introduced), 9999)
        FROM clean.censo_data_dictionary d2
        WHERE d2.table_name = censo_data_dictionary.table_name
          AND d2.column_name = censo_data_dictionary.column_name
      ))
    ")
  }

  sql <- paste0(sql, " ORDER BY table_name, column_name, year_introduced ")

  df <- DBI::dbGetQuery(con, sql)

  if (nrow(df) == 0) {
    warning("Nenhuma linha encontrada para tabelas: ", paste(tables, collapse = ", "))
    return(df)
  }

  # Parse JSONB value_domain -> lista nomeada
  if (include_domain && "value_domain" %in% names(df)) {
    df$value_domain <- lapply(df$value_domain, function(x) {
      if (is.null(x) || is.na(x)) return(NULL)
      if (is.list(x)) return(x)  # já parseado pelo driver
      jsonlite::fromJSON(x, simplifyVector = FALSE)
    })
  } else {
    df$value_domain <- NULL
  }

  # Remover proveniência se não solicitado
  if (!include_provenance) {
    df$source_url <- NULL
    df$source_license <- NULL
    df$retrieved_at <- NULL
  }

  # Tipar colunas lógicas
  df$is_pk <- as.logical(df$is_pk)
  df$is_fk <- as.logical(df$is_fk)

  # Ordenar
  df <- df[order(df$table_name, df$column_name, df$year_introduced), ]
  rownames(df) <- NULL

  class(df) <- c("censo_dictionary", "data.frame")
  df
}

#' Método print para censo_dictionary
#' @export
print.censo_dictionary <- function(x, ..., n = 20) {
  cat(sprintf("<censo_dictionary> %d colunas em %d tabela(s)\n",
              nrow(x), length(unique(x$table_name))))
  if ("value_domain" %in% names(x)) {
    n_dom <- sum(!vapply(x$value_domain, is.null, logical(1)))
    cat(sprintf("  %d colunas com value_domain (enum)\n", n_dom))
  }
  if ("year_changed" %in% names(x)) {
    n_chg <- sum(!is.na(x$year_changed))
    if (n_chg > 0) cat(sprintf("  %d colunas com mudança de código registrada\n", n_chg))
  }
  if ("year_deprecated" %in% names(x)) {
    n_dep <- sum(!is.na(x$year_deprecated))
    if (n_dep > 0) cat(sprintf("  %d colunas deprecadas\n", n_dep))
  }
  NextMethod()
  invisible(x)
}

#' Resumo por tabela
#' @export
summary.censo_dictionary <- function(object, ...) {
  tabs <- unique(object$table_name)
  res <- lapply(tabs, function(t) {
    sub <- object[object$table_name == t, ]
    data.frame(
      table = t,
      n_cols = nrow(sub),
      n_pk = sum(sub$is_pk),
      n_fk = sum(sub$is_fk),
      n_with_domain = sum(!vapply(sub$value_domain %||% list(), is.null, logical(1))),
      n_changed = sum(!is.na(sub$year_changed)),
      n_deprecated = sum(!is.na(sub$year_deprecated)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, res)
}

#' Filtrar dicionário por padrão de nome de coluna
#' @param dict Objeto `censo_dictionary`.
#' @param pattern Regex no `column_name`.
#' @export
censo_dict_filter <- function(dict, pattern) {
  stopifnot(inherits(dict, "censo_dictionary"))
  dict[grepl(pattern, dict$column_name), , drop = FALSE]
}

#' Obter domínio de uma coluna específica
#' @export
censo_dict_domain <- function(dict, table, column) {
  stopifnot(inherits(dict, "censo_dictionary"))
  row <- dict[dict$table_name == table & dict$column_name == column, ]
  if (nrow(row) == 0) return(NULL)
  row$value_domain[[1]]
}

#' Verificar se há colunas/códigos novos não documentados
#'
#' Compara as colunas reais do banco (via information_schema) com o
#' dicionário. Útil para rodar em teste/CI: falha se houver coluna na
#' tabela que não está no dicionário, ou código em tp_*/in_* sem
#' value_domain.
#'
#' @param con Conexão DBI.
#' @param tables Vetor de tabelas (default: 4 tabelas censo).
#' @return `list(ok = logical, missing_cols = character, missing_domains = character)`
#' @export
censo_dict_validate <- function(con, tables = NULL) {
  base_tables <- c("clean.censo_escolas", "clean.censo_matriculas",
                   "clean.censo_docentes", "clean.censo_gestor")
  tables <- tables %||% base_tables

  dict <- censo_dictionary(con, tables = tables, include_domain = TRUE)

  # Colunas reais no banco
  where_tables <- paste(sprintf("'%s'", tables), collapse = ", ")
  sql <- sprintf("
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'clean'
      AND table_name IN (%s)
      AND table_name NOT LIKE 'censo_data_dictionary'
  ", where_tables)
  real <- DBI::dbGetQuery(con, sql)

  # Guard: se não há tabelas, retorna ok
  if (nrow(real) == 0) {
    return(list(ok = TRUE, missing_cols = character(), missing_domains = character()))
  }

  real$table_name <- paste0("clean.", real$table_name)

  dict_keys <- paste(dict$table_name, dict$column_name, sep = ".")
  real_keys <- paste(real$table_name, real$column_name, sep = ".")

  missing <- setdiff(real_keys, dict_keys)

  # Domínios faltando em tp_*/in_*
  dict_tp_in <- dict[grepl("^(tp_|in_)", dict$column_name), ]
  missing_domains <- dict_tp_in[
    vapply(dict_tp_in$value_domain, is.null, logical(1)),
    "table_name", "column_name"
  ]
  missing_domains <- if (nrow(missing_domains) > 0) {
    paste(missing_domains$table_name, missing_domains$column_name, sep = ".")
  } else character()

  list(
    ok = length(missing) == 0 && length(missing_domains) == 0,
    missing_cols = missing,
    missing_domains = missing_domains
  )
}