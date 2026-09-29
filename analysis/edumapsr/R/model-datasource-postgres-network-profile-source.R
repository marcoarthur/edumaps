# R/model/datasource/postgres_network_profile_source.R
#
# DataSource Postgres do PERFIL DA REDE (issue #109, roadmap do #105).
#
# Dado um `codigo_ibge` (e, opcionalmente, `tp_dependencia`), agrega as
# escolas ativas do recorte:
#   - distribuição por cluster (nº de escolas + médias dos indicadores);
#   - média da rede por indicador vs. a referência do Brasil (#107).
#
# Reusa a população/whitelist de indicadores do perfil da escola
# (`.profile_pop_body`, `.profile_avg_cols_alias`) e a referência
# pré-computada (`analytics.school_profile_reference`). `codigo_ibge` entra
# sempre como bind.

#' Carrega um `NetworkProfileModel` a partir de uma fonte
#'
#' Generic S3.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros da implementação.
#'
#' @return Objeto da classe `network_profile_model`.
#'
#' @export
load_network_profile <- function(source, ...) {
  UseMethod("load_network_profile")
}

#' Converte a agregação wide por cluster em formato longo
#'
#' @keywords internal
.network_clusters_long <- function(wide, labels) {
  inds <- PROFILE_INDICATORS
  empty <- data.frame(
    cluster_id = integer(0), cluster_label = character(0), n = integer(0),
    indicador = character(0), label = character(0), media = numeric(0),
    stringsAsFactors = FALSE
  )
  if (nrow(wide) == 0) {
    return(empty)
  }

  do.call(rbind, lapply(seq_len(nrow(wide)), function(i) {
    cid <- wide$cluster_id[i]
    lab <- NA_character_
    if (nrow(labels) > 0 && !is.na(cid)) {
      lab <- labels$cluster_label[match(cid, labels$cluster_id)]
    }
    cluster_label <- if (is.na(cid)) {
      "Sem cluster"
    } else if (is.na(lab)) {
      sprintf("Cluster %d", cid)
    } else {
      lab
    }

    data.frame(
      cluster_id = as.integer(cid),
      cluster_label = cluster_label,
      n = as.integer(wide$n[i]),
      indicador = inds,
      label = unname(PROFILE_LABELS[inds]),
      media = suppressWarnings(as.numeric(wide[i, inds])),
      stringsAsFactors = FALSE
    )
  }))
}

#' Monta o quadro de indicadores da rede vs. Brasil
#'
#' @keywords internal
.network_indicators_df <- function(mean_row, brasil) {
  inds <- PROFILE_INDICATORS
  rede <- suppressWarnings(as.numeric(mean_row[1, inds]))
  names(rede) <- inds
  brasil <- as.numeric(brasil[inds])

  data.frame(
    indicador = inds,
    label = unname(PROFILE_LABELS[inds]),
    rede = rede,
    brasil = brasil,
    variacao = rede - brasil,
    stringsAsFactors = FALSE
  )
}

