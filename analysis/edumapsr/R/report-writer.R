# R/report-writer.R
#
# Redação das seções de texto do Assistente de Relatório (#219).
#
# O LLM NÃO chama ferramentas: recebe os dados já estruturados (JSON enxuto
# das seções de dados, fontes e avisos) e só redige duas seções — `resumo`
# (a primeira) e `leitura` (a última, "Como ler"). O system prompt é o da
# persona `pesquisadora-educacional` do eduBR (`eduBR::prompt_persona()`),
# que traz as regras de precisão e de causalidade, mais um complemento que
# pede linguagem acessível ao gestor escolar.
#
# Falha do LLM não derruba o relatório: as seções de dados saem, com um
# resumo determinístico curto, `rastreio.llm = "indisponivel"` e um aviso
# `{tipo: "llm"}`. O provider `mock` gera texto determinístico (testes/e2e).

#' Teto de caracteres do JSON de dados enviado ao LLM
#' @keywords internal
REPORT_LLM_MAX_CHARS <- 9000

#' Teto de linhas por tabela/gráfico enviadas ao LLM
#' @keywords internal
REPORT_LLM_MAX_ROWS <- 20

#' Teto de caracteres de cada seção redigida
#' @keywords internal
REPORT_TEXT_MAX_CHARS <- 3000

#' Complemento do system prompt (linguagem para o gestor)
#'
#' @param extras blocos de regras adicionais (temas profundos, listas de
#'   escolas, complemento do assistente), inseridos antes do formato da
#'   resposta.
#' @param formato_resumo instrução de tamanho do [RESUMO] (o relatório em
#'   capítulos pede um resumo mais longo).
#' @keywords internal
report_prompt_complemento <- function(extras = NULL,
                                      formato_resumo = "Um a dois parágrafos curtos (até ~120 palavras) com o que mais importa.") {
  paste(
    "## Assistente de Relatório do EduMaps",
    "",
    "Agora você escreve para um GESTOR ESCOLAR (diretor ou coordenador), não",
    "para uma pesquisadora. O relatório já foi montado: as tabelas e os",
    "gráficos vêm prontos nos DADOS abaixo. Você só redige dois textos curtos.",
    "",
    "Regras (as da persona continuam valendo):",
    "- Linguagem simples e direta, frases curtas, sem jargão estatístico; se",
    "  usar um termo técnico, explique em poucas palavras.",
    "- Use SOMENTE números que aparecem nos DADOS. Não faça contas próprias",
    "  (diferenças, percentuais, médias, rankings novos).",
    "- Não afirme causa: descreva o que os dados mostram.",
    "- Cite a edição/ano, o recorte e o n (fontes) dos números principais.",
    "- Números no padrão brasileiro: vírgula decimal (6,3; nunca 6.3) e IDEB",
    "  com uma casa decimal, como nas tabelas.",
    "- Não mencione nomes internos de ferramentas, tabelas ou colunas (ex.:",
    "  ideb_agregado, co_municipio): cite a fonte pela descrição e edição",
    "  (ex.: \"IDEB 2023, municípios de SP\").",
    "- Não comente estas regras nem a formatação do relatório no texto.",
    "- Se houver avisos (dados cortados, sem dados), mencione-os.",
    "- Markdown simples: parágrafos, listas com '-', **negrito**. Sem HTML,",
    "  links, imagens, tabelas ou títulos com '#'.",
    "",
    if (length(extras)) paste0(paste(extras, collapse = "\n\n"), "\n"),
    "Formato da resposta (exatamente estes dois marcadores, nesta ordem):",
    "[RESUMO]",
    formato_resumo,
    "[LEITURA]",
    "Três a cinco itens em lista explicando como ler os números e os seus",
    "limites.",
    sep = "\n"
  )
}

#' Complemento do prompt para temas profundos (regressão, listas de escolas)
#'
#' Contrato da Fase 2: associação não é causa, cite o n, não ranqueie como
#' julgamento de qualidade.
#'
#' @keywords internal
report_prompt_profunda <- function() {
  paste(
    "## Temas aprofundados",
    "",
    "- Associação NÃO é causa: diga \"anda junto com\", \"está associado a\";",
    "  nunca \"melhora\", \"causa\", \"faz subir\" ou \"explica\".",
    "- Cite o n (quantas escolas entraram) junto dos resultados principais.",
    "- Não ranqueie escolas nem territórios como julgamento de qualidade",
    "  (\"melhor\", \"pior\", \"fraca\"): a posição numa lista só descreve onde",
    "  a nota está, e o IDEB não mede tudo o que a escola faz.",
    "- Em associações, \"segurança baixa\" ou \"sem relação clara\" significa",
    "  que os dados não permitem afirmar nada sobre aquele item.",
    sep = "\n"
  )
}

