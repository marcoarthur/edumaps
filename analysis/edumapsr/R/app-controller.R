# R/app/controller.R
#
# Único ponto de entrada pra rodar uma análise. Responsabilidades:
# validar o nome contra o registry, validar que recebeu um modelo
# semântico (não dados crus nem uma conexão), validar que o modelo tem os
# campos que a análise exige, orquestrar a execução e devolver sempre um
# AnalysisResult.
#
# Toda falha de validação aqui é um erro DO CLIENTE (nome de análise
# errado, model do tipo errado, dataset incompleto) — por isso usa as
# condições tipadas de R/conditions.R em vez de stop() genérico. Um bug
# de verdade dentro de analyze_*() continua sendo um stop() comum, que o
# adapter HTTP trata como 500 (ver inst/plumber/endpoints.R).

#' @export
run_analysis <- function(name, model, parameters = list()) {
  entry <- analysis_registry[[name]]
  if (is.null(entry)) {
    stop_invalid_analysis(sprintf("Análise desconhecida: %s", name))
  }
  if (!inherits(model, "school_indicator_model")) {
    stop_invalid_parameter("run_analysis espera um modelo semântico (school_indicator_model), não dados crus")
  }

  .assert_required_fields(model, entry$required)

  entry$fn(model, parameters)
}

# Construída dentro da função (não no nível superior do arquivo) de
# propósito: uma lista no nível superior referenciando `values`/`groups`
# etc. seria avaliada durante o CARREGAMENTO do pacote, na ordem em que
# os arquivos são lidos — e isso já causou um bug real (ver histórico:
# "object 'values' not found", porque app-controller.R carregava antes
# de model-semantic-school-indicator-model.R em ordem alfabética).
# Dentro da função, isso só roda quando run_analysis() é chamado, bem
# depois de todo o pacote já estar carregado — não importa mais em que
# ordem os arquivos foram lidos.
.assert_required_fields <- function(model, required) {
  model_accessors <- list(
    value = values,
    x = values_x,
    y = values_y,
    group = groups
  )

  missing_fields <- Filter(function(field) {
    accessor <- model_accessors[[field]]
    is.null(accessor) || is.null(accessor(model)) || length(accessor(model)) == 0
  }, required %||% character(0))

  if (length(missing_fields) > 0) {
    stop_invalid_dataset(sprintf(
      "Modelo semântico não tem os campos exigidos por esta análise: %s",
      paste(missing_fields, collapse = ", ")
    ))
  }
}
