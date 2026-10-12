# R/adapter-edubr.R
#
# Adapter do eduBR (DataSource do Assistente de Relatório, issue #219).
#
# Única porta de entrada do edumapsAnalytics para o pacote eduBR. O eduBR
# fica em Suggests: tudo aqui é chamado como `eduBR::...` e só depois de
# `requireNamespace()`; sem ele, o relatório responde um erro de cliente
# claro (400) e o resto do pacote continua funcionando.
#
# O adapter NÃO usa o eduBR por meio de um LLM: os roteiros chamam as
# ferramentas (`ellmer::ToolDef`) como funções, de forma determinística, e
# convertem o envelope JSON `dados/metadados/erro` em data.frames, avisos e
# fontes. Assim o relatório herda do eduBR o que ele tem de mais valioso —
# validação de argumentos, teto de linhas, timeout, ledger, remoção de PII e
# anti-vazamento de schema — sem SQL próprio.
#
# Limitações do eduBR tratadas aqui (Fase 0):
#   - `ideb_agregado`, `redes_municipio` e `docentes_rede` não filtram UM
#     município: o roteiro pede o nível município dentro da UF (`n` até 1000)
#     e filtra o código no adapter ([edubr_fetch_within()]); quando a resposta
#     vem truncada, refaz a chamada em fatias (por rede, por localização...).
#   - `docentes_rede` sem `colunas` estoura o limite de caracteres: o roteiro
#     sempre pede as colunas necessárias.

#' Persona do eduBR usada pelo Assistente de Relatório
#'
#' O gestor é tratado como pesquisador (plano v1.1): persona
#' `pesquisadora-educacional`.
#'
#' @keywords internal
REPORT_PERSONA <- "pesquisadora-educacional"

#' Limites do eduBR para o relatório
#'
#' Mais apertados que o padrão do eduBR em chamadas, mas com `max_linhas`
#' 1000 (necessário para filtrar um município dentro da UF) e
#' `max_caracteres` alto: os dados não vão para o LLM — quem os lê é o
#' adapter —, então o corte por caracteres (feito para a janela de contexto
#' de modelos locais) só atrapalharia.
#'
#' @keywords internal
report_limits <- function() {
  list(
    n_padrao = 100L,
    max_linhas = 1000L,
    max_chamadas = 40L,
    max_linhas_total = 60000,
    timeout_s = 30,
    max_caracteres = 5000000L,
    persistir = FALSE
  )
}

#' Erro: eduBR indisponível (cliente, 400)
#' @keywords internal
stop_edubr_unavailable <- function() {
  stop(new_client_error(
    paste0(
      "O Assistente de Relatório depende do pacote eduBR, que não está ",
      "instalado neste serviço analítico."
    ),
    "edubr_unavailable"
  ))
}

#' Erro: a fonte de dados (eduBR/banco) falhou (interno, 500)
#'
#' Não é erro do cliente: falha de conexão, timeout ou parâmetro que o
#' próprio roteiro montou errado. Vira 500 (e o backend não guarda em cache).
#'
#' @keywords internal
stop_report_source <- function(msg) {
  stop(structure(
    class = c("report_source_error", "error", "condition"),
    list(message = msg, call = sys.call(-1))
  ))
}

#' O eduBR está instalado?
#' @keywords internal
edubr_available <- function() {
  requireNamespace("eduBR", quietly = TRUE)
}

#' Versão do eduBR instalada (ou NA)
#' @keywords internal
edubr_version <- function() {
  if (!edubr_available()) {
    return(NA_character_)
  }
  as.character(utils::packageVersion("eduBR"))
}

#' DataSource do eduBR
#'
#' Encapsula as ferramentas do eduBR de UMA sessão (um pedido de relatório):
#' conexão injetada, persona e limites. `tools` permite injetar ferramentas
#' falsas nos testes (lista nomeada de funções que devolvem a string JSON do
#' envelope, como as do eduBR); nesse caso o eduBR não é exigido.
#'
#' @param con conexão DBI somente-leitura (role `edumaps_leitor`).
#' @param limites lista de limites do eduBR (padrão [report_limits()]).
#' @param persona persona do eduBR.
#' @param tools lista nomeada opcional de ferramentas (injeção em testes).
#'
#' @return Objeto S3 da classe `edubr_source`.
#'
#' @export
edubr_source <- function(con = NULL,
                         limites = report_limits(),
                         persona = REPORT_PERSONA,
                         tools = NULL) {
  if (is.null(tools)) {
    if (!edubr_available()) {
      stop_edubr_unavailable()
    }
    tools <- eduBR::ferramentas_edubr(con, persona = persona, limites = limites)
  }
  if (!is.list(tools) || is.null(names(tools))) {
    stop("`tools` deve ser uma lista nomeada de ferramentas")
  }

  # Estado mutável do pedido: quantas chamadas, a que ferramentas.
  state <- new.env(parent = emptyenv())
  state$calls <- list()

  structure(
    list(con = con, tools = tools, persona = persona, limites = limites, state = state),
    class = "edubr_source"
  )
}

