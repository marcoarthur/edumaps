# R/model/datasource/postgres_source.R
#
# DataSource que consulta o Postgres diretamente. USO RESTRITO: pipelines
# batch/offline com parâmetros controlados pelo próprio código (ex.: um
# job agendado "recalcular o resumo de todos os municípios aos domingos"),
# NUNCA a partir de parâmetros vindos direto de uma requisição HTTP de
# usuário — para isso, ver memory_source.R.
#
# Mesmo em uso batch, não hardcoda confiança: indicator_id/rede são
# checados contra o mesmo whitelist fechado usado no lado Perl
# (EduMaps::Model::Chart::School), e a query usa sempre parâmetros
# vinculados (nunca interpolação de string). Se esta fonte for exposta a
# parâmetros externos por engano no futuro, ela ainda falha fechado.

INDICATOR_WHITELIST <- c(
  "infraestrutura", "capacidade_atendimento", "capacitacao_docente",
  "diversidade_discente", "capacidade_gestora", "sustentabilidade",
  "ideb_anos_iniciais", "ideb_anos_finais", "ideb_ensino_medio",
  "nota_matematica_fund_ii", "nota_matematica_medio",
  "nota_portugues_fund_ii", "nota_portugues_medio",
  "taxa_aprovacao_fund_i", "taxa_aprovacao_fund_ii", "taxa_aprovacao_medio"
)

NETWORK_WHITELIST <- c("todas", "municipal", "estadual", "privada")

#' Cria uma fonte de dados Postgres (uso batch/offline)
#'
#' @param con conexão DBI ativa (ex.: `RPostgres::dbConnect(...)`)
#' @export
postgres_source <- function(con) {
  structure(list(con = con), class = c("postgres_source", "data_source"))
}

#' Carrega os valores de UM indicador direto do Postgres
#'
#' @param source objeto `postgres_source`
#' @param indicator_id um dos valores em `INDICATOR_WHITELIST`
#' @param rede um dos valores em `NETWORK_WHITELIST`
#' @param municipio_id inteiro ou `NULL`
#' @export
load_school_indicator.postgres_source <- function(source, indicator_id, rede = "todas", municipio_id = NULL, ...) {
  if (!(indicator_id %in% INDICATOR_WHITELIST)) {
    stop(sprintf("indicator_id desconhecido: %s", indicator_id))
  }
  if (!(rede %in% NETWORK_WHITELIST)) {
    stop(sprintf("rede desconhecida: %s", rede))
  }

  sql <- "
    SELECT re.id_escola AS school_id, re.valor AS value
    FROM analytics.ranking_escola re
    JOIN clean.censo_escolas esc ON esc.co_entidade = re.id_escola
    WHERE re.indicador_id = $1
      AND re.rede = $2
      AND ($3::int IS NULL OR esc.co_municipio = $3)
      AND esc.tp_situacao_funcionamento = 1
  "
  rows <- DBI::dbGetQuery(source$con, sql, params = list(indicator_id, rede, municipio_id))

  new_school_indicator_model(
    data = rows,
    metadata = list(
      value_label = indicator_id,
      indicator_id = indicator_id,
      rede = rede,
      municipio_id = municipio_id
    )
  )
}
