# R/chat-translate.R
#
# Tradutor NL->SQL do Assistente do Censo. Monta o chat (ellmer), injeta o
# system prompt com o dicionário, registra as ferramentas `run_sql` e
# `registrar_grafico` e devolve a resposta estruturada.
#
# Segurança em camadas:
#   1. O SQL gerado pelo modelo só executa via `run_sql`, contra a conexão
#      da role `edumaps_leitor` (read-only garantida NO BANCO), com
#      statement_timeout e sem grants de escrita;
#   2. `chat_validate_sql()` bloqueia keywords destrutivas, multi-statement e
#      schemas fora da whitelist (cortesia — falha de paranoia é aceitável e
#      o modelo apenas tenta de novo);
#   3. `chat_redact()` remove colunas PII do resultado antes de devolver;
#   4. Resultado truncado a `cfg$max_rows` linhas.
#
# Limite de linhas enviadas de volta ao modelo (o cliente recebe até
# max_rows; enviar 200 linhas ao modelo estoura o limite de TPM de provedores
# como o Groq). O modelo deve usar agregados no SQL quando precisar de totais.

CHAT_MAX_LINHAS_MODELO <- 15

# Orçamento de caracteres do resultado enviado ao modelo (limite de TPM).
CHAT_MAX_CHARS_MODELO <- 3500

#' Erros do chat: cliente (400)
#' @keywords internal
chat_invalid <- function(msg, class = "invalid_pergunta") {
  stop(new_client_error(msg, class))
}

#' Erros do chat: modelo de linguagem/provedor falhou (502)
#' @keywords internal
chat_provider_failed <- function(msg) {
  stop(structure(
    class = c("chat_provider_error", "error", "condition"),
    list(message = msg, call = sys.call(-1))
  ))
}

#' Erros do chat: bug interno (500)
#' @keywords internal
chat_internal_failed <- function(msg) {
  stop(structure(
    class = c("chat_internal_error", "error", "condition"),
    list(message = msg, call = sys.call(-1))
  ))
}

#' Normaliza a URL base do provedor (garante sufixo /v1)
#' @keywords internal
chat_provider_url <- function(url) {
  url <- sub("/+$", "", url)
  if (!grepl("(/v1)$", url)) paste0(url, "/v1") else url
}

#' Instancia o chat do provedor configurado
#'
#' Usa o provider nativo do Google para "gemini" (o caminho OpenAI-compatible
#' não preserva o `thought_signature` exigido pelos modelos Gemini 3 no
#' tool-calling, resultando em HTTP 400). "ollama", "openai" e "groq" usam a
#' API OpenAI-compatível do ellmer. "mock" é tratado antes, em [ask_censo()].
#'
#' @param cfg configuração de [chat_config()].
#' @keywords internal
chat_llm <- function(cfg) {
  if (cfg$provider == "gemini") {
    return(ellmer::chat_google_gemini(
      model = cfg$model,
      base_url = cfg$url,
      credentials = function() cfg$api_key
    ))
  }

  url <- if (cfg$provider == "openai" || cfg$provider == "groq") {
    cfg$url
  } else {
    chat_provider_url(cfg$url)
  }

  credentials <- if (nzchar(cfg$api_key)) {
    function() cfg$api_key
  } else {
    NULL
  }

  ellmer::chat_openai_compatible(
    model = cfg$model,
    base_url = url,
    credentials = credentials
  )
}

#' Valida SQL gerado pelo modelo
#'
#' Bloqueia (cortesia de segurança): multi-statement (";"), comandos que não
#' sejam SELECT top-level, keywords destrutivas/perigosas, funções de
#' catálogo pg_* e referências a schemas fora da whitelist. Devolve TRUE/FALSE.
#'
#' @param sql SQL como string.
#' @keywords internal
chat_validate_sql <- function(sql) {
  if (is.null(sql) || !nzchar(trimws(sql))) return(FALSE)
  if (grepl(";", sql, fixed = TRUE)) return(FALSE)
  if (!grepl("^[[:space:]]*select[[:space:]]", sql, ignore.case = TRUE)) {
    return(FALSE)
  }

  perigoso <- paste0(
    "(?i)\\b(",
    "drop|delete|update|insert|into|alter|truncate|grant|revoke|create|",
    "comment|vacuum|reindex|refresh|copy|execute|call|do|set|reset|show|",
    "explain|analyze|listen|notify|merge|returning|",
    "pg_[a-z0-9_]+|information_schema",
    ")\\b"
  )
  if (grepl(perigoso, sql, perl = TRUE)) return(FALSE)

  refs <- chat_origem(sql)
  if (length(refs) == 0) return(FALSE)
  if (!all(grepl(sprintf("^(%s)\\.[^.]+$", paste(CHAT_ALLOWED_SCHEMAS, collapse = "|")), refs))) {
    return(FALSE)
  }

  TRUE
}

