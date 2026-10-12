# R/analysis-report-composto.R
#
# Execução de um assistente `composto` (#219, Fase 4), ex.: "EDA do
# município". Reaproveita os roteiros dos temas SEM mudar a sua interface:
#
#   para cada capítulo (em ordem):
#     modelo do tema (recorte do pedido ou a escola do gestor; opções fixas
#     do capítulo sobrepostas pelas do assistente) → roteiro do tema → só
#     as seções de DADOS (a redação por tema fica desligada)
#   → seções com `capitulo` (ids prefixados pelo capítulo, únicos)
#   → fontes e avisos unidos
#   → UMA chamada de LLM para o relatório inteiro (`resumo` e `leitura`
#     gerais), a partir de um pacote enxuto por capítulo.
#
# Capítulo que falha (ex.: município sem dados, consulta que caiu) vira um
# aviso `{tipo: "capitulo"}` e não derruba o relatório; se TODOS falharem, o
# primeiro erro sobe como no modo tema (400 do cliente, 500 da fonte).
#
# Capítulos com `recorte: escola` são opcionais: rodam sobre a escola do
# gestor (`contexto.cod_inep`) e só entram quando ela fica no território do
# pedido (mesmo município/UF/região). Sem escola, ou fora do território, o
# capítulo é omitido sem aviso.

#' Teto de caracteres do JSON enviado ao LLM no relatório em capítulos
#' @keywords internal
REPORT_LLM_MAX_CHARS_COMPOSTO <- 18000

#' Linhas por tabela/gráfico tentadas no pacote do LLM (em ordem)
#' @keywords internal
REPORT_LLM_ROWS_COMPOSTO <- c(10L, 6L, 3L)

