#!/usr/bin/env Rscript
# =================================================================
# Arealização do raster de cobertura do solo do MapBiomas (Coleção 11)
# sobre a área de influência da escola (clean.escola_influencia).
# Issue #255 — bloco F (meio ambiente) do IVET.
#
# Quem chama: o job EduMaps::Ingestion::Job::MapBiomasEscola. O Perl baixa o
# COG e exporta os buffers em GeoJSON; este script NÃO toca na base de dados
# — lê ficheiros, calcula frações por classe e escreve CSV.
#
# Uso:
#   Rscript --vanilla extract_mapbiomas_escola.R \
#     --buffers=<geojson> --raster=<tif> --ano=<AAAA> --raio=<m> \
#     --saida=<csv> [--orfaos=<csv>]
#
#   # Teste/sanidade sem raster (pesos já calculados; ver o job):
#   Rscript --vanilla extract_mapbiomas_escola.R \
#     --dados=<csv> --ano=<AAAA> --raio=<m> --saida=<csv> [--orfaos=<csv>]
#
# Entrada do modo --dados (o resultado "cru" da extração zonal):
#   co_entidade,nu_ano_censo,classe,peso
#
# Regra #154 (ausência ≠ zero): um buffer SEM interseção com o raster não
# produz linha nenhuma. Um peso 0 nunca entra. Não há preenchimento com 0.
#
# A legenda é a do MapBiomas (nível 4). Vive aqui, e não no banco, porque a
# arealização é um produto derivado do raster, não da estatística municipal
# (clean.mapbiomas_cobertura). Um código fora da legenda é rotulado
# "(classe N, ausente da legenda)", nunca em silêncio.
# =================================================================

args <- commandArgs(trailingOnly = TRUE)

die <- function(...) {
  cat("ERRO:", ..., "\n", file = stderr())
  quit(status = 1)
}

opcao <- function(nome, padrao = NULL, obrigatorio = FALSE) {
  chave <- paste0("--", nome, "=")
  valor <- NULL
  for (a in args) if (startsWith(a, chave)) valor <- substring(a, nchar(chave) + 1)
  if (is.null(valor)) {
    if (obrigatorio) die("falta --", nome, "=")
    return(padrao)
  }
  valor
}

buffers <- opcao("buffers")
raster  <- opcao("raster")
dados   <- opcao("dados")
saida   <- opcao("saida", obrigatorio = TRUE)
orfaos  <- opcao("orfaos")

ano <- suppressWarnings(as.integer(opcao("ano", obrigatorio = TRUE)))
raio <- suppressWarnings(as.integer(opcao("raio", obrigatorio = TRUE)))
if (is.na(ano) || ano < 1985 || ano > 2025) die("--ano inválido (esperado 1985..2025)")
if (is.na(raio) || raio <= 0) die("--raio inválido (esperado > 0)")

if (is.null(dados) && (is.null(buffers) || is.null(raster))) {
  die("forneça --dados=<csv> ou o par --buffers=<geojson> --raster=<tif>")
}

# -----------------------------------------------------------------
# Legenda MapBiomas (código → descrição, nível 4). Coleção 11.
# -----------------------------------------------------------------
LEGENDA <- c(
  "0"  = "0. Not Observed",
  "3"  = "1.1. Forest Formation",
  "4"  = "1.2. Savanna Formation",
  "5"  = "1.3. Mangrove",
  "6"  = "1.4 Floodable Forest",
  "9"  = "3.3. Forest Plantation",
  "11" = "2.1. Wetland",
  "12" = "2.2. Grassland",
  "13" = "2.6. Other non Forest Formations",
  "15" = "3.1. Pasture",
  "20" = "3.2.1.2. Sugar cane",
  "21" = "3.4. Mosaic of Uses",
  "23" = "4.1. Beach, Dune and Sand Spot",
  "24" = "4.2. Urban Area",
  "25" = "4.5. Other non Vegetated Areas",
  "29" = "2.4. Rocky Outcrop",
  "30" = "4.3. Mining",
  "31" = "5.2. Aquaculture",
  "32" = "2.3. Hypersaline Tidal Flat",
  "33" = "5.1. River, Lake and Ocean",
  "35" = "3.2.2.3. Palm Oil",
  "39" = "3.2.1.1. Soybean",
  "40" = "3.2.1.3. Rice",
  "41" = "3.2.1.5. Other Temporary Crops",
  "46" = "3.2.2.1. Coffee",
  "47" = "3.2.2.2. Citrus",
  "48" = "3.2.2.4. Other Perennial Crops",
  "49" = "1.5. Wooded Sandbank Vegetation",
  "50" = "2.4. Herbaceous Sandbank Vegetation",
  "62" = "3.2.1.4. Cotton",
  "75" = "4.4. Photovoltaic Project"
)

