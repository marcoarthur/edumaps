#!/usr/bin/env Rscript
# =================================================================
# Extraccao BrazilCrime/SINESP -> clean.brazilcrime_municipio
# Issue #164
#
# Este script e o `extract_brazilcrime.R` que o job
# EduMaps::Ingestion::Job::BrazilCrime chama e que nunca existiu.
#
# O script NAO toca na base de dados. Le a lista de municipios e
# escreve um CSV. Quem faz o COPY e o Perl, que ja tem a ligacao.
# Motivo: assim este ficheiro e testavel sem base de dados e sem
# pacotes R de acesso a dados -- RPostgres nao esta garantido no
# runtime dos jobs Minion.
#
# Uso:
#   Rscript --vanilla extract_brazilcrime.R \
#       <municipios.csv> <saida.csv> [opcoes]
#
# Argumentos:
#   municipios.csv   codigo_ibge;sigla_uf;nome_municipio  (exportado pelo Perl)
#   saida.csv        ficheiro a escrever
#
# Opcoes:
#   --pacote=BrazilCrime    pacote R de onde tirar os dados (default)
#   --dados=<csv>           usar um CSV em vez do pacote (para testes)
#   --variantes=<csv>       mapa de variantes de nome (default: ao lado deste ficheiro)
#   --snapshot=AAAA-MM-DD   dt_snapshot a escrever (default: hoje)
#   --orfaos=<csv>          escrever o relatorio de orfaos aqui
#
# -----------------------------------------------------------------
# As cinco coisas que este script tem de acertar
# -----------------------------------------------------------------
# Cada uma existe porque medir a fonte mostrou que a alternativa
# produz numero errado com aspecto de numero certo:
#
# 1. O sentinela "NAO INFORMADO". O pacote tem 27 pares (uf, "NAO
#    INFORMADO"). O de RJ sozinho tem 66 377 vitimas -- mais do que
#    o Rio de Janeiro (59 580). Sem exclusao, o "maior municipio
#    criminal" do Brasil seria um bucket sem municipio.
#
# 2. O join e por (uf, nome), nao por nome. 233 nomes repetem-se
#    entre UFs (AGUA BRANCA em AL/PB/PI). O pacote nao tem codigo IBGE.
#
# 3. Variantes de nome sao DADO, nao codigo. Barão DE Monte Alto vs
#    DO, Gracho vs Graccho: um `if` no meio do join seria um
#    primeiro-numero-que-fala-mais-alto do ficheiro. Vao em CSV.
#
# 4. Só categoria "vitimas", e a coluna total_vitima. A fonte tem 8
#    categorias (arma de fogo, drogas, bombeiros, ocorrencias...) e
#    703 608 linhas sem categoria. Somar tudo conta apreensao de
#    droga como crime.
#
# 5. Supressão so para 1..4. Zero e um facto ("a fonte cobre este
#    municipio e nao registou"); 1..4 e sigilo. Se suprimir o zero,
#    perde-se a distincao que o #154 veio criar.
#
# -----------------------------------------------------------------
# Um aviso sobre a fonte
# -----------------------------------------------------------------
# Os dados estao EMBUTIDOS no pacote CRAN. Nao ha fetch: get_
# sinesp_vde_data() le um data.frame do namespace. Isto e bom
# (sem rede, sem chave) e tem um custo: os dados congelam na versao
# publicada. Actualizar significa reinstalar o pacote. A coluna
# dt_snapshot existe para tornar essa versao visivel.
# =================================================================

suppressWarnings(suppressMessages({
  args <- commandArgs(trailingOnly = TRUE)
}))

die <- function(...) {
  cat("ERRO:", ..., "\n", file = stderr())
  quit(status = 1)
}

# ---- opcoes ---------------------------------------------------------
opt <- list(pacote = "BrazilCrime", dados = NA_character_,
            variantes = NA_character_, snapshot = Sys.Date(), orfaos = NA_character_,
            lib = NA_character_)
if (length(args) < 2) die("faltam argumentos: <municipios.csv> <saida.csv>")

