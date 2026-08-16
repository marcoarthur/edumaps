# inst/plumber/endpoints.R
#
# Camada HTTP do Controller. O endpoint é deliberadamente burro: constrói
# o DataSource a partir do payload e delega o resto pra API da aplicação
# (load_dataset -> run_analysis -> export_result, ver app-application.R)
# — ele não conhece render_plotly nem nenhuma outra camada individual, só
# o contrato da fachada. Isso evita que este arquivo vá gradualmente
# virando um controller gordo conforme o serviço cresce.
#
# Contrato de entrada/saída idêntico ao que já existia — o lado Perl
# (EduMaps::Model::Chart::Base) não precisa mudar nada.

#' @post /chart
function(req, res) {
  payload <- req$body

  tryCatch(
    {
      source <- memory_source(payload$data, metadata = payload$variables %||% list())
      model <- load_dataset(source)
      result <- run_analysis(payload$chart_type, model, payload$variables %||% list())
      export_result(result, "plotly")
    },
    # Erro do CLIENTE (nome de análise inválido, parâmetro errado, dataset
    # sem os campos exigidos) — mensagem é segura de expor.
    edumaps_client_error = function(e) {
      res$status <- 400
      list(error = conditionMessage(e))
    },
    # Qualquer outro erro é interno (bug em analyze_*, falha inesperada) —
    # não vaza detalhe pro cliente, só loga no servidor.
    error = function(e) {
      cat(sprintf("[edumapsAnalytics] erro interno em /chart: %s\n", conditionMessage(e)))
      res$status <- 500
      list(error = "Erro interno ao gerar o gráfico")
    }
  )
}

#' @get /health
function() {
  list(status = "ok")
}
