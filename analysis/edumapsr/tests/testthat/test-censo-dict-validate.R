# tests/testthat/test-censo-dict-validate.R
#
# censo_dict_validate() e chat_dictionary() sem banco: conexão falsa (S4 que
# herda de DBIConnection) cujo dbGetQuery responde por padrão de SQL.
# Cobre a issue #134 (R1): função SQL presente com e sem violações, fallback
# por schema + tabela, nunca ok = TRUE vazio por engano, e o dicionario.yml
# do chat com os rótulos do INEP.

library(DBI)

methods::setClass("MockCensoCon", contains = "DBIConnection",
                  representation(handler = "function", log = "environment"))
methods::setMethod("dbGetQuery", signature("MockCensoCon", "character"),
                   function(conn, statement, ...) {
                     conn@log$sql <- c(conn@log$sql, statement)
                     conn@handler(statement)
                   })

mock_con <- function(handler) {
  methods::new("MockCensoCon", handler = handler, log = new.env())
}

# Dicionário canônico mínimo (formato de clean.censo_data_dictionary).
dict_rows <- function(table_name, column_name, value_domain = NA_character_) {
  n <- length(column_name)
  data.frame(
    table_name = rep(table_name, length.out = n),
    column_name = column_name,
    data_type = "integer",
    description = paste("desc", column_name),
    value_domain = rep(value_domain, length.out = n),
    year_introduced = 2025L, year_changed = NA_integer_, year_deprecated = NA_integer_,
    is_pk = FALSE, is_fk = FALSE, fk_target_table = NA_character_,
    fk_target_column = NA_character_, source_file = NA_character_,
    source_url = NA_character_, source_license = NA_character_,
    retrieved_at = NA_character_, notes = NA_character_,
    stringsAsFactors = FALSE
  )
}

# Handler genérico: decide pelo texto do SQL.
make_handler <- function(fn_existe, violacoes = NULL, real = NULL, dict = NULL,
                         meta = NULL) {
  function(sql) {
    if (grepl("to_regprocedure", sql, fixed = TRUE)) {
      return(data.frame(existe = fn_existe))
    }
    if (grepl("FROM clean.censo_dict_violacoes()", sql, fixed = TRUE)) {
      return(violacoes)
    }
    if (grepl("information_schema.columns", sql, fixed = TRUE)) {
      return(real)
    }
    if (grepl("FROM clean.censo_data_dictionary", sql, fixed = TRUE)) {
      if (is.null(dict)) stop("relation \"clean.censo_data_dictionary\" does not exist")
      return(dict)
    }
    if (grepl("pg_attribute", sql, fixed = TRUE)) {
      return(meta %||% data.frame(schema = character(), tabela = character(),
                                  coluna = character(), tipo = character(),
                                  comentario = character(), stringsAsFactors = FALSE))
    }
    stop("SQL inesperado no mock: ", sql)
  }
}

violacoes_vazias <- function() {
  data.frame(tipo = character(), tabela = character(), coluna = character(),
             valor = character(), n = numeric(), stringsAsFactors = FALSE)
}

# ── função SQL presente ─────────────────────────────────────────────────

test_that("validate usa clean.censo_dict_violacoes() e devolve ok sem violações", {
  con <- mock_con(make_handler(TRUE, violacoes = violacoes_vazias()))
  val <- censo_dict_validate(con)
  expect_identical(val$fonte, "funcao")
  expect_true(val$ok)
  expect_equal(nrow(val$violacoes), 0)
  expect_equal(names(val$violacoes), c("tipo", "tabela", "coluna", "valor", "n"))
  expect_length(val$missing_cols, 0)
  # Não consulta o information_schema quando a função existe.
  expect_false(any(grepl("information_schema", con@log$sql)))
})

test_that("validate com a função falha (ok = FALSE) e repassa as violações", {
  v <- data.frame(
    tipo = c("codigo_fora_do_dominio", "coluna_sem_dicionario", "binaria_invalida",
             "codigo_fora_do_dominio"),
    tabela = c("clean.censo_escolas", "censo_escolas", "clean.censo_escolas",
               "clean.censo_gestor"),
    coluna = c("tp_aee", "coluna_nova", "in_agua_potavel", "tp_cargo_gestor"),
    valor = c("7", NA, "2", "5"),
    n = c(3, NA, 1, 2),
    stringsAsFactors = FALSE
  )
  con <- mock_con(make_handler(TRUE, violacoes = v))

  val <- censo_dict_validate(con)
  expect_false(val$ok)
  expect_equal(nrow(val$violacoes), 4)
  # Tabela sem schema vem qualificada.
  expect_true(all(grepl("^clean\\.", val$violacoes$tabela)))
  expect_identical(val$missing_cols, "clean.censo_escolas.coluna_nova")
  expect_setequal(val$missing_domains, c("clean.censo_escolas.tp_aee",
                                         "clean.censo_escolas.in_agua_potavel",
                                         "clean.censo_gestor.tp_cargo_gestor"))

  # Filtro por tabela.
  so_escolas <- censo_dict_validate(con, tables = "clean.censo_escolas")
  expect_equal(nrow(so_escolas$violacoes), 3)
  so_gestor <- censo_dict_validate(con, tables = "clean.censo_gestor")
  expect_false(so_gestor$ok)
  expect_equal(so_gestor$violacoes$valor, "5")
  so_docentes <- censo_dict_validate(con, tables = "clean.censo_docentes")
  expect_true(so_docentes$ok)
})

