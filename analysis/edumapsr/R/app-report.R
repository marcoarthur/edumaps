# R/app-report.R
#
# Ponto de entrada da aplicação para o Assistente de Relatório (#219),
# usado pelo endpoint `POST /report`:
#
#   payload → report_request_model (valida assistente/tema; 400)
#           → eduBR presente? (400)
#           → conexão somente-leitura do chat (aberta e fechada aqui)
#           → edubr_source (limites do assistente) → analyze_report
#           → render_report_json
#
# Não há Repository nesta fase: o cache de 24 h é do backend Perl.

#' Gera um relatório (ReportResult)
#'
#' @param geotag lista `{nivel, codigo}`.
#' @param tema id do tema (ignorado no assistente `composto`).
#' @param opcoes lista opcional de opções do tema.
#' @param contexto lista opcional (`cod_inep` do gestor).
#' @param config lista opcional `{provider, model, url, api_key}` do Painel
#'   (sobrepõe [chat_config()]).
#' @param tools ferramentas injetadas (testes); `NULL` usa o eduBR.
#' @param llm função opcional `(system, prompt) -> texto` (testes).
#' @param con conexão opcional (testes); `NULL` abre a do chat
#'   (`edumaps_leitor`) e a fecha ao fim.
#' @param assistente id do assistente (Fase 4; `NULL` = `relatorio`).
#'
#' @return Lista ReportResult (ver [render_report_json()]).
#'
#' @export
run_report <- function(geotag, tema, opcoes = NULL, contexto = NULL,
                       config = NULL, tools = NULL, llm = NULL, con = NULL,
                       assistente = NULL) {
  model <- new_report_request_model(geotag, tema, opcoes, contexto, assistente = assistente)
  cfg <- chat_config(override = config)

  if (is.null(tools)) {
    if (!edubr_available()) {
      stop_edubr_unavailable()
    }
    if (is.null(con)) {
      con <- chat_db_connection(cfg)
      on.exit(DBI::dbDisconnect(con), add = TRUE)
    }
  }

  source <- edubr_source(con, limites = report_limits_assistente(model$assistente), tools = tools)
  result <- analyze_report(model, source, config = cfg, llm = llm)
  render_report_json(result)
}
