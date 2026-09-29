# R/app/tasks.R
#
# Fachadas de compatibilidade com jobs batch — o que o documento de
# arquitetura chama de "compute_and_save_*() deixa de ser a unidade
# fundamental, passa a ser apenas uma fachada". Pensado pra uma futura
# task batch (Minion no lado Perl, ou um cron chamando `Rscript -e
# 'edumapsAnalytics::compute_and_save_school_chart(...)'`).
#
# O caminho HTTP ao vivo (inst/plumber/endpoints.R) NÃO usa isto — ele
# chama run_analysis()/render_plotly() diretamente e deixa o Perl gravar
# o cache, porque é lá que o cache_key e o whitelist de variáveis já são
# validados por requisição. Esta função é o exemplo de como uma análise
# batch fica no mesmo padrão, agora com PostgresSource + Repository.

#' Calcula um gráfico de indicador escolar e persiste no cache do Postgres
#'
#' @param con conexão DBI ativa
#' @param indicator_id ver INDICATOR_WHITELIST em postgres_source.R
#' @param chart_type "histogram" | "scatter" | "boxplot"
#' @param rede "todas" | "municipal" | "estadual" | "privada"
#' @param municipio_id inteiro ou NULL
#' @param feature nome da feature (coluna `feature` em analytics.chart_cache)
#' @param cache_key chave já calculada (mesmo esquema usado no lado Perl:
#'   SHA-256 de {feature, chart_type, variables, filters} canônico)
#' @export
compute_and_save_school_chart <- function(con, indicator_id, chart_type,
                                           rede = "todas", municipio_id = NULL,
                                           feature = "escola", cache_key) {
  source <- postgres_source(con)
  model <- load_dataset(source, indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)

  parameters <- list(indicator_id = indicator_id, rede = rede, municipio_id = municipio_id)
  result <- run_analysis(chart_type, model, parameters)

  repository <- postgres_repository(con)
  persist_result(result, repository, feature = feature, cache_key = cache_key)

  invisible(result)
}

# ---------------------------------------------------------------------------
# Batch do Perfil da Escola (issue #107 — Fase 2): referências, percentis de
# cluster e perfil por escola. Mesmo contrato das demais `compute_and_save_*`.
# ---------------------------------------------------------------------------

#' Calcula e persiste as referências comparativas do perfil
#'
#' Materializa as médias de Brasil/rede/município em
#' `analytics.school_profile_reference` (UPSERT por ano/escopo/chave/
#' indicador).
#'
#' @param con conexão DBI ativa.
#' @param nu_ano_censo ano do censo (`NULL` resolve o mais recente).
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas.
#' @param output_schema schema de destino (default: "analytics").
#'
#' @return Lista com `persisted`, `nu_ano_censo`, `rows` e `table`.
#'
#' @export
compute_and_save_school_profile_reference <- function(
  con,
  nu_ano_censo = NULL,
  schema = "clean",
  include_inactive = FALSE,
  output_schema = "analytics"
) {
  ano <- if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    resolve_censo_ano(con, schema)
  } else {
    as.integer(nu_ano_censo)
  }

  source <- postgres_source(con)
  rows <- load_school_profile_reference(
    source,
    nu_ano_censo = ano,
    schema = schema,
    include_inactive = include_inactive
  )

  persist_school_profile_reference(
    postgres_school_profile_reference_repository(con),
    rows,
    nu_ano_censo = ano,
    output_schema = output_schema
  )
}

#' Calcula e persiste os percentis por cluster do perfil
#'
#' Materializa p25/p50/p75/média por indicador de cada `cluster_id` em
#' `analytics.school_cluster_profile`.
#'
#' @param con conexão DBI ativa.
#' @param nu_ano_censo ano do censo (`NULL` resolve o mais recente).
#' @param schema schema do censo (default: "clean").
#' @param include_inactive inclui escolas inativas.
#' @param output_schema schema de destino (default: "analytics").
#' @param run_id identificador da execução (procedência).
#'
#' @return Lista com `persisted`, `clusters`, `rows` e `table`.
#'
#' @export
compute_and_save_school_cluster_profile <- function(
  con,
  nu_ano_censo = NULL,
  schema = "clean",
  include_inactive = FALSE,
  output_schema = "analytics",
  run_id = generate_run_id()
) {
  ano <- if (is.null(nu_ano_censo) || is.na(nu_ano_censo)) {
    resolve_censo_ano(con, schema)
  } else {
    as.integer(nu_ano_censo)
  }

  source <- postgres_source(con)
  rows <- load_school_cluster_profile(
    source,
    nu_ano_censo = ano,
    schema = schema,
    include_inactive = include_inactive
  )

  persist_school_cluster_profile(
    postgres_school_cluster_profile_repository(con),
    rows,
    nu_ano_censo = ano,
    run_id = run_id,
    output_schema = output_schema
  )
}