#' Executa um assistente composto
#'
#' @param model `report_request_model` de um assistente `composto`.
#' @param source `edubr_source` (uma sessão para todos os capítulos).
#' @param cfg configuração de [chat_config()].
#' @param llm função opcional `(system, prompt) -> texto` (testes).
#'
#' @return `analysis_result` (análise `"report"`).
#' @keywords internal
analyze_report_composto <- function(model, source, cfg, llm = NULL) {
  t0 <- proc.time()[["elapsed"]]
  ast <- model$assistente

  execs <- lapply(ast$capitulos, function(ch) report_run_capitulo(ch, model, source))

  ok <- vapply(execs, function(x) identical(x$status, "ok"), logical(1))
  falhas <- Filter(function(x) identical(x$status, "falha"), execs)
  territoriais <- Filter(function(x) identical(x$status, "ok") && is.null(x$capitulo$recorte), execs)
  if (!length(territoriais) && length(falhas)) {
    # Nenhum capítulo do território saiu: o erro é do pedido ou da fonte.
    stop(falhas[[1]]$erro)
  }

  recorte <- if (length(territoriais)) {
    territoriais[[1]]$dados$recorte
  } else {
    report_recorte_static(model)
  }
  recorte_nome <- report_recorte_display(recorte)
  titulo <- sprintf("%s — %s", ast$titulo, recorte_nome)

  capitulos <- list()
  secoes_dados <- list()
  fontes <- list()
  avisos <- list()
  caps_llm <- list()
  leituras <- character()
  profundidade <- "descritiva"

  for (x in execs) {
    ch <- x$capitulo
    if (identical(x$status, "pulado")) next
    if (identical(x$status, "falha")) {
      if (is.null(ch$recorte)) {
        avisos <- report_avisos_unir(avisos, list(report_aviso_capitulo(ch, x$erro)))
      }
      next
    }
    dados <- x$dados
    if (!is.null(ch$recorte) && !report_recorte_contem(recorte, dados$recorte)) {
      next
    }
    avisos_cap <- dados$avisos
    if (!length(dados$secoes)) {
      # Capítulo vazio: um aviso só ("ficou sem dados") no lugar dos
      # `sem_dados` do roteiro; os demais avisos (ex.: cortes) continuam.
      avisos_cap <- Filter(function(a) !identical(a$tipo, "sem_dados"), avisos_cap)
    }
    avisos_cap <- lapply(avisos_cap, function(a) {
      a$mensagem <- sprintf("%s: %s", ch$titulo, a$mensagem %||% "")
      a
    })
    avisos <- report_avisos_unir(avisos, avisos_cap)
    fontes <- report_fontes_unir(fontes, dados$fontes)
    if (!length(dados$secoes)) {
      avisos <- report_avisos_unir(avisos, list(list(
        tipo = "sem_dados",
        mensagem = sprintf("O capítulo \"%s\" ficou sem dados para este recorte.", ch$titulo)
      )))
      next
    }
    if (identical(x$entry$profundidade, "profunda")) profundidade <- "profunda"
    secoes <- lapply(dados$secoes, function(s) {
      s$id <- sprintf("%s-%s", ch$id, s$id)
      s$capitulo <- ch$id
      s
    })
    capitulos[[length(capitulos) + 1L]] <- list(id = ch$id, titulo = ch$titulo, tema = ch$tema)
    caps_llm[[length(caps_llm) + 1L]] <- list(titulo = ch$titulo, secoes = secoes)
    secoes_dados <- c(secoes_dados, secoes)
    if (!is.null(dados$leitura) && nzchar(dados$leitura)) {
      leituras <- c(leituras, sprintf("**%s**\n\n%s", ch$titulo, dados$leitura))
    }
  }

  report <- list(
    titulo = titulo,
    recorte = recorte,
    recorte_nome = recorte_nome,
    tema = list(id = ast$id, titulo = ast$titulo),
    profundidade = profundidade,
    secoes = secoes_dados,
    capitulos = caps_llm,
    fontes = fontes,
    avisos = avisos,
    leitura_padrao = if (length(leituras)) {
      paste(leituras, collapse = "\n\n")
    } else {
      "- Nenhum capítulo teve dados para este recorte."
    }
  )

  system <- report_system_prompt(
    profundidade,
    report_tem_lista_escolas(report),
    complemento = c(report_prompt_composto(), ast$prompt_complemento),
    formato_resumo = paste(
      "Três a cinco parágrafos curtos (até ~300 palavras): uma visão geral",
      "e o que cada capítulo mostra de mais importante."
    )
  )
  user <- report_user_prompt_composto(report)
  texto <- report_write_text(
    report, cfg, llm, system = system, user = user,
    resumo_fn = report_resumo_composto
  )

  secoes <- c(
    list(report_section_text("resumo", "Resumo", texto$resumo)),
    secoes_dados,
    list(report_section_text("leitura", "Como ler", texto$leitura))
  )
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

  tabelas <- Filter(function(s) identical(s$tipo, "tabela"), secoes_dados)
  tables <- stats::setNames(
    lapply(tabelas, `[[`, "linhas"),
    vapply(tabelas, `[[`, character(1), "id")
  )
  fontes_df <- if (length(fontes)) {
    do.call(rbind, lapply(fontes, as.data.frame, stringsAsFactors = FALSE))
  } else {
    data.frame()
  }

  new_analysis_result(
    analysis = "report",
    parameters = list(
      assistente = ast$id,
      nivel = model$nivel,
      codigo = model$codigo,
      tema = ast$id,
      opcoes = model$opcoes,
      capitulos = vapply(capitulos, `[[`, character(1), "id")
    ),
    data = fontes_df,
    metrics = list(
      secoes = length(secoes),
      avisos = length(avisos),
      chamadas = rastreio$chamadas,
      capitulos = length(capitulos),
      capitulos_falhos = length(falhas)
    ),
    tables = tables,
    metadata = list(
      titulo = titulo,
      gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      recorte = recorte,
      assistente = list(id = ast$id, titulo = ast$titulo, modo = ast$modo),
      tema = report$tema,
      capitulos = capitulos,
      secoes = secoes,
      fontes = fontes,
      avisos = avisos,
      rastreio = rastreio
    )
  )
}

