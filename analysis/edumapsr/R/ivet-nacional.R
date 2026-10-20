# R/ivet-nacional.R
#
# Medição do IVET **v1.2 nacional** (#137, entregável 3; §4.5/§4.8 de
# `docs/analises/ivet.md`).
#
# O núcleo da fórmula (`ivet_v1()`, `ivet_bloco_*()`) é puro: só conhece
# números, nunca o banco. Este arquivo é a **colagem** entre o banco do produto
# (`clean`/`analytics`) e esses blocos. Ele NÃO materializa o IVET no banco
# (decisão de projeto — ver `with_vulnerability_score` em `ivet.md` §3): monta
# um `data.frame` (grão escola), calcula os sete blocos, e devolve o painel em
# memória.
#
# Duas camadas, de propósito:
#
#   - `ivet_painel(dados)`  — **pura e testável**: recebe o `data.frame` de
#     entradas (1 linha/escola) e devolve o painel com `bloco_A`..`bloco_G`,
#     `ivet` e `publicavel`. Não toca no banco.
#   - `ivet_medir_nacional()` — abre a conexão analítica, roda o SQL de extração
#     (`ivet_sql_escolas()`) e chama `ivet_painel()`.
#
# Fontes (grão escola; safra por fonte), conferidas em `database.edumaps`:
#
#   bloco  tabela                                     safra
#   -----  -----------------------------------------  ---------------------
#   A      clean.mv_escolas_scores (matview)          censo_ano
#   B      clean.escola_entorno_socioeconomico        censo_ano × raio_m
#   C      analytics.mobilidade_escola                snapshot
#          clean.isocrona_escolar (piloto ES, #278)  snapshot
#   D      analytics.acessibilidade_saude             snapshot
#   E      clean.brazilcrime_municipio                média de crime_anos
#   F      clean.mapbiomas_escola_risco               censo_ano × raio_m
#          clean.v_mapbiomas_escola_grupos            censo_ano × raio_m
#   G      analytics.esforco_fiscal_educacao          último exercício
#   pop    clean.populacao_municipal                  snapshot (denominador)
#
# Ausência ≠ 0 (#154): quando uma fonte não tem a escola/município, a junção
# devolve `NULL` e o componente correspondente sai `NA` (fora do denominador),
# nunca 0. Um bloco sem nenhum componente vira `NA`; e enquanto faltar algum dos
# blocos territoriais mínimos (C+D+E — `ivet_blocos_territoriais_minimos()`), o
# `ivet` agregado sai `NA` (`publicavel = FALSE`).

# Colunas de entrada que `ivet_painel()` consome. Colunas em falta são tratadas
# como `NA` (o que permite subconjuntos parciais em testes e medições).
IVET_ENTRADAS_COLUNAS <- c(
  # A — escola (scores 0–10 do sistema B)
  "score_capacidade_atendimento", "score_infraestrutura",
  "score_capacitacao_docente", "score_diversidade_discente",
  "score_capacidade_gestora", "score_sustentabilidade",
  # B — socioeconômico (arealização do setor censitário)
  "pct_analfabeto", "pct_agua_sem_rede", "pct_esgoto_inadequado",
  "pct_lixo_inadequado", "pct_sem_banheiro", "renda_resp_media",
  "pct_sem_instrucao", "pct_fund_incomp", "pct_preto_pardo",
  # C — mobilidade: exposição viária + acesso a pé (piloto ES — #278)
  "sinistros_12m", "renavam_total_frota", "pop_acessivel_15min",
  # D — saúde
  "dist_min_km_ubs", "n_ubs_municipio", "ativas_ff", "equipe_esf",
  "efetividade_vagas_aps",
  # E — segurança
  "homicidio_doloso", "latrocinio", "lesao_corporal_seguida_de_morte",
  # F — meio ambiente
  "fogo_frequencia_media", "solo_carbono_medio", "fracao_vegetacao_natural",
  # G — recursos
  "fundeb_por_aluno", "despesa_educ_por_aluno", "autonomia_fiscal_pct",
  # denominador populacional (compartilhado por C/D/E)
  "populacao"
)