#' Tabelas referenciadas num SQL
#'
#' Extrai os identificadores após FROM/JOIN (schema.table, qualificado).
#'
#' @param sql SQL como string.
#' @keywords internal
chat_origem <- function(sql) {
  toks <- regmatches(
    sql,
    gregexpr(
      "(?i)(?:^|[^a-z_])(?:from|join)[[:space:]]+\"?[a-z_][a-z0-9_.]*\"?",
      sql,
      perl = TRUE
    )
  )[[1]]

  if (length(toks) == 0) return(character())

  refs <- sub(
    '(?i)^[^a-z]*(?:from|join)[[:space:]]+',
    "",
    toks,
    perl = TRUE
  )
  refs <- sub('^"|"$', "", refs)
  unique(refs)
}

#' Remove colunas PII e geométricas do resultado
#'
#' Remove colunas cujo nome case com algum padrão da seção `ocultar` do
#' glossário (cpf, senha, telefone, endereço, e-mail, nome de profissional...)
#' e colunas espaciais (`pq_geometry`/PostGIS ou nomes `geometry`/`geom`), que
#' não são serializáveis em JSON pelo Plumber e quebrariam a resposta (500).
#'
#' @param df data.frame do resultado da consulta.
#' @param glossario lista retornada por [chat_glossary()]; se NULL, lido.
#' @keywords internal
chat_redact <- function(df, glossario = NULL) {
  if (is.null(df) || nrow(df) == 0 || ncol(df) == 0) return(df)
  glossario <- glossario %||% chat_glossary()

  padroes <- glossario$ocultar %||% character()
  esconder <- vapply(names(df), function(nome) {
    any(vapply(padroes, function(p) grepl(p, nome, ignore.case = TRUE), logical(1)))
  }, logical(1))

  # Colunas geométricas (PostGIS): o driver devolve classe `pq_geometry`, que
  # jsonlite não serializa ("No method asJSON S3 class: pq_geometry").
  espacial <- vapply(seq_len(ncol(df)), function(i) {
    inherits(df[[i]], "pq_geometry") ||
      isTRUE(any(grepl("^(geometry|geom)$", names(df)[[i]], ignore.case = TRUE)))
  }, logical(1))

  df[, !(esconder | espacial), drop = FALSE]
}

