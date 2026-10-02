#!/usr/bin/env Rscript
# =================================================================
# Instalação/verificação do pacote R BrazilCrime
# Issue #164
#
# Este script e o `install_brazilcrime.R` que o job
# EduMaps::Ingestion::Job::BrazilCrime chama e que nunca existiu.
#
# Uso:
#   Rscript --vanilla install_brazilcrime.R [opcoes]
#
# Opcoes:
#   --lib=<dir>      biblioteca de destino (default: primeira da .libPaths)
#   --forcar         reinstala mesmo que ja esteja na versao pedida
#
# -----------------------------------------------------------------
# Porque e preciso um script e nao um comando no job
# -----------------------------------------------------------------
# Os dados do SINESP vêm EMBUTIDOS no pacote. get_sinesp_vde_data()
# nao faz fetch nenhum: le um data.frame do namespace, com 7 185 846
# linhas e ~740 MB em memoria. Actualizar os dados significa, portanto,
# actualizar o PACOTE.
#
# Daqui duas coisas:
#
#  1. A versao do pacote tem de ficar registada em cada extracção. Sem
#     isso, um dia os numeros mudam e ninguem sabe porquê — a fonte é
#     um snapshot congelado, nao um servico.
#
#  2. O caminho rápido importa: o download são ~700 MB de dados mais as
#     dependencias (dplyr, forecast, ggplot2). Numa tarefa mensal, dar
#     skip quando a versao ja esta lá evita media hora de rede.
# =================================================================

args <- commandArgs(trailingOnly = TRUE)

die <- function(...) {
  cat("ERRO:", ..., "\n", file = stderr())
  quit(status = 1)
}

PACOTE <- "BrazilCrime"
# Versao minima conhecida. Subir este numero e um acto deliberado:
# uma versao nova pode trazer dados novos E colunas novas, que o
# contrato em brazilcrime_contrato_sinesp tem de acompanhar.
VERSAO_MINIMA <- "0.3.0"

opt <- list(lib = NULL, forcar = FALSE)
for (a in args) {
  if (grepl("^--lib=", a))    opt$lib    <- sub("^--lib=", "", a)
  else if (a == "--forcar")   opt$forcar <- TRUE
  else die("opcao desconhecida: ", a)
}

# O --lib tem de entrar no .libPaths antes de qualquer requireNamespace.
# Sem isto, o script instala para o sitio certo e a seguir diz que o
# pacote "continua nao instalado" — porque o estava a procurar noutro.
if (!is.null(opt$lib)) {
  if (!dir.exists(opt$lib)) dir.create(opt$lib, recursive = TRUE)
  .libPaths(c(opt$lib, .libPaths()))
}

# ---- 1. ja esta instalado? ------------------------------------------
instalado <- tryCatch({
  suppressWarnings(suppressMessages(requireNamespace(PACOTE, quietly = TRUE)))
}, error = function(e) FALSE)

versao <- if (instalado) as.character(utils::packageVersion(PACOTE)) else NA_character_

if (instalado && !opt$forcar && !is.na(versao) &&
    utils::compareVersion(versao, VERSAO_MINIMA) >= 0) {
  cat(sprintf("%s %s ja instalado (minimo %s). A saltar.\n", PACOTE, versao, VERSAO_MINIMA))
} else {
  if (instalado) cat(sprintf("%s %s instalado, versao exigida %s — a reinstalar.\n",
                             PACOTE, versao, VERSAO_MINIMA))
  # lib tem de ser uma string, nao um array. c(lib = opt$lib) cria um
  # array com nome, e install.packages falha com "comprimento de
  # 'dimnames' [2] nao e igual ao tamanho do array" -- um erro que nao
  # diz nada sobre o que esta errado.
  lib_arg <- if (is.null(opt$lib)) NULL else opt$lib

  cat(sprintf("A instalar %s >= %s do CRAN...\n", PACOTE, VERSAO_MINIMA))
  cat("Isto pode demorar varios minutos: as dependencias (dplyr, forecast,\n")
  cat("ggplot2) sao pesadas, e o proprio pacote traz ~700 MB de dados SINESP.\n")

  # Dependencias: Depends + Imports + LinkingTo, e NAO Suggests.
  #
  # install.packages(dependencies=TRUE) traz tudo, incluindo os
  # Suggests (ggcorrplot, kableExtra, rmarkdown, bookdown, testthat) —
  # que sao para os vignettes do pacote e nao tem nada a ver com
  # extrair dados. Numa primeira instalacao mediu-se isso a pagar:
  # varias dezenas de pacotes e minutos de compilacao por nada.
  #
  # Ficar por Depends+Imports tambem evita o "there is no package called
  # 'forecast'" em runtime, que e um erro de carregamento e nao de
  # instalacao, e por isso o primeiro erro que se le.
  deps <- c("Depends", "Imports", "LinkingTo")
  cat("Dependencias a instalar:", paste(deps, collapse = ", "), "(Suggests ignorados)\n")

  res <- tryCatch({
    utils::install.packages(PACOTE, lib = lib_arg, repos = "https://cloud.r-project.org",
                            dependencies = deps)
  }, error = function(e) { cat("ERRO ao instalar:", conditionMessage(e), "\n"); quit(status = 1) })

  cat("Instalacao terminada.\n")
}

# ---- 2. confirmar que veio o que se espera --------------------------
instalado <- suppressWarnings(suppressMessages(requireNamespace(PACOTE, quietly = TRUE)))
if (!instalado) die("o pacote ", PACOTE, " continua nao instalado depois da instalacao")

versao <- as.character(utils::packageVersion(PACOTE))
if (utils::compareVersion(versao, VERSAO_MINIMA) < 0) {
  die(sprintf("versao instalada %s e inferior ao minimo %s", versao, VERSAO_MINIMA))
}

# ---- 3. registar o que a extracao vai encontrar --------------------
# Estas linhas vao para o log do job de propósito. Se um dia o numero
# mudar, a diferenca tem de estar no log e não numa suposição.
ns <- asNamespace(PACOTE)
if (!exists("sinesp_vde_data", envir = ns))
  die("o pacote ", PACOTE, " nao tem sinesp_vde_data no namespace — a API mudou")

d <- get("sinesp_vde_data", envir = ns)
cat(sprintf("\nPacote %s %s pronto.\n", PACOTE, versao))
cat(sprintf("  sinesp_vde_data: %d linhas x %d colunas\n", nrow(d), ncol(d)))
if ("ano" %in% names(d)) {
  anos <- sort(unique(d$ano))
  cat(sprintf("  anos: %s..%s (%d)\n", min(anos), max(anos), length(anos)))
}
if ("municipio" %in% names(d))
  cat(sprintf("  municipios na fonte: %d\n", length(unique(d$municipio))))

# Aviso que tem de aparecer sempre. A tabela vai envelhecer sem que
# ninguem se aperceba, porque nada neste pipeline avisa: o job corre,
# sai verde, e o dado e de ha meses.
cat("\nNOTA: os dados sao um snapshot embutido no pacote, congelado nesta versao.\n")
cat("      Nao ha sincronizacao com o SINESP. Para dados mais recentes,\n")
cat("      reinstalar o pacote (--forcar) e registar a nova versao no log.\n")
