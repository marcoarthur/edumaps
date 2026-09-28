# R/model/datasource/postgres_school_profile_source.R
#
# DataSource Postgres que monta o `school_profile_model` (issue #105).
#
# Faz uma query agregada (uma passada sobre a população do Censo mais
# recente) que devolve, numa única statement: a linha da escola, os
# agregados comparativos (município / rede / Brasil) e — quando há
# cluster persistido — os quartis (p25/p50/p75 + média) do cluster a que
# a escola pertence. Com isso a análise pura não faz I/O e a payload fica
# pronta para o frontend.
#
# Quando a escola NÃO tem `cluster_id` persistido em
# `clean.school_indicators` (coluna criada dinamicamente pelo job de
# clustering), o perfil cai num cluster calculado on-the-fly, RESTRITO AO
# MUNICÍPIO (decisão de escopo do ciclo), marcando
# `cluster_source = "fallback_kmeans"`. O mesmo vale para os peers: se
# `analytics.similarity_pairs` não tiver pares para a escola, eles são
# calculados por Gower dentro do município (`peers_source = "gower_municipio"`).
#
# `co_entidade` e todos os parâmetros de usuário entram SEMPRE como binds
# ($1/$2/$3) — nunca interpolados. Os nomes de indicador vêm de um
# whitelist fechado interno (`.profile_indicator_exprs`).

PROFILE_INDICATORS <- c(
  "prop_licenciatura",
  "prop_mestrado",
  "prop_doutorado",
  "prop_efetivos",
  "prop_sem_especializacao",
  "ratio_aluno_docente",
  "ideb_observado",
  "nota_media",
  "inse"
)

PROFILE_LABELS <- c(
  prop_licenciatura       = "Docentes com licenciatura",
  prop_mestrado           = "Docentes com mestrado",
  prop_doutorado          = "Docentes com doutorado",
  prop_efetivos           = "Docentes efetivos (concursados)",
  prop_sem_especializacao = "Docentes sem especialização",
  ratio_aluno_docente     = "Relação aluno/docente",
  ideb_observado          = "IDEB observado",
  nota_media              = "Nota média (SAEB)",
  inse                    = "INSE (nível socioeconômico)"
)

#' Expressões SQL (whitelist fechado) de cada indicador do perfil
#'
#' @keywords internal
.profile_indicator_exprs <- function() {
  c(
    prop_licenciatura       = "(d.qt_doc_bas_esco_sup_grad_licen::float8 / NULLIF(d.qt_doc_bas, 0))",
    prop_mestrado           = "(d.qt_doc_bas_esco_sup_pos_mestra::float8 / NULLIF(d.qt_doc_bas, 0))",
    prop_doutorado          = "(d.qt_doc_bas_esco_sup_pos_douto::float8 / NULLIF(d.qt_doc_bas, 0))",
    prop_efetivos           = "(d.qt_doc_bas_vinculo_concur::float8 / NULLIF(d.qt_doc_bas, 0))",
    prop_sem_especializacao = "(d.qt_doc_bas_espec_nenhum::float8 / NULLIF(d.qt_doc_bas, 0))",
    ratio_aluno_docente     = "(m.qt_mat_bas::float8 / NULLIF(d.qt_doc_bas, 0))",
    ideb_observado          = "i.ideb_observado",
    nota_media              = "i.nota_media",
    inse                    = "s.media_inse"
  )
}

#' Templates dos sinais de atenção (avançam para a análise pura)
#'
#' Regra v1 (fiel ao issue #105): atencao = escola no quartil inferior
#' do cluster. Refinamento por direção do indicador (alguns são "quanto
#' menor, melhor") fica documentado como evolução futura.
#'
#' @keywords internal
.school_profile_flags_meta <- function() {
  inds <- PROFILE_INDICATORS
  code <- c(
    "prop_licenciatura_baixo", "prop_mestrado_baixo", "prop_doutorado_baixo",
    "prop_efetivos_baixo", "prop_sem_especializacao_alta",
    "ratio_aluno_docente_alta", "ideb_observado_baixo", "nota_media_baixo",
    "inse_baixo"
  )
  msg <- c(
    "Proporção de docentes com licenciatura no quartil inferior do cluster",
    "Proporção de docentes com mestrado no quartil inferior do cluster",
    "Proporção de docentes com doutorado no quartil inferior do cluster",
    "Proporção de docentes efetivos no quartil inferior do cluster",
    "Proporção de docentes sem especialização no quartil superior do cluster",
    "Relação aluno/docente no quartil inferior do cluster",
    "IDEB observado no quartil inferior do cluster",
    "Nota média (SAEB) no quartil inferior do cluster",
    "INSE no quartil inferior do cluster"
  )
  data.frame(
    indicador = inds,
    codigo = code,
    severidade = "media",
    mensagem = msg,
    stringsAsFactors = FALSE
  )
}

