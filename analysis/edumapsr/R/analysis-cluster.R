# R/analysis/cluster.R
#
# Análise pura de clusterização de entidades (kmeans/dbscan/gmm/spectral).
#
# Contrato:
#
#   school_cluster_model
#            ↓
#   analyze_cluster()
#            ↓
#      analysis_result
#
# A função não conhece DataSource, PostgreSQL, HTTP ou Repository —
# mesma separação de histogram/scatter/boxplot. Os resultados (atribuição
# de cluster + estatísticas por cluster) são devolvidos num
# `analysis_result`; a persistência (in-place na tabela de origem e em
# `analytics.clustering_metadata`) é responsabilidade do Repository.
#
# Espelha o comportamento dos scripts legados em
# backend/templates/rscripts/cluster/ (padronização via scale(),
# set.seed(42), centroides desnormalizados e coluna `is_noise` apenas para
# dbscan), para que a migração preserve o contrato de saída.

CLUSTER_ALGORITHMS <- c("kmeans", "dbscan", "gmm", "spectral")

#' is_noise para dbscan
#'
#' @keywords internal
.is_noise_flag <- function(cluster_ids, algorithm) {
  if (identical(algorithm, "dbscan")) cluster_ids == 0L else rep(FALSE, length(cluster_ids))
}

#' Converte um vetor numérico em JSON objeto nomeado
#'
#' @keywords internal
.centroid_json <- function(values, names_) {
  values <- as.numeric(values)
  jsonlite::toJSON(
    stats::setNames(as.list(values), names_),
    auto_unbox = TRUE
  )
}

#' Calcula centroides por cluster usando médias (dbscan/spectral)
#'
#' @keywords internal
.centroids_by_means <- function(x, cluster_id, features) {
  ids <- sort(unique(cluster_id[cluster_id != 0L]))
  vapply(ids, function(ci) {
    rows <- which(cluster_id == ci)
    .centroid_json(colMeans(x[rows, , drop = FALSE]), features)
  }, character(1))
}

#' Desnormaliza centroides calculados sobre dados padronizados
#'
#' @keywords internal
.unscale_centroids <- function(centroids, center, scale) {
  t(apply(centroids, 1, function(row) {
    as.numeric(row) * as.numeric(scale) + as.numeric(center)
  }))
}

#' executa um algoritmo de clusterização puro
#'
#' @keywords internal
.cluster_fit <- function(x, algorithm, parameters, features) {
  center <- attr(x, "scaled:center")
  scale <- attr(x, "scaled:scale")

  if (algorithm == "kmeans") {
    fit <- stats::kmeans(x, centers = parameters$clusters, nstart = 25)
    list(
      cluster = fit$cluster,
      centroids_scaled = fit$centers,
      sizes = as.integer(fit$size),
      extra = list(within_ss = as.numeric(fit$withinss)),
      centroid_kind = "unscale",
      centroid_features = features
    )
  } else if (algorithm == "dbscan") {
    fit <- dbscan::dbscan(x, eps = parameters$eps, minPts = parameters$min_pts)
    valid <- fit$cluster[fit$cluster != 0L]
    ids <- sort(unique(valid))
    sizes <- as.integer(vapply(
      ids,
      function(id) sum(valid == id),
      integer(1)
    ))
    list(
      cluster = fit$cluster,
      centroids_scaled = NULL,
      sizes = sizes,
      extra = list(),
      centroid_kind = "means",
      centroid_features = features
    )
  } else if (algorithm == "spectral") {
    fit <- kernlab::specc(x, centers = parameters$clusters)
    cluster <- as.integer(fit)
    ids <- sort(unique(cluster))
    ws <- tryCatch(
      as.numeric(kernlab::withinss(fit)),
      error = function(e) rep(NA_real_, length(ids))
    )
    list(
      cluster = cluster,
      centroids_scaled = NULL,
      sizes = as.integer(tabulate(cluster)[ids]),
      extra = list(within_ss = ws),
      centroid_kind = "means",
      centroid_features = features
    )
  } else if (algorithm == "gmm") {
    # mclust resolve helpers internos (mclustBIC etc.) no search() path,
    # não no namespace do pacote — precisa estar ATTACHED, não só carregado
    # (mesma postura do script legado, que fazia library(mclust)).
    if (!"package:mclust" %in% search()) {
      tryCatch(
        attachNamespace("mclust"),
        error = function(e) NULL
      )
    }
    fit <- suppressWarnings(
      mclust::Mclust(x, G = parameters$clusters, verbose = FALSE)
    )
    if (is.null(fit)) {
      stop("GMM não convergiu para os parâmetros informados")
    }
    ids <- seq_len(parameters$clusters)
    probs <- sapply(ids, function(g) {
      idx <- which(fit$classification == g)
      if (length(idx) == 0) NA_real_ else mean(fit$z[idx, g])
    })
    list(
      cluster = fit$classification,
      centroids_scaled = fit$parameters$mean,
      sizes = as.integer(table(factor(fit$classification, levels = ids))),
      extra = list(avg_probability = probs),
      centroid_kind = "unscale",
      centroid_features = features
    )
  }
}

