#!/usr/bin/env Rscript
# =================================================================
# Arealização de EXPOSIÇÃO A RISCO (MapBiomas Fogo + Solo) sobre a área de
# influência da escola. Issue #278 — bloco F do IVET.
#
# Quem chama: o job EduMaps::Ingestion::Job::MapBiomasRisco. O Perl baixa os
# COGs e exporta os buffers em GeoJSON; este script NÃO toca na base — lê
# ficheiros, agrega e escreve CSV.
#
# Uso:
#   Rscript --vanilla extract_mapbiomas_risco.R \
#     --buffers=<geojson> --raster_fogo=<tif> --raster_solo=<tif> \
#     --ano=<AAAA> --raio=<m> --saida=<csv> [--orfaos=<csv>]
#
#   # Teste/sanidade sem raster (extração "crua" já feita):
#   Rscript --vanilla extract_mapbiomas_risco.R --dados=<csv> \
#     --ano=<AAAA> --raio=<m> --saida=<csv>
#
# Entrada do modo --dados (célula × polígono, valor + peso):
#   co_entidade,nu_ano_censo,indicador,valor,peso
#   indicador: "fogo" (frequência de queimada) ou "solo" (carbono, tC/ha)
#
# Regra #154 (ausência ≠ zero): buffer SEM interseção com um raster tem a
# coluna `NULL`; buffer sem NENHUM indicador NÃO produz linha.
#
# Indicadores por buffer (peso = fração da célula dentro do polígono):
#   fogo_frequencia_media  média ponderada da frequência de queimada
#   fogo_frequencia_max    máximo da frequência no buffer
#   fogo_fracao_queimada   soma dos pesos com frequência > 0 / soma dos pesos
#   solo_carbono_medio     média ponderada do carbono do solo
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
raster_fogo <- opcao("raster_fogo")
raster_solo <- opcao("raster_solo")
dados <- opcao("dados")
saida <- opcao("saida", obrigatorio = TRUE)
orfaos <- opcao("orfaos")

ano <- suppressWarnings(as.integer(opcao("ano", obrigatorio = TRUE)))
raio <- suppressWarnings(as.integer(opcao("raio", obrigatorio = TRUE)))
if (is.na(ano) || ano < 1985 || ano > 2025) die("--ano inválido (esperado 1985..2025)")
if (is.na(raio) || raio <= 0) die("--raio inválido (esperado > 0)")

if (is.null(dados) && (is.null(buffers) || (is.null(raster_fogo) && is.null(raster_solo)))) {
  die("forneça --dados=<csv> ou --buffers=<geojson> com ao menos um raster")
}

# -----------------------------------------------------------------
# Agregação: long (indicador, valor, peso) -> wide por escola.
# -----------------------------------------------------------------
agregar <- function(d, ano, raio) {
  d$co_entidade <- as.character(d$co_entidade)
  d$nu_ano_censo <- as.character(d$nu_ano_censo)
  d$valor <- suppressWarnings(as.numeric(d$valor))
  d$peso <- suppressWarnings(as.numeric(d$peso))
  d <- d[!is.na(d$valor) & !is.na(d$peso) & d$peso > 0, , drop = FALSE]

  vazio <- data.frame(
    co_entidade = integer(0), nu_ano_censo = integer(0), ano = integer(0),
    raio_m = integer(0), fogo_frequencia_media = numeric(0),
    fogo_frequencia_max = integer(0), fogo_fracao_queimada = numeric(0),
    solo_carbono_medio = numeric(0)
  )
  if (nrow(d) == 0) return(vazio)

  chave <- function(x) paste0(x$co_entidade, "\x1f", x$nu_ano_censo)
  chaves <- chave(d)
  ids <- unique(chaves)
  # Índice por chave calculado UMA vez (O(linhas)). Antes, chave(d) era
  # recomputado para cada escola dentro do lapply: O(n²·pixels) — em blocos
  # grandes (Campinas, 1875 escolas) passava de 3600s e morria no stall.
  idx <- split(seq_len(nrow(d)), chaves)

  linhas <- lapply(ids, function(k) {
    dd <- d[idx[[k]], , drop = FALSE]
    fogo <- dd[dd$indicador == "fogo", , drop = FALSE]
    solo <- dd[dd$indicador == "solo", , drop = FALSE]
    tot_fogo <- sum(fogo$peso)
    tot_solo <- sum(solo$peso)
    fm <- if (nrow(fogo) && tot_fogo > 0) sum(fogo$valor * fogo$peso) / tot_fogo else NA_real_
    fx <- if (nrow(fogo)) as.integer(max(fogo$valor)) else NA_integer_
    ff <- if (nrow(fogo) && tot_fogo > 0) sum(fogo$peso[fogo$valor > 0]) / tot_fogo else NA_real_
    sm <- if (nrow(solo) && tot_solo > 0) sum(solo$valor * solo$peso) / tot_solo else NA_real_
    # Formatação com casas FIXAS: o write.csv usa notação científica para
    # valores pequenos (8.5e-05), que o contrato do loader não aceita.
    data.frame(
      co_entidade = as.integer(dd$co_entidade[1]),
      nu_ano_censo = as.integer(dd$nu_ano_censo[1]),
      ano = as.integer(ano),
      raio_m = as.integer(raio),
      fogo_frequencia_media = if (is.na(fm)) NA_character_ else sprintf("%.3f", fm),
      fogo_frequencia_max = fx,
      fogo_fracao_queimada = if (is.na(ff)) NA_character_ else sprintf("%.6f", ff),
      solo_carbono_medio = if (is.na(sm)) NA_character_ else sprintf("%.3f", sm),
      stringsAsFactors = FALSE
    )
  })
  res <- do.call(rbind, linhas)
  res[order(res$co_entidade, res$nu_ano_censo), , drop = FALSE]
}

