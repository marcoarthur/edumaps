# R/model-semantic-report-request-model.R
#
# Modelo semântico do PEDIDO de relatório (Assistente de Relatório, #219).
#
# Recebe o payload cru de `POST /report` e devolve um `report_request_model`
# validado e normalizado: recorte (`geotag`), tema do catálogo, opções com
# padrões aplicados e contexto. Toda falha aqui é ERRO DO CLIENTE (400),
# com a classe `invalid_report_request`.
#
# O território é conhecido sem consultar o banco: código IBGE → UF (dois
# primeiros dígitos), UF → macrorregião. O nome do município ou da escola é
# resolvido depois, pelo roteiro (via eduBR).

#' UFs: código IBGE (2 dígitos) → sigla
#' @keywords internal
REPORT_UF_CODIGOS <- c(
  "11" = "RO", "12" = "AC", "13" = "AM", "14" = "RR", "15" = "PA",
  "16" = "AP", "17" = "TO", "21" = "MA", "22" = "PI", "23" = "CE",
  "24" = "RN", "25" = "PB", "26" = "PE", "27" = "AL", "28" = "SE",
  "29" = "BA", "31" = "MG", "32" = "ES", "33" = "RJ", "35" = "SP",
  "41" = "PR", "42" = "SC", "43" = "RS", "50" = "MS", "51" = "MT",
  "52" = "GO", "53" = "DF"
)

#' UFs: sigla → nome
#' @keywords internal
REPORT_UF_NOMES <- c(
  RO = "Rondônia", AC = "Acre", AM = "Amazonas", RR = "Roraima",
  PA = "Pará", AP = "Amapá", TO = "Tocantins", MA = "Maranhão",
  PI = "Piauí", CE = "Ceará", RN = "Rio Grande do Norte", PB = "Paraíba",
  PE = "Pernambuco", AL = "Alagoas", SE = "Sergipe", BA = "Bahia",
  MG = "Minas Gerais", ES = "Espírito Santo", RJ = "Rio de Janeiro",
  SP = "São Paulo", PR = "Paraná", SC = "Santa Catarina",
  RS = "Rio Grande do Sul", MS = "Mato Grosso do Sul", MT = "Mato Grosso",
  GO = "Goiás", DF = "Distrito Federal"
)

#' Macrorregiões: sigla → nome (grafia do eduBR em `nome_regiao`)
#' @keywords internal
REPORT_REGIOES <- c(
  N = "Norte", NE = "Nordeste", SE = "Sudeste", S = "Sul", CO = "Centro-oeste"
)

#' Macrorregião (sigla) de uma UF
#' @keywords internal
report_uf_regiao <- function(uf) {
  switch(uf,
    RO = , AC = , AM = , RR = , PA = , AP = , TO = "N",
    MA = , PI = , CE = , RN = , PB = , PE = , AL = , SE = , BA = "NE",
    MG = , ES = , RJ = , SP = "SE",
    PR = , SC = , RS = "S",
    MS = , MT = , GO = , DF = "CO",
    NA_character_
  )
}

#' UFs de uma macrorregião
#' @keywords internal
report_regiao_ufs <- function(regiao) {
  ufs <- names(REPORT_UF_NOMES)
  ufs[vapply(ufs, report_uf_regiao, character(1)) == regiao]
}

#' Rótulo de exibição de uma região ("Região Sudeste")
#' @keywords internal
report_regiao_label <- function(regiao) {
  paste("Região", REPORT_REGIOES[[regiao]])
}

#' Erro de validação do pedido (cliente, 400)
#' @keywords internal
stop_invalid_report <- function(msg) {
  stop(new_client_error(msg, "invalid_report_request"))
}

#' Normaliza um código que pode vir como número no JSON
#' @keywords internal
report_codigo_texto <- function(x) {
  if (is.numeric(x) && length(x) == 1L && !is.na(x) && x == round(x)) {
    return(format(x, scientific = FALSE, trim = TRUE))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    return(trimws(x))
  }
  NULL
}

