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
#' Combina o dicionário canônico do Censo (tabela `clean.censo_data_dictionary`)
#' com a whitelist curada (YAML). Para tabelas do Censo, usa o dicionário
#' canônico como fonte primária (todas as colunas, tipos, domínios de valor,
#' versionamento). Para demais tabelas, usa o catálogo do banco filtrado pela
#' whitelist do YAML.
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

  # 1) Carregar dicionário canônico do Censo para as tabelas censo_*
  census_tables <- c("clean.censo_escolas", "clean.censo_matriculas",
                     "clean.censo_docentes", "clean.censo_gestor")
  census_in_whitelist <- intersect(tabelas$schema_table, census_tables)
  other_tables <- setdiff(tabelas$schema_table, census_tables)

  dict_parts <- list()

  # 1a) Tabelas do Censo: usar censo_dictionary() (fonte canônica)
  if (length(census_in_whitelist) > 0) {
    censo_dict <- tryCatch(
      censo_dictionary(con, tables = census_in_whitelist, include_domain = TRUE),
      error = function(e) {
        warning("Falha ao ler censo_dictionary: ", e$message, "; caindo para catálogo")
        NULL
      }
    )

    if (!is.null(censo_dict) && nrow(censo_dict) > 0) {
      # Normalizar para formato do chat
      censo_dict$schema_table_col <- paste(censo_dict$table_name, censo_dict$column_name, sep = ".")
      censo_dict$tipo <- censo_dict$data_type
      censo_dict$descricao <- censo_dict$description
      censo_dict$value_domain_json <- vapply(censo_dict$value_domain %||% list(), function(v) {
        if (is.null(v)) return("null")
        jsonlite::toJSON(v, auto_unbox = TRUE)
      }, character(1))
      censo_dict$descricao_tabela <- tabelas$descricao[match(censo_dict$table_name, tabelas$schema_table)]
      censo_dict$chave <- tabelas$chave[match(censo_dict$table_name, tabelas$schema_table)]

      dict_parts$censo <- censo_dict[, c("schema_table_col", "coluna", "tipo", "descricao",
                                         "value_domain_json", "schema_table", "descricao_tabela", "chave")]
    }
  }

  # 1b) Demais tabelas: catálogo do banco filtrado pela whitelist (comportamento anterior)
  if (length(other_tables) > 0) {
    metas <- chat_fetch_column_meta(con)
    metas$schema_table <- paste(metas$schema, metas$tabela, sep = ".")
    metas$schema_table_col <- paste(metas$schema_table, metas$coluna, sep = ".")

    tabelas$schema_table <- paste(tabelas$schema, tabelas$tabela, sep = ".")
    curadas$schema_table <- paste(curadas$schema, curadas$tabela, sep = ".")
    curadas$schema_table_col <- paste(curadas$schema_table, curadas$coluna, sep = ".")

    other_tabelas <- tabelas[tabelas$schema_table %in% other_tables, , drop = FALSE]
    other_curadas <- curadas[curadas$schema_table %in% other_tables, , drop = FALSE]

    coringas <- setdiff(other_tabelas$schema_table, other_curadas$schema_table)

    wildcard <- metas[metas$schema_table %in% coringas, , drop = FALSE]
    curated <- merge(
      other_curadas,
      metas[, c("schema_table_col", "tipo")],
      by = "schema_table_col",
      all.x = TRUE
    )

    other_dict <- data.frame(
      schema_table_col = c(wildcard$schema_table_col, curated$schema_table_col),
      coluna = c(wildcard$coluna, curated$coluna),
      tipo = c(wildcard$tipo, curated$tipo),
      descricao = c(wildcard$comentario, curated$descricao),
      value_domain_json = "null",
      schema_table = c(wildcard$schema_table, curated$schema_table),
      stringsAsFactors = FALSE
    )

    other_mesclado <- merge(
      other_dict,
      other_tabelas[, c("schema_table", "descricao", "chave")],
      by = "schema_table"
    )
    names(other_mesclado)[names(other_mesclado) == "descricao.x"] <- "descricao"
    names(other_mesclado)[names(other_mesclado) == "descricao.y"] <- "descricao_tabela"

    dict_parts$other <- other_mesclado
  }

  # Combinar
  final_dict <- do.call(rbind, dict_parts)
  if (is.null(final_dict) || nrow(final_dict) == 0) {
    return(data.frame(
      schema_table_col = character(), coluna = character(),
      tipo = character(), descricao = character(),
      value_domain_json = character(), schema_table = character(),
      descricao_tabela = character(), chave = character(),
      stringsAsFactors = FALSE
    ))
  }

  final_dict
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

      # Adicionar domínio de valores (enum) se disponível
      domain_anotacao <- ""
      if ("value_domain_json" %in% names(parte)) {
        vd <- parte$value_domain_json[[i]]
        if (!is.null(vd) && vd != "null" && nzchar(vd)) {
          # Parse JSON e resumir (máx 3 pares)
          dom <- tryCatch(jsonlite::fromJSON(vd), error = function(e) NULL)
          if (!is.null(dom) && length(dom) > 0) {
            dom_str <- paste(sprintf("%s=%s", names(dom), unlist(dom)), collapse = ", ")
            if (nchar(dom_str) > 60) dom_str <- substr(dom_str, 1, 60)
            domain_anotacao <- sprintf(" [enum: %s]", dom_str)
          }
        }
      }

      linhas <- c(linhas, sprintf("- %s %s%s%s", parte$coluna[[i]], parte$tipo[[i]], anotacao, domain_anotacao))
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