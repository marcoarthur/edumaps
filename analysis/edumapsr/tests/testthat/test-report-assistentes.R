# tests/testthat/test-report-assistentes.R
#
# Assistentes declarativos (#219, Fase 4): carregador e validação dos YAML,
# `relatorio.yml` equivalente às Fases 1–3, `eda_municipio.yml` (modo
# composto) com ferramentas falsas e o critério de aceite — um terceiro
# assistente criado só com um YAML de teste (tests/testthat/assistentes/).

assistentes_pacote <- function() {
  d <- system.file("assistentes", package = "edumapsAnalytics")
  if (!nzchar(d)) d <- testthat::test_path("..", "..", "inst", "assistentes")
  sort(list.files(d, pattern = "\\.ya?ml$", full.names = TRUE))
}

# Escreve YAMLs num diretório temporário (nome do arquivo → conteúdo).
yaml_dir <- function(arquivos) {
  d <- tempfile("assistentes-")
  dir.create(d)
  for (nm in names(arquivos)) writeLines(arquivos[[nm]], file.path(d, nm))
  d
}

# Usa diretórios extras de assistentes durante `code`.
com_assistentes <- function(dirs, code) {
  old <- options(edumapsAnalytics.assistentes_dirs = dirs)
  on.exit(options(old), add = TRUE)
  force(code)
}

eda <- function(codigo = "3509502", opcoes = NULL, contexto = list(cod_inep = "35038751"),
                provider = "mock", llm = NULL, tools = fake_edubr_tools(),
                assistente = "eda_municipio") {
  run_report(
    geotag = list(nivel = "municipio", codigo = codigo), tema = NULL, opcoes = opcoes,
    contexto = contexto, config = fake_report_config(provider), tools = tools,
    llm = llm, assistente = assistente
  )
}

secao_ids <- function(r) vapply(r$secoes, `[[`, character(1), "id")
cap_ids <- function(r) vapply(r$capitulos, `[[`, character(1), "id")

# ---------------------------------------------------------------------------
# YAMLs do pacote

test_that("cada YAML do pacote é válido", {
  arquivos <- assistentes_pacote()
  expect_setequal(basename(arquivos), c("relatorio.yml", "eda_municipio.yml"))
  for (f in arquivos) {
    ast <- report_assistente_validar(yaml::read_yaml(f), f)
    expect_equal(ast$id, sub("\\.yml$", "", basename(f)), info = f)
  }
  out <- utils::capture.output(todos <- report_assistentes_carregar())
  expect_length(out, 0)
  expect_setequal(names(todos), c("relatorio", "eda_municipio"))
})

test_that("relatorio.yml reproduz o catálogo das Fases 1–3", {
  ast <- report_assistente("relatorio")
  expect_equal(ast$modo, "tema")
  expect_equal(ast$temas, names(report_catalog()))
  expect_setequal(ast$niveis, REPORT_NIVEIS)
  expect_null(ast$prompt_complemento)
  expect_length(ast$limites, 0)
  expect_identical(report_limits_assistente(ast), report_limits())
  # Padrão = relatorio
  expect_identical(report_assistente(NULL), ast)
  expect_identical(report_assistente(""), ast)

  # /report/temas: com e sem assistente, igual ao catálogo em todos os níveis
  for (nivel in list(NULL, "municipio", "uf", "regiao", "escola")) {
    padrao <- report_temas(nivel)
    expect_identical(report_temas(nivel, assistente = "relatorio"), padrao)
    cat_ids <- names(Filter(function(t) is.null(nivel) || nivel %in% t$niveis, report_catalog()))
    expect_equal(vapply(padrao$temas, `[[`, character(1), "id"), cat_ids)
  }
})

test_that("relatorio: o pedido com assistente é igual ao pedido sem assistente", {
  limpa <- function(r) {
    r$gerado_em <- NULL
    r$rastreio$duracao_ms <- NULL
    r
  }
  g <- list(nivel = "municipio", codigo = "3555406")
  ctx <- list(cod_inep = "35038751")
  a <- fake_report(g, "ideb_escolas", contexto = ctx)
  b <- run_report(g, "ideb_escolas", contexto = ctx, config = fake_report_config(),
                  tools = fake_edubr_tools(), assistente = "relatorio")
  expect_identical(limpa(a), limpa(b))
  expect_equal(a$assistente, list(id = "relatorio", titulo = "Relatório por tema", modo = "tema"))
  expect_null(a$capitulos)
  expect_false(any(vapply(a$secoes, function(s) !is.null(s$capitulo), logical(1))))

  # o tema continua obrigatório no modo tema
  expect_error(
    run_report(g, NULL, config = fake_report_config(), tools = fake_edubr_tools(), assistente = "relatorio"),
    class = "invalid_report_request"
  )
})