#' Número de chamadas feitas às ferramentas nesta sessão
#' @keywords internal
edubr_call_count <- function(source) {
  length(source$state$calls)
}

#' Chama uma ferramenta do eduBR e devolve o envelope (lista R)
#'
#' Remove argumentos `NULL` (o eduBR distingue "omitido" de "informado"),
#' chama a ferramenta como função, faz o parse do JSON e registra a chamada.
#' Erros `conexao`, `limite_excedido` e `parametro_invalido` param o
#' relatório com [stop_report_source()] (500): não são do cliente — as opções
#' do cliente já foram validadas pelo modelo semântico. `sem_dados` volta no
#' envelope para o roteiro decidir.
#'
#' @param source `edubr_source`.
#' @param tool nome da ferramenta.
#' @param args lista nomeada de argumentos.
#'
#' @return Envelope `list(dados, metadados, erro)`.
#'
#' @keywords internal
edubr_call <- function(source, tool, args = list()) {
  fn <- source$tools[[tool]]
  if (is.null(fn)) {
    stop_report_source(sprintf("Ferramenta do eduBR indisponível: %s", tool))
  }
  args <- args[!vapply(args, is.null, logical(1))]

  t0 <- proc.time()[["elapsed"]]
  # O eduBR emite warnings de R em algumas consultas (ex.: perfil_escola);
  # não interessam ao relatório e poluiriam o log do Plumber.
  raw <- suppressWarnings(do.call(fn, args))
  env <- edubr_parse_envelope(raw)

  source$state$calls[[length(source$state$calls) + 1L]] <- list(
    ferramenta = tool,
    duracao_ms = round((proc.time()[["elapsed"]] - t0) * 1000),
    erro = env$erro$tipo %||% NA_character_
  )

  tipo <- env$erro$tipo
  if (!is.null(tipo) && tipo %in% c("conexao", "limite_excedido", "parametro_invalido")) {
    stop_report_source(sprintf(
      "Ferramenta %s falhou (%s): %s",
      tool, tipo, env$erro$mensagem %||% ""
    ))
  }

  env
}

#' Parse do envelope JSON do eduBR
#' @keywords internal
edubr_parse_envelope <- function(raw) {
  if (is.list(raw) && !is.null(raw$metadados)) {
    return(raw)
  }
  txt <- paste(as.character(raw), collapse = "")
  env <- tryCatch(
    jsonlite::fromJSON(txt, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (!is.list(env) || !("dados" %in% names(env))) {
    stop_report_source("Resposta do eduBR em formato inesperado")
  }
  env$dados <- env$dados %||% list()
  env$metadados <- env$metadados %||% list()
  env
}

#' A ferramenta devolveu dados?
#' @keywords internal
edubr_has_data <- function(env) {
  is.null(env$erro) && length(env$dados) > 0
}

#' Colunas que são identificadores (ficam como texto)
#' @keywords internal
EDUBR_ID_COLUMNS <- "^(co_|codigo|cod_|id_|sg_|sigla|escola_id|nu_ano)"

#' Converte `dados` do envelope em data.frame
#'
#' Um registro por linha; `null` vira `NA`. Contagens que o eduBR devolve como
#' texto (inteiros grandes, `integer64`) são convertidas para número, exceto
#' as colunas de identificação (códigos IBGE/INEP, siglas), que continuam
#' texto.
#'
#' @param dados lista de registros (`env$dados`).
#'
#' @return data.frame (0 linhas se vazio).
#'
#' @keywords internal
edubr_rows <- function(dados) {
  if (is.list(dados) && !is.null(dados$dados) && !is.null(dados$metadados)) {
    dados <- dados$dados
  }
  if (!length(dados)) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(dados, names)))
  out <- lapply(cols, function(col) {
    vals <- lapply(dados, function(r) {
      v <- r[[col]]
      if (is.null(v) || length(v) != 1L) NA else v
    })
    v <- unlist(vals, use.names = FALSE)
    if (is.character(v) && !grepl(EDUBR_ID_COLUMNS, col)) {
      ok <- is.na(v) | grepl("^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$", v)
      if (all(ok) && any(!is.na(v))) v <- as.numeric(v)
    }
    v
  })
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE, optional = TRUE)
}

