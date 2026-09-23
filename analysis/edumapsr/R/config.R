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

#' Chat configuration
#'
#' Configurações do Assistente do Censo (chat NL->SQL). Ficam centralizadas
#' aqui para o restante da camada analítica não conhecer detalhes de ambiente.
#' A conexão de chat usa um serviço PostgreSQL dedicado e somente-leitura
#' (role `edumaps_leitor`), garantido no banco e não apenas por convenção.
#'
#' @return Lista com as configurações do chat.
#'
#' @keywords internal
chat_config <- function() {
  provider <- Sys.getenv("EDUMAPS_LLM_PROVIDER", "ollama")
  list(
    db_service = Sys.getenv("EDUMAPS_CHAT_DB_SERVICE", "edumaps_leitor"),
    provider = provider,
    model = Sys.getenv(
      "EDUMAPS_LLM_MODEL",
      switch(provider,
        gemini = "gemini-flash-lite-latest",
        groq = "openai/gpt-oss-120b",
        openai = "gpt-4.1-mini",
        "qwen2.5:3b"
      )
    ),
    url = Sys.getenv(
      "EDUMAPS_LLM_URL",
      switch(provider,
        gemini = "https://generativelanguage.googleapis.com/v1beta/",
        groq = "https://api.groq.com/openai/v1",
        openai = "https://api.openai.com/v1",
        "http://localhost:11434"
      )
    ),
    api_key = Sys.getenv("EDUMAPS_LLM_API_KEY", ""),
    max_rows = as.integer(Sys.getenv("EDUMAPS_CHAT_MAX_ROWS", "200")),
    # Motor de conversa: "tool" (tool-calling em 2 turnos; padrão) ou "single"
    # (1 turno: o modelo devolve o SQL e nós executamos + resumimos). O Groq
    # free (TPM 8k) não comporta 2 turnos com o dicionário no system prompt.
    engine = Sys.getenv(
      "EDUMAPS_CHAT_ENGINE",
      if (identical(provider, "groq")) "single" else "tool"
    )
  )
}

#' Open the chat read-only database connection
#'
#' Conexão usada exclusivamente pela ferramenta `run_sql` do chat. A role
#' `edumaps_leitor` é read-only no banco (transaction_read_only + grants de
#' SELECT apenas em clean/analytics), então mesmo um SQL malicioso gerado pelo
#' modelo não consegue escrever — a segurança efetiva é do banco, não do R.
#'
#' @return A DBI database connection (read-only).
#'
#' @keywords internal
chat_db_connection <- function() {
  config <- chat_config()

  DBI::dbConnect(
    RPostgres::Postgres(),
    service = config$db_service
  )
}
