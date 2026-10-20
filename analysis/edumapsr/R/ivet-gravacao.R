# R/ivet-gravacao.R
#
# Materialização do painel do IVET (#296): `analytics.ivet_escola` guarda o
# resultado vigente da medição nacional, na mesma linha de
# `analytics.ranking_escola` (bloco B) — a **lógica continua só neste
# pacote** (`ivet_medir_nacional()`/`ivet_painel()`), a tabela é artefato de
# entrega para a API. O job Minion `refresh_ivet` chama o endpoint Plumber
# `/ivet/refresh`, que executa `ivet_refresh()`.
#
# Ausência ≠ 0 (#154): `bloco_*`/`ivet` ausentes gravam `NULL` — a gravação
# NUNCA coalesce para 0.
#
# Idempotência: o upsert é por (co_entidade, nu_ano_censo, raio_m,
# dt_snapshot); re rodar o refresh no mesmo dia substitui as linhas do dia,
# e o histórico de dias anteriores permanece (a API lê o snapshot mais
# recente por escola).

#' Dataframe de gravação do painel (função pura)
#'
#' Mapeia o painel (`ivet_painel()`) para as colunas de
#' `analytics.ivet_escola`: `bloco_A..G` → `bloco_a..g`, atributos de
#' proveniência (`formula`, `dataset_version`, `transform_version`) em
#' colunas escalares e os parâmetros da medição (`nu_ano_censo`, `raio_m`,
#' `dt_snapshot`) replicados por linha.
#'
#' @param painel `data.frame` devolvido por `ivet_painel()`.
#' @param nu_ano_censo ano do Censo Escolar da medição.
#' @param raio_m raio da área de influência usado na medição.
#' @param dt_snapshot `Date` da medição (dia do refresh).
#' @return `data.frame` no formato das colunas de `analytics.ivet_escola`.
#' @keywords internal
ivet_gravacao_tabela <- function(painel, nu_ano_censo = 2025L, raio_m = 1000L,
                                 dt_snapshot = Sys.Date()) {
  if (!is.data.frame(painel)) {
    stop("ivet_gravacao_tabela: 'painel' precisa ser um data.frame")
  }
  rotulos <- unname(ivet_blocos())
  nome_coluna <- function(l) paste0("bloco_", l)
  exigidas <- c("co_entidade", "ivet", "publicavel", vapply(rotulos, nome_coluna, character(1)))
  faltando <- setdiff(exigidas, names(painel))
  if (length(faltando) > 0) {
    stop(
      "ivet_gravacao_tabela: colunas ausentes no painel: ",
      paste(faltando, collapse = ", ")
    )
  }
  if (anyNA(painel$publicavel)) {
    stop("ivet_gravacao_tabela: 'publicavel' com NA (o painel sempre decide TRUE/FALSE)")
  }
  if (length(nu_ano_censo) != 1 || is.na(nu_ano_censo)) {
    stop("ivet_gravacao_tabela: 'nu_ano_censo' precisa ser um inteiro")
  }
  if (length(raio_m) != 1 || is.na(raio_m) || raio_m <= 0) {
    stop("ivet_gravacao_tabela: 'raio_m' precisa ser um inteiro positivo")
  }

  n <- nrow(painel)
  # Atributo escalar vira coluna repetida; ausente vira NA (#154).
  escala_chr <- function(x) {
    if (is.null(x)) rep(NA_character_, n) else rep(as.character(x)[[1]], n)
  }
  formula <- attr(painel, "formula")
  if (is.null(formula)) formula <- ivet_versao()

  out <- data.frame(
    co_entidade       = painel$co_entidade,
    nu_ano_censo      = as.integer(nu_ano_censo),
    raio_m            = as.integer(raio_m),
    ivet              = as.numeric(painel$ivet),
    publicavel        = as.logical(painel$publicavel),
    bloco_a           = as.numeric(painel[[nome_coluna(rotulos[[1]])]]),
    bloco_b           = as.numeric(painel[[nome_coluna(rotulos[[2]])]]),
    bloco_c           = as.numeric(painel[[nome_coluna(rotulos[[3]])]]),
    bloco_d           = as.numeric(painel[[nome_coluna(rotulos[[4]])]]),
    bloco_e           = as.numeric(painel[[nome_coluna(rotulos[[5]])]]),
    bloco_f           = as.numeric(painel[[nome_coluna(rotulos[[6]])]]),
    bloco_g           = as.numeric(painel[[nome_coluna(rotulos[[7]])]]),
    formula           = escala_chr(formula),
    dataset_version   = escala_chr(attr(painel, "dataset_version")),
    transform_version = escala_chr(attr(painel, "transform_version")),
    dt_snapshot       = rep(as.Date(dt_snapshot), n),
    stringsAsFactors  = FALSE
  )
  rownames(out) <- NULL
  out
}