#' Complemento do prompt para relatórios com lista de escolas
#' @keywords internal
report_prompt_nomes <- function() {
  paste(
    "## Escolas citadas",
    "",
    "- NÃO cite nomes de escolas, exceto a do próprio gestor (marcada com",
    "  \"sua_escola\": true nos DADOS). Fale das demais de forma agregada",
    "  (quantas, faixa de notas, redes, municípios).",
    sep = "\n"
  )
}

#' System prompt do relatório (persona do eduBR + complemento)
#'
#' Sem o eduBR (ex.: testes com ferramentas falsas), usa um texto curto com
#' as mesmas regras essenciais.
#'
#' @param profundidade `"descritiva"` ou `"profunda"` (acrescenta as regras
#'   de [report_prompt_profunda()]).
#' @param lista_escolas o relatório lista escolas de terceiros? Acrescenta
#'   [report_prompt_nomes()].
#' @param complemento blocos extras (ex.: regras do relatório em capítulos e
#'   o `prompt_complemento` do assistente, Fase 4).
#' @param formato_resumo ver [report_prompt_complemento()]; `NULL` = padrão.
#'
#' @keywords internal
report_system_prompt <- function(profundidade = "descritiva", lista_escolas = FALSE,
                                 complemento = NULL, formato_resumo = NULL) {
  persona <- if (edubr_available()) {
    tryCatch(eduBR::prompt_persona(REPORT_PERSONA), error = function(e) NULL)
  }
  persona <- persona %||% paste(
    "Você apoia análises de educação básica no Brasil. Nunca invente números;",
    "cite edição, recorte e n; compare IDEB só na mesma edição, etapa e rede;",
    "associação não é causa."
  )
  extras <- c(
    if (identical(profundidade, "profunda")) report_prompt_profunda(),
    if (isTRUE(lista_escolas)) report_prompt_nomes(),
    complemento
  )
  comp <- if (is.null(formato_resumo)) {
    report_prompt_complemento(extras)
  } else {
    report_prompt_complemento(extras, formato_resumo)
  }
  paste(persona, comp, sep = "\n\n")
}

#' O relatório tem seção com nomes de escolas a ocultar do LLM?
#' @keywords internal
report_tem_lista_escolas <- function(report) {
  any(vapply(report$secoes, function(s) length(s$.ocultar_llm) > 0, logical(1)))
}

#' Visão enxuta do relatório para o LLM (JSON)
#' @keywords internal
# Casas decimais de um formato de seção (NA = não arredondar).
report_digits_formato <- function(formato) {
  switch(formato %||% "",
         decimal1 = 1L, decimal2 = 2L, inteiro = 0L, percentual = 3L, NA_integer_)
}

# Arredonda um valor conforme o formato — o LLM vê os números como a tela os
# mostra (ex.: IDEB 5,9, não 5,94) e não "reinventa" precisão.
report_round_formato <- function(x, formato) {
  d <- report_digits_formato(formato)
  if (is.na(d) || !is.numeric(x)) return(x)
  round(x, d)
}

# Linhas de uma tabela para o LLM: arredondadas pelo formato, no máximo
# REPORT_LLM_MAX_ROWS (as linhas `_destaque` entram sempre), com a marca
# `_destaque` como `sua_escola` e sem as colunas `.ocultar_llm` (nomes de
# escolas de terceiros) fora das linhas destacadas.
report_llm_linhas <- function(s, max_rows = REPORT_LLM_MAX_ROWS) {
  linhas <- s$linhas
  for (c in s$colunas) {
    if (!is.null(c$id) && c$id %in% names(linhas)) {
      linhas[[c$id]] <- report_round_formato(linhas[[c$id]], c$formato)
    }
  }
  destaque <- if (REPORT_DESTAQUE %in% names(linhas)) {
    linhas[[REPORT_DESTAQUE]] %in% TRUE
  } else {
    rep(FALSE, nrow(linhas))
  }
  idx <- seq_len(min(nrow(linhas), max_rows))
  idx <- sort(unique(c(idx, which(destaque))))
  rows <- report_json_rows(linhas[idx, setdiff(names(linhas), REPORT_DESTAQUE), drop = FALSE])
  ocultar <- s$.ocultar_llm %||% character()
  lapply(seq_along(rows), function(k) {
    r <- rows[[k]]
    if (destaque[idx[k]]) {
      r$sua_escola <- TRUE
    } else if (length(ocultar)) {
      r[intersect(ocultar, names(r))] <- NULL
    }
    r
  })
}