#' Constrói um `report_request_model`
#'
#' Valida o recorte (`geotag`), o tema contra o catálogo (tema × nível) e as
#' opções do tema (etapa/rede), aplicando os padrões.
#'
#' @param geotag lista `{nivel, codigo}`.
#' @param tema id do tema (ver [report_temas()]).
#' @param opcoes lista opcional de opções do tema.
#' @param contexto lista opcional (`cod_inep` da escola do gestor).
#'
#' @return Objeto S3 da classe `report_request_model` com `nivel`, `codigo`,
#'   `uf` (sigla, quando o recorte está numa UF), `regiao` (sigla), `tema`
#'   (entrada do catálogo), `opcoes` e `contexto`.
#'
#' @export
new_report_request_model <- function(geotag, tema, opcoes = NULL, contexto = NULL) {
  if (!is.list(geotag) || is.null(geotag$nivel) || is.null(geotag$codigo)) {
    stop_invalid_report("Informe o recorte: geotag = {nivel, codigo}.")
  }
  nivel <- geotag$nivel
  if (!is.character(nivel) || length(nivel) != 1L || !nivel %in% REPORT_NIVEIS) {
    stop_invalid_report(sprintf(
      "Nível de recorte inválido. Use um de: %s.",
      paste(REPORT_NIVEIS, collapse = ", ")
    ))
  }
  codigo <- report_codigo_texto(geotag$codigo)
  if (is.null(codigo)) {
    stop_invalid_report("O código do recorte deve ser um texto.")
  }

  uf <- NA_character_
  regiao <- NA_character_
  if (nivel == "municipio") {
    if (!grepl("^[0-9]{7}$", codigo) || is.na(REPORT_UF_CODIGOS[substr(codigo, 1, 2)])) {
      stop_invalid_report("Município inválido: informe o código IBGE com 7 dígitos.")
    }
    uf <- unname(REPORT_UF_CODIGOS[substr(codigo, 1, 2)])
    regiao <- report_uf_regiao(uf)
  } else if (nivel == "uf") {
    if (!codigo %in% names(REPORT_UF_NOMES)) {
      stop_invalid_report("UF inválida: informe a sigla com 2 letras maiúsculas (ex.: SP).")
    }
    uf <- codigo
    regiao <- report_uf_regiao(uf)
  } else if (nivel == "regiao") {
    if (!codigo %in% names(REPORT_REGIOES)) {
      stop_invalid_report(sprintf(
        "Região inválida: use uma de %s.",
        paste(names(REPORT_REGIOES), collapse = ", ")
      ))
    }
    regiao <- codigo
  } else if (nivel == "escola") {
    if (!grepl("^[0-9]{8}$", codigo)) {
      stop_invalid_report("Escola inválida: informe o código INEP com 8 dígitos.")
    }
    cod_inep <- report_codigo_texto((contexto %||% list())$cod_inep)
    if (!is.null(cod_inep) && !identical(cod_inep, codigo)) {
      stop_invalid_report("O recorte por escola só vale para a escola do próprio gestor.")
    }
  }

  if (!is.character(tema) || length(tema) != 1L || !nzchar(tema)) {
    stop_invalid_report("Informe o tema do relatório.")
  }
  catalog <- report_catalog()
  entry <- catalog[[tema]]
  if (is.null(entry)) {
    stop_invalid_report(sprintf("Tema desconhecido: %s.", tema))
  }
  if (!nivel %in% entry$niveis) {
    stop_invalid_report(sprintf(
      "O tema \"%s\" não está disponível para o nível %s (níveis: %s).",
      entry$titulo, nivel, paste(entry$niveis, collapse = ", ")
    ))
  }

  opcoes <- report_validate_opcoes(opcoes, entry)

  structure(
    list(
      nivel = nivel,
      codigo = codigo,
      uf = uf,
      regiao = regiao,
      tema = entry,
      opcoes = opcoes,
      contexto = contexto %||% list()
    ),
    class = "report_request_model"
  )
}

#' Valida e completa as opções de um tema
#' @keywords internal
report_validate_opcoes <- function(opcoes, entry) {
  if (is.null(opcoes) || (is.list(opcoes) && !length(opcoes))) {
    opcoes <- list()
  }
  if (!is.list(opcoes) || (length(opcoes) && is.null(names(opcoes)))) {
    stop_invalid_report("`opcoes` deve ser um objeto {etapa?, rede?}.")
  }
  # Valores nulos/vazios valem como "não informado".
  opcoes <- opcoes[!vapply(opcoes, function(v) is.null(v) || identical(v, ""), logical(1))]

  desconhecidas <- setdiff(names(opcoes), names(entry$opcoes))
  if (length(desconhecidas)) {
    stop_invalid_report(sprintf(
      "Opção não aceita pelo tema \"%s\": %s.%s",
      entry$titulo, paste(desconhecidas, collapse = ", "),
      if (length(entry$opcoes)) {
        sprintf(" Aceitas: %s.", paste(names(entry$opcoes), collapse = ", "))
      } else {
        " Este tema não tem opções."
      }
    ))
  }

  out <- list()
  for (nm in names(entry$opcoes)) {
    spec <- entry$opcoes[[nm]]
    v <- opcoes[[nm]]
    if (is.null(v)) {
      out[nm] <- list(spec$padrao)
      next
    }
    if (!is.character(v) || length(v) != 1L || !v %in% spec$valores) {
      stop_invalid_report(sprintf(
        "Valor inválido para `%s`. Use um de: %s.",
        nm, paste(spec$valores, collapse = ", ")
      ))
    }
    out[[nm]] <- v
  }
  out
}
