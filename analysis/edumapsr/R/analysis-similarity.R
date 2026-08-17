# R/analysis/similarity.R
#
# Análise pura de similaridade entre escolas usando distância de Gower.
#
# Contrato:
#
#   school_similarity_model
#            ↓
#   analyze_gower_similarity()
#            ↓
#      analysis_result
#
# A função não conhece DataSource, PostgreSQL, HTTP ou Repository.
# Isso mantém a mesma separação já usada por histogram/scatter/boxplot.
#
# A distância de Gower é particularmente adequada aqui porque permite
# trabalhar com features de naturezas diferentes sem exigir que todas
# sejam previamente transformadas em uma escala comum.
#
# A similaridade é definida como:
#
#   similarity = 1 - distance
#
# portanto permanece no intervalo [0, 1].

#' Calcula similaridade de Gower entre entidades
#'
# Calcula a distância de Gower entre todas as entidades do modelo e
# converte a distância em similaridade através de `1 - distance`.
# Cada par de entidades aparece uma única vez no resultado.
#'
#' @param model objeto da classe `school_similarity_model`.
#' @param parameters lista de parâmetros da execução, preservada no
#'   `analysis_result`.
#'
#' @return Objeto da classe `analysis_result`, contendo uma linha por par
#'   de entidades e as colunas `entity_id_a`, `entity_id_b`, `distance` e
#'   `similarity`.
#'
#' @export
analyze_gower_similarity <- function(
  model,
  parameters = list()
) {
  if (!inherits(model, "school_similarity_model")) {
    stop("analyze_gower_similarity requer um school_similarity_model")
  }

  data <- similarity_data(model)
  entity_ids <- similarity_entity_ids(model)
  features <- similarity_features(model)

  if (length(features) == 0) {
    stop("similaridade requer pelo menos uma feature")
  }

  if (anyDuplicated(entity_ids)) {
    stop("IDs das entidades devem ser únicos")
  }

  if (nrow(data) < 2) {
    stop("similaridade requer pelo menos duas entidades")
  }

  x <- data[, features, drop = FALSE]

  distance <- cluster::daisy(
    x,
    metric = "gower"
  )

  distance_matrix <- as.matrix(distance)

  # A matriz de distância é simétrica e a diagonal representa a
  # comparação de uma entidade consigo mesma. Usamos somente o
  # triângulo superior para produzir cada par exatamente uma vez.
  pair_index <- which(
    upper.tri(distance_matrix),
    arr.ind = TRUE
  )

  pairs <- data.frame(
    entity_id_a = entity_ids[pair_index[, "row"]],
    entity_id_b = entity_ids[pair_index[, "col"]],
    distance = distance_matrix[pair_index],
    similarity = 1 - distance_matrix[pair_index],
    stringsAsFactors = FALSE
  )

  pairs <- pairs[
    order(pairs$similarity, decreasing = TRUE),
    ,
    drop = FALSE
  ]

  new_analysis_result(
    analysis = "gower_similarity",
    parameters = parameters,
    data = pairs,
    metrics = list(
      n_entities = nrow(data),
      n_features = length(features),
      n_pairs = nrow(pairs),
      mean_similarity = if (nrow(pairs) > 0) {
        mean(pairs$similarity, na.rm = TRUE)
      } else {
        NA_real_
      }
    ),
    metadata = list(
      entity_id = model$entity_id,
      features = features
    )
  )
}