mun_file   <- args[[1]]
out_file   <- args[[2]]
for (a in args[-c(1, 2)]) {
  if (grepl("^--pacote=", a))     opt$pacote     <- sub("^--pacote=", "", a)
  else if (grepl("^--dados=", a)) opt$dados      <- sub("^--dados=", "", a)
  else if (grepl("^--variantes=", a)) opt$variantes <- sub("^--variantes=", "", a)
  else if (grepl("^--snapshot=", a))   opt$snapshot <- as.Date(sub("^--snapshot=", "", a))
  else if (grepl("^--orfaos=", a))     opt$orfaos   <- sub("^--orfaos=", "", a)
  else if (grepl("^--lib=", a))        opt$lib      <- sub("^--lib=", "", a)
}

# O --lib tem de entrar no .libPaths antes de qualquer requireNamespace.
# Sem isto, o script nao encontra o pacote e morre com "pacote nao
# instalado" -- que e uma mensagem que nao diz onde procurou.
if (!is.na(opt$lib)) {
  if (!dir.exists(opt$lib)) dir.create(opt$lib, recursive = TRUE)
  .libPaths(c(opt$lib, .libPaths()))
}

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
if (is.na(opt$variantes)) opt$variantes <- file.path(script_dir, "brazilcrime_variantes.csv")

# ---- normalizacao ---------------------------------------------------
# Sem accents, maiusculas, espacos colapsados. E o que torna
# comparável "ACRELÂNDIA" com "ACRELANDIA".
norm <- function(x) {
  x <- iconv(as.character(x), from = "UTF-8", to = "ASCII//TRANSLIT")
  x <- toupper(x)
  x <- gsub("[^A-Z0-9 ]", " ", x)
  trimws(gsub(" +", " ", x))
}

# ---- municipios de referencia --------------------------------------
if (!file.exists(mun_file)) die("nao encontro o ficheiro de municipios: ", mun_file)
# sep="," explicito: nao depende do locale (em pt-BR o default do R
# seria ";" e o ficheiro viria partido em colunas erradas).
# header=FALSE e obrigatorio: o CSV exportado pelo Perl nao tem
# cabecalho. Sem isto, read.csv assume que a primeira linha e o
# cabecalho -- e o primeiro municipio da lista vira o nome da coluna.
# Medido: 5572 linhas lidas em vez de 5573, e o join falhava para
# "RO|ALTA FLORESTA D OESTE" sem nenhuma mensagem de erro.
mun <- utils::read.csv(mun_file, colClasses = "character", sep = ",",
                       header = FALSE,
                       col.names = c("codigo_ibge", "sigla_uf", "nome_municipio"))
cat(sprintf("Municipios de referencia: %d\n", nrow(mun)))

# As "AREAS OPERACIONAIS" estao na malha_municipio mas nao sao
# municipios (regiao das lagoas do RS, no IBGE). Excluir e certo;
# exclude-se com registo, a nao ser que aparecam sem rasto -- que e
# o defeito da #155.
eh_area_operacional <- grepl("^AREA OPERACIONAL", norm(mun$nome_municipio))
if (any(eh_area_operacional)) {
  cat(sprintf("Excluidos %d 'area operacional' da malha (nao sao municipios): %s\n",
              sum(eh_area_operacional),
              paste(norm(mun$nome_municipio[eh_area_operacional]), collapse = ", ")))
}
mun <- mun[!eh_area_operacional, ]
mun$chave <- paste(mun$sigla_uf, norm(mun$nome_municipio), sep = "|")

# ---- dados da fonte -------------------------------------------------
if (!is.na(opt$dados)) {
  cat("A ler dados de:", opt$dados, "(modo teste)\n")
  d <- utils::read.csv(opt$dados, colClasses = "character", sep = ",")
  d$ano <- as.integer(d$ano)
  for (cn in c("total_vitima")) d[[cn]] <- suppressWarnings(as.numeric(d[[cn]]))
} else {
  cat("A carregar pacote:", opt$pacote, "\n")
  if (!requireNamespace(opt$pacote, quietly = TRUE))
    die("pacote ", opt$pacote, " nao instalado. Ver install_brazilcrime.R")
  ns <- asNamespace(opt$pacote)
  if (!exists("sinesp_vde_data", envir = ns))
    die("o pacote ", opt$pacote, " nao tem sinesp_vde_data no namespace")
  d <- get("sinesp_vde_data", envir = ns)
  cat(sprintf("Fonte: %d linhas, %d colunas\n", nrow(d), ncol(d)))
}