# Calcula os sete blocos de UMA escola (linha do painel) e devolve um vetor
# nomeado na ordem de `ivet_blocos()`. `x` é a lista de colunas já puxada.
ivet_blocos_linha <- function(x, i) {
  c(
    escola = ivet_bloco_escola(
      score_capacidade_atendimento = x$score_capacidade_atendimento[[i]],
      score_infraestrutura         = x$score_infraestrutura[[i]],
      score_capacitacao_docente    = x$score_capacitacao_docente[[i]],
      score_diversidade_discente   = x$score_diversidade_discente[[i]],
      score_capacidade_gestora     = x$score_capacidade_gestora[[i]],
      score_sustentabilidade       = x$score_sustentabilidade[[i]]
    ),
    socioeconomico = ivet_bloco_socioeconomico(
      pct_analfabeto        = x$pct_analfabeto[[i]],
      pct_agua_sem_rede     = x$pct_agua_sem_rede[[i]],
      pct_esgoto_inadequado = x$pct_esgoto_inadequado[[i]],
      pct_lixo_inadequado   = x$pct_lixo_inadequado[[i]],
      pct_sem_banheiro      = x$pct_sem_banheiro[[i]],
      renda                 = x$renda_resp_media[[i]],
      pct_sem_instrucao     = x$pct_sem_instrucao[[i]],
      pct_fund_incomp       = x$pct_fund_incomp[[i]],
      pct_preto_pardo       = x$pct_preto_pardo[[i]]
    ),
    mobilidade = ivet_bloco_mobilidade(
      sinistros_12m       = x$sinistros_12m[[i]],
      renavam_total_frota = x$renavam_total_frota[[i]],
      populacao           = x$populacao[[i]],
      pop_acessivel_15min = x$pop_acessivel_15min[[i]]
    ),
    saude = ivet_bloco_saude(
      dist_min_km_ubs        = x$dist_min_km_ubs[[i]],
      n_ubs_municipio        = x$n_ubs_municipio[[i]],
      ativas_ff              = x$ativas_ff[[i]],
      equipe_esf             = x$equipe_esf[[i]],
      efetividade_vagas_aps  = x$efetividade_vagas_aps[[i]],
      populacao              = x$populacao[[i]]
    ),
    seguranca = ivet_bloco_seguranca(
      homicidio_doloso                 = x$homicidio_doloso[[i]],
      latrocinio                       = x$latrocinio[[i]],
      lesao_corporal_seguida_de_morte  = x$lesao_corporal_seguida_de_morte[[i]],
      populacao                        = x$populacao[[i]]
    ),
    meio_ambiente = ivet_bloco_meio_ambiente(
      fogo_frequencia_media     = x$fogo_frequencia_media[[i]],
      fracao_vegetacao_natural  = x$fracao_vegetacao_natural[[i]],
      solo_carbono_medio        = x$solo_carbono_medio[[i]]
    ),
    recursos = ivet_bloco_recursos(
      fundeb_por_aluno        = x$fundeb_por_aluno[[i]],
      despesa_educ_por_aluno  = x$despesa_educ_por_aluno[[i]],
      autonomia_fiscal_pct    = x$autonomia_fiscal_pct[[i]]
    )
  )
}