test_that("validate rejeita tabela fora das 4 do Censo", {
  con <- mock_con(make_handler(TRUE, violacoes = violacoes_vazias()))
  expect_error(censo_dict_validate(con, tables = "clean.inse"), "não reconhecidas")
})

# ── fallback (banco sem a função) ───────────────────────────────────────

test_that("fallback casa schema + tabela e acha coluna sem dicionário", {
  real <- data.frame(
    table_schema = "clean", table_name = "censo_escolas",
    column_name = c("co_entidade", "tp_dependencia", "in_agua_potavel", "coluna_nova"),
    stringsAsFactors = FALSE
  )
  dict <- dict_rows("clean.censo_escolas",
                    c("co_entidade", "tp_dependencia", "in_agua_potavel"),
                    c(NA, '{"1":"Federal","2":"Estadual","3":"Municipal","4":"Privada"}', NA))
  con <- mock_con(make_handler(FALSE, real = real, dict = dict))

  val <- censo_dict_validate(con, tables = "clean.censo_escolas")
  expect_identical(val$fonte, "fallback")
  expect_false(val$ok)
  expect_identical(val$missing_cols, "clean.censo_escolas.coluna_nova")
  # in_* não exige domínio.
  expect_length(val$missing_domains, 0)

  sql_is <- grep("information_schema", con@log$sql, value = TRUE)
  expect_length(sql_is, 1)
  expect_match(sql_is, "('clean', 'censo_escolas')", fixed = TRUE)
  # O bug antigo: comparar table_name com o nome qualificado.
  expect_false(grepl("'clean.censo_escolas'", sql_is, fixed = TRUE))
})

test_that("fallback aponta tp_* sem value_domain", {
  real <- data.frame(table_schema = "clean", table_name = "censo_escolas",
                     column_name = c("tp_aee", "in_agua_potavel"),
                     stringsAsFactors = FALSE)
  dict <- dict_rows("clean.censo_escolas", c("tp_aee", "in_agua_potavel"))
  con <- mock_con(make_handler(FALSE, real = real, dict = dict))

  val <- censo_dict_validate(con, tables = "clean.censo_escolas")
  expect_false(val$ok)
  expect_identical(val$missing_domains, "clean.censo_escolas.tp_aee")
  expect_identical(val$violacoes$tipo, "sem_dominio")
})

test_that("fallback nunca devolve ok = TRUE quando a tabela não existe", {
  real <- data.frame(table_schema = character(), table_name = character(),
                     column_name = character(), stringsAsFactors = FALSE)
  dict <- dict_rows("clean.censo_escolas", "co_entidade")
  con <- mock_con(make_handler(FALSE, real = real, dict = dict))

  val <- censo_dict_validate(con, tables = "clean.censo_escolas")
  expect_false(val$ok)
  expect_identical(val$violacoes$tipo, "tabela_ausente")
  expect_identical(val$violacoes$tabela, "clean.censo_escolas")
})

test_that("fallback devolve ok = TRUE quando dados e dicionário batem", {
  real <- data.frame(table_schema = "clean", table_name = "censo_escolas",
                     column_name = c("co_entidade", "tp_localizacao"),
                     stringsAsFactors = FALSE)
  dict <- dict_rows("clean.censo_escolas", c("co_entidade", "tp_localizacao"),
                    c(NA, '{"1":"Urbana","2":"Rural"}'))
  con <- mock_con(make_handler(FALSE, real = real, dict = dict))

  val <- censo_dict_validate(con, tables = "clean.censo_escolas")
  expect_true(val$ok)
  expect_equal(nrow(val$violacoes), 0)
})

# ── exports ─────────────────────────────────────────────────────────────