# ---- (4) so vitimas -------------------------------------------------
# A fonte tem 8 categorias. So "vitimas" e' que interessa.
#
# Medido: a categoria "ocorrencias" tem 13 452 linhas, mas TODAS com
# municipio == "NÃO INFORMADO" -- o pacote NAO publica crimes
# patrimoniais (roubo, furto) por municipio. Incluir "ocorrencias" nao
# acrescenta nenhuma linha util: o sentinela e' excluido a seguir, e
# as 4 colunas de crimes patrimoniais ficam vazias.
#
# As outras categorias (arma de fogo, drogas, bombeiros, desaparecidos,
# profissionais de seguranca, e as 703 608 linhas sem categoria) sao
# excluidas: apreensao de droga e atendimento de bombeiros nao sao
# criminalidade, e "tentativa" nao tem vitima.
n_antes <- nrow(d)
d <- d[!is.na(d$categoria) & d$categoria == "vitimas", ]
cat(sprintf("Categoria 'vitimas': %d de %d linhas (descartadas %d)\n",
            nrow(d), n_antes, n_antes - nrow(d)))

# ---- (1) sentinela NAO INFORMADO -------------------------------------
d$uf <- toupper(as.character(d$uf))
d$municipio_norm <- norm(d$municipio)
orfaos <- list()

n_antes <- nrow(d)
d <- d[d$municipio_norm != "NAO INFORMADO", ]
cat(sprintf("Excluidos %d linhas do sentinela 'NAO INFORMADO'\n", n_antes - nrow(d)))

# ---- (3) variantes de nome -------------------------------------------
if (file.exists(opt$variantes)) {
  var <- utils::read.csv(opt$variantes, colClasses = "character", sep = ",")
  var$nome_fonte_norm <- norm(var$nome_fonte)
  var$chave <- paste(var$uf, var$nome_ibge, sep = "|")
  for (i in seq_len(nrow(var))) {
    alvo <- var$chave[i]
    mask <- d$uf == toupper(var$uf[i]) & d$municipio_norm == var$nome_fonte_norm[i]
    if (any(mask)) {
      cat(sprintf("Variante aplicada: %s|%s -> %s (%d linhas)\n",
                  var$uf[i], var$nome_fonte_norm[i], alvo, sum(mask)))
      d$municipio_norm[mask] <- norm(var$nome_ibge[i])
    }
  }
} else {
  cat("AVISO: sem ficheiro de variantes (", opt$variantes, ")\n", sep = "")
}
d$chave <- paste(d$uf, d$municipio_norm, sep = "|")

# ---- (2) join ---------------------------------------------------------
idx <- match(d$chave, mun$chave)
d$codigo_ibge <- mun$codigo_ibge[idx]

orfaos_fonte <- unique(d$chave[is.na(d$codigo_ibge)])
if (length(orfaos_fonte)) {
  cat(sprintf("\n!! %d pares da FONTE sem municipio correspondente:\n", length(orfaos_fonte)))
  print(head(orfaos_fonte, 20))
}
orfaos_fonte_tbl <- d[is.na(d$codigo_ibge), c("uf", "municipio_norm")]

d <- d[!is.na(d$codigo_ibge), ]

orfaos_base <- setdiff(mun$chave, unique(d$chave))
if (length(orfaos_base)) {
  cat(sprintf("\n!! %d municipios da BASE sem qualquer dado na fonte:\n", length(orfaos_base)))
  print(orfaos_base)
}

