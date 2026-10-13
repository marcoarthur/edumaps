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
#' @param x Objeto `censo_dictionary`.
#' @param ... Repassado ao método de `data.frame`.
#' @param n Reservado (compatibilidade).
#' @return `x`, invisível.
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
#' @param object Objeto `censo_dictionary`.
#' @param ... Ignorado.
#' @return `data.frame` com uma linha por tabela.
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
#' @param dict Objeto `censo_dictionary`.
#' @param table Tabela qualificada (ex.: `"clean.censo_escolas"`).
#' @param column Nome da coluna.
#' @return Lista nomeada `codigo -> rótulo` ou `NULL`.
#' @export
censo_dict_domain <- function(dict, table, column) {
  stopifnot(inherits(dict, "censo_dictionary"))
  row <- dict[dict$table_name == table & dict$column_name == column, ]
  if (nrow(row) == 0) return(NULL)
  row$value_domain[[1]]
}

#' Verificar se há colunas/códigos novos não documentados
#'
#' Confere os dados reais do Censo contra o dicionário canônico. Útil em
#' teste/CI: `ok` só é `TRUE` quando não há nenhuma violação.
#'
#' Quando o banco tem a função `clean.censo_dict_violacoes()` (migration
#' `censo_data_dictionary_inep`), ela é a fonte: devolve colunas reais fora
#' do dicionário (`coluna_sem_dicionario`), códigos fora do `value_domain`
#' (`codigo_fora_do_dominio`) e binárias `in_*` fora de {0,1}
#' (`binaria_invalida`).
#'
#' Sem a função (banco antigo), cai num fallback que só confere a estrutura:
#' colunas reais (por `table_schema` + `table_name`) ausentes do dicionário
#' (`coluna_sem_dicionario`), colunas `tp_*` sem `value_domain`
#' (`sem_dominio`; as `in_*` são binárias e não exigem domínio) e tabelas
#' pedidas que não existem no banco (`tabela_ausente`). O fallback não
#' confere códigos.
#'
#' @param con Conexão DBI.
#' @param tables Vetor de tabelas qualificadas (default: as 4 tabelas censo).
#' @return Lista com:
#'   \itemize{
#'     \item `ok`: `TRUE` se e somente se não há violações;
#'     \item `violacoes`: `data.frame(tipo, tabela, coluna, valor, n)`;
#'     \item `missing_cols`: `"tabela.coluna"` sem dicionário;
#'     \item `missing_domains`: `"tabela.coluna"` sem domínio ou com código
#'       fora dele;
#'     \item `fonte`: `"funcao"` ou `"fallback"`.
#'   }
#' @export
censo_dict_validate <- function(con, tables = NULL) {
  tables <- tables %||% CENSO_DICT_TABLES
  invalid <- setdiff(tables, CENSO_DICT_TABLES)
  if (length(invalid) > 0) {
    stop("Tabelas não reconhecidas: ", paste(invalid, collapse = ", "),
         ". Válidas: ", paste(CENSO_DICT_TABLES, collapse = ", "))
  }

  if (censo_dict_has_violacoes_fn(con)) {
    violacoes <- censo_dict_violacoes_fn(con, tables)
    fonte <- "funcao"
  } else {
    violacoes <- censo_dict_violacoes_fallback(con, tables)
    fonte <- "fallback"
  }

  chave <- paste(violacoes$tabela, violacoes$coluna, sep = ".")
  list(
    ok = nrow(violacoes) == 0,
    violacoes = violacoes,
    missing_cols = unique(chave[violacoes$tipo %in% c("coluna_sem_dicionario", "tabela_ausente")]),
    missing_domains = unique(chave[violacoes$tipo %in% c("sem_dominio", "codigo_fora_do_dominio",
                                                         "binaria_invalida")]),
    fonte = fonte
  )
}

# Tabelas do Censo cobertas pelo dicionário canônico.
CENSO_DICT_TABLES <- c("clean.censo_escolas", "clean.censo_matriculas",
                       "clean.censo_docentes", "clean.censo_gestor")

