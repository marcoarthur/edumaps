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
# O grupo de referência (#493, regra 5) são as 30 escolas do município de
# CONTEXTO mais parecido (Gower sobre rede, localização, porte, etapas
# oferecidas e INSE), marcando `cluster_source = "contexto_municipio"`. O
# IDEB, a nota e os docentes NÃO formam o grupo: são o que se compara com
# ele. Até a regra 4 o grupo era um k-means sobre os próprios indicadores
# comparados (o IDEB escolhia o grupo; correlação 0,83 entre o IDEB da
# escola e a mediana do grupo em Salvador) ou o `cluster_id` do último
# agrupamento rodado na plataforma. As escolas similares (#495, regra 6) são
# as 10 primeiras da mesma ordem do grupo, no município inteiro, dentro do
# limiar de distância (`peers_source = "contexto_municipio"`). Até a regra 5
# eram um Gower sobre os indicadores comparados, IDEB e nota inclusive, só
# entre as primeiras 299 escolas do município, ou os pares de
# `analytics.similarity_pairs`.
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
  # #522: qt_doc_bas_espec_nenhum é a formação continuada (80h ou mais), não a
  # especialização (pós-graduação). O id do indicador ficou o antigo.
  prop_sem_especializacao = "Docentes sem formação continuada",
  ratio_aluno_docente     = "Relação aluno/docente",
  ideb_observado          = "IDEB observado",
  nota_media              = "Nota média (SAEB)",
  inse                    = "INSE (nível socioeconômico)"
)

# Sentido de cada indicador (#421, AN-02): "maior" = quanto maior, melhor;
# "menor" = quanto menor, melhor. Decide o lado do cluster que gera o sinal
# de atenção. INSE fica "maior": o sinal aponta contexto mais vulnerável.
PROFILE_DIRECAO <- c(
  prop_licenciatura       = "maior",
  prop_mestrado           = "maior",
  prop_doutorado          = "maior",
  prop_efetivos           = "maior",
  prop_sem_especializacao = "menor",
  ratio_aluno_docente     = "menor",
  ideb_observado          = "maior",
  nota_media              = "maior",
  inse                    = "maior"
)

# Versão do perfil gravada no payload (`metadata$regra_sinais`; o nome ficou
# da #421). Perfil materializado com versão anterior deixa de ser servido do
# cache (read_school_profile_cache), e o backend usa o mesmo número na chave
# do seu cache. 1: quartil inferior para todos (#105). 2: sentido do
# indicador e só pior que a mediana (#421). 3: IDEB e nota SAEB rotulados
# com a etapa e o ano da escola (#431). 4: IDEB e nota SAEB comparados na
# mesma etapa da escola, e o IDEB de cada etapa (#483). 5: grupo de
# referência pelo contexto (as 30 escolas do município mais parecidas), o
# INSE sem sinal de atenção e o N de cada indicador (#493). 6: escolas
# similares pelo mesmo contexto do grupo, no município inteiro (#495). 7:
# "sem especialização" passa a "sem formação continuada" no rótulo e no sinal
# (#522).
PROFILE_REGRA_SINAIS <- 7L

# Quantas escolas similares o perfil mostra (#495): as primeiras da ordem
# do grupo de referência, dentro do limiar de distância.
PROFILE_SIMILARES_N <- 10L

# Tamanho do grupo de referência (#493): as K escolas de contexto mais
# parecido no município (o município inteiro, se tiver menos).
PROFILE_GRUPO_K <- 30L

# Indicadores que não geram sinal de atenção (#493, RI-02): o INSE é o
# contexto dos alunos, não algo em que a escola possa agir.
PROFILE_SEM_SINAL <- c("inse")