orfaos_tbl <- rbind(
  # rep() em todas as colunas: data.frame(lado="fonte", uf=<0 linhas>)
  # rebenta com "argumentos implicam em numero de linhas distintos:
  # 1, 0". Como um dos lados quase nunca tem orfaos ao mesmo tempo
  # que o outro, isso rebentava em praticamente toda a execucao real
  # -- e so apareceu porque o teste exercitou o caso de um lado vazio.
  data.frame(lado = rep("fonte", nrow(orfaos_fonte_tbl)),
             uf   = orfaos_fonte_tbl$uf,
             nome = orfaos_fonte_tbl$municipio_norm,
             stringsAsFactors = FALSE),
  data.frame(lado = rep("base", length(orfaos_base)),
             uf   = sub("\\|.*", "", orfaos_base),
             nome = sub("^[^|]*\\|", "", orfaos_base),
             stringsAsFactors = FALSE)
)

# ---- (5) agregacao + supressao ---------------------------------------
# Uma linha por (municipio, ano, evento), com o total anual das vitimas.
#
# Se o join nao casou nada, aggregate() rebenta com "nenhumas linhas
# para agregar" -- que e uma mensagem que nao diz nada. Falhar aqui,
# com o numero, e o que permite perceber se o problema e o ficheiro de
# municipios, o mapa de variantes, ou a fonte.
if (nrow(d) == 0L)
  die(sprintf("nenhuma linha da fonte casou com um municipio (%d pares orfaos, %d municipios de referencia sem dados). Ver o relatorio de orfaos",
              length(orfaos_fonte), nrow(mun)))

agg <- stats::aggregate(d$total_vitima,
                        by = list(codigo_ibge = d$codigo_ibge,
                                  ano = d$ano,
                                  evento = d$evento),
                        FUN = function(x) sum(x, na.rm = TRUE))
names(agg)[4] <- "valor"
cat(sprintf("Agregado: %d linhas (municipio x ano x evento)\n", nrow(agg)))

# Pivot: evento -> coluna. Os nomes das colunas sao os do contrato
# (data_pipeline/deploy/brazilcrime_sem_patrimoniais.sql).
# So 3 eventos: o pacote NAO publica crimes patrimoniais por municipio.
mapa <- c(
  "Homicídio doloso"                         = "homicidio_doloso",
  "Roubo seguido de morte (latrocínio)"      = "latrocinio",
  "Lesão corporal seguida de morte"          = "lesao_corporal_seguida_de_morte"
)
faltam <- setdiff(names(mapa), unique(agg$evento))
tem    <- setdiff(unique(agg$evento), names(mapa))
if (length(faltam)) cat("AVISO: eventos do mapa sem linhas na fonte:", paste(faltam, collapse = ", "), "\n")
if (length(tem))    cat("NOTA: eventos na fonte sem coluna no contrato (descartados):",
                        paste(tem, collapse = ", "), "\n")
agg$coluna <- unname(mapa[agg$evento])
agg <- agg[!is.na(agg$coluna), ]

# As colunas do CONTRATO (o valor do mapa), nunca as do evento (o nome
# do mapa). Confundir os dois e o que fez a supressao virar um no-op
# silencioso.
cols_cr <- unname(mapa)

# Pivot escrito a mao, com stats::reshape.
#
# Duas razoes, ambas medidas nesta base:
#
#  1. reshape() nao prefixa os nomes com "wide." mas com o nome da
#     coluna medida -- aqui "valor.", porque a coluna chama-se
#     "valor". O sub("^wide\\.") nao tirava nada, o intersect com
#     cols_cr dava vazio, e a supressao nao corria. Sem erro, sem
#     aviso: as 7 colunas saiam inteiramente vazias e o script
#     terminava com exit 0.
#
#  2. reshape() descarta linhas duplicadas em silencio ("multiple rows
#     match for coluna=X: first taken"). Aqui o agg ja e unico por
#     (codigo_ibge, ano, evento), mas um pivot que depende dessa
#     invariante e um pivot que pode perder dados sem dizer nada.
#
# O contrato tem 7 colunas fixas: um ciclo explicito e mais curto e
# mais honesto do que um reshape cujas convencoes de nomeacao mudam
# com o nome da coluna medida.
chave_de <- function(cod, ano) paste(cod, ano, sep = "\r")
wide <- unique(agg[, c("codigo_ibge", "ano")])
for (cn in cols_cr) {
  sel <- which(agg$coluna == cn)
  wide[[cn]] <- NA_real_
  if (length(sel)) {
    i <- match(chave_de(agg$codigo_ibge[sel], agg$ano[sel]),
               chave_de(wide$codigo_ibge, wide$ano))
    wide[[cn]][i] <- as.numeric(agg$valor[sel])
  }
}