#' Executa UM capítulo (roteiro do tema, sem redação)
#'
#' @return `list(status = "ok"|"falha"|"pulado", capitulo, entry, dados?,
#'   erro?)`.
#' @keywords internal
report_run_capitulo <- function(ch, model, source) {
  entry <- report_catalog()[[ch$tema]]
  out <- list(status = "pulado", capitulo = ch, entry = entry)

  if (identical(ch$recorte, "escola")) {
    cod <- report_codigo_texto((model$contexto %||% list())$cod_inep)
    if (is.null(cod) || !grepl("^[0-9]{8}$", cod)) {
      return(out)
    }
    geo <- list(nivel = "escola", codigo = cod, uf = NA_character_, regiao = NA_character_)
  } else {
    geo <- list(nivel = model$nivel, codigo = model$codigo, uf = model$uf, regiao = model$regiao)
  }

  # Opções: as fixas do capítulo, sobrepostas pelas escolhidas no assistente
  # que o tema aceita (valores nulos não sobrepõem).
  escolhidas <- model$opcoes[intersect(names(model$opcoes), names(entry$opcoes))]
  escolhidas <- Filter(Negate(is.null), escolhidas)
  opcoes <- utils::modifyList(ch$opcoes %||% list(), escolhidas)

  res <- tryCatch(
    {
      m <- report_model_tema(geo, entry, opcoes, model$contexto)
      list(status = "ok", dados = entry$roteiro(m, source))
    },
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] capítulo %s falhou no /report: %s\n",
        ch$id, conditionMessage(e)
      ))
      list(status = "falha", erro = e)
    }
  )
  utils::modifyList(out, res)
}

#' A escola (recorte do capítulo) fica no território do pedido?
#'
#' O eduBR identifica o município da escola pelo NOME (sem código); a
#' comparação ignora caixa e acentos, e confere a UF.
#'
#' @keywords internal
report_recorte_contem <- function(territorio, escola) {
  uf <- escola$uf %||% NA_character_
  if (is.na(uf) || !nzchar(uf)) return(FALSE)
  switch(territorio$nivel,
    municipio = identical(uf, territorio$uf) &&
      identical(report_nome_chave(escola$municipio), report_nome_chave(territorio$nome)),
    uf = identical(uf, territorio$codigo),
    regiao = identical(report_uf_regiao(uf), territorio$codigo),
    FALSE
  )
}

#' Chave de comparação de nomes (minúsculas, sem acentos nem espaços extras)
#' @keywords internal
report_nome_chave <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[[1]])) return(NA_character_)
  # chartr com a tabela explícita: o ASCII//TRANSLIT do iconv depende do
  # locale (em C.UTF-8 pode trocar acentos por "?").
  y <- tolower(enc2utf8(as.character(x[[1]])))
  y <- chartr(
    "\u00e1\u00e0\u00e2\u00e3\u00e4\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ee\u00ef\u00f3\u00f2\u00f4\u00f5\u00f6\u00fa\u00f9\u00fb\u00fc\u00e7\u00f1",
    "aaaaaeeeeiiiiooooouuuucn", y
  )
  y <- gsub("[^a-z0-9 ]", " ", y)
  trimws(gsub("[[:space:]]+", " ", y))
}

#' Aviso de capítulo que falhou (sem detalhes internos)
#'
#' Erros do cliente (ex.: "Etapa não ofertada") têm mensagem pensada para o
#' gestor; os demais (consulta que caiu, bug) têm texto genérico, sem nomes
#' de ferramentas.
#'
#' @keywords internal
report_aviso_capitulo <- function(ch, erro) {
  motivo <- if (inherits(erro, "edumaps_client_error")) {
    conditionMessage(erro)
  } else {
    "a consulta aos dados falhou."
  }
  list(
    tipo = "capitulo",
    mensagem = sprintf("O capítulo \"%s\" não pôde ser gerado: %s", ch$titulo, motivo)
  )
}

#' União de avisos (sem repetir tipo + mensagem)
#' @keywords internal
report_avisos_unir <- function(avisos, novos) {
  chave <- function(a) paste(a$tipo %||% "", a$mensagem %||% "", sep = "\r")
  vistos <- vapply(avisos, chave, character(1))
  for (a in novos) {
    k <- chave(a)
    if (!k %in% vistos) {
      avisos[[length(avisos) + 1L]] <- a
      vistos <- c(vistos, k)
    }
  }
  avisos
}

#' União de fontes (sem repetir fontes idênticas)
#' @keywords internal
report_fontes_unir <- function(fontes, novas) {
  for (f in novas) {
    if (!any(vapply(fontes, identical, logical(1), f))) {
      fontes[[length(fontes) + 1L]] <- f
    }
  }
  fontes
}

