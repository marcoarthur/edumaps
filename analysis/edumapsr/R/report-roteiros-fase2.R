# R/report-roteiros-fase2.R
#
# Roteiros FIXOS dos temas da Fase 2 do Assistente de Relatório (#219):
#
#   - `ideb_escolas`        (profunda)   município → `municipios` + `ideb`
#   - `infraestrutura_ideb` (profunda)   UF        → `regressao_escolas`
#   - `historico_escola`    (descritiva) escola    → `resumo_escola` +
#                                                    `serie_ideb_escola` +
#                                                    `scores_escola`
#   - `escolas_parecidas`   (descritiva) escola    → `resumo_escola` +
#                                                    `escolas_similares`
#
# Como na Fase 1, nada aqui fala com o LLM: as contas (mediana, mínimo,
# máximo, posição, faixas, direção e segurança das associações) são
# DETERMINÍSTICAS no R e ficam declaradas nas notas. As ferramentas da escola
# vêm do complemento B (ferramentas sem persona, escolhidas por nome; ver
# [edubr_source()]).

#' Edição do IDEB dos temas da Fase 2 (fixa no contrato)
#' @keywords internal
REPORT_IDEB_ANO <- 2023L

#' Ano do Censo Escolar usado pela regressão (padrão do eduBR)
#' @keywords internal
REPORT_CENSO_ANO <- 2025L

#' Desfecho da regressão por etapa (colunas de `covariaveis_escola`)
#' @keywords internal
REPORT_DESFECHO_ETAPA <- c(
  fundamental_i = "ideb_fund_i",
  fundamental_ii = "ideb_fund_ii",
  ensino_medio = "ideb_medio"
)

#' Preditores fixos do tema `infraestrutura_ideb` (nomes do eduBR → rótulos)
#'
#' Conferidos no eduBR (`covariaveis_escola`: `in_*` de
#' `eduBR_infra_perfil()`, `docentes` = `qt_doc_bas`, `matriculas` =
#' `qt_mat_bas`).
#'
#' @keywords internal
REPORT_PREDITORES <- c(
  in_biblioteca = "Biblioteca",
  in_internet = "Internet",
  in_laboratorio_informatica = "Laboratório de informática",
  docentes = "Nº de professores",
  matriculas = "Nº de matrículas"
)

#' Corte fixo da regressão
#' @keywords internal
REPORT_REG_CORTE <- "localizacao"

#' Faixas de IDEB do gráfico do tema `ideb_escolas`
#' @keywords internal
REPORT_FAIXAS_IDEB <- list(
  limites = c(-Inf, 4, 5, 6, 7, Inf),
  rotulos = c("Abaixo de 4,0", "4,0 a 4,9", "5,0 a 5,9", "6,0 a 6,9", "7,0 ou mais")
)

#' Rótulos dos scores compostos da escola (0–10)
#' @keywords internal
REPORT_SCORES <- c(
  score_infraestrutura = "Infraestrutura",
  score_capacidade_atendimento = "Capacidade de atendimento",
  score_capacitacao_docente = "Capacitação docente",
  score_capacidade_gestora = "Capacidade gestora",
  score_diversidade_discente = "Diversidade discente",
  score_sustentabilidade = "Sustentabilidade"
)

#' Etapa do IDEB → sufixo das colunas de `resumo_escola`
#' @keywords internal
REPORT_ETAPA_SUFIXO <- c(
  fundamental_i = "fund_i", fundamental_ii = "fund_ii", ensino_medio = "medio"
)

#' Ordinal em PT-BR ("3ª")
#' @keywords internal
report_ordinal <- function(k) paste0(k, "ª")

#' Aviso fixo dos relatórios de regressão (contrato da Fase 2)
#' @keywords internal
report_aviso_associacao <- function() {
  list(
    tipo = "associacao",
    mensagem = paste(
      "Os resultados mostram associações entre características das escolas e",
      "o IDEB, não causas: outras diferenças entre as escolas (como o perfil",
      "das famílias) não entram no modelo."
    )
  )
}