legendar <- function(cl) {
  cl <- as.character(cl)
  fora <- !(cl %in% names(LEGENDA))
  d <- unname(LEGENDA[cl])
  d[fora] <- paste0("(classe ", cl[fora], ", ausente da legenda)")
  d
}

# -----------------------------------------------------------------
# Normalização: peso cru por (escola, censo, classe) -> fração em [0,1].
# Linhas com peso NA/<=0 são descartadas (nunca contam como 0).
# -----------------------------------------------------------------
normalizar <- function(d, ano, raio) {
  d <- d[, c("co_entidade", "nu_ano_censo", "classe", "peso"), drop = FALSE]
  d$classe <- as.character(d$classe)
  d$peso <- suppressWarnings(as.numeric(d$peso))
  d <- d[!is.na(d$peso) & d$peso > 0 & !is.na(d$classe) & nzchar(d$classe), , drop = FALSE]

  vazio <- data.frame(
    co_entidade = integer(0), nu_ano_censo = integer(0), ano = integer(0),
    raio_m = integer(0), classe = character(0), classe_desc = character(0),
    fracao = numeric(0)
  )
  if (nrow(d) == 0) return(vazio)

  agg <- aggregate(peso ~ co_entidade + nu_ano_censo + classe, data = d, FUN = sum)
  tot <- aggregate(peso ~ co_entidade + nu_ano_censo, data = agg, FUN = sum)
  names(tot)[names(tot) == "peso"] <- "total"
  agg <- merge(agg, tot, by = c("co_entidade", "nu_ano_censo"))
  if (any(agg$total <= 0)) die("total de peso não-positivo — inesperado")

  agg$fracao <- round(agg$peso / agg$total, 6)
  agg$classe_desc <- legendar(agg$classe)
  agg$ano <- ano
  agg$raio_m <- raio

  res <- agg[order(agg$co_entidade, agg$nu_ano_censo, -agg$fracao, agg$classe),
             c("co_entidade", "nu_ano_censo", "ano", "raio_m", "classe",
               "classe_desc", "fracao")]
  # Chaves como inteiro: o CSV sai sem aspas nos números e o loader lê direto.
  res$co_entidade  <- as.integer(res$co_entidade)
  res$nu_ano_censo <- as.integer(res$nu_ano_censo)
  res$ano          <- as.integer(res$ano)
  res$raio_m       <- as.integer(res$raio_m)
  res$fracao       <- as.numeric(res$fracao)
  # Fração com 6 casas FIXAS: o write.csv usa notação científica para valores
  # pequenos (5.1e-05), que o contrato do loader não aceita. numeric(7,6) no
  # banco tem exatamente esta precisão.
  res$fracao <- sprintf("%.6f", res$fracao)
  res
}

# -----------------------------------------------------------------
# Extração do raster (ou leitura do CSV cru no modo --dados)
# -----------------------------------------------------------------
chaves_alvo <- NULL   # keys (co_entidade|nu_ano_censo) dos buffers de entrada

