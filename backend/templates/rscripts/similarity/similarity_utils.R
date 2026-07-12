#' similarity_utils.R
#'
#' Funções comuns compartilhadas por todos os scripts de similaridade
#' (gower.R, euclidean_zscore.R, mahalanobis.R, aitchison.R, dtw.R).
#'
#' Espelha o papel de clustering_utils.R para EduMaps::Task::Clustering,
#' com uma diferença estrutural importante: o resultado de uma similaridade
#' par-a-par tem cardinalidade O(n²) (todos os pares de entidades), entao
#' NUNCA e devolvido por completo no payload de stdout (ao contrario do
#' clustering, onde o payload tem uma linha por cluster - O(n) pequeno).
#' Os pares sao sempre persistidos direto no Postgres; o stdout carrega
#' apenas um resumo (contagens, estatisticas, uma amostra dos pares mais
#' similares) para inspecao/debug.
#'
#' Cada script de metrica deve apenas:
#'   1. Ler e preparar os dados (colunas numericas/mistas/composicionais/
#'      series temporais, conforme a metrica)
#'   2. Calcular uma matriz ou objeto de distancia entre as entidades
#'   3. Chamar pairs_from_distance() para converter em pares (entidade_1,
#'      entidade_2, distancia, similaridade)
#'   4. Chamar write_similarity_pairs() para persistir
#'   5. Finalizar com build_similarity_response_payload()
#'
#' @import DBI
#' @import jsonlite
#' @import dplyr

suppressPackageStartupMessages({
  library(DBI, quietly = TRUE)
  library(jsonlite, quietly = TRUE)
  library(dplyr, quietly = TRUE)
})

# Nome fixo da tabela de pares, compartilhada entre todas as metricas.
# A coluna `metric` diferencia a origem, `target_table` diferencia a
# entidade/tabela de origem de cada linha.
SIMILARITY_PAIRS_TABLE <- "similarity_pairs"


#' Gera um identificador único de execução baseado em timestamp
#'
#' @return string no formato "run_<epoch>"
generate_run_id <- function() {
  paste0("run_", as.integer(Sys.time()))
}


#' Seleciona as colunas numericas elegiveis para metricas puramente
#' numericas (euclidean_zscore, mahalanobis), excluindo id_column e
#' quaisquer colunas ja calculadas em execucoes anteriores.
#'
#' @param df data.frame ou tibble de origem
#' @param id_column nome da coluna de identificacao
#' @return character vector com os nomes das colunas numericas elegiveis
select_numeric_features <- function(df, id_column) {
  numeric_features <- df %>%
    dplyr::select(where(is.numeric)) %>%
    colnames()

  numeric_features <- setdiff(numeric_features, id_column)

  if (length(numeric_features) == 0) {
    stop("Nenhuma coluna numerica encontrada para computar a similaridade.")
  }

  numeric_features
}


#' Seleciona colunas numericas E categoricas/logicas elegiveis, para
#' metricas que lidam nativamente com tipos mistos (gower).
#'
#' @param df data.frame ou tibble de origem
#' @param id_column nome da coluna de identificacao
#' @return character vector com os nomes das colunas elegiveis
select_mixed_features <- function(df, id_column) {
  eligible <- df %>%
    dplyr::select(where(~ is.numeric(.x) || is.character(.x) || is.factor(.x) || is.logical(.x))) %>%
    colnames()

  eligible <- setdiff(eligible, id_column)

  if (length(eligible) == 0) {
    stop("Nenhuma coluna elegivel encontrada para computar a similaridade.")
  }

  eligible
}


#' Converte uma matriz/objeto de distancia (n x n) em um data.frame de
#' pares (entidade_1, entidade_2, distancia, similaridade), mantendo
#' apenas i < j - evita duplicatas e auto-comparacao, mesmo criterio do
#' script SQL original (WHERE a.cod_municipio < b.cod_municipio).
#'
#' @param ids vetor de identificadores das entidades, na mesma ordem das
#'   linhas/colunas da matriz de distancia
#' @param dist_matrix objeto 'dist' (ex: retorno de stats::dist(),
#'   cluster::daisy(), dtwclust::proxy) ou uma matriz n x n de distancias
#' @return tibble com entity_1, entity_2, distance, similarity
pairs_from_distance <- function(ids, dist_matrix) {
  m <- as.matrix(dist_matrix)
  stopifnot(nrow(m) == length(ids), ncol(m) == length(ids))
  dimnames(m) <- list(ids, ids)

  idx <- which(upper.tri(m), arr.ind = TRUE)

  tibble::tibble(
    entity_1   = ids[idx[, 1]],
    entity_2   = ids[idx[, 2]],
    distance   = m[idx],
    # normalizacao 1/(1+d) - mesma formula do script SQL original.
    # Sempre em (0, 1], decrescente com a distancia, sem exigir que a
    # distancia esteja previamente limitada a um intervalo conhecido.
    similarity = 1 / (1 + m[idx])
  )
}