#' Carrega o perfil da rede a partir do Postgres
#'
#' @param source objeto da classe `postgres_source`.
#' @param codigo_ibge código IBGE do município (7 dígitos).
#' @param tp_dependencia dependência administrativa (1..4) ou `NULL`
#'   para todas.
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas (default: `FALSE`).
#' @param output_schema schema das tabelas pré-computadas (default: "analytics").
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `network_profile_model`.
#'
#' @export
load_network_profile.postgres_source <- function(
  source,
  codigo_ibge,
  tp_dependencia = NULL,
  schema = "clean",
  include_inactive = FALSE,
  output_schema = "analytics",
  ...
) {
  con <- source$con
  codigo_ibge <- as.character(codigo_ibge)

  if (is.na(codigo_ibge) || !grepl("^[0-9]{7}$", codigo_ibge)) {
    stop_invalid_parameter(sprintf("codigo_ibge inválido: %s", codigo_ibge))
  }

  DBI::dbExecute(con, "SET client_encoding = 'UTF8'")
  schema_q <- DBI::dbQuoteIdentifier(con, schema)

  ano <- resolve_censo_ano(con, schema)

  # Identificação do recorte (e existência de escolas no município).
  mun <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT no_municipio, sg_uf
         FROM %s.censo_escolas
        WHERE co_municipio = $1
        ORDER BY nu_ano_censo DESC
        LIMIT 1",
      schema_q
    ),
    params = list(as.integer(codigo_ibge))
  )
  if (nrow(mun) == 0) {
    stop_invalid_dataset(sprintf("Município sem escolas no censo: %s", codigo_ibge))
  }

  if (is.null(tp_dependencia) || is.na(tp_dependencia)) {
    where_extra <- "AND e.co_municipio = $1"
    ano_expr <- "$2"
    params <- list(as.integer(codigo_ibge), as.integer(ano))
    tp_dep <- NA_integer_
  } else {
    where_extra <- "AND e.co_municipio = $1 AND e.tp_dependencia = $2"
    ano_expr <- "$3"
    params <- list(as.integer(codigo_ibge), as.integer(tp_dependencia), as.integer(ano))
    tp_dep <- as.integer(tp_dependencia)
  }

  pop_body <- .profile_pop_body(
    schema_q, include_inactive,
    ano_expr = ano_expr, where_extra = where_extra
  )

  mean_row <- DBI::dbGetQuery(
    con,
    sprintf(
      "
WITH pop AS MATERIALIZED (
%s
)
SELECT count(*) AS n_escolas, %s FROM pop p
",
      pop_body, .profile_avg_cols_alias("p")
    ),
    params = params
  )

  if (mean_row$n_escolas[1] == 0) {
    stop_invalid_dataset(sprintf(
      "Nenhuma escola ativa no recorte (codigo_ibge=%s, tp_dependencia=%s)",
      codigo_ibge, ifelse(is.na(tp_dep), "todas", tp_dep)
    ))
  }

  if (.school_indicators_has_cluster_id(con, schema_q)) {
    clusters_wide <- DBI::dbGetQuery(
      con,
      sprintf(
        "
WITH pop AS MATERIALIZED (
%s
)
SELECT si.cluster_id AS cluster_id, count(*) AS n, %s
  FROM pop p
  LEFT JOIN %s.school_indicators si ON si.co_entidade = p.co_entidade
 GROUP BY si.cluster_id
 ORDER BY si.cluster_id NULLS LAST
",
        pop_body, .profile_avg_cols_alias("p"), schema_q
      ),
      params = params
    )
  } else {
    # Sem clusterização no banco: um único grupo "Sem cluster" com a rede
    # inteira (a análise/rota continuam válidas).
    clusters_wide <- mean_row
    clusters_wide$n <- clusters_wide$n_escolas
    clusters_wide$cluster_id <- NA_integer_
  }

  labels <- tryCatch(
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT DISTINCT cluster_id, cluster_label
           FROM %s.school_indicators
          WHERE cluster_id IS NOT NULL AND cluster_label IS NOT NULL",
        schema_q
      )
    ),
    error = function(e) data.frame(cluster_id = integer(0), cluster_label = character(0))
  )

  # Referência do Brasil (pré-computada no #107; fallback live).
  ref <- tryCatch(
    read_school_profile_reference(
      postgres_school_profile_reference_repository(con),
      ano,
      scopes = "brasil",
      output_schema = output_schema
    ),
    error = function(e) NULL
  )
  brasil <- NULL
  if (is.data.frame(ref) && nrow(ref) > 0) {
    brasil <- stats::setNames(as.numeric(ref$valor), ref$indicador)
  } else {
    live <- .profile_scope_live(con, schema_q, include_inactive, ano, "brasil", "todas")
    brasil <- live$valor
  }

  clusters <- .network_clusters_long(clusters_wide, labels)
  indicadores <- .network_indicators_df(mean_row, brasil)

  new_network_profile_model(
    clusters = clusters,
    indicadores = indicadores,
    metadata = list(
      codigo_ibge = codigo_ibge,
      no_municipio = as.character(mun$no_municipio[1]),
      sg_uf = as.character(mun$sg_uf[1]),
      tp_dependencia = tp_dep,
      nu_ano_censo = ano,
      n_escolas = as.integer(mean_row$n_escolas[1]),
      n_clusters = length(unique(clusters$cluster_id[!is.na(clusters$cluster_id)])),
      n_brasil = if (!is.null(ref) && nrow(ref) > 0) as.integer(ref$n_escolas[1]) else NA_integer_
    )
  )
}