# R/chat-dictionary.R
#
# Dicionário do Assistente do Censo: transforma o glossário curado
# (inst/chat/dicionario.yml) + comentários das colunas no banco em um bloco
# de texto que vai no system prompt do modelo.
#
# Segurança: a whitelist de tabelas expostas ao modelo vive NO ARQUIVO YAML,
# não em heurística em runtime. Tabelas sensíveis (gestores, sessoes,
# contatos, relacoes, inventario, pesquisas, minion...) simplesmente não
# entram no dicionário — o modelo não sabe que existem.

# Tabelas e colunas permitidas (nomes 'schema.tabela' e 'schema.tabela.coluna').
CHAT_ALLOWED_SCHEMAS <- c("clean", "analytics")

#' Caminho do arquivo de glossário do chat
#'
#' @keywords internal
chat_glossary_path <- function() {
  installed <- system.file("chat/dicionario.yml", package = "edumapsAnalytics")
  if (nzchar(installed)) {
    return(installed)
  }

  path <- file.path("inst", "chat", "dicionario.yml")
  if (file.exists(path)) {
    return(path)
  }

  stop_chat_internal("Glossário do chat (dicionario.yml) não encontrado")
}

#' Glossário curado do chat
#'
#' Lê inst/chat/dicionario.yml e devolve como lista R.
#'
#' @return Lista tipada com o glossário (tabelas, colunas, termos, ...).
#' @keywords internal
chat_glossary <- function() {
  con <- file(chat_glossary_path(), encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  yaml::yaml.load(paste(readLines(con, warn = FALSE), collapse = "\n"))
}

#' Tabelas da whitelist do chat
#'
#' Normaliza a seção `tabelas` do glossário em um data.frame com uma linha por
#' tabela (schema, tabela, descricao, chave).
#'
#' @param glossario lista retornada por [chat_glossary()].
#' @keywords internal
chat_tables <- function(glossario) {
  nomes <- names(glossario$tabelas)
  if (is.null(nomes)) {
    return(data.frame(
      schema = character(), tabela = character(),
      descricao = character(), chave = character(),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(seq_along(glossario$tabelas), function(i) {
    partes <- strsplit(nomes[[i]], ".", fixed = TRUE)[[1]]
    meta <- glossario$tabelas[[i]]
    data.frame(
      schema = partes[[1]],
      tabela = partes[[2]],
      descricao = meta$descricao %||% "",
      chave = meta$chave %||% "",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Colunas curadas por tabela
#'
#' Normaliza a seção `colunas` do glossário: uma linha por
#' (schema, tabela, coluna, descricao). Tabelas configuradas com
#' `colunas: '*'` não aparecem aqui (todas as colunas são aceitas).
#'
#' @param glossario lista retornada por [chat_glossary()].
#' @keywords internal
chat_curated_columns <- function(glossario) {
  tabelas <- names(glossario$colunas)
  if (is.null(tabelas)) {
    return(data.frame(
      schema = character(), tabela = character(),
      coluna = character(), descricao = character(),
      stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(tabelas, function(nome) {
    partes <- strsplit(nome, ".", fixed = TRUE)[[1]]
    colunas <- glossario$colunas[[nome]]
    if (is.null(colunas)) {
      return(NULL)
    }
    data.frame(
      schema = partes[[1]],
      tabela = partes[[2]],
      coluna = names(colunas),
      descricao = vapply(colunas, as.character, character(1)),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

#' Metadados de colunas de clean/analytics
#'
#' Consulta o catálogo do banco (pg_attribute/pg_class) e devolve coluna,
#' tipo e comentário de TODAS as colunas de clean/analytics. A filtragem pela
#' whitelist acontece em memória — a query é leve (só catálogo).
#'
#' @param con conexão DBI read-only.
#' @keywords internal
chat_fetch_column_meta <- function(con) {
  sql <- paste0(
    "SELECT n.nspname AS schema, c.relname AS tabela, a.attname AS coluna, ",
    "format_type(a.atttypid, a.atttypmod) AS tipo, ",
    "col_description(c.oid, a.attnum) AS comentario ",
    "FROM pg_attribute a ",
    "JOIN pg_class c ON c.oid = a.attrelid ",
    "JOIN pg_namespace n ON n.oid = c.relnamespace ",
    "WHERE n.nspname = ANY (ARRAY['clean','analytics']) ",
    "AND a.attnum > 0 AND NOT a.attisdropped"
  )

  DBI::dbGetQuery(con, sql)
}

#' Dicionário efetivo do chat (colunas + descrições)
#'
#' Cruza a whitelist curada (YAML) com o catálogo do banco e devolve um
#' data.frame (schema_table_col, coluna, tipo, descricao, schema_table,
#' descricao_tabela) com EXATAMENTE as colunas que o modelo pode consultar:
#' - tabela com `colunas: '*'` (ou sem inscrição na seção `colunas`): todas
#'   as colunas, com descrição vinda do comentário do banco;
#' - demais: apenas as colunas curadas no YAML.
#'
#' @param con conexão DBI read-only.
#' @param glossario lista retornada por [chat_glossary()]; se NULL, é lido.
#' @keywords internal
chat_dictionary <- function(con, glossario = NULL) {
  glossario <- glossario %||% chat_glossary()
  tabelas <- chat_tables(glossario)
  curadas <- chat_curated_columns(glossario)

  if (nrow(tabelas) == 0) {
    return(data.frame(
      schema_table_col = character(), coluna = character(),
      tipo = character(), descricao = character(),
      schema_table = character(), descricao_tabela = character(),
      stringsAsFactors = FALSE
    ))
  }

  metas <- chat_fetch_column_meta(con)
  metas$schema_table <- paste(metas$schema, metas$tabela, sep = ".")
  metas$schema_table_col <- paste(metas$schema_table, metas$coluna, sep = ".")

  tabelas$schema_table <- paste(tabelas$schema, tabelas$tabela, sep = ".")
  curadas$schema_table <- paste(curadas$schema, curadas$tabela, sep = ".")
  curadas$schema_table_col <- paste(curadas$schema_table, curadas$coluna, sep = ".")

  coringas <- setdiff(tabelas$schema_table, curadas$schema_table)

  wildcard <- metas[metas$schema_table %in% coringas, , drop = FALSE]
  curated <- merge(
    curadas,
    metas[, c("schema_table_col", "tipo")],
    by = "schema_table_col",
    all.x = TRUE
  )

  dicionario <- data.frame(
    schema_table_col = c(wildcard$schema_table_col, curated$schema_table_col),
    coluna = c(wildcard$coluna, curated$coluna),
    tipo = c(wildcard$tipo, curated$tipo),
    descricao = c(wildcard$comentario, curated$descricao),
    schema_table = c(wildcard$schema_table, curated$schema_table),
    stringsAsFactors = FALSE
  )

  mesclado <- merge(
    dicionario,
    tabelas[, c("schema_table", "descricao", "chave")],
    by = "schema_table"
  )
  names(mesclado)[names(mesclado) == "descricao.x"] <- "descricao"
  names(mesclado)[names(mesclado) == "descricao.y"] <- "descricao_tabela"

  mesclado
}

# Bloco de colunas exibidas por tabela. O prompt completo do dicionário é
# enviado a cada requisição; provedores com limite baixo de TPM (ex.: Groq
# on-demand, 8k TPM) exigem um dicionário enxuto, senão a chamada volta 413.
# O modelo descobre as demais colunas via SELECT * LIMIT 1.
CHAT_MAX_COLUNAS_POR_TABELA <- 4

# Tamanho máximo (chars) de cada descrição de coluna exibida no prompt.
CHAT_MAX_CHARS_DESCRICAO <- 45

# Tamanho máximo (chars) da descrição de cada termo do glossário.
CHAT_MAX_CHARS_TERMO <- 110

# Tamanho máximo (chars) da descrição de cada tabela e de cada conexão.
CHAT_MAX_CHARS_TABELA <- 110
CHAT_MAX_CHARS_CONEXAO <- 80

# Máximo de colunas citadas por termo do glossário (elas são um atalho, não a
# lista completa — que já aparece no bloco do dicionário).
CHAT_MAX_COLUNAS_TERMO <- 4

#' Bloco de dicionário para o system prompt
#'
#' Gera o texto do esquema em formato compacto (uma linha por coluna), com o
#' número de colunas por tabela limitado por `CHAT_MAX_COLUNAS_POR_TABELA` e as
#' descrições truncadas. O prompt inteiro é reenviado a cada requisição, então o
#' tamanho importa: provedores com limite baixo de TPM (ex.: Groq on-demand,
#' 8k TPM) estouram se o dicionário for verboso.
#'
#' @param dicionario data.frame de [chat_dictionary()].
#' @param glossario lista retornada por [chat_glossary()].
#' @keywords internal
chat_dictionary_text <- function(dicionario, glossario) {
  linhas <- c(
    "## DICIONÁRIO DE DADOS (base do Censo Escolar)",
    "Schemas `clean` e `analytics`. Estas são as ÚNICAS tabelas/colunas válidas",
    "(não invente). Há mais colunas além das listadas: descubra com",
    "`SELECT * ... LIMIT 1` antes de selecionar colunas específicas.",
    ""
  )

  ordem <- unique(dicionario$schema_table)
  for (schema_table in ordem) {
    parte <- dicionario[dicionario$schema_table == schema_table, , drop = FALSE]
    linha_tabela <- parte[1, ]

    linhas <- c(
      linhas,
      sprintf("### %s (chave: %s)", schema_table, linha_tabela$chave),
      sprintf("Descrição: %s", trimws(substr(linha_tabela$descricao_tabela, 1, CHAT_MAX_CHARS_TABELA))),
      "Colunas:"
    )

    n_mostrar <- min(nrow(parte), CHAT_MAX_COLUNAS_POR_TABELA)
    for (i in seq_len(n_mostrar)) {
      desc <- parte$descricao[[i]]
      anotacao <- if (is.na(desc) || !nzchar(desc)) {
        ""
      } else {
        sprintf(" — %s", trimws(substr(desc, 1, CHAT_MAX_CHARS_DESCRICAO)))
      }
      linhas <- c(linhas, sprintf("- %s %s%s", parte$coluna[[i]], parte$tipo[[i]], anotacao))
    }
    if (nrow(parte) > n_mostrar) {
      linhas <- c(linhas, sprintf("- (+%d colunas; use SELECT * para ver)", nrow(parte) - n_mostrar))
    }

    linhas <- c(linhas, "")
  }

  c(
    linhas,
    "",
    "## COMO AS TABELAS SE CONECTAM (chaves de join)",
    bullet_lines(glossario$conexoes, width = CHAT_MAX_CHARS_CONEXAO),
    "",
    "## GLOSSÁRIO EDUCACIONAL (termos -> colunas)",
    term_lines(glossario$termos),
    "",
    "## CODIFICAÇÕES (enums)",
    scalar_lines(glossario$codificacoes),
    "",
    sprintf(
      "## RESTRIÇÕES DE PRIVACIDADE\nColunas que correspondam aos padrões (%s) são REMOVIDAS do resultado automaticamente — nem tente retorná-las.",
      paste(glossario$ocultar %||% character(), collapse = ", ")
    )
  )
}

#' Formata listas simples de strings como bullets
#' @keywords internal
bullet_lines <- function(x, width = NULL) {
  x <- x %||% character()
  vals <- vapply(x, function(v) {
    v <- as.character(v)
    if (!is.null(width)) v <- trimws(substr(v, 1, width))
    sprintf("- %s", v)
  }, character(1))
  unname(vals)
}

#' Formata listas nomeadas de escalares como "nome: valor"
#' @keywords internal
scalar_lines <- function(x) {
  x <- x %||% list()
  if (is.null(names(x))) {
    return(bullet_lines(x))
  }
  vapply(seq_along(x), function(i) {
    sprintf("- %s: %s", names(x)[[i]], as.character(x[[i]]))
  }, character(1))
}

#' Formata o glossário educacional (nome -> {descricao, colunas})
#' @keywords internal
term_lines <- function(x) {
  x <- x %||% list()
  if (is.null(names(x))) {
    return(bullet_lines(x))
  }

  partes <- lapply(seq_along(x), function(i) {
    nome <- names(x)[[i]]
    termo <- x[[i]]
    desc <- termo$descricao %||% ""
    desc <- trimws(substr(desc, 1, CHAT_MAX_CHARS_TERMO))
    cabecalho <- sprintf("- %s: %s", nome, desc)
    colunas <- termo$colunas
    if (!is.null(colunas) && length(colunas) > 0) {
      n <- min(length(colunas), CHAT_MAX_COLUNAS_TERMO)
      cols <- paste(trimws(substr(unlist(colunas)[seq_len(n)], 1, 30)), collapse = ", ")
      c(cabecalho, sprintf("    cols: %s", cols))
    } else {
      cabecalho
    }
  })

  unlist(partes, use.names = FALSE)
}