#' Grava os pares de uma execução na tabela compartilhada
#' `similarity_pairs`, sempre em modo append (preserva histórico, mesma
#' filosofia de clustering_metadata: run_id disambigua execucoes).
#'
#' IMPORTANTE sobre volume: diferente de clustering_metadata (uma linha por
#' cluster), aqui sao O(n²) linhas por execucao. Para uma tabela de milhares
#' de entidades isso pode crescer rapido se rodado com frequencia - avalie
#' uma rotina de limpeza (ex: manter so o run_id mais recente por
#' target_table+metric) se este job rodar em um cron periodico, em vez de
#' sob demanda.
#'
#' @param con conexão DBI ativa
#' @param schema nome do schema onde a tabela de pares vive (ex: "analytics")
#' @param metric nome da metrica ("gower", "euclidean_zscore", "mahalanobis",
#'   "aitchison", "dtw")
#' @param run_id identificador da execução (ver generate_run_id())
#' @param target_table nome completo "schema.tabela" da tabela de origem
#' @param id_column nome da coluna de identificacao usada na tabela de origem
#' @param params lista nomeada com os parâmetros usados (ex: list(composition_columns=...))
#' @param pairs_df tibble retornado por pairs_from_distance()
#' @return invisible(TRUE)
write_similarity_pairs <- function(con, schema, metric, run_id, target_table, id_column, params, pairs_df) {
  pairs_tb <- pairs_df %>%
    dplyr::mutate(
      run_id       = run_id,
      metric       = metric,
      target_table = target_table,
      id_column    = id_column,
      params_json  = as.character(jsonlite::toJSON(params, auto_unbox = TRUE)),
      computed_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
      .before = 1
    )

  DBI::dbWriteTable(
    con,
    DBI::Id(schema = schema, table = SIMILARITY_PAIRS_TABLE),
    pairs_tb,
    append = TRUE
  )

  invisible(TRUE)
}


#' Monta o payload de resumo e o imprime em stdout como JSON, encerrando o
#' processo R com status 0. Esse e o unico ponto de saida esperado pelo
#' EduMaps::Analysis::R::Pipe (que faz decode_json do stdout).
#'
#' Ao contrario de build_response_payload() em clustering_utils.R, este
#' payload NAO inclui os pares completos (seriam O(n²) linhas) - apenas um
#' resumo com uma amostra dos pares mais similares, suficiente para debug/
#' preview. Os pares completos ja foram persistidos por write_similarity_pairs()
#' e devem ser consultados via SQL (analytics.similarity_pairs) filtrando
#' por target_table + metric + run_id.
#'
#' @param metric nome da metrica
#' @param run_id identificador da execução
#' @param schema nome do schema de origem dos dados
#' @param table_name nome da tabela de origem dos dados
#' @param id_column nome da coluna de identificação
#' @param output_schema schema onde os pares foram gravados (ex: "analytics")
#' @param params lista nomeada com os parâmetros usados
#' @param pairs_df tibble completo de pares (usado so para calcular o
#'   resumo/amostra, nao e serializado por inteiro)
#' @param top_n quantos pares de exemplo (mais similares) incluir na amostra
#' @return não retorna; encerra o processo via quit(status = 0)
build_similarity_response_payload <- function(metric, run_id, schema, table_name, id_column,
                                               output_schema, params, pairs_df, top_n = 5) {
  n_entities <- length(unique(c(pairs_df$entity_1, pairs_df$entity_2)))

  sample_top_pairs <- pairs_df %>%
    dplyr::arrange(dplyr::desc(similarity)) %>%
    utils::head(top_n)

  response_payload <- list(
    status         = "success",
    metric         = as.character(metric),
    run_id         = as.character(run_id),
    schema         = as.character(schema),
    table_name     = as.character(table_name),
    id_column      = as.character(id_column),
    output_table   = paste0(output_schema, ".", SIMILARITY_PAIRS_TABLE),
    timestamp      = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    params         = params,
    n_entities     = n_entities,
    n_pairs        = nrow(pairs_df),
    avg_similarity = mean(pairs_df$similarity),
    sample_top_pairs = sample_top_pairs
  )

  # cat envia texto puro ao stdout, sem os índices [1] do print classico do R
  cat(jsonlite::toJSON(response_payload, auto_unbox = TRUE))
  quit(status = 0)
}