#' Carrega um `SchoolProfileModel` a partir de uma fonte
#'
#' Generic S3 para carregar o modelo semântico de perfil de escola.
#'
#' @param source objeto DataSource.
#' @param ... parâmetros específicos da implementação da fonte.
#'
#' @return Objeto da classe `school_profile_model`.
#'
#' @export
load_school_profile <- function(source, ...) {
  UseMethod("load_school_profile")
}

#' Corpo da CTE `pop`: uma linha por escola ativa do Censo mais recente,
#' com os 9 indicadores do perfil.
#'
#' @keywords internal
.profile_pop_body <- function(schema_q, include_inactive) {
  inactive <- if (include_inactive) "" else "AND e.tp_situacao_funcionamento = 1"
  exprs <- .profile_indicator_exprs()
  ind_sql <- paste0(
    sprintf("%s AS %s", unname(exprs), names(exprs)),
    collapse = ",\n      "
  )

  sprintf(
    "
    SELECT
      e.co_entidade,
      e.no_entidade,
      e.co_municipio,
      e.no_municipio,
      e.sg_uf,
      e.co_uf,
      e.tp_dependencia,
      e.tp_localizacao,
      %s
    FROM %s.censo_escolas e
    LEFT JOIN %s.censo_docentes d
      ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = e.nu_ano_censo
    LEFT JOIN %s.censo_matriculas m
      ON m.co_entidade = e.co_entidade AND m.nu_ano_censo = e.nu_ano_censo
    LEFT JOIN LATERAL (
      SELECT i.ideb_observado, i.nota_media
      FROM %s.ideb_notas_escolas i
      WHERE i.id_escola = e.co_entidade
      ORDER BY i.ano DESC, i.nota_media DESC
      LIMIT 1
    ) i ON TRUE
    LEFT JOIN %s.inse s
      ON s.id_escola = e.co_entidade
     AND s.nu_ano_saeb = (SELECT max(nu_ano_saeb) FROM %s.inse)
    WHERE e.nu_ano_censo = (SELECT max(nu_ano_censo) FROM %s.censo_escolas)
      %s
  ",
    ind_sql,
    schema_q, schema_q, schema_q, schema_q, schema_q, schema_q, schema_q,
    inactive
  )
}

#' Colunas de agregação média (município/rede/Brasil)
#'
#' @keywords internal
.profile_avg_cols <- function() {
  inds <- PROFILE_INDICATORS
  paste0(sprintf("avg(%s) AS %s", inds, inds), collapse = ",\n      ")
}

#' Colunas de quartis/média do cluster (CTE clus_stats)
#'
#' @keywords internal
.profile_cluster_stat_cols <- function() {
  inds <- PROFILE_INDICATORS
  parts <- character(0)
  for (ind in inds) {
    parts <- c(
      parts,
      sprintf("percentile_cont(0.25) WITHIN GROUP (ORDER BY p.%s) AS p25_%s", ind, ind),
      sprintf("percentile_cont(0.50) WITHIN GROUP (ORDER BY p.%s) AS p50_%s", ind, ind),
      sprintf("percentile_cont(0.75) WITHIN GROUP (ORDER BY p.%s) AS p75_%s", ind, ind),
      sprintf("avg(p.%s) AS media_%s", ind, ind)
    )
  }
  paste0(parts, collapse = ",\n      ")
}