# Seções de dados no formato enxuto do LLM (sem campos internos, números
# arredondados pelo formato, no máximo `max_rows` linhas por tabela/gráfico).
report_llm_secoes <- function(secoes, max_rows = REPORT_LLM_MAX_ROWS) {
  lapply(secoes, function(s) {
    out <- s[setdiff(names(s), c("linhas", "dados", "colunas", "series", "x", "itens"))]
    out <- out[!startsWith(names(out), ".")]
    if (identical(s$tipo, "associacoes")) {
      out$itens <- unname(s$itens)
    }
    if (identical(s$tipo, "indicadores")) {
      out$itens <- lapply(s$itens, function(it) {
        it$valor <- report_round_formato(it$valor, it$formato)
        if (!is.null(it$referencia)) {
          it$referencia$valor <- report_round_formato(it$referencia$valor, it$formato)
        }
        it
      })
    }
    if (identical(s$tipo, "tabela")) {
      out$colunas <- vapply(s$colunas, function(c) sprintf("%s=%s", c$id, c$rotulo), character(1))
      out$linhas <- report_llm_linhas(s, max_rows)
      if (nrow(s$linhas) > length(out$linhas)) {
        out$linhas_omitidas <- nrow(s$linhas) - length(out$linhas)
      }
    }
    if (identical(s$tipo, "grafico")) {
      out$series <- vapply(s$series, function(c) sprintf("%s=%s", c$id, c$rotulo), character(1))
      dados <- s$dados
      for (sr in s$series) {
        if (!is.null(sr$id) && sr$id %in% names(dados)) {
          dados[[sr$id]] <- report_round_formato(dados[[sr$id]], sr$formato %||% s$formato)
        }
      }
      out$dados <- utils::head(dados, max_rows)
    }
    out
  })
}

# Fontes e avisos para o LLM: sem o nome interno da ferramenta e sem o
# prefixo "[ferramenta] " das mensagens de aviso.
report_llm_fontes <- function(fontes) {
  lapply(fontes, function(f) f[setdiff(names(f), "ferramenta")])
}

report_llm_avisos <- function(avisos) {
  lapply(avisos, function(a) {
    a$mensagem <- sub("^\\[[A-Za-z0-9_]+\\] ", "", a$mensagem %||% "")
    a
  })
}

report_llm_payload <- function(report) {
  secoes <- report_llm_secoes(report$secoes)
  payload <- list(
    titulo = report$titulo,
    recorte = report$recorte,
    tema = report$tema,
    secoes = secoes,
    # sem o nome interno da ferramenta: o LLM cita a fonte pela descrição
    fontes = report_llm_fontes(report$fontes),
    avisos = report_llm_avisos(report$avisos)
  )
  txt <- as.character(jsonlite::toJSON(
    payload, auto_unbox = TRUE, na = "null", null = "null", digits = 4,
    dataframe = "rows"
  ))
  if (nchar(txt) > REPORT_LLM_MAX_CHARS) {
    txt <- substr(txt, 1, REPORT_LLM_MAX_CHARS)
  }
  txt
}

#' Prompt do usuário para a redação
#' @keywords internal
report_user_prompt <- function(report) {
  paste0(
    "Redija o [RESUMO] e a [LEITURA] do relatório \"", report$titulo, "\".\n\n",
    "DADOS (JSON):\n", report_llm_payload(report)
  )
}

#' Chamada padrão ao LLM do painel (via [chat_llm()])
#' @keywords internal
report_llm_default <- function(cfg) {
  force(cfg)
  function(system, prompt) {
    chat <- chat_llm(cfg)
    chat$set_system_prompt(system)
    as.character(chat$chat(prompt, echo = "none"))
  }
}