#' Monta o system prompt do chat
#'
#' @param dicionario data.frame de [chat_dictionary()].
#' @param glossario lista de [chat_glossary()].
#' @param contexto lista com cod_municipio, cod_inep, nome_escola,
#'   nome_municipio e/ou sg_uf do gestor logado.
#' @keywords internal
chat_system_prompt <- function(dicionario, glossario, contexto) {
  contexto <- contexto %||% list()

  regras <- c(
    "## PAPEL",
    "Você é o Assistente do Censo do EduMaps: responde perguntas de gestores",
    "escolares sobre a base do Censo Escolar brasileiro, em PT-BR (markdown),",
    "com números concretos vindos das consultas.",
    "",
    "## ESCOPO DO GESTOR (único permitido)",
    sprintf("município: %s (co_municipio = %s)", contexto$nome_municipio %||% "(não informado)", contexto$cod_municipio %||% "?"),
    sprintf("escola: %s (INEP = %s); UF: %s", contexto$nome_escola %||% "(não informado)", contexto$cod_inep %||% "?", contexto$sg_uf %||% contexto$uf %||% "?"),
    "Quando a pergunta for sobre 'meu município'/'aqui', filtre por co_municipio",
    "com o valor acima (nunca peça o código). Sem co_municipio e dependendo do",
    "município, diga que não pode responder.",
    "",
    "## REGRAS",
    "- Consulte SEMPRE com a ferramenta run_sql antes de responder; VOCÊ roda a",
    "  consulta (nunca peça SQL ao usuário).",
    "- Só SELECT (leitura). Filtre escolas ativas com tp_situacao_funcionamento = 1.",
    "- Nunca presuma o ano (o Censo atual é 2025): use o mais recente com",
    "  `nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_escolas)`.",
    "- Prefira colunas listadas no dicionário; se faltar, descubra com `SELECT * LIMIT 1`.",
    "- NUNCA selecione colunas geométricas (`geometry`/`geom`): não são serializáveis.",
    "- Agregue (COUNT/SUM/AVG/GROUP BY) quando houver muitas escolas; LIMIT 200.",
    "- Prefira clean.school_indicators para indicadores já calculados.",
    "- Resposta em markdown, até ~8 linhas, com os números principais; se vazio, diga.",
    "- Fora do tema educacional/censo, explique que não pode ajudar.",
    "- Se um gráfico ajudar (comparação/tendência), chame registrar_grafico",
    "  (tipo barra/linha/pizza)."
  )

  c(regras, "", chat_dictionary_text(dicionario, glossario))
}

#' Ferramenta run_sql (executa consulta read-only)
#'
#' Retorna as linhas como texto JSON para o modelo, ou uma mensagem de erro
#' (que o modelo usa para se corrigir e tentar de novo). Registra no estado
#' o SQL executado, o resultado e a origem.
#'
#' @param con conexão read-only.
#' @param cfg configuração de chat.
#' @param glossario glossário (para redação PII).
#' @param estado ambiente de estado da conversa.
#' @keywords internal
chat_tool_run_sql <- function(con, cfg, glossario, estado) {
  ellmer::tool(
    function(sql) {
      sql <- trimws(sql)
      if (!chat_validate_sql(sql)) {
        return(paste0(
          "ERRO: consulta recusada pela política de segurança (apenas SELECT ",
          "somente-leitura, de tabelas clean./analytics., sem multi-statement). ",
          "Escreva uma consulta SELECT válida."
        ))
      }

      tryCatch(
        {
          res <- DBI::dbGetQuery(con, sql)
          res <- chat_redact(res, glossario)
          linhas <- nrow(res)
          if (linhas > cfg$max_rows) {
            res <- res[seq_len(cfg$max_rows), , drop = FALSE]
          }

          estado$sql <- sql
          estado$resultado <- res
          estado$origem <- chat_origem(sql)

          modelo_res <- res
          if (nrow(modelo_res) > CHAT_MAX_LINHAS_MODELO) {
            modelo_res <- modelo_res[seq_len(CHAT_MAX_LINHAS_MODELO), , drop = FALSE]
          }

          corpo <- jsonlite::toJSON(
            as.data.frame(modelo_res),
            dataframe = "rows",
            na = "null",
            auto_unbox = TRUE
          )
          corpo <- as.character(corpo)
          if (nchar(corpo) > CHAT_MAX_CHARS_MODELO) {
            corpo <- substr(corpo, 1, CHAT_MAX_CHARS_MODELO)
          }
          sprintf(
            "RESULTADO (%d linha(s) - amostra de %d; use agregados no SQL p/ totais exatos):\n%s",
            linhas, min(linhas, CHAT_MAX_LINHAS_MODELO), corpo
          )
        },
        error = function(e) {
          sprintf(
            "ERRO DE BANCO: %s. Corrija a consulta (qualifique com clean./analytics. antes do nome da tabela se precisar) e tente novamente.",
            conditionMessage(e)
          )
        }
      )
    },
    "Executa uma consulta SQL somente-leitura na base do Censo Escolar e devolve o resultado como JSON. Use para todo dado que precisar responder.",
    arguments = list(sql = ellmer::type_string(
      "A consulta SQL (apenas SELECT) a executar."
    ))
  )
}