# Critério do grupo, em texto, para o payload e a tela (#493).
PROFILE_GRUPO_CRITERIO <- paste(
  "As escolas do mesmo município de contexto mais parecido, pela distância de Gower",
  "com o mesmo peso para rede, localização (urbana ou rural), porte (matrículas, em log),",
  "etapas oferecidas (infantil, anos iniciais, anos finais, médio e EJA) e INSE.",
  "O IDEB, a nota SAEB e os indicadores de docentes não entram: são o que se compara."
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
#' Regra v2 (#421): atencao = escola no quartil do lado ruim do cluster,
#' segundo o sentido do indicador (`PROFILE_DIRECAO`), e estritamente pior
#' que a mediana. "Quanto maior, melhor" → quartil inferior; "quanto menor,
#' melhor" → quartil superior.
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
  # #493: o INSE (contexto) não gera sinal; a linha fica fora dos modelos.
  msg <- c(
    "Proporção de docentes com licenciatura no quartil inferior do grupo de referência",
    "Proporção de docentes com mestrado no quartil inferior do grupo de referência",
    "Proporção de docentes com doutorado no quartil inferior do grupo de referência",
    "Proporção de docentes efetivos no quartil inferior do grupo de referência",
    "Proporção de docentes sem formação continuada (80h ou mais) no quartil superior do grupo de referência",
    "Relação aluno/docente no quartil superior do grupo de referência",
    "IDEB observado no quartil inferior do grupo de referência",
    "Nota média (SAEB) no quartil inferior do grupo de referência",
    "INSE no quartil inferior do grupo de referência"
  )
  out <- data.frame(
    indicador = inds,
    codigo = code,
    severidade = "media",
    mensagem = msg,
    stringsAsFactors = FALSE
  )
  out[!out$indicador %in% PROFILE_SEM_SINAL, , drop = FALSE]
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

# Níveis do INSE na classificação do INEP (#497): o texto "Nível I" ...
# "Nível VIII" da coluna `inse_classificacao` vira o número 1 a 8.
INSE_NIVEIS <- c("I", "II", "III", "IV", "V", "VI", "VII", "VIII")

#' Expressão SQL do nível do INSE (1 a 8) a partir do texto do INEP
#'
#' @param col coluna com o texto ("Nível III").
#' @keywords internal
.inse_nivel_sql <- function(col) {
  casos <- paste(sprintf("WHEN 'Nível %s' THEN %d", INSE_NIVEIS, seq_along(INSE_NIVEIS)),
                 collapse = " ")
  sprintf("(CASE %s %s END)::int", col, casos)
}

#' Corpo da CTE `pop`: uma linha por escola ativa do Censo mais recente,
#' com os 9 indicadores do perfil.
#'
#' @keywords internal
.profile_pop_body <- function(schema_q, include_inactive, ano_expr = "$2", where_extra = "",
                              ideb_etapa = NULL) {
  inactive <- if (include_inactive) "" else "AND e.tp_situacao_funcionamento = 1"
  # #483: com a etapa, o IDEB/SAEB de cada escola é o daquela etapa (vazio
  # se a escola não tem nota nela); sem ela, a etapa de maior nota. A etapa
  # vem de um whitelist fechado (.ideb_etapa_valida), por isso entra literal.
  etapa <- .ideb_etapa_valida(ideb_etapa)
  filtro_etapa <- if (is.null(etapa)) "" else sprintf("AND i.etapa = '%s'", etapa)
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
      -- #493: contexto para o grupo de referência
      m.qt_mat_bas::float8 AS ctx_matriculas,
      (COALESCE(e.in_comum_creche, 0) = 1 OR COALESCE(e.in_comum_pre, 0) = 1)::int AS ctx_infantil,
      (COALESCE(e.in_comum_fund_ai, 0) = 1)::int AS ctx_ai,
      (COALESCE(e.in_comum_fund_af, 0) = 1)::int AS ctx_af,
      (COALESCE(e.in_comum_medio_medio, 0) = 1 OR COALESCE(e.in_comum_medio_integrado, 0) = 1
        OR COALESCE(e.in_comum_medio_normal, 0) = 1)::int AS ctx_medio,
      (COALESCE(e.in_comum_eja_fund, 0) = 1 OR COALESCE(e.in_comum_eja_medio, 0) = 1)::int AS ctx_eja,
      -- #497: nível do INSE na classificação do INEP (1 a 8), grupos da rede
      %s AS inse_nivel,
      %s
    FROM %s.censo_escolas e
    LEFT JOIN %s.censo_docentes d
      ON d.co_entidade = e.co_entidade AND d.nu_ano_censo = %s
    LEFT JOIN %s.censo_matriculas m
      ON m.co_entidade = e.co_entidade AND m.nu_ano_censo = %s
    LEFT JOIN (
      SELECT DISTINCT ON (i.id_escola)
        i.id_escola, i.ideb_observado, i.nota_media
      FROM %s.ideb_notas_escolas i
      WHERE i.ano = (SELECT max(ano) FROM %s.ideb_notas_escolas)
        %s
      ORDER BY i.id_escola, i.nota_media DESC
    ) i ON i.id_escola = e.co_entidade
    LEFT JOIN %s.inse s
      ON s.id_escola = e.co_entidade
     AND s.nu_ano_saeb = (SELECT max(nu_ano_saeb) FROM %s.inse)
    WHERE e.nu_ano_censo = %s
      %s
      %s
  ",
    .inse_nivel_sql("s.inse_classificacao"),
    ind_sql,
    schema_q, schema_q, ano_expr, schema_q, ano_expr, schema_q, schema_q, filtro_etapa, schema_q, schema_q, ano_expr,
    inactive,
    where_extra
  )
}

