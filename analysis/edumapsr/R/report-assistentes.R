# R/report-assistentes.R
#
# Assistentes declarativos do Assistente de Relatório (#219, Fase 4).
#
# Um assistente é um ARQUIVO YAML em `inst/assistentes/<id>.yml`; criar um
# assistente novo é escrever um YAML, sem código R. Dois modos:
#
#   - `tema`: o gestor escolhe um tema da lista `temas` (ids do catálogo).
#     O `relatorio.yml` ("Relatório por tema") reproduz as Fases 1–3.
#   - `composto`: capítulos fixos (`capitulos`), executados em ordem pelos
#     roteiros dos temas; uma única redação geral do LLM (ver
#     analysis-report-composto.R).
#
# Campos (contrato da Fase 4):
#
#   id, titulo, descricao, publico [perfis], modo, niveis [..]
#   temas: [ids]                                   (modo tema)
#   capitulos:                                     (modo composto)
#     - { tema, titulo, id?, opcoes?: {..}, recorte?: escola }
#   opcoes: { <nome>: { valores?: [..], padrao?: .. } }   (escolha do gestor)
#   prompt_complemento: texto acrescentado ao system prompt
#   limites: { max_chamadas: 80, ... }             (sobrepõe report_limits())
#
# Extensões desta implementação (opcionais):
#   - `capitulos[].id`: padrão = `tema` (deve ser único no assistente);
#   - `capitulos[].recorte: escola`: o capítulo roda sobre a escola do gestor
#     (`contexto.cod_inep`) e é OPCIONAL — só entra quando a escola está no
#     território pedido;
#   - `opcoes.<nome>.valores` omitido: a interseção dos valores aceitos pelos
#     capítulos que aceitam a opção.
#
# Validação ao carregar: YAML legível, campos obrigatórios, `id` = nome do
# arquivo, temas/capítulos existem no catálogo, nível do assistente
# compatível com o de cada tema, opções coerentes. Um YAML inválido é
# IGNORADO COM LOG e não derruba os outros.
#
# Diretórios lidos (nesta ordem; o primeiro `id` vence): o do pacote
# (`inst/assistentes`), os da opção `edumapsAnalytics.assistentes_dirs` e os
# da variável `EDUMAPS_ASSISTENTES_DIRS` (separados por ":").

#' Assistente padrão (Fases 1–3)
#' @keywords internal
REPORT_ASSISTENTE_PADRAO <- "relatorio"

#' Modos de assistente
#' @keywords internal
REPORT_MODOS <- c("tema", "composto")

#' Recortes de capítulo aceitos (além do recorte do pedido)
#' @keywords internal
REPORT_RECORTES_CAPITULO <- "escola"

#' Diretórios de assistentes
#' @keywords internal
report_assistentes_dirs <- function() {
  extra_env <- Sys.getenv("EDUMAPS_ASSISTENTES_DIRS", "")
  dirs <- c(
    system.file("assistentes", package = "edumapsAnalytics"),
    unlist(getOption("edumapsAnalytics.assistentes_dirs")),
    if (nzchar(extra_env)) strsplit(extra_env, ":", fixed = TRUE)[[1]]
  )
  dirs <- dirs[nzchar(dirs) & dir.exists(dirs)]
  unique(normalizePath(dirs, mustWork = FALSE))
}

#' Log de assistente ignorado (não derruba os demais)
#' @keywords internal
report_assistente_log <- function(arquivo, motivo) {
  cat(sprintf(
    "[edumapsAnalytics] assistente ignorado (%s): %s\n",
    basename(arquivo), motivo
  ))
}

#' Carrega e valida todos os assistentes
#'
#' @param dirs diretórios (padrão [report_assistentes_dirs()]).
#'
#' @return Lista nomeada (por id) de assistentes normalizados.
#' @keywords internal
report_assistentes_carregar <- function(dirs = report_assistentes_dirs()) {
  out <- list()
  for (d in dirs) {
    arquivos <- sort(list.files(d, pattern = "\\.ya?ml$", full.names = TRUE))
    for (f in arquivos) {
      ast <- tryCatch(
        report_assistente_validar(yaml::read_yaml(f), f),
        error = function(e) {
          report_assistente_log(f, conditionMessage(e))
          NULL
        }
      )
      if (is.null(ast)) next
      if (!is.null(out[[ast$id]])) {
        report_assistente_log(f, sprintf("id \"%s\" repetido; vale o primeiro carregado", ast$id))
        next
      }
      out[[ast$id]] <- ast
    }
  }
  out
}

# Erro de validação de um YAML (mensagem curta, vira log).
report_assistente_invalido <- function(fmt, ...) {
  stop(simpleError(sprintf(fmt, ...)))
}

