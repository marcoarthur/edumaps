# R/app/registry.R
#
# Catálogo FECHADO das análises disponíveis — deixou de ser só um
# dispatcher e passou a ser o catálogo das capacidades analíticas do
# serviço. Cada entrada descreve:
#
#   fn       - a função pura de análise: function(model, parameters) -> AnalysisResult
#   required - quais dimensões do modelo semântico a análise precisa ter
#              preenchidas (ver MODEL_ACCESSORS em app-controller.R) —
#              permite ao Controller falhar cedo, com um erro claro,
#              antes de entrar na análise em si
#   view     - renderer padrão esperado para esta análise (hoje só
#              "plotly" existe; guardar o nome já prepara terreno pra
#              quando existir mais de um renderer por análise, ou um
#              endpoint tipo /analysis que liste capacidades)
#   model_class - classe do modelo semântico que a análise consome.
#              Opcional; quando ausente assume "school_indicator_model"
#              (histogram/scatter/boxplot). O `school_profile` consome um
#              `school_profile_model` (perfil multimodal), por isso a
#              entrada declara a classe explicitamente.
#
# O Controller nunca aceita um nome de análise fora desta lista, e o
# dispatch é sempre por lookup nesta lista, nunca por string arbitrária
# avaliada como código.
#
# Adicionar uma análise nova (ex.: score_distribution, school_clusters)
# é: 1) escrever a função pura em R/analysis-*, 2) adicionar uma entrada
# aqui, 3) (se for gráfico) adicionar o builder correspondente em
# view-plotly.R.

#' @export
analysis_registry <- list(
  histogram = list(
    fn = analyze_histogram,
    required = c("value"),
    view = "plotly"
  ),
  scatter = list(
    fn = analyze_scatter,
    required = c("x", "y"),
    view = "plotly"
  ),
  boxplot = list(
    fn = analyze_boxplot,
    required = c("value", "group"),
    view = "plotly"
  ),
  school_profile = list(
    fn = analyze_school_profile,
    required = character(0),
    view = "json",
    model_class = "school_profile_model"
  ),
  school_evolution = list(
    fn = analyze_school_evolution,
    required = character(0),
    view = "json",
    model_class = "school_evolution_model"
  )
)