#' Colunas de agregação média (município/rede/Brasil)
#'
#' @keywords internal
.profile_avg_cols <- function() {
  inds <- PROFILE_INDICATORS
  paste0(sprintf("avg(%s) AS %s", inds, inds), collapse = ",\n      ")
}

#' Médias por indicador com alias de tabela (ex.: agregação por cluster)
#'
#' @keywords internal
.profile_avg_cols_alias <- function(alias = "p") {
  inds <- PROFILE_INDICATORS
  paste0(sprintf("avg(%s.%s) AS %s", alias, inds, inds), collapse = ",\n      ")
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

#' Resolve o ano do censo mais recente com um scan de índice
#'
#' Usa `censo_matriculas`, cuja PK tem `nu_ano_censo` como primeira
#' coluna (evita o seq scan de `censo_escolas`, sem índice nesse campo).
#'
#' @keywords internal
resolve_censo_ano <- function(con, schema = "clean") {
  schema_q <- DBI::dbQuoteIdentifier(con, schema)
  row <- DBI::dbGetQuery(
    con,
    sprintf("SELECT max(nu_ano_censo) AS nu_ano_censo FROM %s.censo_matriculas", schema_q)
  )
  if (nrow(row) == 0 || is.na(row$nu_ano_censo[1])) {
    stop_invalid_dataset("Nenhum ano de censo disponível")
  }
  as.integer(row$nu_ano_censo[1])
}

#' Linha única da escola alvo (com seus indicadores)
#'
#' @keywords internal
.school_profile_school_row <- function(con, schema_q, include_inactive, co_entidade, ano,
                                       ideb_etapa = NULL) {
  pop_body <- .profile_pop_body(
    schema_q, include_inactive,
    ano_expr = "$2", where_extra = "AND e.co_entidade = $1", ideb_etapa = ideb_etapa
  )
  sql <- sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT * FROM pop
",
    pop_body
  )
  DBI::dbGetQuery(con, sql, params = list(co_entidade, as.integer(ano)))
}

#' Etapa e ano do IDEB usados no perfil da escola (#431)
#'
#' Mesma regra do `.profile_pop_body`: edição mais recente do IDEB e, com
#' mais de uma etapa, a de maior nota média. Sem IDEB, `NULL` nos dois.
#'
#' @keywords internal
.school_profile_ideb_etapa <- function(con, schema_q, co_entidade) {
  row <- tryCatch(
    DBI::dbGetQuery(
      con,
      sprintf(
        "SELECT i.etapa, i.ano
           FROM %s.ideb_notas_escolas i
          WHERE i.id_escola = $1::bigint
            AND i.ano = (SELECT max(ano) FROM %s.ideb_notas_escolas)
          ORDER BY i.nota_media DESC
          LIMIT 1",
        schema_q, schema_q
      ),
      params = list(co_entidade)
    ),
    error = function(e) data.frame()
  )
  if (nrow(row) == 0) return(list(etapa = NULL, ano = NULL))
  list(etapa = as.character(row$etapa[1]), ano = as.integer(row$ano[1]))
}