# Texto escalar não vazio?
report_is_texto <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x))
}

# Vetor de textos não vazio (lista YAML de strings).
report_as_textos <- function(x) {
  if (is.list(x)) x <- unlist(x, use.names = FALSE)
  if (!is.character(x) || !length(x) || anyNA(x) || !all(nzchar(x))) return(NULL)
  x
}

#' Valida e normaliza um assistente lido do YAML
#'
#' @param raw lista do `yaml::read_yaml()`.
#' @param arquivo caminho do arquivo (o `id` deve ser o nome do arquivo).
#'
#' @return Assistente normalizado; erro (com a causa) se inválido.
#' @keywords internal
report_assistente_validar <- function(raw, arquivo) {
  if (!is.list(raw) || is.null(names(raw))) {
    report_assistente_invalido("o YAML não é um objeto")
  }
  obrig <- c("id", "titulo", "descricao", "publico", "modo", "niveis")
  faltam <- obrig[!obrig %in% names(raw) | vapply(obrig, function(k) is.null(raw[[k]]), logical(1))]
  if (length(faltam)) {
    report_assistente_invalido("campos obrigatórios ausentes: %s", paste(faltam, collapse = ", "))
  }

  id <- raw$id
  if (!report_is_texto(id) || !grepl("^[a-z0-9_]+$", id)) {
    report_assistente_invalido("`id` deve ser um texto [a-z0-9_]+")
  }
  esperado <- sub("\\.ya?ml$", "", basename(arquivo))
  if (!identical(id, esperado)) {
    report_assistente_invalido("`id` (%s) diferente do nome do arquivo (%s)", id, esperado)
  }
  for (k in c("titulo", "descricao")) {
    if (!report_is_texto(raw[[k]])) report_assistente_invalido("`%s` deve ser um texto", k)
  }
  publico <- report_as_textos(raw$publico)
  if (is.null(publico)) report_assistente_invalido("`publico` deve ser uma lista de perfis")
  modo <- raw$modo
  if (!report_is_texto(modo) || !modo %in% REPORT_MODOS) {
    report_assistente_invalido("`modo` deve ser um de: %s", paste(REPORT_MODOS, collapse = ", "))
  }
  niveis <- report_as_textos(raw$niveis)
  if (is.null(niveis) || !all(niveis %in% REPORT_NIVEIS)) {
    report_assistente_invalido(
      "`niveis` deve ser uma lista com valores em: %s", paste(REPORT_NIVEIS, collapse = ", ")
    )
  }
  niveis <- unique(niveis)

  catalog <- report_catalog()
  ast <- list(
    id = id,
    titulo = trimws(raw$titulo),
    descricao = trimws(raw$descricao),
    publico = unique(publico),
    modo = modo,
    niveis = niveis,
    temas = NULL,
    capitulos = NULL,
    opcoes = list(),
    prompt_complemento = NULL,
    limites = list(),
    arquivo = arquivo
  )

  if (modo == "tema") {
    if (!is.null(raw$capitulos)) report_assistente_invalido("`capitulos` só vale no modo composto")
    temas <- report_as_textos(raw$temas)
    if (is.null(temas)) report_assistente_invalido("o modo tema exige `temas` (lista de ids)")
    desconhecidos <- setdiff(temas, names(catalog))
    if (length(desconhecidos)) {
      report_assistente_invalido("temas fora do catálogo: %s", paste(desconhecidos, collapse = ", "))
    }
    for (t in temas) {
      if (!length(intersect(catalog[[t]]$niveis, niveis))) {
        report_assistente_invalido(
          "o tema %s não está disponível em nenhum nível do assistente (%s)",
          t, paste(niveis, collapse = ", ")
        )
      }
    }
    ast$temas <- unique(temas)
    if (length(raw$opcoes)) {
      report_assistente_invalido("no modo tema as opções vêm dos temas; `opcoes` deve ficar vazio")
    }
  } else {
    if (!is.null(raw$temas)) report_assistente_invalido("`temas` só vale no modo tema")
    ast$capitulos <- report_assistente_capitulos(raw$capitulos, niveis, catalog)
    ast$opcoes <- report_assistente_opcoes(raw$opcoes, ast$capitulos, catalog)
  }

  if (!is.null(raw$prompt_complemento)) {
    if (!report_is_texto(raw$prompt_complemento)) {
      report_assistente_invalido("`prompt_complemento` deve ser um texto")
    }
    ast$prompt_complemento <- trimws(raw$prompt_complemento)
  }
  ast$limites <- report_assistente_limites(raw$limites)
  ast
}