if (!is.null(dados)) {
  if (!file.exists(dados)) die("--dados não existe: ", dados)
  cru <- read.csv(dados, colClasses = "character", check.names = FALSE)
  faltam <- setdiff(c("co_entidade", "nu_ano_censo", "classe", "peso"), names(cru))
  if (length(faltam)) die("--dados: faltam colunas: ", paste(faltam, collapse = ", "))
  d <- data.frame(
    co_entidade  = as.character(cru$co_entidade),
    nu_ano_censo = as.character(cru$nu_ano_censo),
    classe       = as.character(cru$classe),
    peso         = as.character(cru$peso),
    stringsAsFactors = FALSE
  )
  cat(sprintf("[mapbiomas_escola] modo --dados: %d linhas cruas de %s\n", nrow(d), dados))
} else {
  if (!file.exists(raster)) die("--raster não existe: ", raster)
  if (!file.exists(buffers)) die("--buffers não existe: ", buffers)
  if (!requireNamespace("terra", quietly = TRUE)) {
    die("pacote R 'terra' ausente. O host de ingestão precisa dele (Rex deploy_minion_dev).")
  }
  r <- terra::rast(raster)
  if (terra::nlyr(r) != 1) die("--raster tem ", terra::nlyr(r), " camadas; esperava 1")

  v <- terra::vect(buffers)
  for (col in c("co_entidade", "nu_ano_censo")) {
    if (!(col %in% names(v))) die("--buffers sem a coluna '", col, "'")
  }

  # SIRGAS2000 (4674, do banco) e WGS84 (EPSG:4326, do raster): a diferença é
  # sub-métrica, muito abaixo de um pixel de 30 m. Atribuir o CRS à geometria
  # evita uma reprojeção PROJ quase-identidade, que só custaria tempo e memória.
  try(terra::crs(v) <- terra::crs(r), silent = TRUE)

  # Garantir códigos numéricos: um COG com tabela de categorias devolveria
  # rótulos em vez dos códigos da legenda.
  try(terra::levels(r) <- NULL, silent = TRUE)

  cat(sprintf("[mapbiomas_escola] extraindo %s (%d buffers)...\n",
              basename(raster), nrow(v)))

  e <- terra::extract(r, v, weights = TRUE, ID = TRUE, touches = FALSE)
  if (ncol(e) < 2) die("extract não devolveu valores")
  pesos_col <- if ("weight" %in% names(e)) "weight" else names(e)[ncol(e)]
  valor_col <- setdiff(names(e), c("ID", pesos_col))
  if (length(valor_col) != 1) die("raster não é de uma só banda (colunas: ",
                                  paste(names(e), collapse = ", "), ")")

  chaves_alvo <- unique(paste0(v$co_entidade, "|", v$nu_ano_censo))
  d <- data.frame(
    co_entidade  = as.character(v$co_entidade[e$ID]),
    nu_ano_censo = as.character(v$nu_ano_censo[e$ID]),
    classe       = as.character(e[[valor_col]]),
    peso         = as.character(e[[pesos_col]]),
    stringsAsFactors = FALSE
  )
  cat(sprintf("[mapbiomas_escola] %d linhas cruas (célula × polígono)\n", nrow(d)))
}

res <- normalizar(d, ano, raio)

# -----------------------------------------------------------------
# Relatório de órfãos (só no modo raster): buffers sem NENHUMA interseção
# com o raster válido. É a materialização da regra #154 — não entram com 0.
# -----------------------------------------------------------------
if (!is.null(orfaos)) {
  dir.create(dirname(orfaos), showWarnings = FALSE, recursive = TRUE)
  if (is.null(chaves_alvo)) {
    write.csv(data.frame(co_entidade = integer(0), nu_ano_censo = integer(0),
                         motivo = character(0)),
              orfaos, row.names = FALSE)
  } else {
    saida_chaves <- unique(paste0(res$co_entidade, "|", res$nu_ano_censo))
    faltantes <- setdiff(chaves_alvo, saida_chaves)
    df <- if (length(faltantes) == 0) {
      data.frame(co_entidade = integer(0), nu_ano_censo = integer(0), motivo = character(0))
    } else {
      partes <- strsplit(faltantes, "|", fixed = TRUE)
      data.frame(
        co_entidade  = vapply(partes, `[[`, character(1), 1),
        nu_ano_censo = vapply(partes, `[[`, character(1), 2),
        motivo       = "sem interseção com o raster (fora da cobertura ou NoData)",
        stringsAsFactors = FALSE
      )
    }
    write.csv(df, orfaos, row.names = FALSE)
    cat(sprintf("[mapbiomas_escola] órfãos (sem interseção com o raster): %d\n", nrow(df)))
  }
}

dir.create(dirname(saida), showWarnings = FALSE, recursive = TRUE)
# write.csv com aspas (padrão): há descrições com vírgula ("4.1. Beach, Dune
# and Sand Spot"), e sem aspas o CSV ficaria corrompido.
write.csv(res, saida, row.names = FALSE, na = "")
cat(sprintf("[mapbiomas_escola] %d linhas gravadas em %s (ano %d, raio %d m)\n",
            nrow(res), saida, ano, raio))