#' Separa a resposta do LLM em resumo e leitura
#'
#' @return `list(resumo, leitura)`; `leitura` pode ser `NULL` (marcador
#'   ausente).
#' @keywords internal
report_parse_llm <- function(texto) {
  texto <- paste(texto, collapse = "\n")
  # Marcadores "[RESUMO]"/"[LEITURA]" (pedidos no prompt) ou, na falta,
  # linhas de título "Resumo"/"Como ler"/"Leitura".
  pat <- paste0(
    "(?im)\\[(RESUMO|LEITURA|COMO LER)\\]|",
    "^[#*[:space:]]*(RESUMO|LEITURA|COMO LER)[*:[:space:]]*$"
  )
  m <- gregexpr(pat, texto, perl = TRUE)[[1]]
  if (m[1] < 0) {
    resumo <- report_sanitize_markdown(texto)
    return(list(resumo = if (nzchar(resumo)) resumo else NULL, leitura = NULL))
  }
  len <- attr(m, "match.length")
  marcas <- toupper(gsub("[^A-Za-z ]", "", regmatches(texto, list(m))[[1]]))
  marcas <- trimws(marcas)
  ini <- m + len
  fim <- c(m[-1] - 1L, nchar(texto))
  partes <- mapply(function(a, b) substr(texto, a, b), ini, fim, USE.NAMES = FALSE)
  pega <- function(nomes) {
    i <- which(marcas %in% nomes)
    if (!length(i)) return(NULL)
    v <- report_sanitize_markdown(partes[[i[1]]])
    if (nzchar(v)) v else NULL
  }
  resumo <- pega("RESUMO")
  # Texto antes do primeiro marcador vale como resumo, se o marcador faltar.
  if (is.null(resumo) && m[1] > 1) {
    v <- report_sanitize_markdown(substr(texto, 1, m[1] - 1L))
    if (nzchar(v)) resumo <- v
  }
  list(resumo = resumo, leitura = pega(c("LEITURA", "COMO LER")))
}

#' Reduz o markdown do LLM ao subconjunto seguro do `markdownSimples.js`
#'
#' Remove HTML, imagens, links (fica o texto) e blocos de código; títulos
#' viram `##`; limita o tamanho.
#'
#' @keywords internal
report_sanitize_markdown <- function(x) {
  x <- paste(x, collapse = "\n")
  x <- gsub("```[^`]*```", "", x, perl = TRUE)
  x <- gsub("!\\[[^]]*\\]\\([^)]*\\)", "", x, perl = TRUE)
  x <- gsub("\\[([^]]+)\\]\\([^)]*\\)", "\\1", x, perl = TRUE)
  x <- gsub("<[^>]+>", "", x, perl = TRUE)
  x <- gsub("(?m)^#{1,6}[[:space:]]*", "## ", x, perl = TRUE)
  x <- gsub("\n{3,}", "\n\n", x)
  x <- trimws(x)
  if (nchar(x) > REPORT_TEXT_MAX_CHARS) {
    x <- paste0(trimws(substr(x, 1, REPORT_TEXT_MAX_CHARS)), "…")
  }
  x
}

