# tests/testthat/helper-report.R
#
# Ferramentas FALSAS do eduBR para os testes do Assistente de Relatório
# (#219). Cada uma tem os mesmos argumentos da ferramenta real e devolve a
# string JSON do envelope `dados/metadados/erro`, como o eduBR. Nenhum
# teste depende de banco nem do eduBR instalado.
#
# `fake_edubr_tools()` devolve a lista de ferramentas com o atributo `log`
# (ambiente) onde cada chamada fica registrada: `log$calls` é uma lista de
# `list(tool, args)`.

`%||%` <- function(a, b) if (is.null(a)) b else a

fake_envelope <- function(dados = list(), filtros = list(), truncado = FALSE,
                          aviso = NULL, erro = NULL, contexto = NULL,
                          grao = "teste") {
  meta <- list(
    grao = grao,
    filtros = if (length(filtros)) filtros else structure(list(), names = character(0)),
    n = length(dados),
    n_total = if (truncado) NULL else length(dados),
    truncado = truncado,
    aviso = aviso,
    handle = NULL,
    colunas_omitidas = I(character(0))
  )
  if (!is.null(contexto)) meta$contexto <- contexto
  as.character(jsonlite::toJSON(
    list(dados = dados, metadados = meta, erro = erro),
    auto_unbox = TRUE, null = "null", na = "null", digits = NA
  ))
}

fake_sem_dados <- function(filtros = list()) {
  fake_envelope(
    filtros = filtros,
    erro = list(tipo = "sem_dados", mensagem = "A consulta não retornou linhas.")
  )
}