# ---- supressao de celula pequena -------------------------------------
# So 1..4. Zero e um facto, nao sigilo. E o que mantem a distincao
# entre "nenhum crime registado" e "o numero foi ocultado".
cobertos <- unique(wide$codigo_ibge)
for (cn in intersect(cols_cr, names(wide))) {
  v <- wide[[cn]]
  a_suprimir <- !is.na(v) & v > 0 & v < 5
  n_sup <- sum(a_suprimir)
  if (n_sup > 0) {
    wide[[cn]][a_suprimir] <- NA_integer_
    if (!"supressao_celula_pequena" %in% names(wide)) wide$supressao_celula_pequena <- FALSE
    wide$supressao_celula_pequena[a_suprimir] <- TRUE
    cat(sprintf("Supressao: %d valores de %s entre 1 e 4\n", n_sup, cn))
  }
}
if (!"supressao_celula_pequena" %in% names(wide)) wide$supressao_celula_pequena <- FALSE

# ---- municipios que a fonte nao cobre -------------------------------
# Nao se escreve 0, e tambem nao se escreve uma linha de NULLs: a
# ausencia da linha numa LEFT JOIN ja produz NULL, e multiplicar
# 5573 municipios por 11 anos de NULL seria ruido.
#
# O que nao pode acontecer e desaparecer em silencio. O municipio fica
# no relatorio de orfaos e no log, e o consumidor tem de fazer LEFT
# JOIN -- e o teste verifica que nenhum consumidor faz INNER JOIN.
faltam_mun <- mun[!mun$codigo_ibge %in% cobertos, ]
if (nrow(faltam_mun)) {
  cat(sprintf("\nMunicipios sem cobertura na fonte: %d -- ficam SEM LINHA (NULL num LEFT JOIN, nunca 0)\n",
              nrow(faltam_mun)))
  print(paste(faltam_mun$sigla_uf, faltam_mun$nome_municipio, sep = "/", collapse = ", "))
  orfaos_tbl <- rbind(orfaos_tbl,
    data.frame(lado = "sem_cobertura", uf = faltam_mun$sigla_uf,
               nome = norm(faltam_mun$nome_municipio), stringsAsFactors = FALSE))
}

# ---- colunas finais --------------------------------------------------
for (cn in cols_cr) if (!cn %in% names(wide)) wide[[cn]] <- NA_integer_
wide$ano <- as.integer(wide$ano)
wide$dt_snapshot <- as.character(opt$snapshot)
wide <- wide[, c("codigo_ibge", "ano", cols_cr, "supressao_celula_pequena", "dt_snapshot")]
wide <- wide[order(wide$codigo_ibge, wide$ano), ]

utils::write.csv(wide, out_file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
cat(sprintf("\nEscrito %s: %d linhas, %d colunas\n", out_file, nrow(wide), ncol(wide)))
cat(sprintf("Snapshot: %s\n", opt$snapshot))

# O relatorio de orfaos escreve-se no fim, com tudo junto. Um orfao que
# fica no log e nao no ficheiro e um orfao que ninguem volta a ver -- que
# e o modo como a #155 perdeu localidades.
if (!is.na(opt$orfaos)) {
  utils::write.csv(orfaos_tbl, opt$orfaos, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Orfaos: %d registos escritos em %s\n", nrow(orfaos_tbl), opt$orfaos))
}

# ---- o silencio tambem e um resultado ---------------------------------
# Se nada casou, o exit code tem de ser != 0. Um script que acaba com um
# CSV vazio e "bem-sucedido" e o que faz um pipeline parecer saudavel
# enquanto nao carregou nada.
if (nrow(wide) == 0L)
  die("nenhuma linha produzida: o join nao casou nada. Ver o relatorio de orfaos")