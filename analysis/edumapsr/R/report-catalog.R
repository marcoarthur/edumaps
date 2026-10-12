# R/report-catalog.R
#
# Catálogo de temas do Assistente de Relatório (issue #219, contrato da
# onda 1). Cada tema diz em que níveis de recorte (`geotag.nivel`) faz
# sentido, que opções aceita e que ferramentas do eduBR o seu roteiro chama.
# O catálogo é derivado do que as ferramentas realmente aceitam:
#
#   - `ideb_agregado` e `tendencia_ideb_regiao` aceitam só as quatro redes
#     (sem "publica"); `redes_municipio`, `docentes_rede` e `perfil_gestor`
#     aceitam também "publica" (Federal + Estadual + Municipal);
#   - `perfil_gestor` agrega por UF, região ou Brasil (não por município);
#   - `tendencia_ideb_regiao` só existe por macrorregião.
#
# O campo `profundidade` e o argumento `perfil` de [report_temas()] preparam
# a separação futura gestor × pesquisador (plano §10): hoje há um único
# perfil e só a profundidade "descritiva".

#' Níveis de recorte aceitos pelo relatório
#' @keywords internal
REPORT_NIVEIS <- c("municipio", "uf", "regiao", "escola")

#' Etapas do IDEB aceitas (a primeira é o padrão)
#' @keywords internal
REPORT_ETAPAS <- c("fundamental_i", "fundamental_ii", "ensino_medio")

#' Redes aceitas pelas ferramentas de IDEB
#' @keywords internal
REPORT_REDES <- c("Municipal", "Estadual", "Federal", "Privada")

#' Redes aceitas pelas ferramentas de Censo (com "publica")
#' @keywords internal
REPORT_REDES_PUBLICA <- c(REPORT_REDES, "publica")

#' Catálogo de temas (interno, com roteiro)
#'
#' Construído dentro da função (não no topo do arquivo) para referenciar os
#' roteiros só depois do pacote carregado (ver app-controller.R).
#'
#' @keywords internal
report_catalog <- function() {
  opt_etapa <- list(valores = REPORT_ETAPAS, padrao = "fundamental_i", obrigatoria = FALSE)
  opt_rede <- list(valores = REPORT_REDES, padrao = NULL, obrigatoria = FALSE)
  opt_rede_pub <- list(valores = REPORT_REDES_PUBLICA, padrao = NULL, obrigatoria = FALSE)

  list(
    ideb_territorio = list(
      id = "ideb_territorio",
      titulo = "IDEB do território",
      descricao = paste(
        "IDEB médio das escolas do território numa etapa e edição, comparado",
        "ao nível de cima (estado ou região) e separado por rede."
      ),
      niveis = c("municipio", "uf", "regiao"),
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = "ideb_agregado",
      opcoes = list(etapa = opt_etapa, rede = opt_rede),
      roteiro = roteiro_ideb_territorio
    ),
    redes_territorio = list(
      id = "redes_territorio",
      titulo = "Redes de ensino",
      descricao = paste(
        "Escolas, matrículas e professores de cada rede (federal, estadual,",
        "municipal e privada) no território."
      ),
      niveis = c("municipio", "uf", "regiao"),
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = "redes_municipio",
      opcoes = list(rede = opt_rede_pub),
      roteiro = roteiro_redes_territorio
    ),
    docentes_territorio = list(
      id = "docentes_territorio",
      titulo = "Professores",
      descricao = paste(
        "Quantos professores atuam no território e qual a sua formação e o",
        "seu vínculo, por rede, comparados ao nível de cima."
      ),
      niveis = c("municipio", "uf", "regiao"),
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = "docentes_rede",
      opcoes = list(rede = opt_rede_pub),
      roteiro = roteiro_docentes_territorio
    ),
    gestores_territorio = list(
      id = "gestores_territorio",
      titulo = "Perfil dos gestores escolares",
      descricao = paste(
        "Características mais comuns dos gestores escolares (formação,",
        "faixa etária, forma de acesso ao cargo...) no território."
      ),
      niveis = c("uf", "regiao"),
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = "perfil_gestor",
      opcoes = list(rede = opt_rede_pub),
      roteiro = roteiro_gestores_territorio
    ),
    tendencia_ideb = list(
      id = "tendencia_ideb",
      titulo = "Tendência do IDEB",
      descricao = paste(
        "Evolução do IDEB médio da região ao longo das edições e a tendência",
        "linear estimada, comparada às demais regiões."
      ),
      niveis = "regiao",
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = c("tendencia_ideb_regiao", "ideb_agregado"),
      opcoes = list(etapa = opt_etapa, rede = opt_rede),
      roteiro = roteiro_tendencia_ideb
    ),
    minha_escola = list(
      id = "minha_escola",
      titulo = "Minha escola diante do município e do estado",
      descricao = paste(
        "Infraestrutura, IDEB e professores da escola comparados às escolas",
        "da mesma rede no município e no estado."
      ),
      niveis = "escola",
      profundidade = "descritiva",
      perfis = "gestor",
      ferramentas = "perfil_escola",
      opcoes = list(),
      roteiro = roteiro_minha_escola
    )
  )
}

#' Temas disponíveis (visão pública do catálogo)
#'
#' Lista os temas do Assistente de Relatório, opcionalmente filtrados pelo
#' nível do recorte. É o corpo de `GET /report/temas`.
#'
#' @param nivel `NULL` (todos) ou um de `municipio`, `uf`, `regiao`,
#'   `escola`.
#' @param perfil perfil do usuário (hoje só `"gestor"`).
#'
#' @return Lista `{temas: [{id, titulo, descricao, niveis[], profundidade,
#'   opcoes: {etapa?: [..], rede?: [..]}}]}`.
#'
#' @export
report_temas <- function(nivel = NULL, perfil = "gestor") {
  if (!is.null(nivel) && !identical(nivel, "")) {
    if (!is.character(nivel) || length(nivel) != 1L || !nivel %in% REPORT_NIVEIS) {
      stop(new_client_error(
        sprintf(
          "Nível inválido: %s. Use um de: %s.",
          paste(format(nivel), collapse = ", "),
          paste(REPORT_NIVEIS, collapse = ", ")
        ),
        "invalid_report_request"
      ))
    }
  } else {
    nivel <- NULL
  }

  catalog <- Filter(function(t) {
    perfil %in% t$perfis && (is.null(nivel) || nivel %in% t$niveis)
  }, report_catalog())

  list(temas = unname(lapply(catalog, report_tema_public)))
}

#' Visão pública de um tema (sem roteiro, com arrays como listas JSON)
#' @keywords internal
report_tema_public <- function(tema) {
  opcoes <- lapply(tema$opcoes, function(o) as.list(o$valores))
  if (!length(opcoes)) opcoes <- structure(list(), names = character(0))
  list(
    id = tema$id,
    titulo = tema$titulo,
    descricao = tema$descricao,
    niveis = as.list(tema$niveis),
    profundidade = tema$profundidade,
    opcoes = opcoes
  )
}