#' Monta a query principal do perfil (escola + agregados [+ cluster])
#'
#' Quando `cluster_cte`/`cluster_select`/`cluster_cross` são informados
#' (cluster persistido), a mesma statement devolve também os quartis do
#' cluster. `co_entidade` é sempre `$1`.
#'
#' @keywords internal
.profile_query_sql <- function(
  schema_q,
  include_inactive,
  cluster_cte = NULL,
  cluster_select = "",
  cluster_cross = ""
) {
  pop_body <- .profile_pop_body(schema_q, include_inactive)
  inds <- PROFILE_INDICATORS

  esc_cols <- paste0(sprintf("s.%s AS esc_%s", inds, inds), collapse = ",\n      ")
  agg_cols <- .profile_avg_cols()

  city_filter <- "co_municipio = (SELECT max(co_municipio) FROM school)"
  rede_filter <- "tp_dependencia = (SELECT max(tp_dependencia) FROM school)"

  scope_union <- sprintf(
    "  SELECT 'municipio' AS scope, count(*) AS n_esc, %s\n  FROM pop WHERE %s\n  UNION ALL\n  SELECT 'rede' AS scope, count(*) AS n_esc, %s\n  FROM pop WHERE %s\n  UNION ALL\n  SELECT 'brasil' AS scope, count(*) AS n_esc, %s\n  FROM pop",
    agg_cols, city_filter, agg_cols, rede_filter, agg_cols
  )

  sprintf(
    "
WITH pop AS MATERIALIZED (
%s
),
school AS (SELECT * FROM pop WHERE co_entidade = $1),
scope_agg AS (
%s
)
%s
SELECT
  s.co_entidade, s.no_entidade, s.co_municipio, s.no_municipio, s.sg_uf,
  s.co_uf, s.tp_dependencia, s.tp_localizacao,
  %s,
  a.scope, a.n_esc,
  %s
  %s
FROM school s
CROSS JOIN scope_agg a
%s
ORDER BY a.scope
",
    pop_body,
    scope_union,
    cluster_cte %||% "",
    esc_cols,
    agg_cols,
    cluster_select,
    cluster_cross
  )
}

#' Verifica se a escola tem `cluster_id` persistido em
#' `clean.school_indicators` (coluna dinâmica do job de clustering).
#'
#' Retorna `NULL` quando não há coluna/tabela/linha — o perfil então
#' cai no fallback.
#'
#' @keywords internal
.school_profile_persisted_cluster <- function(con, schema_q, co_entidade) {
  col_ok <- tryCatch(
    DBI::dbGetQuery(
      con,
      "SELECT count(*) AS n FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2 AND column_name = $3",
      params = list(schema_q_plain(con, schema_q), "school_indicators", "cluster_id")
    )$n,
    error = function(e) 0
  )

  if (!isTRUE(col_ok > 0)) {
    return(NULL)
  }

  rows <- tryCatch(
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT cluster_id, nu_ano_censo
           FROM %s.school_indicators
          WHERE co_entidade = $1
          ORDER BY nu_ano_censo DESC
          LIMIT 1",
        schema_q
      ),
      params = list(co_entidade)
    ),
    error = function(e) data.frame()
  )

  if (nrow(rows) == 0 || is.na(rows$cluster_id[1])) {
    return(NULL)
  }

  list(cluster_id = rows$cluster_id[1], nu_ano_censo = rows$nu_ano_censo[1])
}

#' Nome do schema sem aspas, para a consulta ao information_schema
#'
#' @keywords internal
schema_q_plain <- function(con, schema_q) {
  gsub('"', "", as.character(schema_q))
}

#' Carrega a escola + comparativos do município (fallback de cluster/peers)
#'
#' Retorna um data.frame com `co_entidade`, `no_entidade`,
#' `ideb_observado` e os 9 indicadores, para as escolas ATIVAS do
#' município no Censo mais recente.
#'
#' @keywords internal
.school_profile_municipio_frame <- function(con, schema_q, co_municipio, include_inactive) {
  pop_body <- .profile_pop_body(schema_q, include_inactive)
  inds <- PROFILE_INDICATORS

  sql <- sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT p.co_entidade, p.no_entidade,
       p.ideb_observado,
       %s
FROM pop p
WHERE p.co_municipio = $1
",
    pop_body,
    paste0(sprintf("p.%s", inds), collapse = ",\n       ")
  )

  DBI::dbGetQuery(con, sql, params = list(co_municipio))
}