fake_edubr_tools <- function(fail = character()) {
  # Ferramentas da Fase 2 (complemento B): ideb, resumo_escola,
  # serie_ideb_escola, scores_escola, escolas_similares, regressao_escolas.
  log <- new.env(parent = emptyenv())
  log$calls <- list()
  registra <- function(tool, args) {
    log$calls[[length(log$calls) + 1L]] <- list(tool = tool, args = args)
    if (tool %in% fail) {
      return(fake_envelope(erro = list(tipo = "conexao", mensagem = "Falha ao consultar a base de dados.")))
    }
    NULL
  }
  # Captura os argumentos informados (não-NULL), como o wrapper do eduBR.
  argumentos <- function(env) {
    a <- as.list(env)
    a[!vapply(a, is.null, logical(1))]
  }

  regioes <- c(Norte = "N", Nordeste = "NE", Sudeste = "SE", Sul = "S", "Centro-oeste" = "CO")
  ideb_reg <- c(Norte = 5.4, Nordeste = 5.5, Sudeste = 6.3, Sul = 6.2, "Centro-oeste" = 6.0)

  tools <- list(
    municipios = function(uf = NULL, n = NULL) {
      e <- registra("municipios", argumentos(environment()))
      if (!is.null(e)) return(e)
      fake_envelope(list(
        list(codigo_ibge = "3509502", nome = "Campinas", sigla_estado = "SP"),
        list(codigo_ibge = "3550308", nome = "São Paulo", sigla_estado = "SP"),
        list(codigo_ibge = "3555406", nome = "Ubatuba", sigla_estado = "SP")
      ), filtros = list(uf = uf))
    },

    ideb_agregado = function(etapa = NULL, nivel = "uf", ano = NULL, rede = NULL, uf = NULL,
                             regiao = NULL, por_rede = NULL, n = NULL) {
      e <- registra("ideb_agregado", argumentos(environment()))
      if (!is.null(e)) return(e)
      ano <- ano %||% 2023L
      filtros <- list(etapa = etapa, nivel = nivel, ano = ano, rede = rede, uf = uf,
                      regiao = regiao, por_rede = isTRUE(por_rede))
      if (identical(etapa, "ensino_medio") && ano < 2017) {
        return(fake_sem_dados(filtros))
      }
      redes <- if (is.null(rede)) c("Estadual", "Municipal") else rede
      if (nivel == "municipio") {
        munis <- list(c("3509502", "Campinas", 6.1), c("3550308", "São Paulo", 5.9))
        if (isTRUE(por_rede)) {
          # Sem filtro de rede a resposta vem truncada (força as fatias).
          if (is.null(rede)) {
            return(fake_envelope(list(
              list(sg_uf = "SP", co_municipio = 3500105L, no_municipio = "Adamantina",
                   rede = "Municipal", ideb_medio = 6.4, escolas_com_nota = "3", escolas = "3")
            ), filtros = filtros, truncado = TRUE,
            aviso = "Há mais linhas do que as 1000 devolvidas; refine os filtros para ver o restante."))
          }
          dados <- lapply(munis, function(m) list(
            sg_uf = "SP", co_municipio = as.integer(m[1]), no_municipio = m[2], rede = rede,
            ideb_medio = as.numeric(m[3]) - if (rede == "Estadual") 0.3 else 0,
            escolas_com_nota = "40", escolas = "42"
          ))
          if (rede %in% c("Federal", "Privada")) return(fake_sem_dados(filtros))
          return(fake_envelope(dados, filtros = filtros))
        }
        dados <- lapply(munis, function(m) list(
          sg_uf = "SP", co_municipio = as.integer(m[1]), no_municipio = m[2],
          ideb_medio = as.numeric(m[3]), escolas_com_nota = "120", escolas = "130"
        ))
        return(fake_envelope(dados, filtros = filtros))
      }
      if (nivel == "uf") {
        ufs <- if (!is.null(uf)) uf else c("ES", "MG", "RJ", "SP")
        dados <- list()
        for (u in ufs) {
          if (isTRUE(por_rede)) {
            for (r in redes) dados[[length(dados) + 1L]] <- list(
              nome_regiao = "Sudeste", sg_uf = u, rede = r,
              ideb_medio = if (r == "Municipal") 6.3 else 6.0,
              escolas_com_nota = "5000", escolas = "5200"
            )
          } else {
            dados[[length(dados) + 1L]] <- list(
              nome_regiao = "Sudeste", sg_uf = u, ideb_medio = 6.2,
              escolas_com_nota = "9000", escolas = "9500"
            )
          }
        }
        return(fake_envelope(dados, filtros = filtros))
      }
      # nivel regiao
      nomes <- if (!is.null(regiao)) names(regioes)[regioes == regiao] else names(regioes)
      dados <- list()
      for (nm in nomes) {
        if (isTRUE(por_rede)) {
          for (r in redes) dados[[length(dados) + 1L]] <- list(
            nome_regiao = nm, rede = r, ideb_medio = ideb_reg[[nm]] - 0.1,
            escolas_com_nota = "8000", escolas = "8500"
          )
        } else {
          dados[[length(dados) + 1L]] <- list(
            nome_regiao = nm, ideb_medio = ideb_reg[[nm]] + (ano - 2023) * 0.1,
            escolas_com_nota = "20000", escolas = "21000"
          )
        }
      }
      fake_envelope(dados, filtros = filtros)
    },

    redes_municipio = function(uf = NULL, regiao = NULL, rede = NULL, n = NULL) {
      e <- registra("redes_municipio", argumentos(environment()))
      if (!is.null(e)) return(e)
      filtros <- list(uf = uf, regiao = regiao, rede = rede)
      linha <- function(cod, nome, u, r, esc, mat, doc) list(
        co_municipio = cod, no_municipio = nome, sg_uf = u, rede = r,
        total_escolas = as.character(esc), total_matriculas = as.character(mat),
        total_docentes = as.character(doc), docentes_superior = as.character(round(doc * 0.9)),
        docentes_concursados = as.character(round(doc * 0.6)),
        ideb_fund_i = if (r == "Municipal") 6.1 else NULL,
        ideb_fund_ii = if (r == "Estadual") 5.2 else NULL,
        ideb_medio = if (r == "Estadual") 4.4 else NULL,
        ano_ideb = 2023L, perc_docentes_superior = 90, alunos_por_docente = 12.5
      )
      if (is.null(rede) || identical(rede, "publica")) {
        # Sem rede (ou "publica"): resposta truncada, força as fatias por rede.
        return(fake_envelope(list(linha("3500105", "Adamantina", uf, "Municipal", 15, 2459, 236)),
                             filtros = filtros, truncado = TRUE,
                             aviso = "Há mais linhas do que as 1000 devolvidas; refine os filtros para ver o restante."))
      }
      if (rede == "Federal") return(fake_sem_dados(filtros))
      esc <- c(Municipal = 200, Estadual = 100, Privada = 150)[[rede]]
      dados <- list(
        linha(paste0(substr("3509502", 1, 2), "09502"), "Campinas", uf, rede, esc, esc * 300, esc * 20),
        linha("3550308", "São Paulo", uf, rede, esc * 5, esc * 1500, esc * 100)
      )
      fake_envelope(dados, filtros = filtros)
    },

    docentes_rede = function(nivel = "brasil", uf = NULL, regiao = NULL, rede = NULL,
                             localizacao = NULL, ano = 2025L, colunas = NULL, n = NULL) {
      e <- registra("docentes_rede", argumentos(environment()))
      if (!is.null(e)) return(e)
      # Lacuna da Fase 0: sem `colunas` a resposta é inútil; o roteiro deve pedir.
      if (is.null(colunas)) stop("docentes_rede chamado sem `colunas`")
      filtros <- list(nivel = nivel, uf = uf, regiao = regiao, rede = rede, localizacao = localizacao)
      redes <- if (is.null(rede)) c("Municipal", "Estadual", "Privada") else rede
      locs <- if (is.null(localizacao)) c("Urbana", "Rural") else tools::toTitleCase(localizacao)
      if (nivel == "municipio" && identical(rede, "Federal")) return(fake_sem_dados(filtros))
      if (nivel == "municipio" && is.null(localizacao)) {
        # No município sem localização a resposta vem truncada (força 2 níveis de fatia).
        return(fake_envelope(list(list(rede = "Municipal", co_municipio = 3500105L, localizacao = "Urbana",
                                       qt_doc_bas = "10")),
                             filtros = filtros, truncado = TRUE))
      }
      dados <- list()
      for (r in redes) for (l in locs) {
        base <- if (nivel == "municipio") 100 else if (nivel == "uf") 10000 else 100000
        rec <- list(rede = r, localizacao = l, qt_doc_bas = as.character(base))
        if (nivel == "municipio") rec$co_municipio <- 3509502L
        for (c in unlist(colunas)) rec[[c]] <- as.character(base / 2)
        dados[[length(dados) + 1L]] <- rec
      }
      fake_envelope(dados, filtros = filtros)
    },

    perfil_gestor = function(corte = "rede", unidade = "gestor", rede = NULL, uf = NULL,
                             regiao = NULL, localizacao = NULL, n = NULL) {
      e <- registra("perfil_gestor", argumentos(environment()))
      if (!is.null(e)) return(e)
      nome <- switch(corte, uf = uf, regiao = names(regioes)[regioes == regiao] %||% regiao, brasil = "Brasil", corte)
      dados <- list(
        list(corte = nome, dimensao = "Sexo", categoria_modal = "Feminino", n = 800L, denom = 1000L,
             prop_modal = 0.8, concentracao = 0.68),
        list(corte = nome, dimensao = "Escolaridade", categoria_modal = "Superior", n = 900L, denom = 1000L,
             prop_modal = 0.9, concentracao = 0.82)
      )
      fake_envelope(dados, filtros = list(corte = corte), contexto = list(
        corte = corte, unidade = unidade, ano_censo = 2025L,
        n_por_corte = list(list(corte = nome, n_gestores = 1000L, n_escolas = 700L))
      ))
    },

    tendencia_ideb_regiao = function(etapa = NULL, rede = NULL) {
      e <- registra("tendencia_ideb_regiao", argumentos(environment()))
      if (!is.null(e)) return(e)
      dados <- list()
      for (nm in names(regioes)) {
        for (termo in c("(Intercept)", "ano")) dados[[length(dados) + 1L]] <- list(
          nome_regiao = nm, sigla_regiao = regioes[[nm]], etapa = etapa %||% "fundamental_i",
          n_anos = 10L, ano_inicial = 2005L, ano_final = 2023L, termo = termo,
          estimativa = if (termo == "ano") 0.08 else -150, erro_padrao = 0.01,
          p_valor = 0.0001, r2 = 0.9, nobs = 10L
        )
      }
      fake_envelope(dados, filtros = list(etapa = etapa, rede = rede))
    },

    perfil_escola = function(escola_id = NULL, ano_ideb = NULL) {
      e <- registra("perfil_escola", argumentos(environment()))
      if (!is.null(e)) return(e)
      if (!identical(escola_id, "35038751")) return(fake_sem_dados(list(escola_id = escola_id)))
      dados <- list(
        list(dimensao = "Infraestrutura", item = "Biblioteca", escola = 1L, municipio = 0.62,
             estado = 0.7, dif_municipio = 0.38, ofertada = NULL),
        list(dimensao = "Infraestrutura", item = "Quadra", escola = 0L, municipio = 0.5,
             estado = 0.6, dif_municipio = -0.5, ofertada = NULL),
        list(dimensao = "IDEB", item = "IDEB fund. II (2023)", escola = 5.1, municipio = 4.8,
             estado = 5.0, dif_municipio = 0.3, ofertada = TRUE),
        list(dimensao = "Docentes", item = "Docentes", escola = 30L, municipio = 25.4,
             estado = 28.1, dif_municipio = 4.6, ofertada = NULL)
      )
      fake_envelope(dados, filtros = list(escola_id = escola_id), contexto = list(
        codigo_inep = "35038751", nome = "EE EXEMPLO", rede = "Estadual",
        municipio = "Ubatuba", uf = "SP", ano_censo = 2025L,
        edicao_ideb = list(fundamental_i = NULL, fundamental_ii = 2023L, ensino_medio = 2023L)
      ))
    }
  )
  # --- Fase 2 ---------------------------------------------------------------
  # Escolas falsas de Ubatuba (3555406) para a ferramenta `ideb`.
  escolas_ideb <- list(
    list(id = "35000001", nome = "ESCOLA ALFA EM", rede = "Municipal", ideb = 6.4),
    list(id = "35000002", nome = "ESCOLA BETA EM", rede = "Municipal", ideb = 5.9),
    list(id = "35038751", nome = "ESCOLA DO GESTOR EE", rede = "Estadual", ideb = 5.9),
    list(id = "35000004", nome = "ESCOLA GAMA EE", rede = "Estadual", ideb = 4.2),
    list(id = "35000005", nome = "ESCOLA DELTA EM", rede = "Municipal", ideb = 7.1),
    list(id = "35000006", nome = "ESCOLA SEM NOTA EM", rede = "Municipal", ideb = NULL),
    list(id = "35000007", nome = "ESCOLA EPSILON EM", rede = "Municipal", ideb = 3.8)
  )
  resumo_ok <- list(
    codigo_inep = "35038751", escola = "ESCOLA DO GESTOR EE", rede = "Estadual",
    municipio = "Ubatuba", uf = "SP", localizacao = "Urbana", etapas = "Fund. II, Médio",
    matriculas = 368L, docentes = 20L,
    ideb_fund_i = NULL, ano_fund_i = NULL, var_fund_i = NULL, oferta_fund_i = FALSE,
    ideb_fund_ii = 4.5, ano_fund_ii = 2023L, var_fund_ii = -0.3, oferta_fund_ii = TRUE,
    ideb_medio = 4.7, ano_medio = 2023L, var_medio = NULL, oferta_medio = TRUE
  )

  tools$ideb <- function(uf = NULL, municipio = NULL, etapa = NULL, rede = NULL, ano = NULL, n = NULL) {
    e <- registra("ideb", argumentos(environment()))
    if (!is.null(e)) return(e)
    filtros <- list(uf = uf, municipio = municipio, etapa = etapa, rede = rede, ano = ano)
    if (!identical(municipio, "Ubatuba") && !identical(municipio, "Campinas")) return(fake_sem_dados(filtros))
    # Campinas: sem rede a resposta vem truncada (força as fatias por rede).
    if (identical(municipio, "Campinas") && is.null(rede)) {
      return(fake_envelope(list(list(id_escola = "35999999", co_municipio = 3509502L, no_municipio = "Campinas",
                                     no_escola = "TRUNCADA", rede = "Municipal", ideb_observado = 9.9)),
                           filtros = filtros, truncado = TRUE,
                           aviso = "Há mais linhas do que as 1000 devolvidas; refine os filtros para ver o restante."))
    }
    cod <- if (identical(municipio, "Ubatuba")) 3555406L else 3509502L
    dados <- list()
    for (x in escolas_ideb) {
      if (!is.null(rede) && !identical(rede, x$rede)) next
      dados[[length(dados) + 1L]] <- list(
        id_escola = x$id, sg_uf = "SP", co_municipio = cod, no_municipio = municipio,
        no_escola = x$nome, rede = x$rede, ano = ano %||% 2023L, etapa = etapa,
        nota_media = 5.5, ideb_observado = x$ideb
      )
    }
    # Homônimo de outra UF/município não deve entrar (filtro pelo código).
    dados[[length(dados) + 1L]] <- list(
      id_escola = "35123456", sg_uf = "SP", co_municipio = 3500105L, no_municipio = municipio,
      no_escola = "ESCOLA DE OUTRO MUNICIPIO", rede = "Municipal", ano = 2023L, etapa = etapa,
      nota_media = 5, ideb_observado = 9.5
    )
    if (!length(dados)) return(fake_sem_dados(filtros))
    fake_envelope(dados, filtros = filtros)
  }

  tools$resumo_escola <- function(escola_id = NULL, ano_ideb = NULL) {
    e <- registra("resumo_escola", argumentos(environment()))
    if (!is.null(e)) return(e)
    if (!identical(escola_id, "35038751")) {
      return(fake_envelope(erro = list(tipo = "sem_dados", mensagem = "escola inexistente")))
    }
    fake_envelope(list(resumo_ok), filtros = list(escola_id = escola_id))
  }

  tools$serie_ideb_escola <- function(escola_id = NULL, etapa = NULL) {
    e <- registra("serie_ideb_escola", argumentos(environment()))
    if (!is.null(e)) return(e)
    dados <- list(
      list(etapa = "ensino_medio", ano = 2019L, ideb_observado = NULL, nota_media = NULL),
      list(etapa = "ensino_medio", ano = 2021L, ideb_observado = 4.3, nota_media = 4.61),
      list(etapa = "ensino_medio", ano = 2023L, ideb_observado = 4.7, nota_media = 4.82),
      list(etapa = "fundamental_ii", ano = 2019L, ideb_observado = 4.6, nota_media = 5.01),
      list(etapa = "fundamental_ii", ano = 2021L, ideb_observado = 4.8, nota_media = 5.12),
      list(etapa = "fundamental_ii", ano = 2023L, ideb_observado = 4.5, nota_media = 4.98)
    )
    fake_envelope(dados, filtros = list(escola_id = escola_id))
  }

  tools$scores_escola <- function(escola_id = NULL) {
    e <- registra("scores_escola", argumentos(environment()))
    if (!is.null(e)) return(e)
    fake_envelope(list(list(
      nu_ano_censo = 2025L, co_entidade = escola_id, score_capacidade_atendimento = 4.89,
      score_infraestrutura = 6.94, score_capacitacao_docente = 5.6,
      score_diversidade_discente = 6.77, score_capacidade_gestora = 4.79,
      score_sustentabilidade = 0, data_atualizacao = "2026-06-05T23:03:00Z"
    )), filtros = list(escola_id = escola_id))
  }

  tools$escolas_similares <- function(escola_id = NULL, n = 5L, etapa = NULL, publica = TRUE) {
    e <- registra("escolas_similares", argumentos(environment()))
    if (!is.null(e)) return(e)
    viz <- list(
      list(co_entidade = "35030703", escola = "VIZINHA UM", municipio = "Pereira Barreto", uf = "SP",
           rede = "Estadual", etapa = "ensino_medio", distancia = 2.4406),
      list(co_entidade = "35030703", escola = "VIZINHA UM", municipio = "Pereira Barreto", uf = "SP",
           rede = "Estadual", etapa = "fundamental_ii", distancia = 2.6183),
      list(co_entidade = "35008254", escola = "VIZINHA DOIS", municipio = "Ubatuba", uf = "SP",
           rede = "Estadual", etapa = "fundamental_ii", distancia = 2.7148),
      list(co_entidade = "31000001", escola = "VIZINHA TRES", municipio = "Belo Horizonte", uf = "MG",
           rede = "Municipal", etapa = "ensino_medio", distancia = 2.9)
    )
    if (!is.null(etapa)) viz <- Filter(function(v) identical(v$etapa, etapa), viz)
    fake_envelope(utils::head(viz, n), filtros = list(escola_id = escola_id, n = n, etapa = etapa, publica = publica))
  }

  tools$regressao_escolas <- function(outcome, predictors, cuts = NULL, uf = NULL, rede = NULL,
                                      ano = NULL, ano_ideb = NULL, ativas = NULL, modelo = "linear") {
    e <- registra("regressao_escolas", argumentos(environment()))
    if (!is.null(e)) return(e)
    filtros <- list(outcome = outcome, predictors = predictors, cuts = cuts, uf = uf, rede = rede)
    if (identical(uf, "RJ")) {
      return(fake_envelope(erro = list(tipo = "limite_excedido", mensagem = "O recorte tem 31.000 linhas.")))
    }
    if (identical(uf, "AC")) return(fake_sem_dados(filtros))
    # Estimativas e p-valores escolhidos para cobrir os limiares do contrato:
    # p < 0,01 (alta), p < 0,05 (média), p >= 0,05 (sem relação clara).
    est <- list(
      Urbana = list(
        "(Intercept)" = c(5.1, 0.1, 1e-50),
        in_biblioteca = c(0.21, 0.03, 0.0005),
        in_internet = c(-0.15, 0.07, 0.03),
        in_laboratorio_informatica = c(0.05, 0.06, 0.40),
        docentes = c(0.004, 0.002, 0.05),
        matriculas = c(-0.0004, 0.0001, 0.009)
      ),
      Rural = list(
        "(Intercept)" = c(4.8, 0.2, 1e-20),
        in_biblioteca = c(0.10, 0.08, 0.20),
        in_internet = c(0.30, 0.09, 0.001),
        in_laboratorio_informatica = c(-0.02, 0.1, 0.80),
        docentes = c(0.01, 0.004, 0.012),
        matriculas = c(0.0001, 0.0003, 0.70)
      )
    )
    dados <- list()
    for (corte in names(est)) for (termo in names(est[[corte]])) {
      v <- est[[corte]][[termo]]
      dados[[length(dados) + 1L]] <- list(localizacao = corte, termo = termo, estimativa = v[1],
                                          erro_padrao = v[2], estatistica = v[1] / v[2], p_valor = v[3])
    }
    fake_envelope(
      dados, filtros = filtros,
      aviso = "8.914 de 13.435 linhas do recorte foram descartadas por `null` no desfecho ou nos preditores (ex.: escolas sem IDEB na etapa).",
      contexto = list(
        formula = paste(outcome, "~", paste(unlist(predictors), collapse = " + ")),
        modelo = modelo, n_recorte = 13435L, n_usado = 4521L,
        cortes = list(list(localizacao = "Rural", n = 293L, ajustado = TRUE),
                      list(localizacao = "Urbana", n = 4228L, ajustado = TRUE)),
        metricas = list(
          list(localizacao = "Urbana", r2 = 0.044, r2_ajustado = 0.0428, nobs = 4228L),
          list(localizacao = "Rural", r2 = 0.025, r2_ajustado = 0.008, nobs = 293L)
        )
      )
    )
  }

  attr(tools, "log") <- log
  tools
}

