# R/model/datasource/postgres_school_evolution_source.R
#
# DataSource Postgres da EVOLUÇÃO da escola (issue #110).
#
# Lê duas fontes históricas já existentes:
#   - clean.ideb_notas_escolas      -> IDEB observado por ano/etapa;
#   - clean.inep_notas_desagregadas -> notas SAEB por ano.
#
# `co_entidade` entra SEMPRE como bind ($1). Quando a escola existe mas
# não tem histórico, devolve série vazia (resposta válida).

#' Carrega um `SchoolEvolutionModel` a partir de uma fonte
#'
#' Generic S3.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros da implementação.
#'
#' @return Objeto da classe `school_evolution_model`.
#'
#' @export
load_school_evolution <- function(source, ...) {
  UseMethod("load_school_evolution")
}

#' Carrega a evolução da escola a partir do Postgres
#'
#' @param source objeto da classe `postgres_source`.
#' @param co_entidade código INEP da escola (8 dígitos).
#' @param schema schema onde os dados vivem (default: "clean").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `school_evolution_model`.
#'
#' @export
load_school_evolution.postgres_source <- function(
  source,
  co_entidade,
  schema = "clean",
  ...
) {
  con <- source$con
  co_entidade <- as.character(co_entidade)

  if (is.na(co_entidade) || !grepl("^[0-9]{8}$", co_entidade)) {
    stop_invalid_parameter(sprintf("co_entidade inválido: %s", co_entidade))
  }

  DBI::dbExecute(con, "SET client_encoding = 'UTF8'")
  schema_q <- DBI::dbQuoteIdentifier(con, schema)

  # Identificação (e existência) da escola — ano mais recente.
  info <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT co_entidade, no_entidade, co_municipio, no_municipio, sg_uf, tp_dependencia
         FROM %s.censo_escolas
        WHERE co_entidade = $1
        ORDER BY nu_ano_censo DESC
        LIMIT 1",
      schema_q
    ),
    params = list(co_entidade)
  )
  if (nrow(info) == 0) {
    stop_invalid_dataset(sprintf("Escola não encontrada: %s", co_entidade))
  }

  ideb <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT ano, etapa, ideb_observado
         FROM %s.ideb_notas_escolas
        WHERE id_escola = $1
        ORDER BY ano, etapa",
      schema_q
    ),
    params = list(co_entidade)
  )

  saeb <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT ano, nota_mat, nota_por, nota_media
         FROM %s.inep_notas_desagregadas
        WHERE id_escola = $1
        ORDER BY ano",
      schema_q
    ),
    params = list(co_entidade)
  )

  long <- .school_evolution_bind(ideb, saeb)

  rede <- "Outra"
  if (!is.na(info$tp_dependencia[1])) {
    rede <- switch(as.character(info$tp_dependencia[1]),
      "1" = "Federal", "2" = "Estadual", "3" = "Municipal", "4" = "Privada",
      "Outra"
    )
  }

  new_school_evolution_model(
    data = long,
    metadata = list(
      co_entidade = co_entidade,
      no_entidade = as.character(info$no_entidade[1]),
      co_municipio = info$co_municipio[1],
      no_municipio = as.character(info$no_municipio[1]),
      sg_uf = as.character(info$sg_uf[1]),
      rede = rede
    )
  )
}

#' Monta a série longa a partir dos dois resultados (puro, testável)
#'
#' @keywords internal
.school_evolution_bind <- function(ideb, saeb) {
  parts <- list()

  if (nrow(ideb) > 0) {
    parts[[length(parts) + 1]] <- data.frame(
      indicador = "ideb_observado",
      label = unname(EVOLUTION_LABELS[["ideb_observado"]]),
      ano = as.integer(ideb$ano),
      etapa = as.character(ideb$etapa),
      valor = suppressWarnings(as.numeric(ideb$ideb_observado)),
      stringsAsFactors = FALSE
    )
  }

  if (nrow(saeb) > 0) {
    saeb_defs <- list(
      saeb_media = "nota_media",
      saeb_matematica = "nota_mat",
      saeb_portugues = "nota_por"
    )
    for (ind in names(saeb_defs)) {
      col <- saeb_defs[[ind]]
      parts[[length(parts) + 1]] <- data.frame(
        indicador = ind,
        label = unname(EVOLUTION_LABELS[[ind]]),
        ano = as.integer(saeb$ano),
        etapa = NA_character_,
        valor = suppressWarnings(as.numeric(saeb[[col]])),
        stringsAsFactors = FALSE
      )
    }
  }

  if (length(parts) == 0) {
    return(data.frame(
      indicador = character(0), label = character(0), ano = integer(0),
      etapa = character(0), valor = numeric(0), stringsAsFactors = FALSE
    ))
  }

  long <- do.call(rbind, parts)
  long <- long[!is.na(long$valor), , drop = FALSE]
  long[order(long$indicador, long$ano, long$etapa), , drop = FALSE]
}