#' Regras de redação do relatório em capítulos
#' @keywords internal
report_prompt_composto <- function() {
  paste(
    "## Relatório em capítulos",
    "",
    "- Os DADOS trazem vários capítulos (`capitulos`), cada um com as suas",
    "  seções. Os textos que você escreve são os ÚNICOS do relatório: cubra",
    "  todos os capítulos, citando-os pelo título.",
    "- Cada capítulo tem a sua fonte e edição; não misture números de",
    "  capítulos diferentes numa mesma conta ou comparação.",
    sep = "\n"
  )
}

#' Pacote de dados do LLM para o relatório em capítulos
#'
#' Enxuto por capítulo: começa com até 10 linhas por tabela/gráfico e reduz
#' (6, 3) até caber em [REPORT_LLM_MAX_CHARS_COMPOSTO]; só então corta.
#'
#' @keywords internal
report_llm_payload_composto <- function(report) {
  txt <- ""
  for (max_rows in REPORT_LLM_ROWS_COMPOSTO) {
    capitulos <- lapply(report$capitulos, function(cp) {
      secoes <- report_llm_secoes(cp$secoes, max_rows)
      # Sem ids internos (tema/capítulo) no pacote: o LLM cita pelo título.
      secoes <- lapply(secoes, function(s) s[setdiff(names(s), c("id", "capitulo"))])
      list(titulo = cp$titulo, secoes = secoes)
    })
    payload <- list(
      titulo = report$titulo,
      recorte = report$recorte,
      capitulos = capitulos,
      fontes = report_llm_fontes(report$fontes),
      avisos = report_llm_avisos(report$avisos)
    )
    txt <- as.character(jsonlite::toJSON(
      payload, auto_unbox = TRUE, na = "null", null = "null", digits = 4,
      dataframe = "rows"
    ))
    if (nchar(txt) <= REPORT_LLM_MAX_CHARS_COMPOSTO) {
      return(txt)
    }
  }
  substr(txt, 1, REPORT_LLM_MAX_CHARS_COMPOSTO)
}

#' Prompt do usuário para a redação geral do relatório em capítulos
#' @keywords internal
report_user_prompt_composto <- function(report) {
  titulos <- vapply(report$capitulos, `[[`, character(1), "titulo")
  paste0(
    "Redija o [RESUMO] e a [LEITURA] do relatório \"", report$titulo, "\"",
    if (length(titulos)) {
      paste0(", que reúne os capítulos: ", paste(titulos, collapse = "; "))
    },
    ".\n\nDADOS (JSON):\n", report_llm_payload_composto(report)
  )
}

#' Resumo determinístico do relatório em capítulos (mock e degradação)
#'
#' Os indicadores principais de cada capítulo (até 4), sem interpretação.
#'
#' @keywords internal
report_resumo_composto <- function(report, prefixo = NULL) {
  blocos <- vapply(report$capitulos, function(cp) {
    kpis <- Filter(function(s) identical(s$tipo, "indicadores"), cp$secoes)
    linhas <- if (length(kpis)) {
      vapply(utils::head(kpis[[1]]$itens, 4L), function(it) {
        ref <- if (!is.null(it$referencia)) {
          sprintf(" (%s: %s)", it$referencia$rotulo, report_format_value(it$referencia$valor, it$formato))
        } else {
          ""
        }
        sprintf("- %s: **%s**%s", it$rotulo, report_format_value(it$valor, it$formato), ref)
      }, character(1))
    } else {
      "- Os dados estão nas tabelas e gráficos do capítulo."
    }
    paste0("**", cp$titulo, "**\n\n", paste(linhas, collapse = "\n"))
  }, character(1))

  fontes <- vapply(report$fontes, function(f) {
    sprintf("%s (%s; %s; n = %s)", f$descricao %||% f$edicao, f$edicao, f$escopo, f$n)
  }, character(1))

  partes <- c(
    prefixo,
    if (length(blocos)) {
      c(sprintf("Principais números de **%s**, por capítulo:", report$recorte_nome), blocos)
    } else {
      sprintf("Não há dados para **%s** com as opções escolhidas.", report$recorte_nome)
    },
    if (length(fontes)) paste0("Fontes: ", paste(fontes, collapse = "; "), ".")
  )
  paste(partes, collapse = "\n\n")
}