# -----------------------------------------------------------------
# Extração (ou leitura do CSV cru no modo --dados)
# -----------------------------------------------------------------
chaves_alvo <- NULL

if (!is.null(dados)) {
  if (!file.exists(dados)) die("--dados não existe: ", dados)
  cru <- read.csv(dados, colClasses = "character", check.names = FALSE)
  faltam <- setdiff(c("co_entidade", "nu_ano_censo", "indicador", "valor", "peso"), names(cru))
  if (length(faltam)) die("--dados: faltam colunas: ", paste(faltam, collapse = ", "))
  d <- data.frame(
    co_entidade = cru$co_entidade, nu_ano_censo = cru$nu_ano_censo,
    indicador = cru$indicador, valor = cru$valor, peso = cru$peso,
    stringsAsFactors = FALSE
  )
  cat(sprintf("[mapbiomas_risco] modo --dados: %d linhas cruas\n", nrow(d)))
} else {
  if (!file.exists(buffers)) die("--buffers não existe: ", buffers)
  if (!requireNamespace("terra", quietly = TRUE)) {
    die("pacote R 'terra' ausente (Rex deploy_minion_dev)")
  }
  v <- terra::vect(buffers)
  for (col in c("co_entidade", "nu_ano_censo")) {
    if (!(col %in% names(v))) die("--buffers sem a coluna '", col, "'")
  }
  chaves_alvo <- unique(paste0(v$co_entidade, "|", v$nu_ano_censo))

  extrair <- function(caminho, indicador) {
    if (is.null(caminho)) return(NULL)
    # Os rasters de fogo/solo têm ~2 GB cada e o host de ingestão não tem disco
    # para os guardar: são lidos em *streaming* pelo GDAL via /vsicurl (HTTP
    # range), sem download. O allowlist é validado pelo job antes.
    if (!startsWith(caminho, "/vsicurl/") && !file.exists(caminho)) {
      die("raster não existe: ", caminho)
    }
    r <- terra::rast(caminho)
    if (terra::nlyr(r) != 1) die("raster ", caminho, " tem ", terra::nlyr(r), " camadas")
    try(terra::crs(v) <- terra::crs(r), silent = TRUE)
    try(terra::levels(r) <- NULL, silent = TRUE)
    # Recorta o raster à extensão dos buffers ANTES de extrair. Ler o raster
    # inteiro (~2 GB) por /vsicurl, polígono a polígono, é lento demais
    # (medido: 539 buffers > 30 min, sem terminar). O crop lê só a AOI numa
    # passagem e a extração corre em memória.
    if (startsWith(caminho, "/vsicurl/")) {
      r <- terra::crop(r, terra::ext(v))
    }
    e <- terra::extract(r, v, weights = TRUE, ID = TRUE, touches = FALSE)
    if (ncol(e) < 2) die("extract não devolveu valores para ", caminho)
    pesos_col <- if ("weight" %in% names(e)) "weight" else names(e)[ncol(e)]
    valor_col <- setdiff(names(e), c("ID", pesos_col))
    if (length(valor_col) != 1) die("raster não é de uma só banda: ", caminho)
    data.frame(
      co_entidade = as.character(v$co_entidade[e$ID]),
      nu_ano_censo = as.character(v$nu_ano_censo[e$ID]),
      indicador = indicador,
      valor = as.character(e[[valor_col]]),
      peso = as.character(e[[pesos_col]]),
      stringsAsFactors = FALSE
    )
  }

  cat(sprintf("[mapbiomas_risco] extraindo %d buffers (ano %d, raio %d m)...\n", nrow(v), ano, raio))
  partes <- Filter(Negate(is.null), list(
    extrair(raster_fogo, "fogo"),
    extrair(raster_solo, "solo")
  ))
  d <- do.call(rbind, partes)
  if (is.null(d)) die("nenhum raster fornecido")
}

res <- agregar(d, ano, raio)

# -----------------------------------------------------------------
# Órfãos: buffers sem NENHUM indicador (sem interseção com os rasters).
# -----------------------------------------------------------------
if (!is.null(orfaos)) {
  dir.create(dirname(orfaos), showWarnings = FALSE, recursive = TRUE)
  if (is.null(chaves_alvo)) {
    write.csv(data.frame(co_entidade = integer(0), nu_ano_censo = integer(0),
                         motivo = character(0)), orfaos, row.names = FALSE)
  } else {
    saida_chaves <- unique(paste0(res$co_entidade, "|", res$nu_ano_censo))
    faltantes <- setdiff(chaves_alvo, saida_chaves)
    df <- if (length(faltantes) == 0) {
      data.frame(co_entidade = integer(0), nu_ano_censo = integer(0), motivo = character(0))
    } else {
      partes <- strsplit(faltantes, "|", fixed = TRUE)
      data.frame(
        co_entidade = vapply(partes, `[[`, character(1), 1),
        nu_ano_censo = vapply(partes, `[[`, character(1), 2),
        motivo = "sem interseção com os rasters (fora da cobertura ou NoData)",
        stringsAsFactors = FALSE
      )
    }
    write.csv(df, orfaos, row.names = FALSE)
    cat(sprintf("[mapbiomas_risco] órfãos (sem indicador): %d\n", nrow(df)))
  }
}

dir.create(dirname(saida), showWarnings = FALSE, recursive = TRUE)
write.csv(res, saida, row.names = FALSE, na = "")
cat(sprintf("[mapbiomas_risco] %d linhas gravadas em %s (ano %d, raio %d m)\n",
            nrow(res), saida, ano, raio))
