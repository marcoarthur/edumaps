# R/report-roteiros.R
#
# Roteiros FIXOS por tema do Assistente de Relatório (#219). Cada roteiro
# recebe o `report_request_model` e o `edubr_source`, chama as ferramentas do
# eduBR de forma determinística e devolve as seções de DADOS do relatório:
#
#   list(recorte = {nivel, codigo, nome, uf?},
#        secoes  = [indicadores/tabela/grafico],
#        fontes  = [...], avisos = [...],
#        leitura = markdown padrão da seção "Como ler")
#
# As seções `resumo` e `leitura` (texto) são redigidas depois, em
# [analyze_report()]. Aqui não há LLM.
#
# Contas feitas no R (somas de contagens, proporções sobre o total) são
# deterministas e ficam declaradas na `nota` da tabela; o LLM é proibido de
# fazer contas próprias.

# ---------------------------------------------------------------------------
# Recorte

#' Resolve o nome de um município pelo eduBR (`municipios`)
#'
#' Código IBGE inexistente é erro do cliente (400).
#'
#' @keywords internal
report_resolve_municipio <- function(source, model, acc) {
  res <- edubr_fetch_within(
    source, "municipios", list(uf = model$uf, n = 1000L),
    keep = function(d) as.character(d$codigo_ibge) == model$codigo
  )
  if (!nrow(res$rows)) {
    stop_invalid_report(sprintf(
      "Município não encontrado: código IBGE %s.", model$codigo
    ))
  }
  nome <- res$rows$nome[[1]] %||% res$rows$nome_municipio[[1]]
  list(nivel = "municipio", codigo = model$codigo, nome = nome, uf = model$uf)
}

#' Recorte de UF ou região (sem consulta)
#' @keywords internal
report_recorte_static <- function(model) {
  if (model$nivel == "uf") {
    return(list(
      nivel = "uf", codigo = model$codigo,
      nome = unname(REPORT_UF_NOMES[[model$codigo]]), uf = model$codigo
    ))
  }
  list(
    nivel = "regiao", codigo = model$codigo,
    nome = report_regiao_label(model$codigo)
  )
}

#' Nome de exibição do recorte (para títulos)
#' @keywords internal
report_recorte_display <- function(recorte) {
  switch(recorte$nivel,
    municipio = sprintf("%s (%s)", recorte$nome, recorte$uf),
    escola = if (!is.null(recorte$municipio)) {
      sprintf("%s — %s (%s)", recorte$nome, recorte$municipio, recorte$uf)
    } else {
      recorte$nome
    },
    recorte$nome
  )
}

#' Fatias por rede conforme a opção `rede`
#'
#' Sem rede: as quatro redes. "publica": as três públicas. Rede única: sem
#' fatia de rede (só localização, se pedida).
#'
#' @keywords internal
report_rede_splits <- function(rede, localizacao = FALSE) {
  if (is.null(rede)) {
    return(edubr_splits_rede(REPORT_REDES, localizacao))
  }
  if (identical(rede, "publica")) {
    return(edubr_splits_rede(c("Municipal", "Estadual", "Federal"), localizacao))
  }
  if (isTRUE(localizacao)) {
    return(list(list(localizacao = "urbana"), list(localizacao = "rural")))
  }
  list()
}

#' Ordena um data.frame pela rede (Municipal, Estadual, Federal, Privada)
#' @keywords internal
report_order_rede <- function(df) {
  if (!nrow(df) || is.null(df$rede)) {
    return(df)
  }
  df[order(match(df$rede, c(REPORT_REDES, "publica")), df$rede), , drop = FALSE]
}

