# R/cluster-labels.R
#
# Descrição em linguagem natural dos clusters obtidos por analyze_cluster().
#
# A análise pura (R/analysis/cluster.R) calcula apenas cluster_id, centroides
# e tamanhos — não sabe o que cada feature significa. Este módulo traduz o
# resultado em rótulos humanos usando o *conceito* do preset (ex.:
# "qualidade de infraestrutura"), a *polaridade* de cada feature (maior é
# melhor vs. pior) e uma gradação dependente do número de clusters.
#
# Escala nomeada (ordenada da pior para a melhor):
#   2 -> baixa, alta
#   3 -> baixa, média, alta
#   4 -> muito baixa, baixa, alta, muito alta
#   5 -> muito baixa, baixa, média, alta, muito alta
#   >= 6 (excessivo) -> fallback inteiro "Cluster 1..N" (1 = mais baixo, N = mais alto)
#
# Quando não há conceito (features customizadas) ou há apenas 1 cluster,
# também cai no fallback inteiro. Ruído de dbscan (cluster_id == 0) recebe
# o rótulo "Ruído" e rank NA.

# Retorna o vetor de adjetivos ordenado (pior -> melhor) para `n` clusters,
# ou NULL quando não há gradação nomeada (n < 2 ou excessivo).
# O gênero controla a concordância do adjetivo (f/m).
.label_scale <- function(n, gender = "f") {
  if (!is.numeric(n) || n < 2 || n > 5) return(NULL)

  scales <- list(
    f = list(
      `2` = c("baixa", "alta"),
      `3` = c("baixa", "média", "alta"),
      `4` = c("muito baixa", "baixa", "alta", "muito alta"),
      `5` = c("muito baixa", "baixa", "média", "alta", "muito alta")
    ),
    m = list(
      `2` = c("baixo", "alto"),
      `3` = c("baixo", "médio", "alto"),
      `4` = c("muito baixo", "baixo", "alto", "muito alto"),
      `5` = c("muito baixo", "baixo", "médio", "alto", "muito alto")
    )
  )

  key <- if (identical(gender, "m")) "m" else "f"
  scales[[key]][[as.character(n)]]
}

# Coloca a primeira letra em maiúscula ("alta" -> "Alta").
.first_upper <- function(s) {
  vapply(s, function(x) {
    if (!nzchar(x)) return(x)
    paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
  }, character(1), USE.NAMES = FALSE)
}

# Calcula um score composto por cluster a partir das médias por feature.
#
# @param means matrix [cluster x feature] com as médias por cluster.
# @param features vetor com os nomes das colunas de `means`.
# @param directions lista nomeada feature -> +1 (maior é melhor) ou -1
#   (maior é pior). Feature ausente assume +1.
#
# @return vetor numérico nomeado pelos ids de cluster (character).
.cluster_scores <- function(means, features, directions = NULL) {
  dirs <- vapply(features, function(f) {
    d <- directions[[f]]
    if (is.null(d) || length(d) != 1 || is.na(d) || !is.finite(d)) 1 else as.numeric(d)
  }, numeric(1))

  norm_col <- function(col) {
    rng <- range(col, na.rm = TRUE)
    if (rng[2] - rng[1] == 0) return(rep(0.5, length(col)))
    (col - rng[1]) / (rng[2] - rng[1])
  }

  m <- apply(means, 2, norm_col)
  if (is.null(dim(m))) m <- matrix(m, nrow = nrow(means), ncol = ncol(means))

  weighted <- sweep(m, 2, dirs, "*")
  scores <- rowMeans(weighted)

  rn <- rownames(means)
  if (is.null(rn)) rn <- as.character(seq_along(scores))
  stats::setNames(as.numeric(scores), rn)
}

# Monta o data.frame cluster_id x (cluster_rank, cluster_label).
#
# @param cluster_ids vetor de ids de cluster presentes (pode incluir 0 = ruído).
# @param scores vetor nomeado de scores (apenas clusters válidos).
# @param concept frase do conceito (ex.: "qualidade de infraestrutura");
#   NULL força fallback inteiro.
# @param gender gênero do adjetivo ("f"/"m").
.cluster_labels <- function(cluster_ids, scores, concept = NULL, gender = "f") {
  valid <- sort(unique(cluster_ids[cluster_ids != 0]))
  n <- length(valid)

  scale <- NULL
  if (!is.null(concept) && nchar(concept) > 0 && n >= 2 && n <= 5) {
    scale <- .label_scale(n, gender)
  }

  score_of <- function(cid) {
    s <- scores[[as.character(cid)]]
    if (is.null(s) || length(s) != 1 || is.na(s) || !is.finite(s)) 0 else s
  }

  if (n > 0) {
    valid_scores <- vapply(valid, score_of, numeric(1))
    ord <- valid[order(valid_scores, valid)]
    rank_map <- stats::setNames(seq_along(ord), as.character(ord))
  } else {
    rank_map <- integer(0)
  }

  ranks <- integer(length(cluster_ids))
  labels <- character(length(cluster_ids))

  for (i in seq_along(cluster_ids)) {
    cid <- cluster_ids[i]
    if (cid == 0) {
      ranks[i] <- NA_integer_
      labels[i] <- "Ruído"
      next
    }
    r <- unname(rank_map[[as.character(cid)]])
    ranks[i] <- r
    if (!is.null(scale)) {
      labels[i] <- paste0(.first_upper(scale[r]), " ", concept)
    } else {
      labels[i] <- paste0("Cluster ", r)
    }
  }

  data.frame(
    cluster_id = cluster_ids,
    cluster_rank = ranks,
    cluster_label = labels,
    stringsAsFactors = FALSE
  )
}
