# R/analysis-report.R
#
# Analysis do Assistente de Relatório (#219): orquestra (a) o roteiro fixo
# do tema, que chama as ferramentas do eduBR e monta as seções de dados, e
# (b) a redação das seções de texto pelo LLM. Devolve um `analysis_result`
# (como toda análise do pacote); quem decide o formato de saída é a View
# ([render_report_json()]).
#
#   AnalysisResult:
#     data     = envelopes não são guardados; `data` traz as fontes
#                (data.frame) para manter o contrato de `analysis_result`
#     tables   = tabelas do relatório (data.frames, por id de seção)
#     metadata = titulo, gerado_em, recorte, tema, secoes, fontes, avisos,
#                rastreio

#' Executa o relatório de um tema sobre um recorte
#'
#' @param model `report_request_model` (de [new_report_request_model()]).
#' @param source `edubr_source` (de [edubr_source()]).
#' @param config configuração de [chat_config()] (provedor do painel).
#' @param llm função opcional `(system, prompt) -> texto` (testes).
#'
#' @return Objeto `analysis_result` (análise `"report"`).
#'
#' @export
analyze_report <- function(model, source, config = NULL, llm = NULL) {
  if (!inherits(model, "report_request_model")) {
    stop_invalid_parameter("analyze_report espera um report_request_model")
  }
  if (!inherits(source, "edubr_source")) {
    stop_invalid_parameter("analyze_report espera um edubr_source")
  }
  cfg <- if (is.list(config) && !is.null(config$provider) && !is.null(config$db_service)) {
    config
  } else {
    chat_config(override = config)
  }
  t0 <- proc.time()[["elapsed"]]

  tema <- model$tema
  dados <- tema$roteiro(model, source)
  recorte_nome <- report_recorte_display(dados$recorte)
  titulo <- sprintf("%s — %s", tema$titulo, recorte_nome)

  report <- list(
    titulo = titulo,
    recorte = dados$recorte,
    recorte_nome = recorte_nome,
    tema = list(id = tema$id, titulo = tema$titulo),
    profundidade = tema$profundidade %||% "descritiva",
    secoes = dados$secoes,
    fontes = dados$fontes,
    avisos = dados$avisos,
    leitura_padrao = dados$leitura
  )

  texto <- report_write_text(report, cfg, llm)

  secoes <- c(
    list(report_section_text("resumo", "Resumo", texto$resumo)),
    dados$secoes,
    list(report_section_text("leitura", "Como ler", texto$leitura))
  )
  avisos <- dados$avisos
  if (!is.null(texto$aviso)) {
    avisos <- c(avisos, list(texto$aviso))
  }

  rastreio <- list(
    provedor = cfg$provider,
    modelo = if (identical(cfg$provider, "mock")) "mock" else cfg$model,
    llm = texto$llm,
    versao_edubr = edubr_version(),
    chamadas = edubr_call_count(source),
    duracao_ms = as.integer(round((proc.time()[["elapsed"]] - t0) * 1000))
  )

  tabelas <- Filter(function(s) identical(s$tipo, "tabela"), dados$secoes)
  tables <- stats::setNames(
    lapply(tabelas, `[[`, "linhas"),
    vapply(tabelas, `[[`, character(1), "id")
  )

  fontes_df <- if (length(dados$fontes)) {
    do.call(rbind, lapply(dados$fontes, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame()
  }

  new_analysis_result(
    analysis = "report",
    parameters = list(
      nivel = model$nivel,
      codigo = model$codigo,
      tema = tema$id,
      opcoes = model$opcoes
    ),
    data = fontes_df,
    metrics = list(
      secoes = length(secoes),
      avisos = length(avisos),
      chamadas = rastreio$chamadas
    ),
    tables = tables,
    metadata = list(
      titulo = titulo,
      gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      recorte = dados$recorte,
      tema = report$tema,
      secoes = secoes,
      fontes = dados$fontes,
      avisos = avisos,
      rastreio = rastreio
    )
  )
}