# data.frame de violações vazio, no formato de clean.censo_dict_violacoes().
censo_dict_violacoes_vazio <- function() {
  data.frame(tipo = character(), tabela = character(), coluna = character(),
             valor = character(), n = numeric(), stringsAsFactors = FALSE)
}

# Qualifica nomes de tabela sem schema com 'clean.'.
censo_dict_qualify <- function(x) {
  x <- as.character(x)
  ifelse(grepl(".", x, fixed = TRUE), x, paste0("clean.", x))
}

#' A função clean.censo_dict_violacoes() existe no banco?
#' @keywords internal
censo_dict_has_violacoes_fn <- function(con) {
  res <- DBI::dbGetQuery(
    con,
    "SELECT to_regprocedure('clean.censo_dict_violacoes()') IS NOT NULL AS existe"
  )
  nrow(res) == 1 && isTRUE(as.logical(res$existe[[1]]))
}

#' Violações via clean.censo_dict_violacoes(), filtradas pelas tabelas pedidas
#' @keywords internal
censo_dict_violacoes_fn <- function(con, tables) {
  v <- DBI::dbGetQuery(
    con,
    "SELECT tipo, tabela, coluna, valor, n FROM clean.censo_dict_violacoes()"
  )
  if (nrow(v) == 0) return(censo_dict_violacoes_vazio())
  v$tabela <- censo_dict_qualify(v$tabela)
  v$valor <- as.character(v$valor)
  v$n <- as.numeric(v$n)
  v <- v[v$tabela %in% tables, c("tipo", "tabela", "coluna", "valor", "n"), drop = FALSE]
  rownames(v) <- NULL
  v
}

#' Violações estruturais quando a função SQL não existe (banco antigo)
#' @keywords internal
censo_dict_violacoes_fallback <- function(con, tables) {
  partes <- strsplit(tables, ".", fixed = TRUE)
  pares <- vapply(partes, function(p) {
    sprintf("(%s, %s)",
            DBI::dbQuoteString(con, p[[1]]), DBI::dbQuoteString(con, p[[2]]))
  }, character(1))

  # Colunas reais: casar schema E nome da tabela (nunca o nome qualificado
  # contra information_schema.table_name).
  sql <- sprintf("
    SELECT table_schema, table_name, column_name
    FROM information_schema.columns
    WHERE (table_schema, table_name) IN (%s)
  ", paste(pares, collapse = ", "))
  real <- DBI::dbGetQuery(con, sql)
  real_tab <- paste(real$table_schema, real$table_name, sep = ".")

  dict <- suppressWarnings(censo_dictionary(con, tables = tables, include_domain = TRUE))

  out <- list()

  ausentes <- setdiff(tables, real_tab)
  if (length(ausentes) > 0) {
    out$ausentes <- data.frame(tipo = "tabela_ausente", tabela = ausentes,
                               coluna = NA_character_, valor = NA_character_,
                               n = NA_real_, stringsAsFactors = FALSE)
  }

  dict_keys <- paste(dict$table_name, dict$column_name, sep = ".")
  real_keys <- paste(real_tab, real$column_name, sep = ".")
  sem_dict <- !(real_keys %in% dict_keys)
  if (any(sem_dict)) {
    out$sem_dict <- data.frame(tipo = "coluna_sem_dicionario",
                               tabela = real_tab[sem_dict],
                               coluna = real$column_name[sem_dict],
                               valor = NA_character_, n = NA_real_,
                               stringsAsFactors = FALSE)
  }

  # Só tp_* exigem domínio; in_* são binárias (0/1) por convenção do INEP.
  if (nrow(dict) > 0 && "value_domain" %in% names(dict)) {
    sem_dom <- grepl("^tp_", dict$column_name) &
      vapply(dict$value_domain, function(v) is.null(v) || length(v) == 0, logical(1))
    if (any(sem_dom)) {
      out$sem_dom <- data.frame(tipo = "sem_dominio",
                                tabela = dict$table_name[sem_dom],
                                coluna = dict$column_name[sem_dom],
                                valor = NA_character_, n = NA_real_,
                                stringsAsFactors = FALSE)
    }
  }

  if (length(out) == 0) return(censo_dict_violacoes_vazio())
  v <- do.call(rbind, unname(out))
  rownames(v) <- NULL
  v
}