# Chamadas registradas para uma ferramenta.
fake_calls <- function(tools, tool = NULL) {
  calls <- attr(tools, "log")$calls
  if (is.null(tool)) return(calls)
  Filter(function(c) identical(c$tool, tool), calls)
}

# Configuração de chat em memória (não lê o banco nem a rede).
fake_report_config <- function(provider = "mock") {
  list(provider = provider, model = "modelo-teste", url = "http://localhost", api_key = "")
}

# Gera um relatório com ferramentas falsas. `contexto` = {cod_inep} do gestor.
fake_report <- function(geotag, tema, opcoes = NULL, provider = "mock", llm = NULL,
                        tools = fake_edubr_tools(), contexto = NULL) {
  run_report(
    geotag = geotag, tema = tema, opcoes = opcoes, contexto = contexto,
    config = fake_report_config(provider), tools = tools, llm = llm
  )
}

# Seção do relatório pelo id.
# Seção do relatório pelo id; `linhas`/`dados` (listas de objetos, já
# renderizadas) voltam a data.frame para facilitar as asserções.
report_secao <- function(report, id) {
  s <- Filter(function(s) identical(s$id, id), report$secoes)
  if (!length(s)) return(NULL)
  s <- s[[1]]
  as_df <- function(rows) {
    if (!length(rows)) return(data.frame())
    # Chaves opcionais (ex.: `_destaque`, só nas linhas destacadas) viram NA.
    chaves <- unique(unlist(lapply(rows, names)))
    do.call(rbind, lapply(rows, function(r) {
      r <- lapply(chaves, function(k) if (is.null(r[[k]])) NA else r[[k]])
      names(r) <- chaves
      as.data.frame(r, stringsAsFactors = FALSE, optional = TRUE)
    }))
  }
  if (!is.null(s$linhas)) s$linhas <- as_df(s$linhas)
  if (!is.null(s$dados)) s$dados <- as_df(s$dados)
  s
}