#' Ferramenta registrar_grafico (configura gráfico do resultado)
#'
#' Registra a configuração do gráfico (tipo, eixos e título) sobre o último
#' resultado de run_sql.
#'
#' @param estado ambiente de estado da conversa.
#' @keywords internal
chat_tool_chart <- function(estado) {
  ellmer::tool(
    function(tipo, x, y, titulo) {
      if (!chat_chart_tipo_valid(tipo)) {
        return(sprintf(
          "Tipo de gráfico inválido: %s. Use: %s.",
          tipo, paste(CHAT_CHART_TYPES, collapse = ", ")
        ))
      }
      if (is.null(estado$resultado)) {
        return("Sem resultado ainda: rode run_sql antes de registrar gráfico.")
      }
      if (!(x %in% names(estado$resultado))) {
        return(sprintf("Coluna '%s' não existe no último resultado.", x))
      }
      if (!(y %in% names(estado$resultado))) {
        return(sprintf("Coluna '%s' não existe no último resultado.", y))
      }

      estado$chart <- list(tipo = tipo, x = x, y = y, titulo = titulo %||% "")
      "Gráfico registrado. Finalize a resposta com a análise."
    },
    "Registra um gráfico (barra, linha ou pizza) sobre o último resultado de run_sql.",
    arguments = list(
      tipo = ellmer::type_enum("barra|linha|pizza", values = CHAT_CHART_TYPES),
      x = ellmer::type_string("Coluna categórica (eixo x / rótulos)"),
      y = ellmer::type_string("Coluna numérica (eixo y / valores)"),
      titulo = ellmer::type_string("Título do gráfico")
    )
  )
}

#' Tradutor determinístico de demonstração (sem LLM)
#'
#' Usado nos testes e quando `EDUMAPS_LLM_PROVIDER=mock`. Responde de forma
#' determinística com uma consulta simples do município do contexto.
#'
#' @keywords internal
chat_translate_mock <- function(pergunta, contexto, con, cfg) {
  sql <- paste(
    "SELECT no_entidade AS escola, no_municipio AS municipio,",
    "tp_dependencia AS rede FROM clean.censo_escolas",
    "WHERE tp_situacao_funcionamento = 1"
  )
  if (!is.null(contexto$cod_municipio)) {
    sql <- sprintf("%s AND co_municipio = %d", sql, as.integer(contexto$cod_municipio))
  }
  sql <- paste(sql, "ORDER BY no_entidade LIMIT", cfg$max_rows)

  resultado <- tryCatch(
    chat_redact(DBI::dbGetQuery(con, sql)),
    error = function(e) NULL
  )
  if (is.null(resultado)) {
    return(list(
      resposta = "Não foi possível consultar os dados (modo demonstração).",
      sql = sql,
      resultado = NULL, linhas = 0, colunas = 0,
      origem = character(), chart = NULL
    ))
  }

  list(
    resposta = sprintf(
      "Modo demonstração (sem modelo de linguagem). Consulta executada: %d escola(s) ativa(s) do município. Pergunta recebida: \"%s\".",
      nrow(resultado), pergunta
    ),
    sql = sql,
    resultado = resultado,
    linhas = nrow(resultado),
    colunas = ncol(resultado),
    origem = chat_origem(sql),
    chart = NULL
  )
}