#' Valida os capítulos de um assistente composto
#' @keywords internal
report_assistente_capitulos <- function(capitulos, niveis, catalog) {
  if (!is.list(capitulos) || !length(capitulos) || !is.null(names(capitulos))) {
    report_assistente_invalido("o modo composto exige `capitulos` (lista)")
  }
  out <- lapply(seq_along(capitulos), function(i) {
    ch <- capitulos[[i]]
    if (!is.list(ch) || is.null(names(ch))) {
      report_assistente_invalido("capítulo %d não é um objeto", i)
    }
    if (!report_is_texto(ch$tema)) report_assistente_invalido("capítulo %d sem `tema`", i)
    entry <- catalog[[ch$tema]]
    if (is.null(entry)) {
      report_assistente_invalido("capítulo %d: tema fora do catálogo: %s", i, ch$tema)
    }
    if (!report_is_texto(ch$titulo)) report_assistente_invalido("capítulo %d sem `titulo`", i)
    cid <- ch$id %||% ch$tema
    if (!report_is_texto(cid) || !grepl("^[a-z0-9_]+$", cid)) {
      report_assistente_invalido("capítulo %d: `id` deve ser [a-z0-9_]+", i)
    }
    recorte <- ch$recorte
    if (!is.null(recorte)) {
      if (!report_is_texto(recorte) || !recorte %in% REPORT_RECORTES_CAPITULO) {
        report_assistente_invalido(
          "capítulo %s: `recorte` deve ser um de: %s",
          cid, paste(REPORT_RECORTES_CAPITULO, collapse = ", ")
        )
      }
      if (!recorte %in% entry$niveis) {
        report_assistente_invalido("capítulo %s: o tema %s não aceita o recorte %s", cid, ch$tema, recorte)
      }
    } else if (!all(niveis %in% entry$niveis)) {
      report_assistente_invalido(
        "capítulo %s: o tema %s não está disponível em todos os níveis do assistente (%s)",
        cid, ch$tema, paste(niveis, collapse = ", ")
      )
    }
    opcoes <- ch$opcoes %||% list()
    if (length(opcoes) && (!is.list(opcoes) || is.null(names(opcoes)))) {
      report_assistente_invalido("capítulo %s: `opcoes` deve ser um objeto", cid)
    }
    tryCatch(
      report_validate_opcoes(opcoes, entry),
      edumaps_client_error = function(e) {
        report_assistente_invalido("capítulo %s: %s", cid, conditionMessage(e))
      }
    )
    list(id = cid, tema = ch$tema, titulo = trimws(ch$titulo), opcoes = opcoes, recorte = recorte)
  })
  ids <- vapply(out, `[[`, character(1), "id")
  if (anyDuplicated(ids)) {
    report_assistente_invalido("ids de capítulo repetidos: %s", paste(unique(ids[duplicated(ids)]), collapse = ", "))
  }
  out
}

#' Valida as opções que o gestor escolhe num assistente composto
#'
#' Mesmo formato interno do catálogo (`valores`, `padrao`, `obrigatoria`).
#' Cada opção precisa ser aceita por ao menos um capítulo, e os seus valores
#' por TODOS os capítulos que a aceitam.
#'
#' @keywords internal
report_assistente_opcoes <- function(opcoes, capitulos, catalog) {
  if (is.null(opcoes) || !length(opcoes)) return(list())
  if (!is.list(opcoes) || is.null(names(opcoes))) {
    report_assistente_invalido("`opcoes` deve ser um objeto {nome: {valores?, padrao?}}")
  }
  out <- list()
  for (nm in names(opcoes)) {
    spec <- opcoes[[nm]] %||% list()
    if (!is.list(spec)) report_assistente_invalido("opção %s: deve ser um objeto {valores?, padrao?}", nm)
    aceitos <- Filter(Negate(is.null), lapply(capitulos, function(ch) catalog[[ch$tema]]$opcoes[[nm]]$valores))
    if (!length(aceitos)) {
      report_assistente_invalido("opção %s: nenhum capítulo a aceita", nm)
    }
    comuns <- Reduce(intersect, aceitos)
    valores <- if (is.null(spec$valores)) comuns else report_as_textos(spec$valores)
    if (is.null(valores) || !length(valores)) {
      report_assistente_invalido("opção %s: sem valores válidos", nm)
    }
    fora <- setdiff(valores, comuns)
    if (length(fora)) {
      report_assistente_invalido(
        "opção %s: valores não aceitos por todos os capítulos: %s", nm, paste(fora, collapse = ", ")
      )
    }
    padrao <- spec$padrao
    if (!is.null(padrao) && (!report_is_texto(padrao) || !padrao %in% valores)) {
      report_assistente_invalido("opção %s: `padrao` fora dos valores", nm)
    }
    out[[nm]] <- list(valores = valores, padrao = padrao, obrigatoria = FALSE)
  }
  out
}