#' Painel do IVET por escola (fórmula `ivet-v1.2`) a partir das entradas brutas
#'
#' Função **pura** (não toca no banco): recebe um `data.frame` com uma linha por
#' escola e as colunas brutas dos blocos (ver `IVET_ENTRADAS_COLUNAS`) e devolve
#' o mesmo `data.frame` acrescido de:
#'
#' - `bloco_A` … `bloco_G`: a dimensão de cada bloco em `[0,1]` (ou `NA`);
#' - `ivet`: o agregado (média das dimensões disponíveis), ou `NA` enquanto
#'   faltar algum bloco territorial mínimo (C+D+E — `ivet_blocos_territoriais_minimos()`);
#' - `publicavel`: `TRUE` quando C, D e E estão disponíveis.
#'
#' Colunas de entrada em falta são tratadas como `NA` (bloco não calculado).
#' A semântica de agregação é a de `ivet_v1()` (dimensão/bloco `NA` cai fora do
#' numerador **e** do denominador — #154); o atributo `formula` carimba a versão.
#'
#' @param dados `data.frame` com uma linha por escola e as colunas brutas dos
#'   blocos (`IVET_ENTRADAS_COLUNAS`); `co_entidade`/`codigo_ibge` são
#'   preservados apenas como identificação.
#' @param lock_path caminho do `datasets.lock.json` (#135). Se informado, os
#'   atributos `dataset_version`/`transform_version` do painel são preenchidos a
#'   partir dele (proveniência).
#' @return o `data.frame` de entrada com as colunas `bloco_*`, `ivet` e
#'   `publicavel`, e os atributos de proveniência.
#' @export
ivet_painel <- function(dados, lock_path = NULL) {
  if (!is.data.frame(dados)) {
    stop("ivet_painel: 'dados' precisa ser um data.frame")
  }

  n <- nrow(dados)
  rotulos <- unname(ivet_blocos())
  nomes_blocos <- names(ivet_blocos())
  minimos <- ivet_blocos_territoriais_minimos()

  # Puxa cada coluna uma vez (coluna ausente -> vetor de NA).
  puxa <- function(nome) {
    v <- dados[[nome]]
    if (is.null(v)) rep(NA_real_, n) else v
  }
  x <- stats::setNames(lapply(IVET_ENTRADAS_COLUNAS, puxa), IVET_ENTRADAS_COLUNAS)

  out <- matrix(
    NA_real_,
    nrow = n, ncol = length(rotulos),
    dimnames = list(NULL, paste0("bloco_", rotulos))
  )
  for (i in seq_len(n)) {
    out[i, ] <- ivet_blocos_linha(x, i)
  }

  for (j in seq_along(rotulos)) {
    dados[[paste0("bloco_", rotulos[[j]])]] <- out[, j]
  }

  # Publicável exige C+D+E disponíveis (mesma regra de `ivet_v1`).
  dados$publicavel <- apply(out, 1L, function(v) {
    names(v) <- nomes_blocos
    all(is.finite(v[minimos]))
  })

  dados$ivet <- vapply(seq_len(n), function(i) {
    if (!isTRUE(dados$publicavel[[i]])) {
      return(NA_real_)
    }
    v <- out[i, ]
    names(v) <- nomes_blocos
    ivet_agregar(v)
  }, numeric(1))

  attr(dados, "formula") <- ivet_versao()
  if (!is.null(lock_path)) {
    attr(dados, "dataset_version") <- ivet_dataset_version(lock_path)
    attr(dados, "transform_version") <- ivet_transform_version(lock_path)
  }
  dados
}

#' Resumo do painel nacional do IVET
#'
#' Números de apoio à leitura da medição: quantas escolas, quantas publicáveis,
#' cobertura (não-`NA`) por bloco e a distribuição do `ivet` (nas publicáveis).
#'
#' @param painel `data.frame` devolvido por `ivet_painel()`/`ivet_medir_nacional()`.
#' @return lista com `n`, `n_publicavel`, `cobertura` (vetor por bloco) e
#'   `ivet` (vetor `min`/`p25`/`p50`/`p75`/`p90`/`max`/`media`).
#' @export
ivet_resumo_nacional <- function(painel) {
  if (!is.data.frame(painel) || is.null(painel$ivet)) {
    stop("ivet_resumo_nacional: 'painel' precisa vir de ivet_painel()/ivet_medir_nacional()")
  }
  cols_bloco <- paste0("bloco_", unname(ivet_blocos()))
  cobertura <- vapply(
    cols_bloco,
    function(col) sum(is.finite(painel[[col]])),
    numeric(1)
  )
  names(cobertura) <- names(ivet_blocos())
  ivet <- painel$ivet[is.finite(painel$ivet)]
  q <- if (length(ivet) == 0) {
    c(min = NA, p25 = NA, p50 = NA, p75 = NA, p90 = NA, max = NA, media = NA)
  } else {
    c(
      min = min(ivet),
      p25 = unname(stats::quantile(ivet, 0.25)),
      p50 = unname(stats::quantile(ivet, 0.50)),
      p75 = unname(stats::quantile(ivet, 0.75)),
      p90 = unname(stats::quantile(ivet, 0.90)),
      max = max(ivet),
      media = mean(ivet)
    )
  }
  list(
    n = nrow(painel),
    n_publicavel = sum(painel$publicavel %in% TRUE),
    cobertura = cobertura,
    ivet = q
  )
}

