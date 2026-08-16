# R/repository/postgres.R
#
# Repository de persistência — usado por pipelines BATCH que precisam
# gravar um AnalysisResult diretamente (ex.: um job agendado tipo
# "recalcular o resumo de todos os municípios aos domingos", ver
# R/app/tasks.R).
#
# DECISÃO ARQUITETURAL TEMPORÁRIA: existem hoje DOIS donos da persistência
# de analytics.chart_cache — o caminho HTTP ao vivo do endpoint /chart
# grava via Perl (EduMaps::Model::Chart::Base), e o caminho batch grava
# via este Repository. Isso não é um descuido: o Perl já possui a lógica
# de cache_key, o whitelist de variáveis por requisição e o contrato HTTP
# legado — duplicar isso em R aumentaria a superfície sem necessidade
# nesse caminho específico. Se algum dia essa duplicidade de dono virar
# um problema real (ex.: os dois formatos de cache_key divergirem), a
# correção é unificar num só — mas não antes disso ser um problema de
# verdade.

#' Criar repositório PostgreSQL
#'
#' Instancia um objeto S3 `postgres_repository` para persistência de dados.
#'
#' @param con Conexão ativa do DBI (PostgreSQL).
#'
#' @return Objeto de classe `postgres_repository`.
#' @export
postgres_repository <- function(con) {
  structure(list(con = con), class = "postgres_repository")
}

#' Persistir resultado de análise
#'
#' Método genérico S3 para gravar um `analysis_result` em um repositório.
#'
#' @param repository Objeto de repositório.
#' @param result Objeto `analysis_result` a ser gravado.
#' @param ... Parâmetros adicionais específicos do repositório.
#'
#' @return O objeto `result` invisivelmente.
#' @export
persist <- function(repository, result, ...) UseMethod("persist")

#' Persistir resultado no PostgreSQL
#'
#' Grava ou atualiza um objeto `analysis_result` na tabela `analytics.chart_cache`.
#'
#' @param repository Objeto da classe `postgres_repository`.
#' @param result Objeto `analysis_result` a ser gravado.
#' @param feature Nome da feature (coluna `feature` em `analytics.chart_cache`).
#' @param cache_key Chave já calculada (mesmo esquema do lado Perl).
#' @param ... Parâmetros adicionais não utilizados.
#'
#' @return O objeto `result` invisivelmente.
#' @export
persist.postgres_repository <- function(repository, result, feature, cache_key, ...) {
  plotly_json <- render_plotly(result)

  DBI::dbExecute(
    repository$con,
    "
      INSERT INTO analytics.chart_cache
        (cache_key, feature, chart_type, variables, filters, plotly_json, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, now())
      ON CONFLICT (cache_key) DO UPDATE SET
        plotly_json = EXCLUDED.plotly_json,
        updated_at = now()
    ",
    params = list(
      cache_key,
      feature,
      result$analysis,
      jsonlite::toJSON(result$parameters, auto_unbox = TRUE),
      jsonlite::toJSON(result$metadata, auto_unbox = TRUE),
      jsonlite::toJSON(plotly_json, auto_unbox = TRUE)
    )
  )

  invisible(result)
}
