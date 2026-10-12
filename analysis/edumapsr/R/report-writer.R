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
#' @keywords internal
report_prompt_complemento <- function() {
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
    "Formato da resposta (exatamente estes dois marcadores, nesta ordem):",
    "[RESUMO]",
    "Um a dois parágrafos curtos (até ~120 palavras) com o que mais importa.",
    "[LEITURA]",
    "Três a cinco itens em lista explicando como ler os números e os seus",
    "limites.",
    sep = "\n"
  )
}

#' System prompt do relatório (persona do eduBR + complemento)
#'
#' Sem o eduBR (ex.: testes com ferramentas falsas), usa um texto curto com
#' as mesmas regras essenciais.
#'
#' @keywords internal
report_system_prompt <- function() {
  persona <- if (edubr_available()) {
    tryCatch(eduBR::prompt_persona(REPORT_PERSONA), error = function(e) NULL)
  }
  persona <- persona %||% paste(
    "Você apoia análises de educação básica no Brasil. Nunca invente números;",
    "cite edição, recorte e n; compare IDEB só na mesma edição, etapa e rede;",
    "associação não é causa."
  )
  paste(persona, report_prompt_complemento(), sep = "\n\n")
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

report_llm_payload <- function(report) {
  secoes <- lapply(report$secoes, function(s) {
    out <- s[setdiff(names(s), c("linhas", "dados", "colunas", "series", "x", "itens"))]
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
      linhas <- s$linhas
      for (c in s$colunas) {
        if (!is.null(c$id) && c$id %in% names(linhas)) {
          linhas[[c$id]] <- report_round_formato(linhas[[c$id]], c$formato)
        }
      }
      s$linhas <- linhas
      out$linhas <- utils::head(s$linhas, REPORT_LLM_MAX_ROWS)
      if (nrow(s$linhas) > REPORT_LLM_MAX_ROWS) {
        out$linhas_omitidas <- nrow(s$linhas) - REPORT_LLM_MAX_ROWS
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
      out$dados <- utils::head(dados, REPORT_LLM_MAX_ROWS)
    }
    out
  })
  payload <- list(
    titulo = report$titulo,
    recorte = report$recorte,
    tema = report$tema,
    secoes = secoes,
    # sem o nome interno da ferramenta: o LLM cita a fonte pela descrição
    fontes = lapply(report$fontes, function(f) f[setdiff(names(f), "ferramenta")]),
    avisos = report$avisos
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

  partes <- c(
    prefixo,
    if (length(linhas)) {
      paste0("Principais números de **", report$recorte_nome, "**:\n\n", paste(linhas, collapse = "\n"))
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
#'
#' @return `list(resumo, leitura, llm = "ok"|"indisponivel", aviso = NULL|aviso)`.
#'
#' @keywords internal
report_write_text <- function(report, cfg, llm = NULL) {
  tem_dados <- length(Filter(function(s) !identical(s$tipo, "texto"), report$secoes)) > 0

  if (identical(cfg$provider, "mock")) {
    return(list(
      resumo = report_resumo_deterministico(
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
      resumo = report_resumo_deterministico(report),
      leitura = report$leitura_padrao,
      llm = "ok",
      aviso = NULL
    ))
  }

  llm <- llm %||% report_llm_default(cfg)
  texto <- tryCatch(
    llm(report_system_prompt(), report_user_prompt(report)),
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
      resumo = report_resumo_deterministico(report),
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