#' Identificação da escola do gestor (`resumo_escola`)
#'
#' INEP sem dados no eduBR é erro do cliente (400).
#'
#' @return `list(recorte, linha)` (`linha` = data.frame de 1 linha).
#' @keywords internal
report_resolve_escola <- function(source, model, acc) {
  env <- edubr_call(source, "resumo_escola", list(escola_id = model$codigo))
  if (!edubr_has_data(env)) {
    stop_invalid_report(sprintf(
      "Escola não encontrada no Censo Escolar: INEP %s.", model$codigo
    ))
  }
  report_add_avisos(acc, edubr_avisos(env, "resumo_escola"))
  linha <- edubr_rows(env)[1, , drop = FALSE]
  val <- function(col) {
    v <- linha[[col]]
    if (is.null(v) || is.na(v[[1]])) NULL else v[[1]]
  }
  list(
    recorte = list(
      nivel = "escola",
      codigo = model$codigo,
      nome = val("escola") %||% model$codigo,
      uf = val("uf"),
      municipio = val("municipio")
    ),
    linha = linha,
    val = val
  )
}

# ---------------------------------------------------------------------------
# Tema: IDEB escola a escola

#' Roteiro do tema `ideb_escolas` (`municipios` + `ideb`)
#'
#' Lista as escolas do município com o IDEB da etapa (edição 2023), com
#' indicadores determinísticos (escolas com nota, mediana, mínimo, máximo),
#' a posição da escola do gestor (`contexto.cod_inep`) e um gráfico por faixa.
#' A ferramenta `ideb` filtra o município pelo NOME (com a UF); o código IBGE
#' é conferido depois, no adapter.
#'
#' @keywords internal
roteiro_ideb_escolas <- function(model, source) {
  acc <- report_acc()
  etapa <- model$opcoes$etapa
  rede <- model$opcoes$rede
  ano <- REPORT_IDEB_ANO
  recorte <- report_resolve_municipio(source, model, acc)

  res <- edubr_fetch_within(
    source, "ideb",
    list(
      uf = model$uf, municipio = recorte$nome, etapa = etapa, rede = rede,
      ano = ano, n = 1000L
    ),
    keep = function(d) {
      if (is.null(d$co_municipio)) rep(TRUE, nrow(d)) else as.character(d$co_municipio) == model$codigo
    },
    splits = report_rede_splits(rede)
  )
  report_add_avisos(acc, Filter(function(a) !identical(a$tipo, "sem_dados"), res$avisos))
  rows <- res$rows

  edicao_txt <- sprintf("IDEB %s — %s", ano, report_etapa_short(etapa))
  escopo <- sprintf(
    "escolas de %s, %s", report_recorte_display(recorte), report_rede_label(rede)
  )
  secoes <- list()
  cod_gestor <- report_codigo_texto((model$contexto %||% list())$cod_inep)

  if (!nrow(rows)) {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf(
        "Sem IDEB %s por escola em %s nos %s (%s).",
        ano, report_recorte_display(recorte), report_etapa_label(etapa),
        report_rede_label(rede)
      )
    )))
    n_escolas <- 0L
  } else {
    rows <- rows[!duplicated(rows$id_escola), , drop = FALSE]
    df <- data.frame(
      id_escola = as.character(rows$id_escola),
      escola = as.character(rows$no_escola %||% rows$id_escola),
      rede = as.character(rows$rede %||% NA_character_),
      ideb = suppressWarnings(as.numeric(rows$ideb_observado)),
      stringsAsFactors = FALSE
    )
    df <- df[order(is.na(df$ideb), -df$ideb, df$escola), , drop = FALSE]
    com_nota <- !is.na(df$ideb)
    df$posicao <- NA_integer_
    df$posicao[com_nota] <- as.integer(rank(-df$ideb[com_nota], ties.method = "min"))
    df[[REPORT_DESTAQUE]] <- !is.null(cod_gestor) & df$id_escola %in% cod_gestor
    n_escolas <- nrow(df)
    n_nota <- sum(com_nota)
    notas <- df$ideb[com_nota]

    itens <- list(
      report_kpi("Escolas com nota", n_nota, "inteiro"),
      if (n_nota) report_kpi("Mediana do IDEB", stats::median(notas), "decimal1"),
      if (n_nota) report_kpi("Menor IDEB", min(notas), "decimal1"),
      if (n_nota) report_kpi("Maior IDEB", max(notas), "decimal1")
    )
    gestor <- df[df[[REPORT_DESTAQUE]], , drop = FALSE]
    if (nrow(gestor)) {
      itens[[length(itens) + 1L]] <- if (!is.na(gestor$posicao[[1]])) {
        report_kpi(
          "Posição da sua escola",
          sprintf("%s de %d", report_ordinal(gestor$posicao[[1]]), n_nota),
          "texto"
        )
      } else {
        report_kpi("Sua escola", "sem nota nesta etapa", "texto")
      }
    }
    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis",
      sprintf("IDEB %s por escola — %s (%s)", ano, report_etapa_label(etapa), report_rede_label(rede)),
      Filter(Negate(is.null), itens)
    )

    sem_nota <- n_escolas - n_nota
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "escolas", "Escolas do município pelo IDEB",
      list(
        report_col("posicao", "Posição", "inteiro"),
        report_col("escola", "Escola"),
        report_col("rede", "Rede"),
        report_col("ideb", sprintf("IDEB %s", ano), "decimal1")
      ),
      df,
      nota = paste0(
        sprintf("Ordenada pelo IDEB %s (%s); empates dividem a mesma posição.", ano, report_etapa_label(etapa)),
        if (sem_nota > 0) {
          sprintf(
            " %d escola(s) sem nota (poucos alunos avaliados) ficam no fim, sem posição.",
            sem_nota
          )
        } else {
          ""
        },
        " A posição só descreve onde a nota está; não é um julgamento da escola."
      ),
      ocultar_llm = "escola"
    )

    if (n_nota) {
      faixa <- cut(
        notas, REPORT_FAIXAS_IDEB$limites,
        labels = REPORT_FAIXAS_IDEB$rotulos, right = FALSE
      )
      cont <- as.integer(table(factor(faixa, levels = REPORT_FAIXAS_IDEB$rotulos)))
      secoes[[length(secoes) + 1L]] <- report_section_chart(
        "grafico_faixas", "Escolas por faixa de IDEB", "barras",
        x = list(id = "faixa", rotulo = "Faixa de IDEB"),
        series = list(list(id = "escolas", rotulo = "Escolas")),
        dados = data.frame(faixa = REPORT_FAIXAS_IDEB$rotulos, escolas = cont, stringsAsFactors = FALSE),
        formato = "inteiro"
      )
    }
  }

  report_add_fonte(acc, report_fonte(
    "ideb", "IDEB observado por escola", edicao_txt, escopo, n_escolas
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      sprintf("- Cada linha é uma escola do município com o IDEB %s dos %s.", ano, report_etapa_label(etapa)),
      "- A mediana é a nota do meio da lista: metade das escolas está acima e metade abaixo.",
      "- Escolas sem nota tiveram poucos alunos avaliados; não significa nota zero.",
      "- A posição descreve onde a nota está na lista, não a qualidade da escola: o IDEB não mede tudo o que a escola faz.",
      "- Compare só escolas da mesma etapa e edição; redes diferentes atendem públicos diferentes.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Infraestrutura e IDEB

#' Roteiro do tema `infraestrutura_ideb` (`regressao_escolas`)
#'
#' Especificação FIXA (contrato da Fase 2): desfecho = IDEB 2023 da etapa;
#' preditores [REPORT_PREDITORES]; corte por localização; modelo linear;
#' só escolas em atividade da UF (e da rede escolhida; padrão "publica").
#' `limite_excedido` (recorte maior que o teto de amostra do eduBR) volta ao
#' cliente como 400, pedindo uma rede.
#'
#' @keywords internal
roteiro_infraestrutura_ideb <- function(model, source) {
  acc <- report_acc()
  etapa <- model$opcoes$etapa
  rede <- model$opcoes$rede
  recorte <- report_recorte_static(model)
  outcome <- REPORT_DESFECHO_ETAPA[[etapa]]
  preditores <- names(REPORT_PREDITORES)

  env <- edubr_call(
    source, "regressao_escolas",
    list(
      outcome = outcome, predictors = preditores, cuts = REPORT_REG_CORTE,
      uf = model$uf, rede = rede, ano = REPORT_CENSO_ANO,
      ano_ideb = REPORT_IDEB_ANO, ativas = TRUE, modelo = "linear"
    ),
    .tolerar = "limite_excedido"
  )
  if (identical(env$erro$tipo, "limite_excedido")) {
    stop_invalid_report(sprintf(
      paste(
        "%s tem escolas demais para a análise de uma vez (%s).",
        "Escolha uma rede específica (municipal ou estadual)."
      ),
      recorte$nome, report_rede_label(rede)
    ))
  }
  report_add_avisos(acc, list(report_aviso_associacao()))
  report_add_avisos(acc, edubr_avisos(env, "regressao_escolas"))

  ctx <- env$metadados$contexto %||% list()
  coef <- edubr_rows(env)
  metr <- edubr_rows(ctx$metricas %||% list())
  cortes <- edubr_rows(ctx$cortes %||% list())
  n_usado <- as.integer(ctx$n_usado %||% sum(cortes$n %||% 0, na.rm = TRUE))
  rede_txt <- report_rede_label(rede)
  escopo <- sprintf("escolas em atividade de %s (%s)", model$uf, rede_txt)
  edicao_txt <- sprintf(
    "Censo Escolar %s; IDEB %s — %s", REPORT_CENSO_ANO, REPORT_IDEB_ANO,
    report_etapa_short(etapa)
  )

  secoes <- list()
  if (nrow(coef) && all(c("termo", "estimativa", "p_valor") %in% names(coef))) {
    if (is.null(coef[[REPORT_REG_CORTE]])) coef[[REPORT_REG_CORTE]] <- NA_character_
    coef$p_valor <- suppressWarnings(as.numeric(coef$p_valor))
    coef$estimativa <- suppressWarnings(as.numeric(coef$estimativa))
    coef$erro_padrao <- suppressWarnings(as.numeric(coef$erro_padrao %||% NA_real_))

    # n por corte: métricas (nobs) ou o resumo dos cortes.
    n_corte <- function(corte) {
      fonte <- if (nrow(metr) && !is.null(metr$nobs)) metr else cortes
      col_n <- if (!is.null(fonte$nobs)) "nobs" else "n"
      if (!nrow(fonte) || is.null(fonte[[col_n]])) {
        return(NA_integer_)
      }
      v <- if (is.na(corte) || is.null(fonte[[REPORT_REG_CORTE]])) {
        fonte[[col_n]][[1]]
      } else {
        fonte[[col_n]][match(corte, fonte[[REPORT_REG_CORTE]])]
      }
      as.integer(v)
    }

    # Cortes em ordem de tamanho (o maior primeiro).
    niveis <- unique(coef[[REPORT_REG_CORTE]])
    ns <- vapply(niveis, n_corte, integer(1))
    niveis <- niveis[order(-ifelse(is.na(ns), 0L, ns))]

    itens <- list()
    for (p in preditores) {
      for (cv in niveis) {
        l <- coef[coef$termo == p & (coef[[REPORT_REG_CORTE]] %in% cv), , drop = FALSE]
        if (!nrow(l)) next
        itens[[length(itens) + 1L]] <- report_associacao(
          REPORT_PREDITORES[[p]],
          report_direcao(l$estimativa[[1]], l$p_valor[[1]]),
          report_seguranca(l$p_valor[[1]]),
          n_corte(cv),
          corte = cv
        )
      }
    }
    secoes[[length(secoes) + 1L]] <- report_section_associacoes(
      "associacoes", "O que anda junto com o IDEB", itens,
      nota = paste(
        "Associação, não causa: cada item compara escolas com e sem o recurso",
        "(ou com mais e menos professores e matrículas), mantidos os demais",
        "itens do modelo, separadamente para escolas urbanas e rurais. Outras",
        "diferenças entre as escolas (como o perfil das famílias) não entram",
        "no modelo. \"Sem relação clara\" = os dados não permitem afirmar nada",
        "(p ≥ 0,05); segurança alta = p < 0,01; média = p < 0,05."
      )
    )

    termo_label <- function(t) {
      ifelse(t == "(Intercept)", "Constante",
             ifelse(t %in% names(REPORT_PREDITORES), REPORT_PREDITORES[t], t))
    }
    tab <- coef
    tab$ordem_corte <- match(tab[[REPORT_REG_CORTE]], niveis)
    tab$ordem_termo <- match(tab$termo, c("(Intercept)", preditores))
    tab <- tab[order(tab$ordem_corte, tab$ordem_termo), , drop = FALSE]
    tab$termo_txt <- unname(termo_label(tab$termo))
    tab$corte <- as.character(tab[[REPORT_REG_CORTE]])
    tab$estimativa_txt <- report_format_signif(tab$estimativa)
    tab$erro_txt <- report_format_signif(tab$erro_padrao)
    tab$p_txt <- report_format_p(tab$p_valor)
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "coeficientes", "Coeficientes do modelo",
      list(
        report_col("corte", "Localização"),
        report_col("termo_txt", "Termo"),
        report_col("estimativa_txt", "Estimativa"),
        report_col("erro_txt", "Erro-padrão"),
        report_col("p_txt", "p-valor")
      ),
      tab,
      nota = sprintf(
        paste(
          "Regressão linear por escola do IDEB %s (%s) sobre %s; um modelo por",
          "localização. Estimativa = variação média do IDEB por unidade do item",
          "(ter o recurso; um professor ou uma matrícula a mais), mantidos os demais."
        ),
        REPORT_IDEB_ANO, report_etapa_label(etapa),
        tolower(paste(REPORT_PREDITORES, collapse = ", "))
      ),
      recolhida = TRUE
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = sprintf(
        "Sem escolas suficientes com IDEB %s (%s) em %s para a análise.",
        REPORT_IDEB_ANO, report_etapa_label(etapa), recorte$nome
      )
    )))
  }

  if (nrow(metr)) {
    if (is.null(metr[[REPORT_REG_CORTE]])) metr[[REPORT_REG_CORTE]] <- NA_character_
    metr$corte <- as.character(metr[[REPORT_REG_CORTE]])
    metr$n <- metr$nobs %||% rep(NA_real_, nrow(metr))
    metr <- metr[order(-ifelse(is.na(metr$n), 0, metr$n)), , drop = FALSE]
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "metricas", "Ajuste do modelo por localização",
      list(
        report_col("corte", "Localização"),
        report_col("n", "Escolas (n)", "inteiro"),
        report_col("r2", "R²", "decimal2"),
        report_col("r2_ajustado", "R² ajustado", "decimal2")
      ),
      metr,
      nota = sprintf(
        paste(
          "R² = parte das diferenças de IDEB entre as escolas que o modelo",
          "acompanha (0 a 1); valores baixos são comuns em educação. %s de %s",
          "escolas do recorte entraram (as demais não têm IDEB na etapa ou",
          "algum dado)."
        ),
        report_format_value(n_usado, "inteiro"),
        report_format_value(as.numeric(ctx$n_recorte %||% NA), "inteiro")
      ),
      recolhida = TRUE
    )
  }

  report_add_fonte(acc, report_fonte(
    "regressao_escolas",
    "Regressão linear por escola: IDEB × infraestrutura e porte, por localização",
    edicao_txt, escopo, n_usado
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- \"Maior\" ou \"menor\" diz se as escolas com o item (ou com mais professores e matrículas) tendem a ter IDEB maior ou menor, comparadas às demais.",
      "- Associação não é causa: ter o item não garante IDEB maior, e outras diferenças entre as escolas não entram no modelo.",
      "- A segurança vem do p-valor: alta e média indicam um padrão claro nos dados; \"sem relação clara\" quer dizer que não dá para afirmar nada.",
      sprintf("- Entraram %s escolas em atividade de %s com IDEB %s na etapa; o n de cada localização aparece em cada item.",
              report_format_value(n_usado, "inteiro"), recorte$nome, REPORT_IDEB_ANO),
      "- Os coeficientes e o R² estão em \"Ver detalhes técnicos\".",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Histórico da minha escola

#' Roteiro do tema `historico_escola`
#'
#' `resumo_escola` (identificação e IDEB mais recente por etapa),
#' `serie_ideb_escola` (série por etapa e edição) e `scores_escola` (scores
#' compostos 0–10 do Censo mais recente).
#'
#' @keywords internal
roteiro_historico_escola <- function(model, source) {
  acc <- report_acc()
  esc <- report_resolve_escola(source, model, acc)
  recorte <- esc$recorte
  val <- esc$val
  secoes <- list()

  # IDEB mais recente por etapa (do resumo do eduBR).
  itens <- list()
  for (etapa in names(REPORT_ETAPA_SUFIXO)) {
    suf <- REPORT_ETAPA_SUFIXO[[etapa]]
    nota <- val(paste0("ideb_", suf))
    if (is.null(nota)) next
    ano <- val(paste0("ano_", suf))
    itens[[length(itens) + 1L]] <- report_kpi(
      sprintf("IDEB %s (%s)", tolower(report_etapa_short(etapa)), ano %||% "?"),
      nota, "decimal1"
    )
    var <- val(paste0("var_", suf))
    if (!is.null(var)) {
      itens[[length(itens) + 1L]] <- report_kpi(
        sprintf("Variação %s desde a edição anterior", tolower(report_etapa_short(etapa))),
        var, "decimal1"
      )
    }
  }
  secoes[[length(secoes) + 1L]] <- report_section_kpis("kpis_ideb", "IDEB mais recente da escola", itens)

  # Série do IDEB.
  env <- edubr_call(source, "serie_ideb_escola", list(escola_id = model$codigo))
  report_add_avisos(acc, Filter(function(a) !identical(a$tipo, "sem_dados"), edubr_avisos(env, "serie_ideb_escola")))
  serie <- edubr_rows(env)
  n_serie <- 0L
  if (nrow(serie) && all(c("etapa", "ano") %in% names(serie))) {
    if (is.null(serie$ideb_observado)) serie$ideb_observado <- NA_real_
    if (is.null(serie$nota_media)) serie$nota_media <- NA_real_
    serie$ano <- as.integer(serie$ano)
    serie <- serie[!(is.na(serie$ideb_observado) & is.na(serie$nota_media)), , drop = FALSE]
  }
  if (nrow(serie) && all(c("etapa", "ano") %in% names(serie))) {
    n_serie <- nrow(serie)
    anos <- sort(unique(serie$ano))
    wide <- data.frame(ano = anos)
    for (etapa in REPORT_ETAPAS) {
      s <- serie[serie$etapa == etapa, , drop = FALSE]
      wide[[etapa]] <- s$ideb_observado[match(anos, s$ano)]
    }
    secoes[[length(secoes) + 1L]] <- report_section_chart(
      "grafico_ideb", "IDEB da escola por edição", "linhas",
      x = list(id = "ano", rotulo = "Edição"),
      series = lapply(REPORT_ETAPAS, function(e) list(id = e, rotulo = report_etapa_short(e))),
      dados = wide, formato = "decimal1"
    )
    tab <- serie[order(match(serie$etapa, REPORT_ETAPAS), serie$ano), , drop = FALSE]
    tab$etapa_txt <- vapply(tab$etapa, report_etapa_short, character(1))
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "serie", "Série do IDEB da escola",
      list(
        report_col("etapa_txt", "Etapa"),
        report_col("ano", "Edição"),
        report_col("ideb_observado", "IDEB", "decimal1"),
        report_col("nota_media", "Nota SAEB padronizada", "decimal2")
      ),
      tab,
      nota = "Edições sem nota (poucos alunos avaliados) não aparecem. Compare só edições da mesma etapa."
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = "A escola não tem IDEB em nenhuma edição (2005 a 2023)."
    )))
  }

  # Scores compostos (Censo mais recente).
  env_s <- edubr_call(source, "scores_escola", list(escola_id = model$codigo))
  scores <- edubr_rows(env_s)
  ano_censo <- NA
  if (nrow(scores)) {
    if (!is.null(scores$nu_ano_censo)) {
      scores <- scores[order(-as.numeric(scores$nu_ano_censo)), , drop = FALSE]
      ano_censo <- scores$nu_ano_censo[[1]]
    }
    itens_s <- lapply(names(REPORT_SCORES), function(col) {
      if (is.null(scores[[col]])) return(NULL)
      report_kpi(REPORT_SCORES[[col]], scores[[col]][[1]], "decimal1")
    })
    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "scores",
      sprintf("Scores da escola (0 a 10%s)", if (!is.na(ano_censo)) sprintf(", Censo %s", ano_censo) else ""),
      Filter(Negate(is.null), itens_s)
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = "Os scores compostos da escola não estão disponíveis."
    )))
  }

  report_add_fonte(acc, report_fonte(
    "serie_ideb_escola", "IDEB observado da escola por etapa e edição",
    "IDEB 2005 a 2023", "a escola", n_serie
  ))
  report_add_fonte(acc, report_fonte(
    "scores_escola", "Scores compostos do EduMaps (presença de recursos, 0 a 10)",
    sprintf("Censo Escolar %s", if (!is.na(ano_censo)) ano_censo else REPORT_CENSO_ANO),
    "a escola", nrow(scores)
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- O IDEB vai de 0 a 10 e combina aprovação e notas do SAEB; compare só edições da mesma etapa.",
      "- A variação é a diferença para a edição anterior em que a escola teve nota.",
      "- Edições sem nota (poucos alunos avaliados) não significam nota zero.",
      "- Os scores medem a PRESENÇA de recursos (tem/não tem), não a qualidade nem o uso; não são nota de desempenho.",
      sep = "\n"
    )
  )
}

