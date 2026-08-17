#' Analytics service configuration
#'
#' Centraliza as configurações de infraestrutura utilizadas pelo serviço
#' analítico. O restante da camada analítica não deve conhecer diretamente
#' detalhes de ambiente, como o nome do serviço PostgreSQL.
#'
#' @return Lista contendo as configurações efetivas do serviço analítico.
#'
#' @keywords internal
analytics_config <- function() {
  list(
    db_service = Sys.getenv(
      "EDUMAPS_ANALYTICS_DB_SERVICE",
      unset = "edumaps_local"
    ),
    output_schema = Sys.getenv(
      "EDUMAPS_ANALYTICS_OUTPUT_SCHEMA",
      unset = "analytics"
    )
  )
}

#' Open the analytics database connection
#'
#' Creates a PostgreSQL connection using the database service configured
#' for the analytics application. Database infrastructure configuration is
#' intentionally kept outside individual analysis functions.
#'
#' @return A DBI database connection.
#'
#' @keywords internal
analytics_db_connection <- function() {
  config <- analytics_config()

  DBI::dbConnect(
    RPostgres::Postgres(),
    service = config$db_service
  )
}