#' Calcula similaridade entre entidades via clusterização
#'
#' Executa o algoritmo de clusterização pedido sobre as features
#' numéricas do modelo e devolve um `analysis_result` com:
#'
#' - `data` — atribuição `entity_id x cluster_id`;
#' - `tables$clusters` — uma linha por cluster (cluster_id, cluster_size,
#'   is_noise, centroids e métricas extras específicas do algoritmo);
#' - `metrics` — contagens e metadados escalares.
#'
#' O parâmetro `parameters` aceita: `algorithm` (kmeans/dbscan/gmm/
#' spectral), `clusters` (kmeans/gmm/spectral), `eps` e `min_pts`
#' (dbscan).
#'
#' @param model objeto da classe `school_cluster_model`.
#' @param parameters lista de parâmetros da execução (algoritmo e
#'   parâmetros específicos do algoritmo).
#'
#' @return Objeto da classe `analysis_result`.
#'
#' @export
analyze_cluster <- function(model, parameters = list()) {
  if (!inherits(model, "school_cluster_model")) {
    stop_invalid_parameter("analyze_cluster requer um school_cluster_model")
  }

  data <- cluster_data(model)
  entity_ids <- cluster_entity_ids(model)
  features <- cluster_features(model)
  algorithm <- parameters$algorithm %||% "kmeans"

  if (!algorithm %in% CLUSTER_ALGORITHMS) {
    stop_invalid_parameter(sprintf(
      "Algoritmo de cluster desconhecido: %s",
      algorithm
    ))
  }

  if (length(features) == 0) {
    stop_invalid_dataset("cluster requer pelo menos uma feature numérica")
  }

  if (anyDuplicated(entity_ids)) {
    stop_invalid_dataset("IDs das entidades devem ser únicos")
  }

  if (nrow(data) < 2) {
    stop_invalid_dataset("cluster requer pelo menos duas entidades")
  }

  if (algorithm %in% c("kmeans", "gmm", "spectral")) {
    parameters$clusters <- parameters$clusters %||% 5L
    parameters$clusters <- as.integer(parameters$clusters)
    if (parameters$clusters < 2L || parameters$clusters > 10L) {
      stop_invalid_parameter(sprintf(
        "clusters deve estar entre 2 e 10 (recebido: %d)",
        parameters$clusters
      ))
    }
  } else if (algorithm == "dbscan") {
    parameters$eps <- parameters$eps %||% 0.5
    parameters$min_pts <- parameters$min_pts %||% 5L
    if (parameters$eps <= 0) {
      stop_invalid_parameter("eps deve ser maior que zero")
    }
    parameters$min_pts <- as.integer(parameters$min_pts)
    if (parameters$min_pts < 1L) {
      stop_invalid_parameter("min_pts deve ser maior ou igual a 1")
    }
  }

  x <- as.matrix(data[, features, drop = FALSE])
  rownames(x) <- entity_ids

  # Robustez a dados ausentes: escolas do Censo podem não ter nota em todas
  # as features selecionadas (NA). scale()/kmeans falham com NA/NaN no kernel,
  # então removemos linhas incompletas e colunas sem variância, mantendo
  # `entity_ids` e `features` alinhados ao subconjunto efetivo.
  complete_rows <- stats::complete.cases(x)
  if (!all(complete_rows)) {
    warning(sprintf(
      "Linhas sem dados completos removidas: %d de %d",
      sum(!complete_rows), nrow(x)
    ))
    x <- x[complete_rows, , drop = FALSE]
    entity_ids <- entity_ids[complete_rows]
  }

  keep_columns <- apply(x, 2L, function(col) length(unique(col)) > 1L)
  if (!all(keep_columns)) {
    warning(sprintf(
      "Features sem variância removidas: %s",
      paste(names(keep_columns)[!keep_columns], collapse = ", ")
    ))
    x <- x[, keep_columns, drop = FALSE]
    features <- features[keep_columns]
  }

  if (nrow(x) < 2L) {
    stop_invalid_dataset("cluster requer pelo menos duas entidades com dados completos nas features")
  }
  if (length(features) == 0L) {
    stop_invalid_dataset("cluster requer pelo menos uma feature numérica com variância")
  }
  if (algorithm %in% c("kmeans", "gmm", "spectral") && parameters$clusters >= nrow(x)) {
    stop_invalid_parameter(sprintf(
      "clusters (%d) deve ser menor que o nº de entidades com dados completos (%d)",
      parameters$clusters, nrow(x)
    ))
  }

  x_scaled <- scale(x)
  set.seed(42)

  fit <- .cluster_fit(x_scaled, algorithm, parameters, features)

  cluster_id <- as.integer(fit$cluster)

  # Centroides
  centroids <- if (identical(fit$centroid_kind, "unscale")) {
    unscaled <- .unscale_centroids(
      fit$centroids_scaled,
      attr(x_scaled, "scaled:center"),
      attr(x_scaled, "scaled:scale")
    )
    vapply(seq_len(nrow(unscaled)), function(i) {
      .centroid_json(unscaled[i, ], fit$centroid_features)
    }, character(1))
  } else {
    .centroids_by_means(
      x,
      cluster_id,
      features
    )
  }

  indices <- if (algorithm == "dbscan") {
    sort(unique(cluster_id[cluster_id != 0L]))
  } else {
    seq_len(
      if (is.null(fit$centroids_scaled)) length(fit$sizes) else parameters$clusters
    )
  }
  indices <- if (length(indices) == 0) integer(0) else sort(unique(indices))

  n_clusters <- length(indices)

  # ---- Rótulos semânticos (linguagem natural) --------------------------
  # A análise pura não sabe o significado das features; o rótulo é derivado
  # do conceito do preset e da polaridade de cada feature (parameters$labeling).
  # Sem conceito (ou com nº excessivo de clusters), cai no fallback inteiro.
  labeling <- if (is.list(parameters$labeling)) parameters$labeling else list()
  concept <- labeling$concept
  gender  <- if (is.null(labeling$gender)) "f" else labeling$gender
  directions <- labeling$directions

  cluster_labels_df <- data.frame(
    cluster_id = integer(0),
    cluster_rank = integer(0),
    cluster_label = character(0),
    stringsAsFactors = FALSE
  )

  if (n_clusters > 0) {
    means <- t(vapply(indices, function(ci) {
      colMeans(x[cluster_id == ci, , drop = FALSE])
    }, numeric(length(features))))
    if (length(indices) == 1) {
      means <- matrix(means, nrow = 1, ncol = length(features))
    }
    rownames(means) <- as.character(indices)
    colnames(means) <- features

    scores <- .cluster_scores(means, features, directions)
    all_ids <- sort(unique(cluster_id))
    cluster_labels_df <- .cluster_labels(all_ids, scores, concept = concept, gender = gender)
  }

  if (n_clusters == 0) {
    # dbscan pode não encontrar nenhum cluster (tudo ruído)
    clusters_df <- data.frame(
      cluster_id = integer(0),
      cluster_size = integer(0),
      is_noise = logical(0),
      centroids = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    size_vec <- if (length(fit$sizes) == n_clusters) {
      fit$sizes
    } else {
      as.integer(tabulate(cluster_id)[indices])
    }

    clusters_df <- data.frame(
      cluster_id = indices,
      cluster_size = size_vec,
      is_noise = .is_noise_flag(indices, algorithm)[seq_len(n_clusters)],
      centroids = centroids[seq_len(n_clusters)],
      stringsAsFactors = FALSE
    )

    for (name in names(fit$extra)) {
      extra <- fit$extra[[name]]
      if (length(extra) == n_clusters) {
        clusters_df[[name]] <- extra
      }
    }
  }

  clusters_df$cluster_rank  <- cluster_labels_df$cluster_rank[match(clusters_df$cluster_id, cluster_labels_df$cluster_id)]
  clusters_df$cluster_label <- cluster_labels_df$cluster_label[match(clusters_df$cluster_id, cluster_labels_df$cluster_id)]

  assignments_df <- data.frame(
    entity_id = entity_ids,
    cluster_id = cluster_id,
    stringsAsFactors = FALSE
  )
  names(assignments_df)[1] <- model$entity_id

  assignments_df$cluster_label <- cluster_labels_df$cluster_label[match(assignments_df$cluster_id, cluster_labels_df$cluster_id)]
  assignments_df$cluster_rank  <- cluster_labels_df$cluster_rank[match(assignments_df$cluster_id, cluster_labels_df$cluster_id)]

  noise_count <- sum(assignments_df$cluster_id == 0L, na.rm = TRUE)

  new_analysis_result(
    analysis = paste0("cluster_", algorithm),
    parameters = parameters,
    data = assignments_df,
    metrics = list(
      algorithm = algorithm,
      n_entities = nrow(assignments_df),
      n_clusters = n_clusters,
      n_noise = if (algorithm == "dbscan") noise_count else 0L,
      n_features = length(features)
    ),
    tables = list(
      clusters = clusters_df
    ),
    metadata = list(
      entity_id = model$entity_id,
      features = features,
      data_source = model$metadata
    )
  )
}