#' SQL de extração das entradas do IVET por escola
#'
#' Monta a consulta que reúne, por escola (grão `co_entidade`), as colunas brutas
#' de todos os blocos. Usa parâmetros vinculados (`$1` = ano do Censo, `$2` =
#' raio em metros); os anos de crime são inteiros controlados pelo código e
#' entram como lista (`IN (...)`), com validação.
#'
#' @param censo_ano ano do Censo Escolar (safra de A/B/F).
#' @param raio_m raio da área de influência, em metros (B e F).
#' @param crime_anos anos de `clean.brazilcrime_municipio` a **mediar** (E).
#' @return a consulta SQL como string.
#' @keywords internal
ivet_sql_escolas <- function(censo_ano = 2025L, raio_m = 1000L,
                             crime_anos = 2021:2023) {
  anos <- suppressWarnings(as.integer(crime_anos))
  if (length(anos) == 0 || anyNA(anos)) {
    stop("ivet_sql_escolas: 'crime_anos' precisa ser um vetor de inteiros")
  }
  anos_sql <- paste(anos, collapse = ", ")

  sprintf('
WITH censo AS (
    SELECT co_entidade, co_municipio::text AS codigo_ibge
    FROM clean.censo_escolas
    WHERE nu_ano_censo = $1
      AND tp_situacao_funcionamento = 1
),
pop AS (
    SELECT codigo_ibge::text AS codigo_ibge,
           populacao_estimada::numeric AS populacao
    FROM clean.populacao_municipal
),
a AS (
    SELECT co_entidade,
           score_capacidade_atendimento, score_infraestrutura,
           score_capacitacao_docente, score_diversidade_discente,
           score_capacidade_gestora, score_sustentabilidade
    FROM clean.mv_escolas_scores
    WHERE nu_ano_censo = $1
),
b AS (
    SELECT co_entidade, pct_analfabeto, pct_agua_sem_rede,
           pct_esgoto_inadequado, pct_lixo_inadequado, pct_sem_banheiro,
           renda_resp_media, pct_sem_instrucao, pct_fund_incomp,
           pct_preto_pardo
    FROM clean.escola_entorno_socioeconomico
    WHERE nu_ano_censo = $1 AND raio_m = $2
),
c AS (
    SELECT co_entidade, sinistros_12m, renavam_total_frota
    FROM analytics.mobilidade_escola
),
c_isocrona AS (
    -- Acesso a pé (piloto #278): soma da população das células H3 da isócrona
    -- de 15 min. `populacao_grade` NULL (célula sem setor conhecido) fica fora
    -- da soma; escola sem linha nenhuma chega como NULL — nunca 0 (#154). Usa
    -- o snapshot mais recente, caso entrem recargas com data diferente.
    SELECT co_entidade,
           -- ::double precision evita que o BIGINT chegue ao R como integer64
           -- (quantile/summary em integer64 voltam lixo em silêncio)
           (sum(populacao_grade) FILTER (WHERE tempo_minutos = 15))::double precision
               AS pop_acessivel_15min
      FROM clean.isocrona_escolar
     WHERE dt_snapshot = (SELECT max(dt_snapshot) FROM clean.isocrona_escolar)
     GROUP BY co_entidade
),
d AS (
    SELECT co_entidade, dist_min_km_ubs, n_ubs_municipio, ativas_ff,
           equipe_esf, efetividade_vagas_aps
    FROM analytics.acessibilidade_saude
),
e AS (
    SELECT codigo_ibge,
           avg(homicidio_doloso) AS homicidio_doloso,
           avg(latrocinio) AS latrocinio,
           avg(lesao_corporal_seguida_de_morte) AS lesao_corporal_seguida_de_morte
    FROM clean.brazilcrime_municipio
    WHERE ano IN (%s)
    GROUP BY codigo_ibge
),
f_fogo AS (
    SELECT co_entidade, fogo_frequencia_media, solo_carbono_medio
    FROM clean.mapbiomas_escola_risco
    WHERE nu_ano_censo = $1 AND raio_m = $2
),
f_veg AS (
    SELECT co_entidade, fracao AS fracao_vegetacao_natural
    FROM clean.v_mapbiomas_escola_grupos
    WHERE nu_ano_censo = $1 AND raio_m = $2 AND grupo = \'vegetacao_natural\'
),
g AS (
    SELECT DISTINCT ON (codigo_ibge) codigo_ibge,
           fundeb_por_aluno, despesa_educ_por_aluno, autonomia_fiscal_pct
    FROM analytics.esforco_fiscal_educacao
    ORDER BY codigo_ibge, exercicio DESC
)
SELECT ce.co_entidade,
       ce.codigo_ibge,
       pop.populacao,
       a.score_capacidade_atendimento, a.score_infraestrutura,
       a.score_capacitacao_docente, a.score_diversidade_discente,
       a.score_capacidade_gestora, a.score_sustentabilidade,
       b.pct_analfabeto, b.pct_agua_sem_rede, b.pct_esgoto_inadequado,
       b.pct_lixo_inadequado, b.pct_sem_banheiro, b.renda_resp_media,
       b.pct_sem_instrucao, b.pct_fund_incomp, b.pct_preto_pardo,
       c.sinistros_12m, c.renavam_total_frota,
       ci.pop_acessivel_15min,
       d.dist_min_km_ubs, d.n_ubs_municipio, d.ativas_ff, d.equipe_esf,
       d.efetividade_vagas_aps,
       e.homicidio_doloso, e.latrocinio, e.lesao_corporal_seguida_de_morte,
       ff.fogo_frequencia_media, ff.solo_carbono_medio,
       fv.fracao_vegetacao_natural,
       g.fundeb_por_aluno, g.despesa_educ_por_aluno, g.autonomia_fiscal_pct
FROM censo ce
LEFT JOIN pop ON pop.codigo_ibge = ce.codigo_ibge
LEFT JOIN a   ON a.co_entidade = ce.co_entidade
LEFT JOIN b   ON b.co_entidade = ce.co_entidade
LEFT JOIN c   ON c.co_entidade = ce.co_entidade
LEFT JOIN c_isocrona ci ON ci.co_entidade = ce.co_entidade
LEFT JOIN d   ON d.co_entidade = ce.co_entidade
LEFT JOIN e   ON e.codigo_ibge = ce.codigo_ibge
LEFT JOIN f_fogo ff ON ff.co_entidade = ce.co_entidade
LEFT JOIN f_veg fv ON fv.co_entidade = ce.co_entidade
LEFT JOIN g   ON g.codigo_ibge = ce.codigo_ibge
', anos_sql)
}

#' Mede o IVET `ivet-v1.2` nacional (painel por escola)
#'
#' Abre a conexão analítica (`analytics_db_connection()`), roda a extração
#' (`ivet_sql_escolas()`) e calcula o painel com `ivet_painel()`. **Não
#' materializa** o IVET no banco — devolve o `data.frame` em memória.
#'
#' @param con conexão DBI; por omissão, `analytics_db_connection()`.
#' @param censo_ano ano do Censo Escolar (default 2025).
#' @param raio_m raio da área de influência, em metros (default 1000).
#' @param crime_anos anos de `clean.brazilcrime_municipio` a mediar (E).
#' @param lock_path caminho do `datasets.lock.json` (proveniência; ver `ivet_painel`).
#' @return o painel (`data.frame`) de `ivet_painel()`.
#' @export
ivet_medir_nacional <- function(con = NULL, censo_ano = 2025L, raio_m = 1000L,
                                crime_anos = 2021:2023, lock_path = NULL) {
  if (is.null(con)) {
    con <- analytics_db_connection()
  }
  sql <- ivet_sql_escolas(
    censo_ano = censo_ano, raio_m = raio_m, crime_anos = crime_anos
  )
  dados <- DBI::dbGetQuery(
    con, sql,
    params = list(as.integer(censo_ano), as.integer(raio_m))
  )
  ivet_painel(dados, lock_path = lock_path)
}