#' Cluster fallback (kmeans restrito ao município)
#'
#' Quando a escola não tem `cluster_id` persistido, roda kmeans
#' on-the-fly sobre as escolas do MESMO município (decisão de escopo:
#' não clusterizar as 214k escolas do Brasil por chamada). Segue a
#' convenção legada (set.seed(42), nstart=25, scale()).
#'
#' @keywords internal
.school_profile_fallback_cluster <- function(
  frame,
  co_entidade,
  clusters = 4
) {
  inds <- PROFILE_INDICATORS
  valid <- frame[stats::complete.cases(frame[inds]), , drop = FALSE]
  school_row <- valid[as.character(valid$co_entidade) == as.character(co_entidade), , drop = FALSE]

  if (nrow(valid) < 2 || nrow(school_row) == 0) {
    warning(sprintf(
      "[school_profile] fallback kmeans degradado: município sem dados suficientes (n=%d) para a escola %s",
      nrow(valid), co_entidade
    ))
    school_val <- if (nrow(school_row) == 0) rep(NA_real_, length(inds)) else as.numeric(school_row[1, inds])
    stats <- lapply(seq_along(inds), function(k) {
      list(
        p25 = school_val[k], p50 = school_val[k],
        p75 = school_val[k], media = school_val[k]
      )
    })
    names(stats) <- inds
    return(list(
      cluster_id = NA_integer_,
      cluster_label = "Sem cluster (dados insuficientes)",
      cluster_source = "fallback_kmeans",
      cluster_scope = "municipio",
      cluster_size = nrow(school_row),
      cluster_n = nrow(school_row),
      stats = stats
    ))
  }

  k_eff <- max(2L, min(as.integer(clusters), floor(nrow(valid) / 2)))
  x <- as.matrix(valid[inds])
  x_scaled <- scale(x)

  set.seed(42)
  fit <- stats::kmeans(x_scaled, centers = k_eff, nstart = 25)

  valid$cluster_id <- as.integer(fit$cluster)
  sid <- valid$cluster_id[as.character(valid$co_entidade) == as.character(co_entidade)][1]

  members <- valid[valid$cluster_id == sid, , drop = FALSE]

  stats <- lapply(inds, function(col) {
    v <- as.numeric(members[[col]])
    list(
      p25 = as.numeric(stats::quantile(v, 0.25, na.rm = TRUE)),
      p50 = as.numeric(stats::quantile(v, 0.50, na.rm = TRUE)),
      p75 = as.numeric(stats::quantile(v, 0.75, na.rm = TRUE)),
      media = mean(v, na.rm = TRUE)
    )
  })
  names(stats) <- inds

  means <- do.call(rbind, lapply(sort(unique(fit$cluster)), function(ci) {
    colMeans(valid[fit$cluster == ci, inds, drop = FALSE], na.rm = TRUE)
  }))
  rownames(means) <- as.character(sort(unique(fit$cluster)))
  scores <- .cluster_scores(means, inds)
  labels <- .cluster_labels(fit$cluster, scores, concept = "perfil escolar", gender = "f")

  label <- labels$cluster_label[labels$cluster_id == sid]
  if (length(label) == 0 || is.na(label)) label <- sprintf("Cluster %d", sid)

  list(
    cluster_id = sid,
    cluster_label = label,
    cluster_source = "fallback_kmeans",
    cluster_scope = "municipio",
    cluster_size = nrow(members),
    cluster_n = nrow(members),
    stats = stats
  )
}

