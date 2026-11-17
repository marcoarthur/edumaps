# R/model/datasource/postgres_profile_ideb_etapa.R
#
# IDEB e nota SAEB comparados na MESMA etapa (#483, RN-01).
#
# A escala do SAEB cresce com a série e o IDEB cai (Brasil, 2023: IDEB 5,66
# nos anos iniciais, 4,74 nos finais, 4,26 no ensino médio). Até a #483, as
# médias de comparação do perfil pegavam, de cada escola, a etapa de maior
# nota, e o "Brasil" (5,33) misturava as três. Aqui as médias de uma etapa,
# com o escopo pedido: Brasil, município, rede (dependência), município e
# rede, ou grupo (cluster_id de clean.school_indicators).
#
# A consulta lê só o IDEB e a lista de escolas do Censo (sem docentes nem
# INSE), então é leve o bastante para o request.

# Etapas do IDEB (código da planilha do INEP -> id do produto e texto).
IDEB_ETAPAS <- c(
  fundamental_i = "anos_iniciais",
  fundamental_ii = "anos_finais",
  ensino_medio = "ensino_medio"
)
IDEB_ETAPA_TEXTO <- c(
  fundamental_i = "anos iniciais",
  fundamental_ii = "anos finais",
  ensino_medio = "ensino médio"
)

#' Valida a etapa do IDEB (whitelist fechado); `NULL` se não for uma delas
#'
#' @keywords internal
.ideb_etapa_valida <- function(etapa) {
  if (is.null(etapa) || length(etapa) != 1 || is.na(etapa)) return(NULL)
  etapa <- as.character(etapa)
  if (etapa %in% names(IDEB_ETAPAS)) etapa else NULL
}

#' Média, quartis e escolas do IDEB e da nota SAEB de uma etapa
#'
#' @param etapa código da etapa no IDEB (`fundamental_i`, `fundamental_ii`,
#'   `ensino_medio`).
#' @param scope "brasil", "municipio", "rede", "municipio_rede" ou "cluster".
#' @param chave código do município (municipio, municipio_rede), da
#'   dependência (rede) ou o `cluster_id` (cluster).
#' @param tp_dependencia dependência, só em "municipio_rede" (NULL = todas).
#'
#' @return lista com `ideb` e `nota`, cada uma com `media`, `p25`, `p50`,
#'   `p75` e `n` (escolas com valor), e `ano` (edição do IDEB).
#'
#' @keywords internal
.profile_ideb_etapa_stats <- function(con, schema_q, include_inactive, ano, etapa,
                                      scope = "brasil", chave = NULL,
                                      tp_dependencia = NULL) {
  etapa <- .ideb_etapa_valida(etapa)
  vazio <- list(media = NA_real_, p25 = NA_real_, p50 = NA_real_, p75 = NA_real_, n = 0L)
  if (is.null(etapa)) return(list(ideb = vazio, nota = vazio, ano = NA_integer_))

  inactive <- if (isTRUE(include_inactive)) "" else "AND e.tp_situacao_funcionamento = 1"
  params <- list(as.integer(ano), etapa)
  join_si <- ""
  where <- ""
  if (identical(scope, "municipio")) {
    where <- "AND e.co_municipio = $3"
    params <- c(params, list(as.integer(chave)))
  } else if (identical(scope, "rede")) {
    where <- "AND e.tp_dependencia = $3"
    params <- c(params, list(as.integer(chave)))
  } else if (identical(scope, "municipio_rede")) {
    where <- "AND e.co_municipio = $3"
    params <- c(params, list(as.integer(chave)))
    if (!is.null(tp_dependencia) && !is.na(tp_dependencia)) {
      where <- paste(where, "AND e.tp_dependencia = $4")
      params <- c(params, list(as.integer(tp_dependencia)))
    }
  } else if (identical(scope, "cluster")) {
    join_si <- sprintf("JOIN %s.school_indicators si ON si.co_entidade = e.co_entidade", schema_q)
    where <- "AND si.cluster_id = $3"
    params <- c(params, list(as.integer(chave)))
  }

  stat_cols <- function(col) {
    sprintf(
      "count(%1$s) AS n_%1$s, avg(%1$s) AS media_%1$s,
       percentile_cont(0.25) WITHIN GROUP (ORDER BY %1$s) AS p25_%1$s,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY %1$s) AS p50_%1$s,
       percentile_cont(0.75) WITHIN GROUP (ORDER BY %1$s) AS p75_%1$s",
      col
    )
  }

  sql <- sprintf(
    "
WITH pop AS (
  SELECT DISTINCT ON (i.id_escola) i.id_escola, i.ideb_observado, i.nota_media, i.ano
    FROM %1$s.ideb_notas_escolas i
    JOIN %1$s.censo_escolas e
      ON e.co_entidade = i.id_escola AND e.nu_ano_censo = $1 %2$s
    %3$s
   WHERE i.ano = (SELECT max(ano) FROM %1$s.ideb_notas_escolas)
     AND i.etapa = $2
     %4$s
   ORDER BY i.id_escola, i.nota_media DESC NULLS LAST
)
SELECT max(ano) AS ano, %5$s, %6$s FROM pop
",
    schema_q, inactive, join_si, where, stat_cols("ideb_observado"), stat_cols("nota_media")
  )
  row <- tryCatch(DBI::dbGetQuery(con, sql, params = params), error = function(e) NULL)
  if (is.null(row) || nrow(row) == 0) return(list(ideb = vazio, nota = vazio, ano = NA_integer_))

  pega <- function(col) {
    list(
      media = as.numeric(row[[paste0("media_", col)]][1]),
      p25 = as.numeric(row[[paste0("p25_", col)]][1]),
      p50 = as.numeric(row[[paste0("p50_", col)]][1]),
      p75 = as.numeric(row[[paste0("p75_", col)]][1]),
      n = as.integer(row[[paste0("n_", col)]][1])
    )
  }
  list(ideb = pega("ideb_observado"), nota = pega("nota_media"), ano = as.integer(row$ano[1]))
}

#' IDEB e nota SAEB da escola em cada etapa em que ela tem nota (#483, RN-02)
#'
#' @return data.frame com `etapa`, `etapa_texto`, `ano`, `ideb_observado`,
#'   `nota_media`.
#'
#' @keywords internal
.school_profile_ideb_etapas <- function(con, schema_q, co_entidade) {
  row <- tryCatch(
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT i.etapa, i.ano, i.ideb_observado, i.nota_media
           FROM %s.ideb_notas_escolas i
          WHERE i.id_escola = $1::bigint
            AND i.ano = (SELECT max(ano) FROM %s.ideb_notas_escolas)
            AND (i.ideb_observado IS NOT NULL OR i.nota_media IS NOT NULL)",
        schema_q, schema_q
      ),
      params = list(co_entidade)
    ),
    error = function(e) data.frame()
  )
  if (nrow(row) == 0) {
    return(data.frame(
      etapa = character(0), etapa_texto = character(0), ano = integer(0),
      ideb_observado = numeric(0), nota_media = numeric(0),
      stringsAsFactors = FALSE
    ))
  }
  row <- row[row$etapa %in% names(IDEB_ETAPAS), , drop = FALSE]
  row <- row[order(match(row$etapa, names(IDEB_ETAPAS))), , drop = FALSE]
  data.frame(
    etapa = as.character(row$etapa),
    etapa_texto = unname(IDEB_ETAPA_TEXTO[as.character(row$etapa)]),
    ano = as.integer(row$ano),
    ideb_observado = as.numeric(row$ideb_observado),
    nota_media = as.numeric(row$nota_media),
    stringsAsFactors = FALSE
  )
}