test_that("funções do dicionário do Censo são exportadas", {
  exps <- getNamespaceExports("edumapsAnalytics")
  expect_true(all(c("censo_dictionary", "censo_dict_filter", "censo_dict_domain",
                    "censo_dict_validate") %in% exps))
  expect_false(is.null(utils::getS3method("print", "censo_dictionary", optional = TRUE)))
  expect_false(is.null(utils::getS3method("summary", "censo_dictionary", optional = TRUE)))
})

# ── chat_dictionary com o dicionário canônico ───────────────────────────

test_that("chat_dictionary usa o dicionário canônico, curadas primeiro", {
  glossario <- list(
    tabelas = list(`clean.censo_escolas` = list(descricao = "Escolas", chave = "co_entidade")),
    colunas = list(`clean.censo_escolas` = list(tp_localizacao = "Localização (curada)"))
  )
  dict <- dict_rows("clean.censo_escolas", c("aaa_coluna", "tp_localizacao"),
                    c(NA, '{"1":"Urbana","2":"Rural"}'))
  con <- mock_con(make_handler(FALSE, dict = dict))

  d <- chat_dictionary(con, glossario)
  expect_equal(nrow(d), 2)
  expect_identical(d$coluna[[1]], "tp_localizacao")
  expect_identical(d$descricao[[1]], "Localização (curada)")
  expect_match(d$value_domain_json[[1]], "Urbana")
  expect_identical(d$value_domain_json[[2]], "null")
  expect_true(all(d$schema_table == "clean.censo_escolas"))
  expect_true(all(d$chave == "co_entidade"))

  texto <- paste(chat_dictionary_text(d, chat_glossary()), collapse = "\n")
  expect_match(texto, "tp_localizacao integer — Localização (curada) [enum: 1=Urbana, 2=Rural]",
               fixed = TRUE)
})

test_that("chat_dictionary cai no catálogo sem o dicionário canônico", {
  glossario <- list(
    tabelas = list(`clean.censo_escolas` = list(descricao = "Escolas", chave = "co_entidade")),
    colunas = list(`clean.censo_escolas` = list(co_entidade = "Código INEP"))
  )
  meta <- data.frame(schema = "clean", tabela = "censo_escolas",
                     coluna = c("co_entidade", "no_entidade"), tipo = "text",
                     comentario = NA_character_, stringsAsFactors = FALSE)
  con <- mock_con(make_handler(FALSE, dict = NULL, meta = meta))

  d <- suppressWarnings(chat_dictionary(con, glossario))
  expect_equal(nrow(d), 1)
  expect_identical(d$coluna, "co_entidade")
  expect_identical(d$descricao, "Código INEP")
  expect_identical(d$descricao_tabela, "Escolas")
})

# ── dicionario.yml do chat ──────────────────────────────────────────────

test_that("dicionario.yml carrega e tem os rótulos do INEP", {
  y <- yaml::read_yaml(chat_glossary_path())
  cod <- y$codificacoes
  expect_type(cod, "list")

  expect_match(cod$tp_dependencia, "1=Federal, 2=Estadual, 3=Municipal, 4=Privada", fixed = TRUE)
  expect_match(cod$tp_localizacao, "1=Urbana, 2=Rural", fixed = TRUE)
  expect_match(cod$tp_situacao_funcionamento, "1=Em atividade", fixed = TRUE)
  expect_match(cod$tp_situacao_funcionamento, "4=Extinta em anos anteriores", fixed = TRUE)
  expect_match(cod$tp_aee, "0=Não oferece, 1=Não exclusivamente, 2=Exclusivamente", fixed = TRUE)
  expect_match(cod$tp_aee, "tp_atividade_complementar", fixed = TRUE)
  expect_match(cod$tp_regulamentacao, "2=Em tramitação", fixed = TRUE)
  expect_match(cod$tp_localizacao_diferenciada, "0=Não está em área diferenciada", fixed = TRUE)
  expect_match(cod$tp_localizacao_diferenciada, "8=Povos e comunidades tradicionais", fixed = TRUE)
  expect_match(cod$nao_informado, "9 = Não informado", fixed = TRUE)

  # Rótulos antigos (errados) não podem voltar.
  todo <- paste(readLines(chat_glossary_path(), encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("Sala multifuncional", todo, fixed = TRUE))
  expect_false(grepl("1=Ativa", todo, fixed = TRUE))
  expect_false(grepl("4=Área remanescente", todo, fixed = TRUE))
  expect_false(grepl("1=Meio período", todo, fixed = TRUE))

  esc <- y$colunas$clean.censo_escolas
  expect_false(grepl("=", esc$tp_situacao_funcionamento, fixed = TRUE))
  expect_false(grepl("=", esc$tp_localizacao_diferenciada, fixed = TRUE))
})