#' Peers fallback (Gower restrito ao município)
#'
#' Quando `analytics.similarity_pairs` não tem pares para a escola,
#' calcula a distância de Gower sobre o município (reusando
#' `analyze_gower_similarity`) e devolve os top-N vizinhos dentro do
#' threshold de `distance`.
#'
#' @keywords internal
.school_profile_fallback_peers <- function(
  frame,
  co_entidade,
  similarity_threshold = 0.3,
  max_schools = 300
) {
  inds <- PROFILE_INDICATORS
  valid <- frame[stats::complete.cases(frame[inds]), , drop = FALSE]
  if (nrow(valid) < 2) {
    return(data.frame(
      co_entidade = character(0), no_entidade = character(0),
      similarity = numeric(0), ideb_observado = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  school_idx <- which(as.character(valid$co_entidade) == as.character(co_entidade))
  if (length(school_idx) == 0) {
    return(data.frame(
      co_entidade = character(0), no_entidade = character(0),
      similarity = numeric(0), ideb_observado = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Pool limitado (escola garantidamente presente) para manter o
  # custo do daisy controlado mesmo em municípios grandes.
  others <- setdiff(seq_len(nrow(valid)), school_idx)
  others <- head(others, max_schools - 1L)
  pool <- valid[c(school_idx, others), , drop = FALSE]

  m <- new_school_similarity_model(
    data = pool,
    entity_id = "co_entidade",
    features = inds
  )
  res <- analyze_gower_similarity(m, list())
  pairs <- res$data

  sub <- pairs[
    pairs$entity_id_a == as.character(co_entidade) |
      pairs$entity_id_b == as.character(co_entidade),
    ,
    drop = FALSE
  ]
  sub$co_entidade <- ifelse(
    sub$entity_id_a == as.character(co_entidade),
    sub$entity_id_b,
    sub$entity_id_a
  )
  sub <- sub[!is.na(sub$distance) & sub$distance <= similarity_threshold, , drop = FALSE]
  sub <- sub[order(sub$similarity, decreasing = TRUE), , drop = FALSE]
  sub <- utils::head(sub, 10L)

  if (nrow(sub) == 0) {
    return(data.frame(
      co_entidade = character(0), no_entidade = character(0),
      similarity = numeric(0), ideb_observado = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  info <- pool[match(sub$co_entidade, pool$co_entidade), , drop = FALSE]
  data.frame(
    co_entidade = sub$co_entidade,
    no_entidade = as.character(info$no_entidade),
    similarity = round(as.numeric(sub$similarity), 4),
    ideb_observado = as.numeric(info$ideb_observado),
    stringsAsFactors = FALSE
  )
}

#' Carrega um `SchoolProfileModel` a partir do Postgres
#'
#' Implementação de `load_school_profile()` para `postgres_source`.
#'
#' @param source objeto da classe `postgres_source`.
#' @param co_entidade código INEP da escola (8 dígitos).
#' @param schema schema onde os dados do censo vivem (default: "clean").
#' @param include_inactive se `TRUE`, inclui escolas com
#'   `tp_situacao_funcionamento != 1` (default: `FALSE`).
#' @param clusters número de clusters do kmeans de fallback
#'   (default: 4).
#' @param similarity_threshold distância máxima (Gower) para considerar
#'   um par similar (default: 0.3).
#' @param fallback_peer_max limite de escolas do município usadas no
#'   fallback de peers (default: 300).
#' @param ... parâmetros adicionais não utilizados.
#'
#' @return Objeto da classe `school_profile_model`.
#'
#' @export
load_school_profile.postgres_source <- function(
  source,
  co_entidade,
  schema = "clean",
  include_inactive = FALSE,
  clusters = 4,
  similarity_threshold = 0.3,
  fallback_peer_max = 300,
  ...
) {
  con <- source$con
  co_entidade <- as.character(co_entidade)

  if (is.na(co_entidade) || !grepl("^[0-9]{8}$", co_entidade)) {
    stop_invalid_parameter(sprintf("co_entidade inválido: %s", co_entidade))
  }

  if (!is.numeric(similarity_threshold) || similarity_threshold <= 0) {
    stop_invalid_parameter("similarity_threshold deve ser um número positivo")
  }

  DBI::dbExecute(con, "SET client_encoding = 'UTF8'")

  quote_ident <- function(x) DBI::dbQuoteIdentifier(con, x)
  schema_q <- quote_ident(schema)

  persisted <- .school_profile_persisted_cluster(con, schema_q, co_entidade)

  cluster_cte <- cluster_select <- cluster_cross <- NULL
  if (!is.null(persisted)) {
    cluster_cte <- sprintf(
      ",
clus_stats AS (
  SELECT
    (SELECT si.cluster_id FROM %s.school_indicators si
       WHERE si.co_entidade = $1
       ORDER BY si.nu_ano_censo DESC LIMIT 1) AS cluster_id,
    count(*) AS cluster_n,
    %s
  FROM pop p
  JOIN %s.school_indicators si ON si.co_entidade = p.co_entidade
  WHERE si.cluster_id = (SELECT si2.cluster_id FROM %s.school_indicators si2
                            WHERE si2.co_entidade = $1
                            ORDER BY si2.nu_ano_censo DESC LIMIT 1)
)",
      schema_q, .profile_cluster_stat_cols(), schema_q, schema_q
    )
    inds <- PROFILE_INDICATORS
    stat_cols <- unlist(lapply(inds, function(ind) {
      c(
        sprintf("c.p25_%s", ind), sprintf("c.p50_%s", ind),
        sprintf("c.p75_%s", ind), sprintf("c.media_%s", ind)
      )
    }))
    cluster_select <- paste0(
      ",\n  c.cluster_id, c.cluster_n,\n  ",
      paste0(stat_cols, collapse = ",\n  ")
    )
    cluster_cross <- "CROSS JOIN clus_stats"
  }

  sql <- .profile_query_sql(
    schema_q, include_inactive,
    cluster_cte = cluster_cte,
    cluster_select = cluster_select,
    cluster_cross = cluster_cross
  )

  rows <- DBI::dbGetQuery(con, sql, params = list(co_entidade))

  if (nrow(rows) == 0) {
    stop_invalid_dataset(sprintf("Escola não encontrada: %s", co_entidade))
  }

  inds <- PROFILE_INDICATORS
  first <- rows[1, , drop = FALSE]

  school_meta <- list(
    co_entidade = co_entidade,
    no_entidade = first$no_entidade,
    co_municipio = first$co_municipio,
    no_municipio = first$no_municipio,
    sg_uf = first$sg_uf,
    nu_ano_censo = NA_integer_
  )

  # nu_ano_censo é resolvido explicitamente (não vem na query principal)
  ano_row <- DBI::dbGetQuery(
    con,
    sprintf(
      "SELECT max(nu_ano_censo) AS nu_ano_censo FROM %s.censo_escolas WHERE co_entidade = $1",
      schema_q
    ),
    params = list(co_entidade)
  )
  school_meta$nu_ano_censo <- if (nrow(ano_row) == 0 || is.na(ano_row$nu_ano_censo[1])) {
    NA_integer_
  } else {
    as.integer(ano_row$nu_ano_censo[1])
  }

  scope_values <- function(scope_name) {
    r <- rows[rows$scope == scope_name, , drop = FALSE]
    if (nrow(r) == 0) return(rep(NA_real_, length(inds)))
    as.numeric(r[1, inds])
  }

  long <- data.frame(
    indicador = inds,
    escola = as.numeric(first[1, paste0("esc_", inds)]),
    municipio = scope_values("municipio"),
    rede = scope_values("rede"),
    brasil = scope_values("brasil"),
    stringsAsFactors = FALSE
  )

  n_municipio <- rows$n_esc[rows$scope == "municipio"][1]
  n_rede <- rows$n_esc[rows$scope == "rede"][1]
  n_brasil <- rows$n_esc[rows$scope == "brasil"][1]

  # --- Cluster: persistido (via SQL) ou fallback kmeans (município) ----
  cluster_block <- list(
    cluster_id = NA_integer_,
    cluster_label = NA_character_,
    cluster_source = "none",
    cluster_scope = NA_character_,
    cluster_size = NA_integer_
  )

  if (!is.null(persisted)) {
    long$cluster_p25 <- as.numeric(first[1, paste0("p25_", inds)])
    long$cluster_p50 <- as.numeric(first[1, paste0("p50_", inds)])
    long$cluster_p75 <- as.numeric(first[1, paste0("p75_", inds)])
    long$cluster_media <- as.numeric(first[1, paste0("media_", inds)])
    long$cluster_n <- as.integer(first$cluster_n)
    cluster_block <- list(
      cluster_id = as.integer(first$cluster_id),
      cluster_label = NA_character_,
      cluster_source = "persisted",
      cluster_scope = "tabela_school_indicators",
      cluster_size = as.integer(first$cluster_n)
    )
  } else {
    muni_frame <- .school_profile_municipio_frame(
      con, schema_q, first$co_municipio, include_inactive
    )
    fc <- .school_profile_fallback_cluster(muni_frame, co_entidade, clusters = clusters)
    for (ind in inds) {
      st <- fc$stats[[ind]]
      long$cluster_p25[long$indicador == ind] <- st$p25
      long$cluster_p50[long$indicador == ind] <- st$p50
      long$cluster_p75[long$indicador == ind] <- st$p75
      long$cluster_media[long$indicador == ind] <- st$media
    }
    long$cluster_n <- fc$cluster_n
    cluster_block <- list(
      cluster_id = fc$cluster_id,
      cluster_label = fc$cluster_label,
      cluster_source = fc$cluster_source,
      cluster_scope = fc$cluster_scope,
      cluster_size = fc$cluster_size
    )
  }

  long$cluster <- long$cluster_p50

  # --- Peers: similarity_pairs persistido ou Gower no município ----
  peers_source <- "gower_municipio"
  table_ok <- tryCatch(
    DBI::dbGetQuery(
      con,
      "SELECT count(*) AS n FROM information_schema.tables
        WHERE table_schema = $1 AND table_name = $2",
      params = list("analytics", "similarity_pairs")
    )$n,
    error = function(e) 0
  )

  if (isTRUE(table_ok > 0)) {
    peers_rows <- tryCatch(
      DBI::dbGetQuery(
        con,
        sprintf(
          "SELECT
             CASE WHEN sp.entity_1 = $1 THEN sp.entity_2 ELSE sp.entity_1 END AS co_entidade,
             e.no_entidade,
             sp.distance,
             sp.similarity,
             i.ideb_observado
           FROM analytics.similarity_pairs sp
           LEFT JOIN %s.censo_escolas e
             ON e.co_entidade = CASE WHEN sp.entity_1 = $1 THEN sp.entity_2 ELSE sp.entity_1 END
            AND e.nu_ano_censo = (SELECT max(nu_ano_censo) FROM %s.censo_escolas)
           LEFT JOIN LATERAL (
             SELECT i.ideb_observado
             FROM %s.ideb_notas_escolas i
             WHERE i.id_escola = CASE WHEN sp.entity_1 = $1 THEN sp.entity_2 ELSE sp.entity_1 END
             ORDER BY i.ano DESC, i.nota_media DESC
             LIMIT 1
           ) i ON TRUE
           WHERE (sp.entity_1 = $1 OR sp.entity_2 = $1)
             AND sp.distance <= $2
           ORDER BY sp.similarity DESC
           LIMIT 10",
          schema_q, schema_q, schema_q
        ),
        params = list(co_entidade, similarity_threshold)
      ),
      error = function(e) data.frame()
    )
    if (nrow(peers_rows) > 0) {
      peers <- data.frame(
        co_entidade = as.character(peers_rows$co_entidade),
        no_entidade = as.character(peers_rows$no_entidade),
        similarity = round(as.numeric(peers_rows$similarity), 4),
        ideb_observado = as.numeric(peers_rows$ideb_observado),
        stringsAsFactors = FALSE
      )
      peers_source <- "similarity_pairs"
    }
  }

  if (!exists("peers") || nrow(peers) == 0) {
    if (!exists("muni_frame")) {
      muni_frame <- .school_profile_municipio_frame(
        con, schema_q, first$co_municipio, include_inactive
      )
    }
    peers <- .school_profile_fallback_peers(
      muni_frame, co_entidade,
      similarity_threshold = similarity_threshold,
      max_schools = fallback_peer_max
    )
    peers_source <- "gower_municipio"
  }

  metadata <- c(
    school_meta,
    list(
      cluster_id = cluster_block$cluster_id,
      cluster_label = cluster_block$cluster_label,
      cluster_source = cluster_block$cluster_source,
      cluster_scope = cluster_block$cluster_scope,
      cluster_size = cluster_block$cluster_size,
      peers_source = peers_source,
      n_municipio = as.integer(n_municipio),
      n_rede = as.integer(n_rede),
      n_brasil = as.integer(n_brasil),
      similarity_threshold = similarity_threshold
    )
  )

  new_school_profile_model(
    data = long,
    peers = peers,
    flags_meta = .school_profile_flags_meta(),
    metadata = metadata
  )
}