#' Resumo determinístico (mock e degradação)
#'
#' Lista os indicadores principais e as fontes, sem interpretação.
#'
#' @keywords internal
report_resumo_deterministico <- function(report, prefixo = NULL) {
  kpis <- Filter(function(s) identical(s$tipo, "indicadores"), report$secoes)
  linhas <- character()
  if (length(kpis)) {
    for (it in kpis[[1]]$itens) {
      ref <- if (!is.null(it$referencia)) {
        sprintf(" (%s: %s)", it$referencia$rotulo, report_format_value(it$referencia$valor, it$formato))
      } else {
        ""
      }
      linhas <- c(linhas, sprintf("- %s: **%s**%s", it$rotulo, report_format_value(it$valor, it$formato), ref))
    }
  }
  fontes <- vapply(report$fontes, function(f) {
    sprintf("%s (%s; %s; n = %s)", f$descricao %||% f$edicao, f$edicao, f$escopo, f$n)
  }, character(1))

  # Sem indicadores: associações (regressão) em palavras, ou só a menção
  # às tabelas quando há outras seções de dados.
  assoc <- Filter(function(s) identical(s$tipo, "associacoes"), report$secoes)
  cabecalho <- paste0("Principais números de **", report$recorte_nome, "**:")
  if (!length(linhas) && length(assoc)) {
    cabecalho <- paste0(
      "O que anda junto com o IDEB em **", report$recorte_nome,
      "** (associação, não causa):"
    )
    dir_txt <- c(
      maior = "IDEB maior", menor = "IDEB menor",
      sem_relacao_clara = "sem relação clara"
    )
    linhas <- vapply(assoc[[1]]$itens, function(it) {
      sprintf(
        "- %s%s: %s (segurança %s; n = %s)",
        it$rotulo, if (!is.null(it$corte)) sprintf(" (%s)", it$corte) else "",
        dir_txt[[it$direcao]], sub("media", "média", it$seguranca, fixed = TRUE),
        report_format_value(it$n, "inteiro")
      )
    }, character(1))
  }
  outras <- Filter(function(s) !s$tipo %in% c("texto", "indicadores"), report$secoes)

  partes <- c(
    prefixo,
    if (length(linhas)) {
      paste0(cabecalho, "\n\n", paste(linhas, collapse = "\n"))
    } else if (length(outras)) {
      sprintf("Os dados de **%s** estão nas tabelas e gráficos abaixo.", report$recorte_nome)
    } else {
      sprintf("Não há dados para **%s** neste tema com as opções escolhidas.", report$recorte_nome)
    },
    if (length(fontes)) paste0("Fontes: ", paste(fontes, collapse = "; "), ".")
  )
  paste(partes, collapse = "\n\n")
}

#' Redige as seções de texto do relatório
#'
#' @param report lista com `titulo`, `recorte`, `recorte_nome`, `tema`,
#'   `secoes` (de dados), `fontes`, `avisos` e `leitura_padrao`.
#' @param cfg configuração de [chat_config()].
#' @param llm função opcional `(system, prompt) -> texto` (injeção em testes);
#'   padrão: o provedor do painel via [chat_llm()].
#' @param system,user prompts prontos (relatório em capítulos, Fase 4);
#'   `NULL` = os do relatório de um tema.
#' @param resumo_fn função `(report, prefixo)` do resumo determinístico (mock
#'   e degradação).
#'
#' @return `list(resumo, leitura, llm = "ok"|"indisponivel", aviso = NULL|aviso)`.
#'
#' @keywords internal
report_write_text <- function(report, cfg, llm = NULL, system = NULL, user = NULL,
                              resumo_fn = report_resumo_deterministico) {
  tem_dados <- length(Filter(function(s) !identical(s$tipo, "texto"), report$secoes)) > 0

  if (identical(cfg$provider, "mock")) {
    return(list(
      resumo = resumo_fn(
        report, "Modo demonstração (sem modelo de linguagem)."
      ),
      leitura = report$leitura_padrao,
      llm = "ok",
      aviso = NULL
    ))
  }

  # Sem dados não há o que redigir: evita gastar uma chamada ao modelo.
  if (!tem_dados) {
    return(list(
      resumo = resumo_fn(report, NULL),
      leitura = report$leitura_padrao,
      llm = "ok",
      aviso = NULL
    ))
  }

  llm <- llm %||% report_llm_default(cfg)
  texto <- tryCatch(
    llm(
      system %||% report_system_prompt(
        report$profundidade %||% "descritiva",
        report_tem_lista_escolas(report),
        complemento = report$prompt_complemento
      ),
      user %||% report_user_prompt(report)
    ),
    error = function(e) {
      cat(sprintf(
        "[edumapsAnalytics] LLM indisponível no /report: %s\n",
        conditionMessage(e)
      ))
      NULL
    }
  )
  partes <- if (!is.null(texto)) report_parse_llm(texto)

  if (is.null(partes) || is.null(partes$resumo)) {
    return(list(
      resumo = resumo_fn(report, NULL),
      leitura = report$leitura_padrao,
      llm = "indisponivel",
      aviso = list(
        tipo = "llm",
        mensagem = paste(
          "O modelo de linguagem não respondeu; o resumo abaixo foi gerado",
          "automaticamente a partir dos dados."
        )
      )
    ))
  }

  list(
    resumo = partes$resumo,
    leitura = partes$leitura %||% report$leitura_padrao,
    llm = "ok",
    aviso = NULL
  )
}