#' Avisos de um envelope, no formato do ReportResult
#'
#' `truncado` vira `{tipo: "truncado"}`; o texto de `aviso` vira
#' `{tipo: "aviso"}` (sem a frase de colunas omitidas, que o contrato não
#' expõe); `erro` vira `{tipo: <erro.tipo>}`.
#'
#' @param env envelope.
#' @param ferramenta nome da ferramenta (prefixa a mensagem).
#'
#' @keywords internal
edubr_avisos <- function(env, ferramenta = NULL) {
  pref <- if (is.null(ferramenta)) "" else sprintf("[%s] ", ferramenta)
  avisos <- list()
  meta <- env$metadados %||% list()

  aviso <- meta$aviso
  if (!is.null(aviso) && nzchar(aviso)) {
    aviso <- gsub("Colunas omitidas \\([^)]*\\):[^.]*\\.?", "", aviso)
    aviso <- trimws(gsub("[[:space:]]+", " ", aviso))
    if (nzchar(aviso)) {
      tipo <- if (isTRUE(meta$truncado)) "truncado" else "aviso"
      avisos[[length(avisos) + 1L]] <- list(tipo = tipo, mensagem = paste0(pref, aviso))
    }
  } else if (isTRUE(meta$truncado)) {
    avisos[[length(avisos) + 1L]] <- list(
      tipo = "truncado",
      mensagem = paste0(pref, "Resultado cortado no limite de linhas.")
    )
  }

  if (!is.null(env$erro)) {
    avisos[[length(avisos) + 1L]] <- list(
      tipo = env$erro$tipo %||% "erro",
      mensagem = paste0(pref, env$erro$mensagem %||% "Sem dados.")
    )
  }
  avisos
}

#' Busca linhas de um recorte que a ferramenta não filtra diretamente
#'
#' Chama `tool` com `args`; se a resposta vier truncada (há mais linhas que o
#' teto), refaz em fatias — cada elemento de `splits` é uma lista de
#' argumentos a sobrepor (ex.: uma rede) e pode, por sua vez, ter fatias
#' mais finas em `attr(split, "splits")`. As linhas de todas as respostas
#' completas são juntadas e filtradas com `keep`.
#'
#' @param source `edubr_source`.
#' @param tool nome da ferramenta.
#' @param args argumentos base.
#' @param keep função `data.frame -> vetor lógico` (filtro do recorte) ou
#'   `NULL` (mantém tudo).
#' @param splits lista de fatias (listas de argumentos).
#'
#' @return Lista com `rows` (data.frame), `envelopes`, `avisos`, `n`
#'   (linhas lidas) e `completo` (nenhuma resposta usada ficou truncada).
#'
#' @keywords internal
edubr_fetch_within <- function(source, tool, args, keep = NULL, splits = list()) {
  env <- edubr_call(source, tool, args)
  truncated <- isTRUE(env$metadados$truncado)

  if (!truncated || !length(splits)) {
    rows <- edubr_rows(env)
    if (nrow(rows) && !is.null(keep)) rows <- rows[keep(rows), , drop = FALSE]
    avisos <- edubr_avisos(env, tool)
    if (truncated) {
      avisos[[length(avisos) + 1L]] <- list(
        tipo = "truncado",
        mensagem = sprintf(
          "[%s] A consulta passou do teto de linhas; o recorte pode estar incompleto.",
          tool
        )
      )
    }
    return(list(
      rows = rows,
      envelopes = list(env),
      avisos = avisos,
      n = length(env$dados),
      completo = !truncated
    ))
  }

  # Truncada: descarta esta resposta e refaz por fatias.
  parts <- lapply(splits, function(sp) {
    edubr_fetch_within(
      source, tool,
      utils::modifyList(args, sp[setdiff(names(sp), "")]),
      keep = keep,
      splits = attr(sp, "splits") %||% list()
    )
  })
  rows <- edubr_bind_rows(lapply(parts, `[[`, "rows"))
  list(
    rows = rows,
    envelopes = unlist(lapply(parts, `[[`, "envelopes"), recursive = FALSE),
    # `sem_dados` de uma fatia (ex.: rede Federal sem escolas) não é aviso.
    avisos = Filter(
      function(a) !identical(a$tipo, "sem_dados"),
      unlist(lapply(parts, `[[`, "avisos"), recursive = FALSE)
    ),
    n = sum(vapply(parts, `[[`, numeric(1), "n")),
    completo = all(vapply(parts, `[[`, logical(1), "completo"))
  )
}

#' Junta data.frames com colunas possivelmente diferentes
#' @keywords internal
edubr_bind_rows <- function(dfs) {
  dfs <- Filter(function(d) is.data.frame(d) && nrow(d) > 0, dfs)
  if (!length(dfs)) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(dfs, names)))
  dfs <- lapply(dfs, function(d) {
    for (c in setdiff(cols, names(d))) d[[c]] <- NA
    d[, cols, drop = FALSE]
  })
  do.call(rbind, dfs)
}

#' Fatias por rede (e, dentro de cada rede, por localização)
#'
#' @param redes redes a fatiar.
#' @param localizacao fatiar também por localização (urbana/rural)?
#'
#' @keywords internal
edubr_splits_rede <- function(redes = c("Municipal", "Estadual", "Federal", "Privada"),
                              localizacao = FALSE) {
  lapply(redes, function(r) {
    sp <- list(rede = r)
    if (isTRUE(localizacao)) {
      attr(sp, "splits") <- list(list(localizacao = "urbana"), list(localizacao = "rural"))
    }
    sp
  })
}