#' Soma colunas numéricas por grupo (base R, sem dependências)
#' @keywords internal
report_sum_by <- function(df, by, cols) {
  if (!nrow(df)) {
    return(data.frame())
  }
  cols <- intersect(cols, names(df))
  for (c in cols) df[[c]] <- as.numeric(df[[c]])
  key <- interaction(df[by], drop = TRUE, lex.order = TRUE)
  parts <- split(df, key)
  out <- lapply(parts, function(p) {
    row <- p[1, by, drop = FALSE]
    for (c in cols) row[[c]] <- sum(p[[c]], na.rm = TRUE)
    row
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

#' Proporção segura (NA quando o denominador é zero/NA)
#' @keywords internal
report_prop <- function(num, den) {
  ifelse(is.na(den) | den == 0, NA_real_, num / den)
}

# ---------------------------------------------------------------------------
# Tema: IDEB do território

#' Roteiro do tema `ideb_territorio` (`ideb_agregado`)
#' @keywords internal
roteiro_ideb_territorio <- function(model, source) {
  acc <- report_acc()
  etapa <- model$opcoes$etapa
  rede <- model$opcoes$rede
  base <- list(etapa = etapa, rede = rede)
  ano <- NA_integer_

  # territorio: linha do recorte; ref: linha do nível de cima;
  # comparativo: linhas do mesmo nível (para o gráfico);
  # terr_rede/ref_rede: separação por rede (só sem filtro de rede).
  terr <- ref <- comparativo <- terr_rede <- ref_rede <- data.frame()
  ref_label <- NULL
  escopo <- NULL

  pegar <- function(res) {
    report_add_avisos(acc, res$avisos)
    ed <- res$envelopes[[1]]$metadados$filtros$ano
    if (!is.null(ed)) ano <<- as.integer(ed)
    res$rows
  }
  chamar <- function(args) {
    env <- edubr_call(source, "ideb_agregado", c(base, args))
    pegar(list(rows = edubr_rows(env), envelopes = list(env), avisos = edubr_avisos(env, "ideb_agregado"), n = length(env$dados)))
  }
  # `n` da fonte: linhas da consulta principal do recorte (ex.: os municípios
  # da UF em que o município foi procurado).
  n_principal <- 0L

  if (model$nivel == "municipio") {
    recorte <- report_resolve_municipio(source, model, acc)
    alvo <- function(d) as.character(d$co_municipio) == model$codigo
    principal <- edubr_fetch_within(
      source, "ideb_agregado",
      c(base, list(nivel = "municipio", uf = model$uf, n = 1000L)),
      keep = alvo
    )
    n_principal <- as.integer(principal$n)
    terr <- pegar(principal)
    ref <- chamar(list(nivel = "uf", uf = model$uf))
    ref_label <- model$uf
    if (is.null(rede)) {
      terr_rede <- pegar(edubr_fetch_within(
        source, "ideb_agregado",
        c(base, list(nivel = "municipio", uf = model$uf, por_rede = TRUE, n = 1000L)),
        keep = alvo,
        splits = report_rede_splits(NULL)
      ))
      ref_rede <- chamar(list(nivel = "uf", uf = model$uf, por_rede = TRUE))
    }
    escopo <- sprintf("municípios de %s", model$uf)
  } else if (model$nivel == "uf") {
    recorte <- report_recorte_static(model)
    comparativo <- chamar(list(nivel = "uf", regiao = model$regiao))
    n_principal <- nrow(comparativo)
    terr <- comparativo[comparativo$sg_uf == model$uf, , drop = FALSE]
    ref <- chamar(list(nivel = "regiao", regiao = model$regiao))
    ref_label <- REPORT_REGIOES[[model$regiao]]
    if (is.null(rede)) {
      terr_rede <- chamar(list(nivel = "uf", uf = model$uf, por_rede = TRUE))
      ref_rede <- chamar(list(nivel = "regiao", regiao = model$regiao, por_rede = TRUE))
    }
    escopo <- sprintf("UFs da %s", report_regiao_label(model$regiao))
  } else {
    recorte <- report_recorte_static(model)
    comparativo <- chamar(list(nivel = "regiao"))
    n_principal <- nrow(comparativo)
    terr <- comparativo[comparativo$nome_regiao == REPORT_REGIOES[[model$regiao]], , drop = FALSE]
    if (is.null(rede)) {
      terr_rede <- chamar(list(nivel = "regiao", regiao = model$regiao, por_rede = TRUE))
    }
    escopo <- "macrorregiões do Brasil"
  }

  edicao_txt <- sprintf("IDEB %s — %s", ano, report_etapa_short(etapa))
  secoes <- list()

  if (nrow(terr)) {
    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", sprintf("IDEB %s — %s (%s)", ano, report_etapa_label(etapa), report_rede_label(rede)),
      list(
        report_kpi(
          sprintf("IDEB médio %s", ano), terr$ideb_medio, "decimal1",
          if (nrow(ref)) list(rotulo = ref_label, valor = ref$ideb_medio)
        ),
        report_kpi(
          "Escolas com nota", terr$escolas_com_nota, "inteiro",
          if (nrow(ref)) list(rotulo = ref_label, valor = ref$escolas_com_nota)
        ),
        report_kpi("Escolas no IDEB", terr$escolas, "inteiro")
      )
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf(
        "Sem IDEB %s para %s na etapa e rede escolhidas.",
        ano, report_recorte_display(recorte)
      )
    )))
  }

  if (nrow(terr_rede)) {
    tab <- terr_rede[, c("rede", "ideb_medio", "escolas_com_nota"), drop = FALSE]
    if (nrow(ref_rede)) {
      tab$ideb_referencia <- ref_rede$ideb_medio[match(tab$rede, ref_rede$rede)]
    }
    tab <- report_order_rede(tab)
    colunas <- list(
      report_col("rede", "Rede"),
      report_col("ideb_medio", sprintf("IDEB — %s", recorte$nome), "decimal1"),
      report_col("escolas_com_nota", "Escolas com nota", "inteiro")
    )
    if (!is.null(ref_label)) {
      colunas[[length(colunas) + 1L]] <- report_col("ideb_referencia", sprintf("IDEB — %s", ref_label), "decimal1")
    }
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "ideb_por_rede", "IDEB por rede", colunas, tab,
      nota = "Média simples das escolas com nota (não ponderada por matrículas). Compare só dentro da mesma edição e etapa."
    )
    if (!is.null(ref_label) && nrow(ref_rede)) {
      series <- list(
        list(id = "ideb_medio", rotulo = recorte$nome),
        list(id = "ideb_referencia", rotulo = ref_label)
      )
    } else {
      series <- list(list(id = "ideb_medio", rotulo = recorte$nome))
    }
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_rede", "IDEB por rede", "barras",
      x = list(id = "rede", rotulo = "Rede"), series = series, dados = tab,
      formato = "decimal1"
    )
  }

  if (nrow(comparativo)) {
    xid <- if (model$nivel == "uf") "sg_uf" else "nome_regiao"
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_comparativo",
      if (model$nivel == "uf") {
        sprintf("IDEB médio das UFs da %s", report_regiao_label(model$regiao))
      } else {
        "IDEB médio por macrorregião"
      },
      "barras",
      x = list(id = xid, rotulo = if (model$nivel == "uf") "UF" else "Região"),
      series = list(list(id = "ideb_medio", rotulo = "IDEB médio")),
      dados = comparativo,
      formato = "decimal1"
    )
  }

  report_add_fonte(acc, report_fonte(
    "ideb_agregado",
    "IDEB médio agregado no banco (média simples das escolas com nota)",
    edicao_txt, escopo, n_principal
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- O IDEB vai de 0 a 10 e combina aprovação e notas do SAEB.",
      sprintf("- Os números são da edição %s do IDEB, %s.", ano, report_etapa_label(etapa)),
      "- A média é simples entre as escolas com nota: escolas grandes e pequenas pesam igual.",
      "- Compare só dentro da mesma edição, etapa e rede; escolas sem nota (poucos alunos avaliados) ficam de fora.",
      "- Diferenças entre territórios descrevem a situação, não explicam as causas.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Redes de ensino

REDES_COUNT_COLS <- c(
  "total_escolas", "total_matriculas", "total_docentes",
  "docentes_superior", "docentes_concursados"
)

#' Roteiro do tema `redes_territorio` (`redes_municipio`)
#' @keywords internal
roteiro_redes_territorio <- function(model, source) {
  acc <- report_acc()
  rede <- model$opcoes$rede
  n_lidas <- 0L
  completo <- TRUE

  buscar <- function(uf, keep = NULL) {
    res <- edubr_fetch_within(
      source, "redes_municipio",
      list(uf = uf, rede = rede, n = 1000L),
      keep = keep,
      splits = report_rede_splits(rede)
    )
    report_add_avisos(acc, res$avisos)
    n_lidas <<- n_lidas + as.integer(res$n)
    completo <<- completo && res$completo
    res$rows
  }

  if (model$nivel == "municipio") {
    recorte <- report_resolve_municipio(source, model, acc)
    rows <- buscar(model$uf, keep = function(d) as.character(d$co_municipio) == model$codigo)
    escopo <- sprintf("municípios de %s", model$uf)
  } else if (model$nivel == "uf") {
    recorte <- report_recorte_static(model)
    rows <- buscar(model$uf)
    escopo <- sprintf("municípios de %s", model$uf)
  } else {
    recorte <- report_recorte_static(model)
    rows <- edubr_bind_rows(lapply(report_regiao_ufs(model$regiao), buscar))
    escopo <- sprintf("municípios da %s", report_regiao_label(model$regiao))
  }

  secoes <- list()
  if (nrow(rows)) {
    por_rede <- report_sum_by(rows, "rede", REDES_COUNT_COLS)
    por_rede$perc_superior <- report_prop(por_rede$docentes_superior, por_rede$total_docentes)
    por_rede$perc_concursados <- report_prop(por_rede$docentes_concursados, por_rede$total_docentes)
    por_rede$alunos_por_docente <- report_prop(por_rede$total_matriculas, por_rede$total_docentes)
    por_rede <- report_order_rede(por_rede)

    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", sprintf("Visão geral (Censo Escolar, %s)", report_rede_label(rede)),
      list(
        report_kpi("Escolas", sum(por_rede$total_escolas, na.rm = TRUE), "inteiro"),
        report_kpi("Matrículas", sum(por_rede$total_matriculas, na.rm = TRUE), "inteiro"),
        report_kpi("Professores (vínculos)", sum(por_rede$total_docentes, na.rm = TRUE), "inteiro")
      )
    )

    colunas <- list(
      report_col("rede", "Rede"),
      report_col("total_escolas", "Escolas", "inteiro"),
      report_col("total_matriculas", "Matrículas", "inteiro"),
      report_col("total_docentes", "Professores", "inteiro"),
      report_col("perc_superior", "Professores com superior", "percentual"),
      report_col("perc_concursados", "Professores concursados", "percentual"),
      report_col("alunos_por_docente", "Alunos por professor", "decimal1")
    )
    nota <- paste(
      "Somas das contagens por município; percentuais e alunos por professor",
      "calculados pelo EduMaps sobre essas somas."
    )
    if (model$nivel == "municipio") {
      # No município a linha da rede já traz o IDEB médio da rede.
      por_rede$ideb_fund_i <- rows$ideb_fund_i[match(por_rede$rede, rows$rede)]
      por_rede$ideb_fund_ii <- rows$ideb_fund_ii[match(por_rede$rede, rows$rede)]
      por_rede$ideb_medio <- rows$ideb_medio[match(por_rede$rede, rows$rede)]
      ano_ideb <- suppressWarnings(max(rows$ano_ideb, na.rm = TRUE))
      colunas <- c(colunas, list(
        report_col("ideb_fund_i", sprintf("IDEB anos iniciais (%s)", ano_ideb), "decimal1"),
        report_col("ideb_fund_ii", sprintf("IDEB anos finais (%s)", ano_ideb), "decimal1"),
        report_col("ideb_medio", sprintf("IDEB ensino médio (%s)", ano_ideb), "decimal1")
      ))
      nota <- paste(
        "Dados do Censo Escolar por rede no município; o IDEB é a média das",
        "escolas da rede na edição indicada (vazio = rede não avaliada)."
      )
    }
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "redes", "Redes de ensino", colunas, por_rede, nota = nota
    )
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_matriculas", "Matrículas por rede", "barras",
      x = list(id = "rede", rotulo = "Rede"),
      series = list(list(id = "total_matriculas", rotulo = "Matrículas")),
      dados = por_rede, formato = "inteiro"
    )

    if (model$nivel == "regiao") {
      por_uf <- report_sum_by(rows, "sg_uf", REDES_COUNT_COLS)
      por_uf <- por_uf[order(match(por_uf$sg_uf, report_regiao_ufs(model$regiao))), , drop = FALSE]
      secoes[[length(secoes) + 1L]] <- report_section_table(
        "redes_por_uf", "Por UF",
        list(
          report_col("sg_uf", "UF"),
          report_col("total_escolas", "Escolas", "inteiro"),
          report_col("total_matriculas", "Matrículas", "inteiro"),
          report_col("total_docentes", "Professores", "inteiro")
        ),
        por_uf,
        nota = "Somas das contagens dos municípios de cada UF."
      )
    }
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf("Sem dados de redes para %s.", report_recorte_display(recorte))
    )))
  }

  report_add_fonte(acc, report_fonte(
    "redes_municipio",
    "Redes escolares por município (escolas, matrículas, professores e IDEB médio)",
    "Censo Escolar 2025", escopo, n_lidas
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- Cada rede (federal, estadual, municipal e privada) aparece separada.",
      "- Professores são contados por vínculo com a escola: quem dá aula em duas escolas conta duas vezes.",
      "- Os percentuais foram calculados sobre o total de professores de cada rede.",
      "- Números maiores refletem o tamanho da rede, não a sua qualidade.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Professores

#' Colunas de contagem pedidas ao `docentes_rede` (lacuna da Fase 0:
#' sem `colunas` a resposta estoura o limite de caracteres)
#' @keywords internal
DOCENTES_COLUNAS <- c(
  "qt_doc_bas_esco_sup_grad", "qt_doc_bas_esco_sup_grad_licen",
  "qt_doc_bas_esco_sup_pos_espec", "qt_doc_bas_esco_sup_pos_mestra",
  "qt_doc_bas_esco_sup_pos_douto", "qt_doc_bas_vinculo_concur",
  "qt_doc_bas_vinculo_contra"
)

#' Roteiro do tema `docentes_territorio` (`docentes_rede` com `colunas`)
#' @keywords internal
roteiro_docentes_territorio <- function(model, source) {
  acc <- report_acc()
  rede <- model$opcoes$rede
  base <- list(rede = rede, colunas = as.list(DOCENTES_COLUNAS))
  conta <- c("qt_doc_bas", DOCENTES_COLUNAS)
  n_lidas <- 0L

  pegar <- function(res) {
    report_add_avisos(acc, res$avisos)
    n_lidas <<- n_lidas + as.integer(res$n)
    res$rows
  }
  chamar <- function(args) {
    env <- edubr_call(source, "docentes_rede", c(base, args))
    pegar(list(rows = edubr_rows(env), avisos = edubr_avisos(env, "docentes_rede"), n = length(env$dados)))
  }

  if (model$nivel == "municipio") {
    recorte <- report_resolve_municipio(source, model, acc)
    terr <- pegar(edubr_fetch_within(
      source, "docentes_rede",
      c(base, list(nivel = "municipio", uf = model$uf, n = 1000L)),
      keep = function(d) as.character(d$co_municipio) == model$codigo,
      splits = report_rede_splits(rede, localizacao = TRUE)
    ))
    ref <- chamar(list(nivel = "uf", uf = model$uf))
    ref_label <- model$uf
    escopo <- sprintf("municípios de %s", model$uf)
  } else if (model$nivel == "uf") {
    recorte <- report_recorte_static(model)
    terr <- chamar(list(nivel = "uf", uf = model$uf))
    ref <- chamar(list(nivel = "regiao", regiao = model$regiao))
    ref_label <- REPORT_REGIOES[[model$regiao]]
    escopo <- sprintf("%s e %s", model$uf, report_regiao_label(model$regiao))
  } else {
    recorte <- report_recorte_static(model)
    terr <- chamar(list(nivel = "regiao", regiao = model$regiao))
    ref <- chamar(list(nivel = "brasil"))
    ref_label <- "Brasil"
    escopo <- sprintf("%s e Brasil", report_regiao_label(model$regiao))
  }

  secoes <- list()
  if (nrow(terr)) {
    # Soma urbana + rural por rede; total geral para os indicadores.
    por_rede <- report_order_rede(report_sum_by(terr, "rede", conta))
    total <- colSums(por_rede[, intersect(conta, names(por_rede)), drop = FALSE], na.rm = TRUE)
    ref_total <- if (nrow(ref)) {
      r <- report_sum_by(ref, "rede", conta)
      colSums(r[, intersect(conta, names(r)), drop = FALSE], na.rm = TRUE)
    }
    p <- function(tot, col) {
      if (is.null(tot) || !col %in% names(tot)) NA else report_prop(tot[[col]], tot[["qt_doc_bas"]])
    }

    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", sprintf("Professores (Censo Escolar 2025, %s)", report_rede_label(rede)),
      list(
        report_kpi("Professores (vínculos)", total[["qt_doc_bas"]], "inteiro"),
        report_kpi(
          "Com ensino superior", p(total, "qt_doc_bas_esco_sup_grad"), "percentual",
          list(rotulo = ref_label, valor = p(ref_total, "qt_doc_bas_esco_sup_grad"))
        ),
        report_kpi(
          "Com pós-graduação (especialização)", p(total, "qt_doc_bas_esco_sup_pos_espec"), "percentual",
          list(rotulo = ref_label, valor = p(ref_total, "qt_doc_bas_esco_sup_pos_espec"))
        ),
        report_kpi(
          "Concursados", p(total, "qt_doc_bas_vinculo_concur"), "percentual",
          list(rotulo = ref_label, valor = p(ref_total, "qt_doc_bas_vinculo_concur"))
        )
      )
    )

    tab <- por_rede
    pct <- c(
      perc_superior = "qt_doc_bas_esco_sup_grad",
      perc_licenciatura = "qt_doc_bas_esco_sup_grad_licen",
      perc_especializacao = "qt_doc_bas_esco_sup_pos_espec",
      perc_mestrado = "qt_doc_bas_esco_sup_pos_mestra",
      perc_doutorado = "qt_doc_bas_esco_sup_pos_douto",
      perc_concursados = "qt_doc_bas_vinculo_concur",
      perc_contratados = "qt_doc_bas_vinculo_contra"
    )
    for (nm in names(pct)) tab[[nm]] <- report_prop(tab[[pct[[nm]]]], tab$qt_doc_bas)

    secoes[[length(secoes) + 1L]] <- report_section_table(
      "docentes_por_rede", "Formação e vínculo por rede",
      list(
        report_col("rede", "Rede"),
        report_col("qt_doc_bas", "Professores", "inteiro"),
        report_col("perc_superior", "Superior", "percentual"),
        report_col("perc_licenciatura", "Licenciatura", "percentual"),
        report_col("perc_especializacao", "Especialização", "percentual"),
        report_col("perc_mestrado", "Mestrado", "percentual"),
        report_col("perc_doutorado", "Doutorado", "percentual"),
        report_col("perc_concursados", "Concursados", "percentual"),
        report_col("perc_contratados", "Contrato temporário", "percentual")
      ),
      tab,
      nota = paste(
        "Contagens de vínculos escola-professor (quem atua em duas escolas conta",
        "duas vezes), somadas entre zonas urbana e rural. Percentuais calculados",
        "pelo EduMaps sobre o total de professores da rede."
      )
    )
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_formacao", "Formação e vínculo por rede", "barras",
      x = list(id = "rede", rotulo = "Rede"),
      series = list(
        list(id = "perc_superior", rotulo = "Com superior"),
        list(id = "perc_especializacao", rotulo = "Com especialização"),
        list(id = "perc_concursados", rotulo = "Concursados")
      ),
      dados = tab, formato = "percentual"
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf("Sem dados de professores para %s.", report_recorte_display(recorte))
    )))
  }

  report_add_fonte(acc, report_fonte(
    "docentes_rede",
    "Contagens de professores por rede, localização e território",
    "Censo Escolar 2025", escopo, n_lidas
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- Professores são contados por vínculo: quem dá aula em duas escolas aparece duas vezes.",
      "- Os percentuais mostram a parcela dos professores de cada rede com a formação ou o vínculo indicado.",
      "- A comparação é com o nível de cima (estado, região ou Brasil), no mesmo Censo (2025).",
      "- O vínculo concursado/temporário vale para as redes públicas.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Perfil dos gestores

#' Roteiro do tema `gestores_territorio` (`perfil_gestor`)
#' @keywords internal
roteiro_gestores_territorio <- function(model, source) {
  acc <- report_acc()
  rede <- model$opcoes$rede
  recorte <- report_recorte_static(model)
  n_lidas <- 0L

  chamar <- function(args) {
    env <- edubr_call(source, "perfil_gestor", c(list(rede = rede, unidade = "gestor"), args))
    report_add_avisos(acc, edubr_avisos(env, "perfil_gestor"))
    n_lidas <<- n_lidas + length(env$dados)
    n_corte <- env$metadados$contexto$n_por_corte %||% list()
    list(
      rows = edubr_rows(env),
      n = if (length(n_corte)) n_corte[[1]] else list()
    )
  }

  if (model$nivel == "uf") {
    terr <- chamar(list(corte = "uf", uf = model$uf))
    ref <- chamar(list(corte = "regiao", regiao = model$regiao))
    ref_label <- REPORT_REGIOES[[model$regiao]]
  } else {
    terr <- chamar(list(corte = "regiao", regiao = model$regiao))
    ref <- chamar(list(corte = "brasil"))
    ref_label <- "Brasil"
  }

  secoes <- list()
  if (nrow(terr$rows)) {
    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", sprintf("Gestores escolares (Censo Escolar 2025, %s)", report_rede_label(rede)),
      list(
        report_kpi("Gestores", terr$n$n_gestores, "inteiro",
                   list(rotulo = ref_label, valor = ref$n$n_gestores)),
        report_kpi("Escolas", terr$n$n_escolas, "inteiro",
                   list(rotulo = ref_label, valor = ref$n$n_escolas))
      )
    )
    tab <- terr$rows[, c("dimensao", "categoria_modal", "prop_modal"), drop = FALSE]
    if (nrow(ref$rows)) {
      i <- match(tab$dimensao, ref$rows$dimensao)
      tab$ref_categoria <- ref$rows$categoria_modal[i]
      tab$ref_prop <- ref$rows$prop_modal[i]
    }
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "perfil_modal", "Característica mais comum dos gestores",
      list(
        report_col("dimensao", "Característica"),
        report_col("categoria_modal", sprintf("Mais comum — %s", recorte$nome)),
        report_col("prop_modal", "Parcela", "percentual"),
        report_col("ref_categoria", sprintf("Mais comum — %s", ref_label)),
        report_col("ref_prop", sprintf("Parcela — %s", ref_label), "percentual")
      ),
      tab,
      nota = paste(
        "Categoria modal (a mais frequente) de cada característica e a parcela",
        "de gestores nela. Contagens agregadas do Censo, sem dados pessoais."
      )
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf("Sem dados de gestores para %s.", recorte$nome)
    )))
  }

  report_add_fonte(acc, report_fonte(
    "perfil_gestor",
    "Perfil modal dos gestores escolares (contagens agregadas)",
    "Censo Escolar 2025",
    sprintf("%s e %s", recorte$nome, ref_label), n_lidas
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- Para cada característica aparece a categoria mais comum e a parcela de gestores nela.",
      "- Quanto maior a parcela, mais parecidos são os gestores naquela característica.",
      "- Cor/raça não declarada fica fora da conta; o vínculo vale só para escolas públicas.",
      "- São dados agregados do Censo Escolar 2025, sem identificar pessoas.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Tendência do IDEB

#' Edições bienais do IDEB
#' @keywords internal
REPORT_EDICOES_IDEB <- seq(2005L, 2023L, by = 2L)

#' Roteiro do tema `tendencia_ideb` (`tendencia_ideb_regiao` + série do
#' `ideb_agregado` por edição)
#' @keywords internal
roteiro_tendencia_ideb <- function(model, source) {
  acc <- report_acc()
  etapa <- model$opcoes$etapa
  rede <- model$opcoes$rede
  recorte <- report_recorte_static(model)
  nome_regiao <- REPORT_REGIOES[[model$regiao]]

  env <- edubr_call(source, "tendencia_ideb_regiao", list(etapa = etapa, rede = rede))
  report_add_avisos(acc, edubr_avisos(env, "tendencia_ideb_regiao"))
  trend <- edubr_rows(env)
  if (nrow(trend)) trend <- trend[trend$termo == "ano", , drop = FALSE]

  # Série: IDEB médio de cada região por edição (uma chamada por edição).
  serie <- list()
  sem_edicao <- integer()
  n_serie <- 0L
  for (ano in REPORT_EDICOES_IDEB) {
    e <- edubr_call(source, "ideb_agregado", list(etapa = etapa, rede = rede, nivel = "regiao", ano = ano))
    rows <- edubr_rows(e)
    if (!nrow(rows)) {
      sem_edicao <- c(sem_edicao, ano)
      next
    }
    n_serie <- n_serie + nrow(rows)
    linha <- data.frame(ano = ano)
    for (sg in names(REPORT_REGIOES)) {
      v <- rows$ideb_medio[rows$nome_regiao == REPORT_REGIOES[[sg]]]
      linha[[sg]] <- if (length(v)) v[[1]] else NA_real_
    }
    serie[[length(serie) + 1L]] <- linha
  }
  serie <- edubr_bind_rows(serie)
  if (length(sem_edicao)) {
    report_add_avisos(acc, list(list(
      tipo = "aviso",
      mensagem = sprintf(
        "Edições sem IDEB para a etapa/rede escolhidas: %s.",
        paste(sem_edicao, collapse = ", ")
      )
    )))
  }

  secoes <- list()
  alvo <- if (nrow(trend)) trend[trend$sigla_regiao == model$regiao, , drop = FALSE] else trend
  if (nrow(alvo)) {
    primeiro <- if (nrow(serie)) serie[which(!is.na(serie[[model$regiao]]))[1], , drop = FALSE] else NULL
    ultimo <- if (nrow(serie)) serie[utils::tail(which(!is.na(serie[[model$regiao]])), 1), , drop = FALSE] else NULL
    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", sprintf("Tendência do IDEB — %s (%s)", report_etapa_label(etapa), report_rede_label(rede)),
      list(
        if (!is.null(primeiro) && nrow(primeiro)) {
          report_kpi(sprintf("IDEB médio %s", primeiro$ano), primeiro[[model$regiao]], "decimal1")
        },
        if (!is.null(ultimo) && nrow(ultimo)) {
          report_kpi(sprintf("IDEB médio %s", ultimo$ano), ultimo[[model$regiao]], "decimal1")
        },
        report_kpi("Variação média por ano (tendência linear)", alvo$estimativa, "decimal2"),
        report_kpi("Ajuste da reta (R²)", alvo$r2, "decimal2"),
        report_kpi("Edições usadas", alvo$nobs, "inteiro")
      )
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf("Sem tendência do IDEB para a %s na etapa/rede escolhidas.", nome_regiao)
    )))
  }

  if (nrow(serie)) {
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_serie", "IDEB médio por edição e região", "linhas",
      x = list(id = "ano", rotulo = "Edição"),
      series = lapply(names(REPORT_REGIOES), function(sg) {
        list(id = sg, rotulo = REPORT_REGIOES[[sg]])
      }),
      dados = serie, formato = "decimal1"
    )
  }

  if (nrow(trend)) {
    tab <- trend[order(match(trend$sigla_regiao, names(REPORT_REGIOES))), , drop = FALSE]
    tab$periodo <- sprintf("%s–%s", tab$ano_inicial, tab$ano_final)
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "tendencia_regioes", "Tendência linear por região",
      list(
        report_col("nome_regiao", "Região"),
        report_col("estimativa", "Variação por ano", "decimal2"),
        report_col("erro_padrao", "Erro-padrão", "decimal2"),
        report_col("p_valor", "p-valor", "decimal2"),
        report_col("r2", "R²", "decimal2"),
        report_col("nobs", "Edições", "inteiro"),
        report_col("periodo", "Período")
      ),
      tab,
      nota = paste(
        "Reta ajustada ao IDEB médio (média simples das escolas) de cada edição.",
        "É associação temporal, não causa; com poucas edições o p-valor e o R² são frágeis."
      )
    )
  }

  report_add_fonte(acc, report_fonte(
    "tendencia_ideb_regiao",
    "Tendência linear do IDEB médio por macrorregião",
    sprintf("IDEB %s — %s", paste(range(REPORT_EDICOES_IDEB), collapse = "–"), report_etapa_short(etapa)),
    "macrorregiões do Brasil", length(env$dados)
  ))
  if (n_serie) {
    report_add_fonte(acc, report_fonte(
      "ideb_agregado",
      "IDEB médio agregado por macrorregião em cada edição",
      sprintf("IDEB %s — %s", paste(range(serie$ano), collapse = "–"), report_etapa_short(etapa)),
      "macrorregiões do Brasil", n_serie
    ))
  }

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- A linha mostra o IDEB médio das escolas da região em cada edição (a cada dois anos).",
      "- A variação por ano vem de uma reta ajustada aos pontos: positiva indica melhora média ao longo do período.",
      "- O R² vai de 0 a 1: perto de 1, os pontos seguem bem a reta.",
      "- As escolas avaliadas mudam de uma edição para outra; a tendência descreve, não explica.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Minha escola