#' SQL do upsert em `analytics.ivet_escola` (função pura)
#'
#' Substitui as linhas do mesmo (escola, censo, raio, snapshot) e atualiza
#' `calculado_em` — re rodar o refresh no mesmo dia é idempotente.
#'
#' @param tabela nome qualificado da tabela de destino.
#' @param staging nome da tabela temporária com o dataframe de gravação.
#' @return o comando `INSERT ... ON CONFLICT` como string.
#' @keywords internal
ivet_gravacao_sql <- function(tabela = "analytics.ivet_escola",
                              staging = "tmp_ivet_escola") {
  colunas <- c(
    "co_entidade", "nu_ano_censo", "raio_m", "ivet", "publicavel",
    "bloco_a", "bloco_b", "bloco_c", "bloco_d", "bloco_e", "bloco_f",
    "bloco_g", "formula", "dataset_version", "transform_version",
    "dt_snapshot"
  )
  sprintf(
    paste0(
      "INSERT INTO %s (%s)\n",
      "SELECT %s\n",
      "FROM %s\n",
      "ON CONFLICT (co_entidade, nu_ano_censo, raio_m, dt_snapshot)\n",
      "DO UPDATE SET %s, calculado_em = now()"
    ),
    tabela,
    paste(colunas, collapse = ", "),
    paste(colunas, collapse = ", "),
    staging,
    paste(sprintf("%s = EXCLUDED.%s", setdiff(colunas, "dt_snapshot"),
                  setdiff(colunas, "dt_snapshot")), collapse = ", ")
  )
}

#' Grava o painel do IVET em `analytics.ivet_escola`
#'
#' Função de glue: monta o dataframe (`ivet_gravacao_tabela()`), sobe uma
#' tabela temporária e executa o upsert (`ivet_gravacao_sql()`). Não decide
#' nada — a medição vem pronta de `ivet_painel()`.
#'
#' @param con conexão DBI.
#' @param painel `data.frame` devolvido por `ivet_painel()`.
#' @param nu_ano_censo ano do Censo Escolar da medição.
#' @param raio_m raio da área de influência usado na medição.
#' @param dt_snapshot `Date` da medição (dia do refresh).
#' @return o número de linhas gravadas (inseridas + atualizadas).
#' @export
ivet_gravar_painel <- function(con, painel, nu_ano_censo = 2025L,
                               raio_m = 1000L, dt_snapshot = Sys.Date()) {
  dados <- ivet_gravacao_tabela(
    painel,
    nu_ano_censo = nu_ano_censo,
    raio_m = raio_m,
    dt_snapshot = dt_snapshot
  )
  DBI::dbWriteTable(
    con, "tmp_ivet_escola", dados, temporary = TRUE, overwrite = TRUE
  )
  on.exit(
    try(DBI::dbRemoveTable(con, "tmp_ivet_escola"), silent = TRUE),
    add = TRUE
  )
  DBI::dbExecute(con, ivet_gravacao_sql())
}

#' Mede o IVET nacional e materializa em `analytics.ivet_escola`
#'
#' Orquestração do refresh (#296): `ivet_medir_nacional()` →
#' `ivet_gravar_painel()`. É o que o endpoint Plumber `/ivet/refresh`
#' executa; a lógica de cálculo permanece só no pacote.
#'
#' @param con conexão DBI; por omissão, `analytics_db_connection()`.
#' @param censo_ano ano do Censo Escolar (default 2025).
#' @param raio_m raio da área de influência, em metros (default 1000).
#' @param crime_anos anos de `clean.brazilcrime_municipio` a mediar (E).
#' @param lock_path caminho do `datasets.lock.json` (proveniência).
#' @param dt_snapshot `Date` da medição (default: hoje).
#' @return lista (invisível) com `n`, `n_publicavel`, `n_gravadas`,
#'   `formula` e `dt_snapshot`.
#' @export
ivet_refresh <- function(con = NULL, censo_ano = 2025L, raio_m = 1000L,
                         crime_anos = 2021:2023, lock_path = NULL,
                         dt_snapshot = Sys.Date()) {
  if (is.null(con)) {
    con <- analytics_db_connection()
  }
  painel <- ivet_medir_nacional(
    con = con, censo_ano = censo_ano, raio_m = raio_m,
    crime_anos = crime_anos, lock_path = lock_path
  )
  n_gravadas <- ivet_gravar_painel(
    con, painel,
    nu_ano_censo = censo_ano, raio_m = raio_m, dt_snapshot = dt_snapshot
  )
  invisible(list(
    n            = nrow(painel),
    n_publicavel = sum(painel$publicavel, na.rm = TRUE),
    n_gravadas   = n_gravadas,
    formula      = attr(painel, "formula"),
    dt_snapshot  = as.Date(dt_snapshot)
  ))
}