#' Pergunta ao Assistente do Censo (NL -> SQL -> resposta)
#'
#' Ponto de entrada principal do chat. Valida a pergunta, monta dicionário,
#' conversa com o modelo (com as ferramentas run_sql/registrar_grafico) e
#' devolve a resposta estruturada para serialização JSON.
#'
#' @param pergunta texto da pergunta do gestor (máx. 500 caracteres).
#' @param contexto lista opcional com cod_municipio, cod_inep, nome_escola,
#'   nome_municipio e/ou sg_uf (escopo do gestor).
#'
#' @return Lista com: resposta (markdown), sql (última consulta), origem
#'   (tabelas usadas), linhas, colunas, resultado (linhas redigidas/limitadas)
#'   e chart (especificação plotly `{data, layout}`) ou NULL.
#'
#' @export
ask_censo <- function(pergunta, contexto = NULL) {
  if (is.null(pergunta) || !is.character(pergunta) || !nzchar(trimws(pergunta))) {
    chat_invalid("A pergunta é obrigatória.", "invalid_pergunta")
  }
  pergunta <- trimws(pergunta)
  if (nchar(pergunta) > 500) {
    chat_invalid("A pergunta não pode passar de 500 caracteres.", "invalid_pergunta")
  }

  cfg <- chat_config()
  con <- chat_db_connection()
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  glossario <- chat_glossary()
  dicionario <- chat_dictionary(con, glossario)

  if (cfg$provider == "mock") {
    return(chat_translate_mock(pergunta, contexto, con, cfg))
  }

  run <- if (identical(cfg$engine, "single")) chat_run_single else chat_run

  tryCatch(
    run(pergunta, contexto, dicionario, glossario, con, cfg),
    chat_provider_error = function(e) stop(e),
    error = function(e) chat_provider_failed(conditionMessage(e))
  )
}

#' Extrai o SQL de uma resposta em texto do modelo
#'
#' Aceita um bloco ```sql ...``` ou, na falta, o primeiro trecho que comece com
#' SELECT/WITH. Devolve NULL se nada plausível for encontrado.
#'
#' @keywords internal
chat_extract_sql <- function(texto) {
  texto <- texto %||% ""
  bloco <- regmatches(texto, regexpr("(?is)```[a-z]*[[:space:]]*(select|with).*?```", texto, perl = TRUE))
  if (length(bloco) == 1 && nzchar(bloco)) {
    sql <- trimws(gsub("(?is)^```[a-z]*[[:space:]]*|```$", "", bloco, perl = TRUE))
    return(chat_strip_sql(sql))
  }
  m <- regmatches(texto, regexpr("(?is)(select|with)[[:space:]].*", texto, perl = TRUE))
  if (length(m) == 1 && nzchar(m)) {
    return(chat_strip_sql(sub(";.*$", "", m)))
  }
  NULL
}

#' Remove espaços e um `;` final de um SQL (o validador bloqueia `;`)
#' @keywords internal
chat_strip_sql <- function(sql) {
  sql <- trimws(sql)
  sql <- sub(";[[:space:]]*$", "", sql)
  trimws(sql)
}

#' Motor de 1 turno (sem tool-calling)
#'
#' Para provedores com limite baixo de TPM (ex.: Groq free, 8k TPM) onde o
#' fluxo de tool-calling em 2 turnos não cabe: pede o SQL ao modelo (1ª
#' chamada, com o dicionário), executa o SQL e faz uma 2ª chamada CURTA (sem o
#' dicionário) só para resumir o resultado em markdown.
#'
#' @keywords internal
chat_run_single <- function(pergunta, contexto, dicionario, glossario, con, cfg) {
  chat <- chat_llm(cfg)
  chat$set_system_prompt(c(chat_system_prompt(dicionario, glossario, contexto), "", single_turn_instrucoes()))

  sql <- chat_extract_sql(as.character(chat$chat(pergunta)))

  if (is.null(sql) || !chat_validate_sql(sql)) {
    return(list(
      resposta = "Não consegui montar uma consulta válida para essa pergunta. Tente reformular.",
      sql = NA_character_,
      origem = character(), linhas = 0, colunas = 0,
      resultado = NULL, chart = NULL
    ))
  }

  resultado <- tryCatch(chat_redact(DBI::dbGetQuery(con, sql), glossario), error = function(e) NULL)
  sql_original <- sql
  if (is.null(resultado)) {
    return(list(
      resposta = "A consulta gerada não pôde ser executada. Tente reformular a pergunta.",
      sql = sql, origem = character(), linhas = 0, colunas = 0,
      resultado = NULL, chart = NULL
    ))
  }

  if (nrow(resultado) > cfg$max_rows) {
    resultado <- resultado[seq_len(cfg$max_rows), , drop = FALSE]
  }

  resposta <- chat_resumir(pergunta, sql, resultado, cfg)
  origem <- chat_origem(sql_original)

  list(
    resposta = resposta %||% "",
    sql = sql_original,
    origem = origem,
    linhas = nrow(resultado),
    colunas = ncol(resultado),
    resultado = resultado,
    chart = NULL
  )
}