#' Média de UM escopo ao vivo (fallback quando falta referência)
#'
#' @keywords internal
.profile_scope_live <- function(con, schema_q, include_inactive, ano, scope, chave) {
  if (identical(scope, "brasil")) {
    where_extra <- ""
    ano_expr <- "$1"
    params <- list(as.integer(ano))
  } else if (identical(scope, "rede")) {
    where_extra <- "AND e.tp_dependencia = $1"
    ano_expr <- "$2"
    params <- list(as.integer(chave), as.integer(ano))
  } else {
    where_extra <- "AND e.co_municipio = $1"
    ano_expr <- "$2"
    params <- list(as.integer(chave), as.integer(ano))
  }

  pop_body <- .profile_pop_body(
    schema_q, include_inactive,
    ano_expr = ano_expr, where_extra = where_extra
  )
  sql <- sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT count(*) AS n_esc, %s FROM pop
",
    pop_body, .profile_avg_cols()
  )
  row <- DBI::dbGetQuery(con, sql, params = params)

  inds <- PROFILE_INDICATORS
  list(
    valor = stats::setNames(as.numeric(row[1, inds]), inds),
    n = as.integer(row$n_esc[1]),
    source = "live"
  )
}

#' Percentis ao vivo de UM cluster (fallback quando falta o perfil)
#'
#' @keywords internal
.profile_cluster_stats_live <- function(con, schema_q, include_inactive, ano, cluster_id) {
  pop_body <- .profile_pop_body(schema_q, include_inactive, ano_expr = "$2")
  sql <- sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT count(*) AS n, %s
  FROM pop p
  JOIN %s.school_indicators si ON si.co_entidade = p.co_entidade
 WHERE si.cluster_id = $1
",
    pop_body, .profile_cluster_stat_cols(), schema_q
  )
  row <- DBI::dbGetQuery(con, sql, params = list(as.integer(cluster_id), as.integer(ano)))
  inds <- PROFILE_INDICATORS

  stats <- lapply(inds, function(ind) {
    list(
      p25 = as.numeric(row[1, paste0("p25_", ind)]),
      p50 = as.numeric(row[1, paste0("p50_", ind)]),
      p75 = as.numeric(row[1, paste0("p75_", ind)]),
      media = as.numeric(row[1, paste0("media_", ind)])
    )
  })
  names(stats) <- inds
  list(stats = stats, n = as.integer(row$n[1]), source = "live", run_id = NA_character_)
}