#' Roteiro do tema `minha_escola` (`perfil_escola`)
#' @keywords internal
roteiro_minha_escola <- function(model, source) {
  acc <- report_acc()
  env <- edubr_call(source, "perfil_escola", list(escola_id = model$codigo))
  if (!edubr_has_data(env)) {
    stop_invalid_report(sprintf(
      "Escola não encontrada no Censo Escolar: INEP %s.", model$codigo
    ))
  }
  report_add_avisos(acc, edubr_avisos(env, "perfil_escola"))
  ctx <- env$metadados$contexto %||% list()
  rows <- edubr_rows(env)

  recorte <- list(
    nivel = "escola",
    codigo = model$codigo,
    nome = ctx$nome %||% model$codigo,
    uf = ctx$uf,
    municipio = ctx$municipio
  )
  rede_txt <- if (!is.null(ctx$rede)) paste("rede", tolower(ctx$rede)) else "mesma rede"

  secoes <- list()
  ideb <- rows[rows$dimensao == "IDEB", , drop = FALSE]
  # Etapa sem nota em nenhum nível (ex.: a escola nunca ofertou) não entra.
  if (nrow(ideb)) {
    ideb <- ideb[!(is.na(ideb$escola) & is.na(ideb$municipio) & is.na(ideb$estado)), , drop = FALSE]
  }
  doc <- rows[rows$dimensao == "Docentes", , drop = FALSE]
  infra <- rows[rows$dimensao == "Infraestrutura", , drop = FALSE]

  itens <- lapply(seq_len(nrow(ideb)), function(i) {
    report_kpi(
      ideb$item[[i]], ideb$escola[[i]], "decimal1",
      list(rotulo = sprintf("%s (%s)", ctx$municipio %||% "Município", rede_txt), valor = ideb$municipio[[i]])
    )
  })
  if (nrow(doc)) {
    itens[[length(itens) + 1L]] <- report_kpi(
      "Professores", doc$escola[[1]], "inteiro",
      list(rotulo = sprintf("Média do município (%s)", rede_txt), valor = doc$municipio[[1]])
    )
  }
  secoes[[length(secoes) + 1L]] <- report_section_kpis("kpis", "A escola em números", itens)

  if (nrow(ideb)) {
    tab <- ideb
    of <- tab$ofertada %||% rep(NA, nrow(tab))
    tab$ofertada_txt <- ifelse(is.na(of), "—", ifelse(of %in% TRUE, "Sim", "Não"))
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "ideb", "IDEB: escola, município e estado",
      list(
        report_col("item", "Etapa (edição)"),
        report_col("escola", "Escola", "decimal1"),
        report_col("municipio", "Município", "decimal1"),
        report_col("estado", "Estado", "decimal1"),
        report_col("dif_municipio", "Escola − município", "decimal1"),
        report_col("ofertada_txt", "Etapa ainda ofertada")
      ),
      tab,
      nota = sprintf(
        "Município e estado: média simples das escolas em atividade da %s, na mesma edição.",
        rede_txt
      )
    )
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_ideb", "IDEB: escola, município e estado", "barras",
      x = list(id = "item", rotulo = "Etapa"),
      series = list(
        list(id = "escola", rotulo = "Escola"),
        list(id = "municipio", rotulo = "Município"),
        list(id = "estado", rotulo = "Estado")
      ),
      dados = ideb, formato = "decimal1"
    )
  }

  if (nrow(infra)) {
    tab <- infra
    tab$escola_txt <- ifelse(is.na(tab$escola), "—", ifelse(tab$escola >= 1, "Sim", "Não"))
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "infraestrutura", "Infraestrutura",
      list(
        report_col("item", "Item"),
        report_col("escola_txt", "A escola tem?"),
        report_col("municipio", "Escolas do município que têm", "percentual"),
        report_col("estado", "Escolas do estado que têm", "percentual")
      ),
      tab,
      nota = sprintf("Parcela das escolas em atividade da %s que têm o item.", rede_txt)
    )
  }

  edicoes <- unique(unlist(ctx$edicao_ideb %||% list()))
  report_add_fonte(acc, report_fonte(
    "perfil_escola",
    "Perfil da escola comparado ao município e ao estado (mesma rede)",
    sprintf(
      "Censo Escolar %s%s", ctx$ano_censo %||% 2025L,
      if (length(edicoes)) sprintf("; IDEB %s", paste(sort(edicoes), collapse = ", ")) else ""
    ),
    sprintf("escola, município de %s e estado %s", ctx$municipio %||% "?", ctx$uf %||% "?"),
    nrow(rows)
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      sprintf("- A escola é comparada às escolas em atividade da %s no município e no estado.", rede_txt),
      "- No IDEB, a comparação é sempre na mesma edição; \"Etapa ainda ofertada = Não\" indica nota histórica.",
      "- Na infraestrutura, município e estado mostram a parcela das escolas que têm cada item.",
      "- São comparações descritivas para situar a escola, não indicam causas.",
      sep = "\n"
    )
  )
}