#' Instruções do motor de 1 turno (só devolver SQL)
#' @keywords internal
single_turn_instrucoes <- function() {
  c(
    "## FORMATO DA RESPOSTA",
    "Responda APENAS com a consulta SQL (um único SELECT), dentro de um bloco",
    "```sql ...``` e nada mais. Não explique, não resuma, não invente números:",
    "nós executaremos o SQL e mostraremos o resultado ao gestor.",
    "",
    "## ANO DE REFERÊNCIA",
    "Nunca presuma o ano. Use o ano mais recente da tabela, por exemplo:",
    "`nu_ano_censo = (SELECT MAX(nu_ano_censo) FROM clean.censo_escolas)`.",
    "",
    "## COLUNAS PROIBIDAS",
    "Nunca inclua colunas geométricas (`geometry`/`geom`): não são serializáveis."
  )
}

#' Resume (curto) o resultado de um SQL já executado, sem reenviar o dicionário
#'
#' Chamada barata em tokens: usada pelo motor de 1 turno. Recebe a pergunta, o
#' SQL e um extrato do resultado (poucas linhas) e devolve markdown.
#'
#' @keywords internal
chat_resumir <- function(pergunta, sql, resultado, cfg) {
  amostra <- resultado
  if (nrow(amostra) > CHAT_MAX_LINHAS_MODELO) {
    amostra <- amostra[seq_len(CHAT_MAX_LINHAS_MODELO), , drop = FALSE]
  }
  corpo <- as.character(jsonlite::toJSON(
    as.data.frame(amostra), dataframe = "rows", na = "null", auto_unbox = TRUE
  ))
  if (nchar(corpo) > CHAT_MAX_CHARS_MODELO) {
    corpo <- substr(corpo, 1, CHAT_MAX_CHARS_MODELO)
  }

  chat <- chat_llm(cfg)
  chat$set_system_prompt(c(
    "Você resume resultados de consultas ao Censo Escolar para um gestor.",
    "Responda em PT-BR, em markdown, em até ~8 linhas, com os números principais",
    "(totais, contagens, comparações presentes no resultado).",
    "Use SOMENTE números/colunas que aparecem no resultado fornecido. É PROIBIDO",
    "inventar percentuais, comparações, médias ou contextos que não estejam nos",
    "dados (ex.: 'supera 150 milhões', '0,28% da rede'). Se não houver base para",
    "comparar, não compare. Seja factual."
  ))

  prompt <- sprintf(
    "Pergunta do gestor: %s\n\nSQL executado:\n%s\n\nResultado (%d linha(s) no total, amostra de %d):\n%s",
    pergunta, sql, nrow(resultado), nrow(amostra), corpo
  )

  as.character(chat$chat(prompt))
}

#' Executa a conversa com o modelo e estrutura a resposta
#' @keywords internal
chat_run <- function(pergunta, contexto, dicionario, glossario, con, cfg) {
  estado <- new.env(parent = emptyenv())
  estado$sql <- NULL
  estado$resultado <- NULL
  estado$origem <- character()
  estado$chart <- NULL

  chat <- chat_llm(cfg)
  chat$set_system_prompt(chat_system_prompt(dicionario, glossario, contexto))
  chat$register_tool(chat_tool_run_sql(con, cfg, glossario, estado))
  chat$register_tool(chat_tool_chart(estado))

  resposta <- as.character(chat$chat(pergunta))

  resultado <- estado$resultado
  linhas <- if (!is.null(resultado)) nrow(resultado) else 0
  colunas <- if (!is.null(resultado)) ncol(resultado) else 0

  chart <- NULL
  if (!is.null(estado$chart) && !is.null(resultado)) {
    chart <- chat_chart_plotly_json(
      resultado,
      estado$chart$tipo,
      estado$chart$x,
      estado$chart$y,
      estado$chart$titulo
    )
  }

  list(
    resposta = resposta %||% "",
    sql = estado$sql %||% NA_character_,
    origem = estado$origem %||% character(),
    linhas = linhas,
    colunas = colunas,
    resultado = resultado,
    chart = chart
  )
}