#' Calcula e persiste o perfil de UMA escola
#'
#' Fachada batch do perfil: reusa `load_school_profile()` +
#' `run_school_profile()` + `persist_school_profile()`, com `persist`
#' desligado no endpoint HTTP (quem persiste é este caminho).
#'
#' @param con conexão DBI ativa.
#' @param co_entidade código INEP da escola (8 dígitos).
#' @param schema schema do censo (default: "clean").
#' @param output_schema schema de destino (default: "analytics").
#' @param ... parâmetros repassados a `load_school_profile()`.
#'
#' @return O `analysis_result` do perfil, invisivelmente.
#'
#' @export
compute_and_save_school_profile <- function(
  con,
  co_entidade,
  schema = "clean",
  output_schema = "analytics",
  ...
) {
  co_entidade <- as.character(co_entidade)
  source <- postgres_source(con)

  model <- load_school_profile(
    source,
    co_entidade = co_entidade,
    schema = schema,
    ...
  )
  result <- run_school_profile(model, parameters = list(co_entidade = co_entidade))

  persist_school_profile_result(
    result,
    postgres_school_profile_repository(con),
    output_schema = output_schema
  )

  invisible(result)
}

#' Calcula e persiste o perfil de um LOTE de escolas
#'
#' Resolve as escolas-alvo (ativas, do ano corrente) e materializa o perfil
#' de cada uma. `scope = "pending"` (default) restringe às que ainda não têm
#' perfil materializado para o ano — o que torna a atualização incremental e
#' retomável.
#'
#' @param con conexão DBI ativa.
#' @param scope "pending" | "municipio" | "uf" | "all".
#' @param co_municipio filtro de município (para `scope = "municipio"`).
#' @param sg_uf filtro de UF (para `scope = "uf"`).
#' @param limit máximo de escolas processadas neste lote (default: 500).
#' @param schema schema do censo (default: "clean").
#' @param output_schema schema de destino (default: "analytics").
#' @param store_repository repository de persistência (opcional; default
#'   `postgres_school_profile_repository(con)`).
#'
#' @return Lista com `processed`, `failed`, `targets` e `nu_ano_censo`.
#'
#' @export
compute_and_save_school_profiles <- function(
  con,
  scope = "pending",
  co_municipio = NULL,
  sg_uf = NULL,
  limit = 500,
  schema = "clean",
  output_schema = "analytics",
  store_repository = NULL
) {
  scope <- match.arg(scope, c("pending", "municipio", "uf", "all"))
  limit <- as.integer(limit)

  ano <- resolve_censo_ano(con, schema)
  schema_q <- DBI::dbQuoteIdentifier(con, schema)
  out_schema_q <- DBI::dbQuoteIdentifier(con, output_schema)

  where <- c("e.nu_ano_censo = $1", "e.tp_situacao_funcionamento = 1")
  params <- list(as.integer(ano))

  if (identical(scope, "municipio")) {
    if (is.null(co_municipio)) {
      stop_invalid_parameter("scope=municipio exige co_municipio")
    }
    params <- c(params, list(as.integer(co_municipio)))
    where <- c(where, sprintf("e.co_municipio = $%d", length(params)))
  } else if (identical(scope, "uf")) {
    if (is.null(sg_uf)) {
      stop_invalid_parameter("scope=uf exige sg_uf")
    }
    params <- c(params, list(as.character(sg_uf)))
    where <- c(where, sprintf("e.sg_uf = $%d", length(params)))
  }

  if (identical(scope, "pending")) {
    where <- c(where, sprintf(
      "NOT EXISTS (SELECT 1 FROM %s.school_profile sp
                    WHERE sp.co_entidade = e.co_entidade AND sp.nu_ano_censo = $1)",
      out_schema_q
    ))
  }

  params <- c(params, list(limit))
  sql <- sprintf(
    "SELECT e.co_entidade::text AS co_entidade
       FROM %s.censo_escolas e
      WHERE %s
      ORDER BY e.co_entidade
      LIMIT $%d",
    schema_q,
    paste(where, collapse = " AND "),
    length(params)
  )

  targets <- DBI::dbGetQuery(con, sql, params = params)$co_entidade

  if (is.null(store_repository)) {
    store_repository <- postgres_school_profile_repository(con)
  }

  processed <- 0L
  failed <- character(0)
  for (co in targets) {
    result <- tryCatch(
      compute_and_save_school_profile(
        con, co,
        schema = schema, output_schema = output_schema
      ),
      error = function(e) e
    )
    if (inherits(result, "error")) {
      failed <- c(failed, as.character(co))
    } else {
      processed <- processed + 1L
    }
  }

  list(
    processed = processed,
    failed = failed,
    targets = length(targets),
    nu_ano_censo = ano
  )
}