test_that("eda_municipio.yml: capítulos, opções e limites", {
  ast <- report_assistente("eda_municipio")
  expect_equal(ast$modo, "composto")
  expect_equal(ast$niveis, "municipio")
  expect_equal(
    vapply(ast$capitulos, `[[`, character(1), "tema"),
    c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas", "minha_escola")
  )
  expect_equal(ast$capitulos[[5]]$recorte, "escola")
  expect_equal(ast$opcoes$etapa$valores, REPORT_ETAPAS)
  expect_equal(ast$opcoes$etapa$padrao, "fundamental_i")
  expect_identical(report_limits_assistente(ast)$max_chamadas, 80L)
  expect_match(ast$prompt_complemento, "capítulos")

  pub <- report_assistentes()$assistentes
  expect_equal(vapply(pub, `[[`, character(1), "id"), c("relatorio", "eda_municipio"))
  e <- pub[[2]]
  expect_equal(e$opcoes, list(etapa = as.list(REPORT_ETAPAS)))
  expect_equal(e$padroes, list(etapa = "fundamental_i"))
  expect_null(e$temas)
  expect_equal(e$capitulos[[5]], list(id = "minha_escola", tema = "minha_escola",
                                      titulo = "Minha escola no município", opcional = TRUE))
  expect_null(e$capitulos[[1]]$opcional)
  r <- pub[[1]]
  expect_length(r$temas, 10)
  expect_null(r$capitulos)
  expect_equal(names(r$opcoes), character(0))
  # JSON: opcoes/padroes vazios saem como objeto, não como lista
  j <- as.character(report_to_json(report_assistentes()))
  expect_match(j, '"opcoes":\\{\\},"padroes":\\{\\}')

  expect_length(report_assistentes(publico = "gestor")$assistentes, 2)
  expect_length(report_assistentes(publico = "ninguem")$assistentes, 0)

  # /report/temas do composto: temas dos capítulos no nível
  ids <- vapply(report_temas("municipio", assistente = "eda_municipio")$temas, `[[`, character(1), "id")
  expect_equal(ids, c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas"))
  expect_error(report_temas(assistente = "nao_existe"), class = "invalid_report_request")
})

# ---------------------------------------------------------------------------
# Validação ao carregar

test_that("YAML inválido é ignorado com log e não derruba os outros", {
  valido <- c(
    "id: valido", "titulo: Válido", "descricao: Teste.", "publico: [gestor]",
    "modo: tema", "niveis: [uf]", "temas: [ideb_territorio]"
  )
  comp <- function(id, ...) c(
    sprintf("id: %s", id), "titulo: T", "descricao: D", "publico: [gestor]",
    "modo: composto", ...
  )
  d <- yaml_dir(list(
    "valido.yml" = valido,
    "quebrado.yml" = c("id: quebrado", "titulo: [sem fechar"),
    "sem_titulo.yml" = valido[-2],
    "outro_nome.yml" = valido,
    "tema_inexistente.yml" = sub("valido", "tema_inexistente", sub("ideb_territorio", "inse", valido)),
    "nivel_tema.yml" = c(sub("valido", "nivel_tema", valido[1:5]), "niveis: [escola]", "temas: [ideb_territorio]"),
    "modo_ruim.yml" = sub("modo: tema", "modo: livre", sub("valido", "modo_ruim", valido)),
    "nivel_ruim.yml" = sub("niveis: \\[uf\\]", "niveis: [bairro]", sub("valido", "nivel_ruim", valido)),
    "cap_nivel.yml" = comp("cap_nivel", "niveis: [municipio]", "capitulos:",
                           "  - { tema: gestores_territorio, titulo: G }"),
    "cap_sem_titulo.yml" = comp("cap_sem_titulo", "niveis: [uf]", "capitulos:",
                                "  - { tema: ideb_territorio }"),
    "cap_repetido.yml" = comp("cap_repetido", "niveis: [uf]", "capitulos:",
                              "  - { tema: ideb_territorio, titulo: A }",
                              "  - { tema: ideb_territorio, titulo: B }"),
    "cap_opcao.yml" = comp("cap_opcao", "niveis: [uf]", "capitulos:",
                           "  - { tema: ideb_territorio, titulo: A, opcoes: { rede: publica } }"),
    "cap_recorte.yml" = comp("cap_recorte", "niveis: [uf]", "capitulos:",
                             "  - { tema: ideb_territorio, titulo: A, recorte: escola }"),
    "opcao_orfa.yml" = comp("opcao_orfa", "niveis: [uf]", "capitulos:",
                            "  - { tema: gestores_territorio, titulo: G }",
                            "opcoes: { etapa: { padrao: fundamental_i } }"),
    "opcao_valor.yml" = comp("opcao_valor", "niveis: [uf]", "capitulos:",
                             "  - { tema: ideb_territorio, titulo: A }",
                             "opcoes: { rede: { valores: [publica] } }"),
    "opcao_padrao.yml" = comp("opcao_padrao", "niveis: [uf]", "capitulos:",
                              "  - { tema: ideb_territorio, titulo: A }",
                              "opcoes: { etapa: { valores: [fundamental_i], padrao: ensino_medio } }"),
    "limite_ruim.yml" = comp("limite_ruim", "niveis: [uf]", "capitulos:",
                             "  - { tema: ideb_territorio, titulo: A }",
                             "limites: { max_tokens: 10 }"),
    "tema_com_opcoes.yml" = c(sub("valido", "tema_com_opcoes", valido), "opcoes: { etapa: { padrao: fundamental_i } }"),
    "Id_Maiusculo.yml" = sub("valido", "Id_Maiusculo", valido)
  ))
  out <- utils::capture.output(todos <- report_assistentes_carregar(d))
  expect_equal(names(todos), "valido")
  # um log por arquivo inválido, com o motivo
  expect_length(out, 18)
  expect_true(all(grepl("^\\[edumapsAnalytics\\] assistente ignorado", out)))
  log_de <- function(arq) out[grepl(sprintf("(%s)", arq), out, fixed = TRUE)]
  expect_match(log_de("sem_titulo.yml"), "campos obrigatórios ausentes: titulo")
  expect_match(log_de("outro_nome.yml"), "diferente do nome do arquivo")
  expect_match(log_de("tema_inexistente.yml"), "fora do catálogo: inse")
  expect_match(log_de("nivel_tema.yml"), "não está disponível em nenhum nível")
  expect_match(log_de("cap_nivel.yml"), "não está disponível em todos os níveis")
  expect_match(log_de("cap_repetido.yml"), "repetidos: ideb_territorio")
  expect_match(log_de("cap_opcao.yml"), "Valor inválido para `rede`")
  expect_match(log_de("cap_recorte.yml"), "não aceita o recorte escola")
  expect_match(log_de("opcao_orfa.yml"), "nenhum capítulo a aceita")
  expect_match(log_de("opcao_valor.yml"), "não aceitos por todos os capítulos: publica")
  expect_match(log_de("opcao_padrao.yml"), "`padrao` fora dos valores")
  expect_match(log_de("limite_ruim.yml"), "limites desconhecidos: max_tokens")

  # Os do pacote continuam carregando ao lado de um diretório com inválidos;
  # id repetido em outro diretório: vale o primeiro (o do pacote).
  d2 <- yaml_dir(list("relatorio.yml" = sub("valido", "relatorio", valido)))
  out <- utils::capture.output(com_assistentes(c(d, d2), {
    ids <- vapply(report_assistentes()$assistentes, `[[`, character(1), "id")
    temas <- report_assistente("relatorio")$temas
  }))
  expect_setequal(ids, c("relatorio", "eda_municipio", "valido"))
  expect_length(temas, 10)
  expect_true(any(grepl("repetido", out)))
})

test_that("pedido valida assistente, nível e opções do assistente (400)", {
  g <- list(nivel = "municipio", codigo = "3509502")
  expect_error(new_report_request_model(g, "ideb_territorio", assistente = "nao_existe"),
               class = "invalid_report_request")
  expect_error(new_report_request_model(g, "ideb_territorio", assistente = 7),
               class = "invalid_report_request")
  expect_error(new_report_request_model(list(nivel = "uf", codigo = "SP"), NULL, assistente = "eda_municipio"),
               "não está disponível para o nível uf")
  expect_error(new_report_request_model(g, NULL, list(rede = "Municipal"), assistente = "eda_municipio"),
               "Opção não aceita pelo assistente")
  expect_error(new_report_request_model(g, NULL, list(etapa = "infantil"), assistente = "eda_municipio"),
               "Valor inválido para `etapa`")

  # composto: tema ignorado, padrão da opção aplicado
  m <- new_report_request_model(g, "qualquer_coisa", assistente = "eda_municipio")
  expect_null(m$tema)
  expect_equal(m$opcoes, list(etapa = "fundamental_i"))
  expect_equal(m$assistente$id, "eda_municipio")

  # modo tema: tema do catálogo fora do assistente → 400
  d <- yaml_dir(list("so_ideb.yml" = c(
    "id: so_ideb", "titulo: Só IDEB", "descricao: D", "publico: [gestor]",
    "modo: tema", "niveis: [municipio, uf]", "temas: [ideb_territorio]"
  )))
  com_assistentes(d, {
    expect_error(new_report_request_model(g, "redes_territorio", assistente = "so_ideb"),
                 "não faz parte do assistente")
    expect_equal(new_report_request_model(g, "ideb_territorio", assistente = "so_ideb")$tema$id,
                 "ideb_territorio")
    expect_equal(vapply(report_temas(assistente = "so_ideb")$temas, `[[`, character(1), "id"),
                 "ideb_territorio")
  })
})

# ---------------------------------------------------------------------------
# Execução do modo composto (ferramentas falsas)

test_that("EDA do município: capítulos, seções com capitulo, fontes e avisos unidos", {
  tools <- fake_edubr_tools()
  r <- eda(tools = tools)
  expect_equal(r$titulo, "EDA do município — Campinas (SP)")
  expect_equal(r$assistente, list(id = "eda_municipio", titulo = "EDA do município", modo = "composto"))
  expect_equal(r$tema, list(id = "eda_municipio", titulo = "EDA do município"))
  expect_equal(r$recorte$nome, "Campinas")
  # a escola do gestor (Ubatuba) não fica em Campinas: sem `minha_escola`
  expect_equal(cap_ids(r), c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas"))
  for (cp in r$capitulos) expect_setequal(names(cp), c("id", "titulo", "tema"))

  ids <- secao_ids(r)
  expect_equal(ids[1], "resumo")
  expect_equal(ids[length(ids)], "leitura")
  expect_false(anyDuplicated(ids) > 0)
  caps <- vapply(r$secoes, function(s) s$capitulo %||% NA_character_, character(1))
  expect_true(all(is.na(caps[c(1, length(caps))])))
  expect_true(all(caps[-c(1, length(caps))] %in% cap_ids(r)))
  # em ordem de capítulo, com o id prefixado pelo capítulo
  meio <- caps[-c(1, length(caps))]
  expect_equal(unique(meio), cap_ids(r))
  expect_true(all(startsWith(ids[-c(1, length(ids))], paste0(meio, "-"))))
  # só resumo e leitura gerais são texto
  tipos <- vapply(r$secoes, `[[`, character(1), "tipo")
  expect_equal(sum(tipos == "texto"), 2)

  # fontes: união das fontes dos capítulos (sem repetir)
  avulsos <- lapply(c("redes_territorio", "docentes_territorio", "ideb_territorio", "ideb_escolas"), function(t) {
    fake_report(list(nivel = "municipio", codigo = "3509502"), t)$fontes
  })
  esperadas <- unique(unlist(avulsos, recursive = FALSE))
  expect_equal(length(r$fontes), length(esperadas))
  expect_true(all(vapply(esperadas, function(f) any(vapply(r$fontes, identical, logical(1), f)), logical(1))))

  # uma só sessão do eduBR para todos os capítulos
  expect_equal(r$rastreio$chamadas, length(fake_calls(tools)))
  expect_equal(r$rastreio$llm, "ok")
  # JSON válido
  j <- jsonlite::fromJSON(as.character(report_to_json(r)), simplifyVector = FALSE)
  expect_length(j$capitulos, 4)
  expect_equal(j$secoes[[2]]$capitulo, "redes_territorio")
})

test_that("EDA: capítulo da escola do gestor só quando ela está no município", {
  r <- eda("3555406")
  expect_true("minha_escola" %in% cap_ids(r))
  esc <- Filter(function(s) identical(s$capitulo, "minha_escola"), r$secoes)
  expect_gt(length(esc), 0)
  # Ubatuba: os capítulos territoriais das ferramentas falsas ficam sem dados
  sem <- Filter(function(a) identical(a$tipo, "sem_dados"), r$avisos)
  expect_true(any(grepl("O capítulo \"Redes de ensino\" ficou sem dados", vapply(sem, `[[`, "", "mensagem"))))
  # um aviso por capítulo vazio (o `sem_dados` do roteiro é substituído)
  expect_equal(sum(grepl("Redes de ensino", vapply(r$avisos, `[[`, "", "mensagem"))), 1)

  # sem contexto: capítulo omitido (sem aviso)
  r2 <- eda("3555406", contexto = NULL)
  expect_false("minha_escola" %in% cap_ids(r2))
  expect_false(any(grepl("Minha escola", vapply(r2$avisos, `[[`, "", "mensagem"))))
  # escola inexistente: omitido, sem derrubar a EDA
  utils::capture.output(r3 <- eda("3555406", contexto = list(cod_inep = "35000000")))
  expect_false("minha_escola" %in% cap_ids(r3))

  expect_true(report_recorte_contem(
    list(nivel = "municipio", nome = "São Paulo", uf = "SP"),
    list(municipio = "SAO PAULO", uf = "SP")
  ))
  expect_false(report_recorte_contem(
    list(nivel = "municipio", nome = "São Paulo", uf = "SP"),
    list(municipio = "São Paulo", uf = "RJ")
  ))
})

test_that("EDA: opções do assistente sobrepõem as fixas dos capítulos que as aceitam", {
  etapas <- function(tools, tool) {
    unique(unlist(lapply(fake_calls(tools, tool), function(c) c$args$etapa)))
  }
  t1 <- fake_edubr_tools()
  eda(tools = t1)
  expect_equal(etapas(t1, "ideb_agregado"), "fundamental_i")
  expect_equal(etapas(t1, "ideb"), "fundamental_i")

  t2 <- fake_edubr_tools()
  eda(opcoes = list(etapa = "ensino_medio"), tools = t2)
  expect_equal(etapas(t2, "ideb_agregado"), "ensino_medio")
  expect_equal(etapas(t2, "ideb"), "ensino_medio")
  # temas que não aceitam etapa não a recebem
  expect_null(etapas(t2, "redes_municipio"))

  # opção sem padrão e não escolhida: vale a fixa do capítulo
  d <- yaml_dir(list("fixa.yml" = c(
    "id: fixa", "titulo: Fixa", "descricao: D", "publico: [gestor]",
    "modo: composto", "niveis: [municipio]", "capitulos:",
    "  - { tema: ideb_territorio, titulo: A, opcoes: { etapa: fundamental_ii } }",
    "opcoes: { etapa: {} }"
  )))
  com_assistentes(d, {
    t3 <- fake_edubr_tools()
    eda(tools = t3, assistente = "fixa")
    expect_equal(etapas(t3, "ideb_agregado"), "fundamental_ii")
    t4 <- fake_edubr_tools()
    eda(opcoes = list(etapa = "ensino_medio"), tools = t4, assistente = "fixa")
    expect_equal(etapas(t4, "ideb_agregado"), "ensino_medio")
  })
})

test_that("EDA: UMA chamada de LLM para o relatório inteiro, com pacote enxuto", {
  chamadas <- list()
  llm <- function(system, prompt) {
    chamadas[[length(chamadas) + 1L]] <<- list(system = system, prompt = prompt)
    "[RESUMO]\nVisão geral de Campinas.\n[LEITURA]\n- Leia por capítulo."
  }
  r <- eda(provider = "gemini", llm = llm)
  expect_length(chamadas, 1)
  expect_equal(r$secoes[[1]]$markdown, "Visão geral de Campinas.")
  expect_equal(r$secoes[[length(r$secoes)]]$markdown, "- Leia por capítulo.")
  expect_equal(r$rastreio$llm, "ok")

  p <- chamadas[[1]]$prompt
  s <- chamadas[[1]]$system
  expect_match(p, "Redes de ensino; Professores; IDEB do município; Escolas do município pelo IDEB", fixed = TRUE)
  expect_lte(nchar(sub("^.*DADOS \\(JSON\\):\n", "", p)), REPORT_LLM_MAX_CHARS_COMPOSTO)
  dados <- jsonlite::fromJSON(sub("^.*DADOS \\(JSON\\):\n", "", p), simplifyVector = FALSE)
  expect_length(dados$capitulos, 4)
  # sem nomes internos de ferramentas, de temas/capítulos ou de escolas de terceiros
  expect_false(grepl("ideb_agregado|redes_municipio|docentes_rede|\"ferramenta\"", p))
  expect_false(grepl("\"capitulo\"|redes_territorio|ideb_escolas", p))
  expect_false(grepl("ESCOLA ALFA|ESCOLA GAMA", p))
  # system: regras dos temas profundos (lista de escolas), capítulos e o
  # complemento do YAML
  expect_match(s, "Relatório em capítulos", fixed = TRUE)
  expect_match(s, "Relatório exploratório do município", fixed = TRUE)
  expect_match(s, "NÃO cite nomes de escolas", fixed = TRUE)
  expect_match(s, "Associação NÃO é causa", fixed = TRUE)
  expect_match(s, "até ~300 palavras", fixed = TRUE)
})

test_that("EDA: pacote do LLM reduz linhas antes de cortar", {
  big <- data.frame(a = seq_len(200), b = rep("x", 200))
  sec <- report_section_table("t", "T", list(report_col("a", "A", "inteiro"), report_col("b", "B")), big)
  rep <- list(
    titulo = "X", recorte = list(nivel = "municipio"),
    capitulos = lapply(1:30, function(i) list(titulo = paste("Cap", i), secoes = list(sec))),
    fontes = list(), avisos = list()
  )
  txt <- report_llm_payload_composto(rep)
  expect_lte(nchar(txt), REPORT_LLM_MAX_CHARS_COMPOSTO)
  rep$capitulos <- rep$capitulos[1:2]
  d <- jsonlite::fromJSON(report_llm_payload_composto(rep), simplifyVector = FALSE)
  expect_length(d$capitulos[[1]]$secoes[[1]]$linhas, 10)
  expect_equal(d$capitulos[[1]]$secoes[[1]]$linhas_omitidas, 190)
})

test_that("EDA: falha do LLM degrada para o resumo determinístico", {
  n <- 0
  llm <- function(system, prompt) {
    n <<- n + 1
    stop("timeout")
  }
  utils::capture.output(r <- eda(provider = "gemini", llm = llm))
  expect_equal(n, 1)
  expect_equal(r$rastreio$llm, "indisponivel")
  expect_true("llm" %in% vapply(r$avisos, `[[`, character(1), "tipo"))
  expect_match(r$secoes[[1]]$markdown, "**Redes de ensino**", fixed = TRUE)
  expect_match(r$secoes[[1]]$markdown, "**Escolas do município pelo IDEB**", fixed = TRUE)
  expect_length(r$capitulos, 4)

  # mock: texto determinístico, leitura com a de cada capítulo
  m <- eda()
  expect_match(m$secoes[[1]]$markdown, "Modo demonstração")
  expect_match(m$secoes[[length(m$secoes)]]$markdown, "**Professores**", fixed = TRUE)
})

test_that("EDA: capítulo que falha vira aviso e não derruba o relatório", {
  utils::capture.output(r <- eda(tools = fake_edubr_tools(fail = "docentes_rede")))
  expect_equal(cap_ids(r), c("redes_territorio", "ideb_territorio", "ideb_escolas"))
  av <- Filter(function(a) identical(a$tipo, "capitulo"), r$avisos)
  expect_length(av, 1)
  expect_equal(av[[1]]$mensagem, "O capítulo \"Professores\" não pôde ser gerado: a consulta aos dados falhou.")
  # sem nome interno de ferramenta nos avisos
  expect_false(any(grepl("docentes_rede|ideb_agregado", vapply(r$avisos, `[[`, "", "mensagem"))))
  expect_false(any(vapply(r$secoes, function(s) identical(s$capitulo, "docentes_territorio"), logical(1))))

  # erro do cliente num capítulo: a mensagem é a do roteiro
  e <- report_aviso_capitulo(list(titulo = "X"), new_client_error("Etapa não ofertada.", "invalid_report_request"))
  expect_equal(e$mensagem, "O capítulo \"X\" não pôde ser gerado: Etapa não ofertada.")
})

test_that("EDA: se todos os capítulos falham, o erro sobe (400 do cliente, 500 da fonte)", {
  # município fora da base: todos os capítulos falham com erro do cliente
  utils::capture.output(expect_error(eda("3500204"), class = "invalid_report_request"))
  # fonte fora do ar: erro da fonte (500 no endpoint)
  utils::capture.output(expect_error(eda(tools = fake_edubr_tools(fail = "municipios")),
                                     class = "report_source_error"))
})

# ---------------------------------------------------------------------------
# Critério de aceite: terceiro assistente só com YAML de teste

test_that("um terceiro assistente criado só com YAML gera relatório sem código novo", {
  dir_teste <- testthat::test_path("assistentes")
  com_assistentes(dir_teste, {
    pub <- report_assistentes()$assistentes
    expect_equal(vapply(pub, `[[`, character(1), "id"), c("relatorio", "eda_municipio", "panorama_uf"))
    p <- pub[[3]]
    expect_equal(p$padroes, list(etapa = "fundamental_ii"))
    expect_equal(p$opcoes, list(etapa = list("fundamental_i", "fundamental_ii")))
    expect_equal(vapply(p$capitulos, `[[`, character(1), "id"),
                 c("ideb_territorio", "gestores_territorio", "infra", "minha_escola"))
    expect_identical(report_limits_assistente(report_assistente("panorama_uf"))$max_chamadas, 50L)

    tools <- fake_edubr_tools()
    chamadas <- 0
    sys <- NULL
    llm <- function(system, prompt) {
      chamadas <<- chamadas + 1
      sys <<- system
      "[RESUMO]\nPanorama.\n[LEITURA]\n- Itens."
    }
    r <- run_report(
      list(nivel = "uf", codigo = "SP"), NULL, contexto = list(cod_inep = "35038751"),
      config = fake_report_config("gemini"), tools = tools, llm = llm, assistente = "panorama_uf"
    )
    expect_equal(r$titulo, "Panorama do estado — São Paulo")
    # a escola do gestor fica em SP: o capítulo opcional entra
    expect_equal(cap_ids(r), c("ideb_territorio", "gestores_territorio", "infra", "minha_escola"))
    expect_true("associacoes" %in% vapply(r$secoes, `[[`, character(1), "tipo"))
    expect_true(any(startsWith(secao_ids(r), "infra-")))
    expect_equal(chamadas, 1)
    expect_match(sys, "PANORAMA-UF", fixed = TRUE)
    # padrão do assistente (fundamental_ii) sobrepõe; rede fixa do capítulo
    reg <- fake_calls(tools, "regressao_escolas")[[1]]$args
    expect_equal(reg$outcome, "ideb_fund_ii")
    expect_equal(reg$rede, "publica")
    expect_true("associacao" %in% vapply(r$avisos, `[[`, character(1), "tipo"))

    # outra UF: a escola (SP) fica de fora
    r2 <- run_report(
      list(nivel = "uf", codigo = "MG"), NULL, contexto = list(cod_inep = "35038751"),
      config = fake_report_config(), tools = fake_edubr_tools(), assistente = "panorama_uf"
    )
    expect_false("minha_escola" %in% cap_ids(r2))
    expect_error(
      run_report(list(nivel = "municipio", codigo = "3509502"), NULL,
                 config = fake_report_config(), tools = fake_edubr_tools(), assistente = "panorama_uf"),
      class = "invalid_report_request"
    )
  })
  # fora da opção, o assistente de teste não existe
  expect_error(report_assistente("panorama_uf"), class = "invalid_report_request")
})