# ---------------------------------------------------------------------------
# Tema: Escolas parecidas com a minha

#' Roteiro do tema `escolas_parecidas` (`escolas_similares`)
#'
#' As 10 escolas públicas mais parecidas (infraestrutura, porte, professores
#' e gestão; sem usar notas). A ferramenta devolve escola × etapa: a tabela
#' junta as etapas de cada escola e guarda a menor distância.
#'
#' @keywords internal
roteiro_escolas_parecidas <- function(model, source) {
  acc <- report_acc()
  etapa <- model$opcoes$etapa
  esc <- report_resolve_escola(source, model, acc)
  recorte <- esc$recorte
  val <- esc$val

  # Etapa pedida que a escola não oferta: erro do cliente (o eduBR responderia
  # um erro genérico).
  if (!is.null(etapa)) {
    oferta <- val(paste0("oferta_", REPORT_ETAPA_SUFIXO[[etapa]]))
    if (identical(oferta, FALSE)) {
      stop_invalid_report(sprintf(
        "A escola não oferta os %s; escolha outra etapa ou deixe em branco.",
        report_etapa_label(etapa)
      ))
    }
  }
  # Escola privada: o eduBR exige publica = false para ela.
  publica <- !identical(val("rede"), "Privada")

  env <- edubr_call(
    source, "escolas_similares",
    list(escola_id = model$codigo, n = 20L, etapa = etapa, publica = publica)
  )
  report_add_avisos(acc, Filter(function(a) !identical(a$tipo, "sem_dados"), edubr_avisos(env, "escolas_similares")))
  rows <- edubr_rows(env)
  secoes <- list()
  n_escolas <- 0L

  if (nrow(rows) && !is.null(rows$co_entidade)) {
    rows$co_entidade <- as.character(rows$co_entidade)
    rows <- rows[rows$co_entidade != model$codigo, , drop = FALSE]
  }
  if (nrow(rows) && !is.null(rows$co_entidade)) {
    if (is.null(rows$distancia)) rows$distancia <- NA_real_
    if (is.null(rows$etapa)) rows$etapa <- NA_character_
    rows <- rows[order(rows$distancia), , drop = FALSE]
    ids <- unique(rows$co_entidade)
    df <- do.call(rbind, lapply(ids, function(id) {
      r <- rows[rows$co_entidade == id, , drop = FALSE]
      etapas <- unique(stats::na.omit(r$etapa))
      etapas <- etapas[order(match(etapas, REPORT_ETAPAS))]
      data.frame(
        co_entidade = id,
        escola = as.character(r$escola[[1]] %||% id),
        municipio = as.character(r$municipio[[1]] %||% NA_character_),
        uf = as.character(r$uf[[1]] %||% NA_character_),
        rede = as.character(r$rede[[1]] %||% NA_character_),
        etapas = if (length(etapas)) paste(vapply(etapas, report_etapa_short, character(1)), collapse = ", ") else NA_character_,
        distancia = suppressWarnings(min(as.numeric(r$distancia), na.rm = TRUE)),
        stringsAsFactors = FALSE
      )
    }))
    df$distancia[!is.finite(df$distancia)] <- NA_real_
    # A ferramenta devolve uma linha por escola × etapa: pedimos 20 linhas e
    # ficamos com as 10 escolas DISTINTAS mais próximas (decisão do coordenador).
    df <- utils::head(df, 10L)
    n_escolas <- nrow(df)

    secoes[[length(secoes) + 1L]] <- report_section_kpis(
      "kpis", "Escolas parecidas encontradas",
      list(
        report_kpi("Escolas parecidas", n_escolas, "inteiro"),
        report_kpi(
          sprintf("No mesmo município (%s)", recorte$municipio %||% "—"),
          sum(df$municipio %in% recorte$municipio & df$uf %in% recorte$uf), "inteiro"
        ),
        report_kpi(sprintf("Na mesma UF (%s)", recorte$uf %||% "—"), sum(df$uf %in% recorte$uf), "inteiro"),
        report_kpi(
          sprintf("Da mesma rede (%s)", tolower(val("rede") %||% "—")),
          sum(df$rede %in% val("rede")), "inteiro"
        )
      )
    )
    secoes[[length(secoes) + 1L]] <- report_section_table(
      "escolas", "Escolas mais parecidas com a sua",
      list(
        report_col("escola", "Escola"),
        report_col("municipio", "Município"),
        report_col("uf", "UF"),
        report_col("rede", "Rede"),
        report_col("etapas", "Etapas comparadas"),
        report_col("distancia", "Distância (menor = mais parecida)", "decimal2")
      ),
      df,
      nota = paste(
        "Semelhança calculada com infraestrutura, porte (matrículas),",
        "professores e gestão, dentro de cada etapa; NÃO usa notas (IDEB/SAEB).",
        "A distância só serve para ordenar (não tem unidade)."
      ),
      ocultar_llm = "escola"
    )
  } else {
    report_add_avisos(acc, list(list(
      tipo = "sem_dados",
      mensagem = "Não foi possível encontrar escolas parecidas com estes critérios."
    )))
  }

  report_add_fonte(acc, report_fonte(
    "escolas_similares",
    "Escolas mais parecidas (infraestrutura, porte, professores e gestão; sem notas)",
    sprintf("Censo Escolar %s", REPORT_CENSO_ANO),
    sprintf(
      "escolas %sdo Brasil%s",
      if (publica) "públicas " else "",
      if (!is.null(etapa)) sprintf(", %s", report_etapa_label(etapa)) else ""
    ),
    n_escolas
  ))

  list(
    recorte = recorte,
    secoes = Filter(Negate(is.null), secoes),
    fontes = acc$fontes,
    avisos = acc$avisos,
    leitura = paste(
      "- As escolas da lista se parecem com a sua em infraestrutura, porte, professores e gestão, não em notas.",
      "- Servem para encontrar com quem comparar resultados ou trocar experiências.",
      "- A distância só ordena a lista: quanto menor, mais parecida; não é uma nota.",
      "- Parecida não quer dizer igual: comunidade, história e projeto de cada escola não entram na conta.",
      sep = "\n"
    )
  )
}