#' Extrai a referência pré-computada de um escopo/chave
#'
#' @keywords internal
.profile_reference_rows <- function(ref_long, scope, chave) {
  if (is.null(ref_long) || nrow(ref_long) == 0) {
    return(NULL)
  }
  r <- ref_long[
    ref_long$scope == scope & ref_long$chave == as.character(chave),
    ,
    drop = FALSE
  ]
  if (nrow(r) == 0) {
    return(NULL)
  }
  inds <- PROFILE_INDICATORS
  list(
    valor = stats::setNames(as.numeric(r$valor[match(inds, r$indicador)]), inds),
    n = as.integer(r$n_escolas[1]),
    source = "reference"
  )
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
.school_profile_municipio_frame <- function(con, schema_q, co_municipio, include_inactive, ano,
                                            ideb_etapa = NULL) {
  # #483: com a etapa da escola, o IDEB das outras é o da mesma etapa; o
  # grupo e as escolas semelhantes do fallback ficam entre escolas com nota
  # nela.
  pop_body <- .profile_pop_body(
    schema_q, include_inactive,
    ano_expr = "$2", where_extra = "AND e.co_municipio = $1", ideb_etapa = ideb_etapa
  )
  inds <- PROFILE_INDICATORS

  sql <- sprintf(
    "
WITH pop AS MATERIALIZED (
%s
)
SELECT p.co_entidade::text AS co_entidade, p.no_entidade,
       p.ideb_observado,
       p.tp_dependencia, p.tp_localizacao, p.ctx_matriculas,
       p.ctx_infantil, p.ctx_ai, p.ctx_af, p.ctx_medio, p.ctx_eja,
       %s
FROM pop p
WHERE p.co_municipio = $1
",
    pop_body,
    paste0(sprintf("p.%s", inds), collapse = ",\n       ")
  )

  DBI::dbGetQuery(con, sql, params = list(co_municipio, ano))
}

#' Distância de Gower de uma escola contra todas as outras (#493)
#'
#' Sem montar a matriz inteira (São Paulo tem ~7,3 mil escolas): só a linha
#' da escola alvo. Numéricas: |x − y| ÷ amplitude da variável no município.
#' Categóricas: 0 se igual, 1 se diferente. Variável ausente em um dos dois
#' sai da conta daquele par, e o peso é redistribuído.
#'
#' @param alvo data.frame de 1 linha.
#' @param outros data.frame com as mesmas colunas.
#' @param numericas,categoricas nomes das colunas.
#' @param pesos vetor nomeado (default 1 para cada coluna).
#' @return vetor numérico de distâncias em [0, 1] (NA se nada comparável).
#' @keywords internal
.profile_gower_um <- function(alvo, outros, numericas = character(0),
                              categoricas = character(0), pesos = NULL) {
  cols <- c(numericas, categoricas)
  if (is.null(pesos)) pesos <- stats::setNames(rep(1, length(cols)), cols)
  n <- nrow(outros)
  soma <- numeric(n)
  peso <- numeric(n)
  for (col in numericas) {
    todos <- suppressWarnings(as.numeric(c(alvo[[col]], outros[[col]])))
    amp <- diff(range(todos, na.rm = TRUE))
    a <- todos[1]
    o <- todos[-1]
    d <- if (!is.finite(amp) || amp == 0) ifelse(is.na(o), NA_real_, 0) else abs(o - a) / amp
    ok <- !is.na(d) & !is.na(a)
    soma[ok] <- soma[ok] + pesos[[col]] * d[ok]
    peso[ok] <- peso[ok] + pesos[[col]]
  }
  for (col in categoricas) {
    a <- as.character(alvo[[col]])
    o <- as.character(outros[[col]])
    ok <- !is.na(o) & !is.na(a)
    d <- as.numeric(o != a)
    soma[ok] <- soma[ok] + pesos[[col]] * d[ok]
    peso[ok] <- peso[ok] + pesos[[col]]
  }
  out <- soma / peso
  out[peso == 0] <- NA_real_
  out
}

#' Grupo de referência pelo contexto (#493, regra 5)
#'
#' As `k` escolas do município de contexto mais parecido com a escola
#' (`.profile_gower_um`): rede, localização, porte (log das matrículas),
#' etapas oferecidas e INSE, cada dimensão com o mesmo peso (as cinco etapas
#' dividem o peso de uma). O IDEB, a nota SAEB e os docentes não entram.
#' Município com até `k` outras escolas: todas. Os quartis de cada
#' indicador são das escolas do grupo com o dado, e o `n` de cada um também.
#'
#' @param frame data.frame do município (`.school_profile_municipio_frame`).
#' @param co_entidade INEP da escola.
#' @param k tamanho do grupo.
#' @keywords internal
.school_profile_context_group <- function(frame, co_entidade, k = PROFILE_GRUPO_K) {
  inds <- PROFILE_INDICATORS
  frame <- frame[!duplicated(as.character(frame$co_entidade)), , drop = FALSE]
  eh_alvo <- as.character(frame$co_entidade) == as.character(co_entidade)
  vazio <- function(label) {
    stats <- lapply(inds, function(i) list(p25 = NA_real_, p50 = NA_real_, p75 = NA_real_,
                                           media = NA_real_, n = 0L))
    names(stats) <- inds
    list(cluster_id = NA_integer_, cluster_label = label,
         cluster_source = "contexto_municipio", cluster_scope = "municipio",
         cluster_size = 0L, stats = stats)
  }
  if (!any(eh_alvo)) return(vazio("Sem grupo (escola fora do Censo do município)"))
  outros <- frame[!eh_alvo, , drop = FALSE]
  if (nrow(outros) == 0) return(vazio("Sem grupo (única escola do município)"))

  ctx <- function(d) {
    d$ctx_porte <- log1p(suppressWarnings(as.numeric(d$ctx_matriculas)))
    d
  }
  alvo <- ctx(frame[eh_alvo, , drop = FALSE][1, , drop = FALSE])
  outros <- ctx(outros)
  etapas <- c("ctx_infantil", "ctx_ai", "ctx_af", "ctx_medio", "ctx_eja")
  pesos <- c(ctx_porte = 1, inse = 1, tp_dependencia = 1, tp_localizacao = 1,
             stats::setNames(rep(1 / length(etapas), length(etapas)), etapas))
  dist <- .profile_gower_um(
    alvo, outros,
    numericas = c("ctx_porte", "inse"),
    categoricas = c("tp_dependencia", "tp_localizacao", etapas),
    pesos = pesos
  )
  ordem <- order(dist, as.character(outros$co_entidade), na.last = TRUE)
  membros <- outros[utils::head(ordem, k), , drop = FALSE]
  # #495: a ordem do município inteiro, para as escolas similares
  vizinhas <- data.frame(
    co_entidade = as.character(outros$co_entidade[ordem]),
    no_entidade = as.character(outros$no_entidade[ordem]),
    distance = as.numeric(dist[ordem]),
    ideb_observado = suppressWarnings(as.numeric(outros$ideb_observado[ordem])),
    stringsAsFactors = FALSE
  )

  stats <- lapply(inds, function(col) {
    v <- suppressWarnings(as.numeric(membros[[col]]))
    v <- v[!is.na(v)]
    if (length(v) == 0) {
      return(list(p25 = NA_real_, p50 = NA_real_, p75 = NA_real_, media = NA_real_, n = 0L))
    }
    list(
      p25 = as.numeric(stats::quantile(v, 0.25)),
      p50 = as.numeric(stats::quantile(v, 0.50)),
      p75 = as.numeric(stats::quantile(v, 0.75)),
      media = mean(v),
      n = length(v)
    )
  })
  names(stats) <- inds

  list(
    cluster_id = NA_integer_,
    cluster_label = sprintf("%d escolas de contexto mais parecido no município", nrow(membros)),
    cluster_source = "contexto_municipio",
    cluster_scope = "municipio",
    cluster_size = nrow(membros),
    stats = stats,
    vizinhas = vizinhas
  )
}

#' Escolas similares do perfil (#495, regra 6)
#'
#' As primeiras `n` escolas da ordem do grupo de referência
#' (`.school_profile_context_group`): o mesmo contexto (rede, localização,
#' porte, etapas, INSE), no município inteiro, sem o IDEB e a nota SAEB.
#' Só entram as que estão dentro do limiar de distância. Similaridade =
#' 1 − distância de Gower.
#'
#' @param grupo resultado de `.school_profile_context_group`.
#' @param similarity_threshold distância máxima.
#' @param n quantas escolas.
#' @keywords internal
.school_profile_context_peers <- function(grupo, similarity_threshold = 0.3,
                                          n = PROFILE_SIMILARES_N) {
  v <- grupo$vizinhas
  if (is.null(v)) v <- data.frame(co_entidade = character(0), distance = numeric(0))
  v <- v[!is.na(v$distance) & v$distance <= similarity_threshold, , drop = FALSE]
  v <- utils::head(v, n)
  data.frame(
    co_entidade = as.character(v$co_entidade),
    no_entidade = as.character(v$no_entidade),
    similarity = round(1 - as.numeric(v$distance), 4),
    ideb_observado = as.numeric(v$ideb_observado),
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
#' @param prefer_reference quando `TRUE` (default), lê as referências
#'   comparativas e os percentis de cluster pré-computados
#'   (`analytics.school_profile_reference` / `school_cluster_profile`);
#'   senão, calcula ao vivo.
#' @param output_schema schema onde as tabelas pré-computadas vivem
#'   (default: "analytics").
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
  prefer_reference = TRUE,
  output_schema = "analytics",
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

  ano <- resolve_censo_ano(con, schema)

  inds <- PROFILE_INDICATORS

  # #483: a etapa do IDEB da escola (a de maior nota) decide a etapa de
  # todas as comparações do IDEB e do SAEB.
  ideb <- .school_profile_ideb_etapa(con, schema_q, co_entidade)
  etapa <- .ideb_etapa_valida(ideb$etapa)

  # Linha única da escola alvo. A população completa só é varrida nos
  # fallbacks live; com referências pré-computadas o request não varre.
  first <- .school_profile_school_row(con, schema_q, include_inactive, co_entidade, ano,
                                      ideb_etapa = etapa)
  if (nrow(first) == 0) {
    stop_invalid_dataset(sprintf("Escola não encontrada: %s", co_entidade))
  }

  school_meta <- list(
    co_entidade = co_entidade,
    no_entidade = first$no_entidade,
    co_municipio = first$co_municipio,
    no_municipio = first$no_municipio,
    sg_uf = first$sg_uf,
    nu_ano_censo = ano
  )
  school_meta$ideb_etapa <- ideb$etapa
  school_meta$ideb_ano <- ideb$ano

  # --- Comparativos: referência pré-computada, senão live -----------
  ref_long <- NULL
  if (isTRUE(prefer_reference)) {
    ref_long <- tryCatch(
      read_school_profile_reference(
        postgres_school_profile_reference_repository(con),
        ano,
        output_schema = output_schema
      ),
      error = function(e) NULL
    )
  }

  comparison <- function(scope, chave) {
    r <- .profile_reference_rows(ref_long, scope, chave)
    if (!is.null(r)) return(r)
    .profile_scope_live(con, schema_q, include_inactive, ano, scope, chave)
  }

  cmp_municipio <- comparison("municipio", first$co_municipio)
  cmp_rede <- comparison("rede", first$tp_dependencia)
  cmp_brasil <- comparison("brasil", "todas")

  long <- data.frame(
    indicador = inds,
    escola = as.numeric(first[1, inds]),
    municipio = as.numeric(cmp_municipio$valor[inds]),
    rede = as.numeric(cmp_rede$valor[inds]),
    brasil = as.numeric(cmp_brasil$valor[inds]),
    stringsAsFactors = FALSE
  )

  # #483 (RN-01): IDEB e nota SAEB do município, da rede e do Brasil na
  # etapa da escola. A referência pré-computada mistura as etapas (a de
  # maior nota de cada escola) e não vale para essas duas linhas. Escola sem
  # IDEB: sem comparação (vazio), em vez de uma média de etapas misturadas.
  ideb_rows <- long$indicador %in% c("ideb_observado", "nota_media")
  ideb_scope <- function(scope, chave) {
    .profile_ideb_etapa_stats(con, schema_q, include_inactive, ano, etapa, scope, chave)
  }
  s_mun <- ideb_scope("municipio", first$co_municipio)
  s_rede <- ideb_scope("rede", first$tp_dependencia)
  s_br <- ideb_scope("brasil", NULL)
  por_ind <- function(s) c(ideb_observado = s$ideb$media, nota_media = s$nota$media)
  long$municipio[ideb_rows] <- por_ind(s_mun)[long$indicador[ideb_rows]]
  long$rede[ideb_rows] <- por_ind(s_rede)[long$indicador[ideb_rows]]
  long$brasil[ideb_rows] <- por_ind(s_br)[long$indicador[ideb_rows]]

  n_municipio <- cmp_municipio$n
  n_rede <- cmp_rede$n
  n_brasil <- cmp_brasil$n
  reference_source_municipio <- cmp_municipio$source
  reference_source_rede <- cmp_rede$source
  reference_source_brasil <- cmp_brasil$source

  # --- Grupo de referência pelo contexto (#493, regra 5) -------------
  # Sempre o do município: o `cluster_id` do último agrupamento rodado na
  # plataforma (clean.school_indicators) não é critério citável e deixou de
  # ser usado aqui. O município vem com o IDEB da etapa da escola (#483).
  muni_frame <- .school_profile_municipio_frame(
    con, schema_q, first$co_municipio, include_inactive, ano, ideb_etapa = etapa
  )
  fc <- .school_profile_context_group(muni_frame, co_entidade)
  long$cluster_p25 <- vapply(inds, function(i) fc$stats[[i]]$p25, numeric(1))
  long$cluster_p50 <- vapply(inds, function(i) fc$stats[[i]]$p50, numeric(1))
  long$cluster_p75 <- vapply(inds, function(i) fc$stats[[i]]$p75, numeric(1))
  long$cluster_media <- vapply(inds, function(i) fc$stats[[i]]$media, numeric(1))
  long$cluster_n <- vapply(inds, function(i) as.integer(fc$stats[[i]]$n), integer(1))
  cluster_block <- list(
    cluster_id = fc$cluster_id,
    cluster_label = fc$cluster_label,
    cluster_source = fc$cluster_source,
    cluster_scope = fc$cluster_scope,
    cluster_size = fc$cluster_size,
    cluster_run_id = NA_character_
  )

  long$cluster <- long$cluster_p50

  # --- Escolas similares: as primeiras da ordem do grupo (#495) -----
  # O mesmo contexto do grupo, no município inteiro. Os pares de
  # analytics.similarity_pairs (último job de similaridade, com os
  # indicadores que ele escolheu) deixaram de ser lidos aqui.
  peers <- .school_profile_context_peers(fc, similarity_threshold)
  peers_source <- "contexto_municipio"

  # #483 (RN-02): o IDEB de cada etapa em que a escola tem nota, com o
  # município, a rede e o Brasil da mesma etapa.
  etapas_escola <- .school_profile_ideb_etapas(con, schema_q, co_entidade)
  ideb_por_etapa <- do.call(rbind, lapply(seq_len(nrow(etapas_escola)), function(k) {
    et <- etapas_escola$etapa[k]
    sm <- .profile_ideb_etapa_stats(con, schema_q, include_inactive, ano, et, "municipio", first$co_municipio)
    sr <- .profile_ideb_etapa_stats(con, schema_q, include_inactive, ano, et, "rede", first$tp_dependencia)
    sb <- .profile_ideb_etapa_stats(con, schema_q, include_inactive, ano, et, "brasil", NULL)
    data.frame(
      etapa = et,
      etapa_texto = etapas_escola$etapa_texto[k],
      ano = etapas_escola$ano[k],
      escola = etapas_escola$ideb_observado[k],
      municipio = sm$ideb$media,
      rede = sr$ideb$media,
      brasil = sb$ideb$media,
      n_municipio = sm$ideb$n,
      n_rede = sr$ideb$n,
      n_brasil = sb$ideb$n,
      principal = identical(et, etapa),
      stringsAsFactors = FALSE
    )
  }))
  if (is.null(ideb_por_etapa)) {
    ideb_por_etapa <- data.frame(
      etapa = character(0), etapa_texto = character(0), ano = integer(0),
      escola = numeric(0), municipio = numeric(0), rede = numeric(0), brasil = numeric(0),
      n_municipio = integer(0), n_rede = integer(0), n_brasil = integer(0),
      principal = logical(0), stringsAsFactors = FALSE
    )
  }

  metadata <- c(
    school_meta,
    list(
      cluster_id = cluster_block$cluster_id,
      cluster_label = cluster_block$cluster_label,
      cluster_source = cluster_block$cluster_source,
      cluster_scope = cluster_block$cluster_scope,
      cluster_size = cluster_block$cluster_size,
      cluster_run_id = cluster_block$cluster_run_id,
      peers_source = peers_source,
      reference_source_municipio = reference_source_municipio,
      reference_source_rede = reference_source_rede,
      reference_source_brasil = reference_source_brasil,
      n_municipio = as.integer(n_municipio),
      n_rede = as.integer(n_rede),
      n_brasil = as.integer(n_brasil),
      n_ideb_municipio = s_mun$ideb$n,
      n_ideb_rede = s_rede$ideb$n,
      n_ideb_brasil = s_br$ideb$n,
      ideb_comparacao = "mesma_etapa",
      grupo_criterio = PROFILE_GRUPO_CRITERIO,
      grupo_k = PROFILE_GRUPO_K,
      peers_criterio = PROFILE_GRUPO_CRITERIO,
      peers_n = PROFILE_SIMILARES_N,
      similarity_threshold = similarity_threshold
    )
  )

  model <- new_school_profile_model(
    data = long,
    peers = peers,
    flags_meta = .school_profile_flags_meta(),
    metadata = metadata
  )
  model$ideb_por_etapa <- ideb_por_etapa
  model
}