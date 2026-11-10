# Dependências do edumapsr derivadas do DESCRIPTION (#363).
#
# Uma lista mantida à mão divergiu do DESCRIPTION na imagem `analytic`, no
# deploy do LXC e no CI (faltava o testthat, entre outros). Este script lê
# Depends, Imports e Suggests do DESCRIPTION e:
#
#   Rscript inst/scripts/dependencias.R instalar  [DESCRIPTION] [repos]
#     instala do CRAN o que faltar (os pacotes de `Remotes:`, como o eduBR,
#     ficam com o passo próprio, em commit fixo);
#   Rscript inst/scripts/dependencias.R verificar [DESCRIPTION]
#     sai com código 1 e lista o que faltar — o build e o deploy param.
#
# Pacotes base (stats, utils, ...) já vêm com o R e são ignorados.

args <- commandArgs(trailingOnly = TRUE)
modo <- if (length(args) >= 1) args[[1]] else "verificar"
arquivo <- if (length(args) >= 2) args[[2]] else "DESCRIPTION"
repos <- if (length(args) >= 3) args[[3]] else getOption("repos")

if (!modo %in% c("instalar", "verificar")) {
  stop("modo deve ser 'instalar' ou 'verificar', veio: ", modo)
}
if (!file.exists(arquivo)) stop("DESCRIPTION não encontrado: ", arquivo)

d <- read.dcf(arquivo)
campo <- function(nome) {
  if (!nome %in% colnames(d)) return(character())
  x <- trimws(strsplit(d[1, nome], ",")[[1]])
  x <- sub("\\s*\\(.*\\)$", "", x)          # tira a versão: "testthat (>= 3.0.0)"
  x[nzchar(x) & x != "R"]
}
remotos <- sub("@.*$", "", sub("^.*/", "", campo("Remotes")))  # marcoarthur/eduBR@sha -> eduBR

base <- rownames(installed.packages(priority = "base"))
pacotes <- setdiff(unique(c(campo("Depends"), campo("Imports"), campo("Suggests"))), base)

# Carrega cada pacote num processo R NOVO: na mesma sessão, uma dependência já
# carregada numa versão antiga faz o pacote recém-instalado "faltar" sem estar
# faltando. Devolve o erro de carga (ou "" se carregou).
erro_de_carga <- function(pkg) {
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"),
    c("-e", shQuote(sprintf(
      "tryCatch({loadNamespace('%s'); cat('OK')}, error = function(e) cat(conditionMessage(e)))", pkg
    ))),
    stdout = TRUE, stderr = TRUE
  ))
  out <- paste(out, collapse = " ")
  if (grepl("OK$", out)) "" else out
}
faltantes <- function(pkgs) {
  erros <- vapply(pkgs, erro_de_carga, character(1))
  erros[nzchar(erros)]
}
erros <- faltantes(pacotes)
faltando <- names(erros)

if (modo == "instalar") {
  cran <- setdiff(faltando, remotos)
  if (length(cran)) {
    message("Instalando do CRAN: ", paste(cran, collapse = ", "))
    install.packages(cran, repos = repos, Ncpus = max(1L, parallel::detectCores()))
  } else {
    message("Dependências do CRAN já instaladas.")
  }
  erros <- faltantes(setdiff(pacotes, remotos))   # remotos: passo próprio
  faltando <- names(erros)
}

if (length(faltando)) {
  message("FALTAM dependências do DESCRIPTION: ", paste(faltando, collapse = ", "))
  for (k in faltando) message("  ", k, ": ", erros[[k]])
  quit(status = 1)
}
message("OK: ", length(pacotes), " dependências do DESCRIPTION instaladas.")