#' Valida os limites do assistente (sobrepõem [report_limits()])
#' @keywords internal
report_assistente_limites <- function(limites) {
  if (is.null(limites) || !length(limites)) return(list())
  base <- report_limits()
  if (!is.list(limites) || is.null(names(limites))) {
    report_assistente_invalido("`limites` deve ser um objeto")
  }
  fora <- setdiff(names(limites), names(base))
  if (length(fora)) {
    report_assistente_invalido("limites desconhecidos: %s", paste(fora, collapse = ", "))
  }
  out <- list()
  for (nm in names(limites)) {
    v <- limites[[nm]]
    if (is.logical(base[[nm]])) {
      if (!is.logical(v) || length(v) != 1L || is.na(v)) report_assistente_invalido("limite %s deve ser lógico", nm)
      out[[nm]] <- v
      next
    }
    if (!is.numeric(v) || length(v) != 1L || is.na(v) || v <= 0) {
      report_assistente_invalido("limite %s deve ser um número positivo", nm)
    }
    out[[nm]] <- if (is.integer(base[[nm]])) as.integer(v) else as.numeric(v)
  }
  out
}

#' Limites do eduBR para um assistente
#' @keywords internal
report_limits_assistente <- function(assistente = NULL) {
  utils::modifyList(report_limits(), (assistente %||% list())$limites %||% list())
}

#' Busca um assistente pelo id (erro de cliente se não existir)
#'
#' @param id id do assistente (`NULL`/vazio = [REPORT_ASSISTENTE_PADRAO]).
#' @keywords internal
report_assistente <- function(id = NULL) {
  if (is.null(id) || identical(id, "")) id <- REPORT_ASSISTENTE_PADRAO
  if (!report_is_texto(id)) {
    stop_invalid_report("`assistente` deve ser o id de um assistente.")
  }
  todos <- report_assistentes_carregar()
  ast <- todos[[id]]
  if (is.null(ast)) {
    stop_invalid_report(sprintf(
      "Assistente desconhecido: %s.%s", id,
      if (length(todos)) sprintf(" Disponíveis: %s.", paste(names(todos), collapse = ", ")) else ""
    ))
  }
  ast
}

#' Ids dos temas usados por um assistente (temas ou capítulos)
#' @keywords internal
report_assistente_tema_ids <- function(ast) {
  if (identical(ast$modo, "tema")) {
    return(ast$temas)
  }
  unique(vapply(ast$capitulos, `[[`, character(1), "tema"))
}

#' Visão pública de um assistente (corpo de `GET /report/assistentes`)
#' @keywords internal
report_assistente_public <- function(ast) {
  vazio <- structure(list(), names = character(0))
  opcoes <- lapply(ast$opcoes, function(o) as.list(o$valores))
  padroes <- Filter(Negate(is.null), lapply(ast$opcoes, function(o) o$padrao))
  out <- list(
    id = ast$id,
    titulo = ast$titulo,
    descricao = ast$descricao,
    modo = ast$modo,
    niveis = as.list(ast$niveis),
    publico = as.list(ast$publico)
  )
  if (identical(ast$modo, "tema")) {
    out$temas <- as.list(ast$temas)
  } else {
    out$capitulos <- lapply(ast$capitulos, function(ch) {
      c(
        list(id = ch$id, tema = ch$tema, titulo = ch$titulo),
        if (!is.null(ch$recorte)) list(opcional = TRUE)
      )
    })
  }
  out$opcoes <- if (length(opcoes)) opcoes else vazio
  out$padroes <- if (length(padroes)) padroes else vazio
  out
}

#' Assistentes disponíveis
#'
#' Corpo de `GET /report/assistentes`. O backend filtra por `publico`; o
#' parâmetro `publico` permite filtrar aqui também.
#'
#' @param publico `NULL` (todos) ou um perfil (ex.: `"gestor"`).
#'
#' @return `{assistentes: [{id, titulo, descricao, modo, niveis, publico,
#'   temas?, capitulos?: [{id, tema, titulo, opcional?}], opcoes, padroes}]}`.
#'
#' @export
report_assistentes <- function(publico = NULL) {
  todos <- report_assistentes_carregar()
  if (!is.null(publico) && !identical(publico, "")) {
    todos <- Filter(function(a) publico %in% a$publico, todos)
  }
  # O padrão (Relatório por tema) vem primeiro; os demais pelo id.
  ids <- names(todos)
  ids <- c(intersect(REPORT_ASSISTENTE_PADRAO, ids), sort(setdiff(ids, REPORT_ASSISTENTE_PADRAO)))
  list(assistentes = unname(lapply(todos[ids], report_assistente_public)))
}
