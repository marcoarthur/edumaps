# testes do núcleo reprodutível do IVET v1.0 (R/ivet.R)

test_that("ivet_versao carimba a versão da fórmula", {
  expect_equal(ivet_versao(), "ivet-v1.2")
})

test_that("ivet_normalizar: binario, proporcao e contagem", {
  # binário: qualquer != 0 vira 1; NA vira 0
  expect_equal(ivet_normalizar(c(0, 1, 3, NA), "binario"), c(0, 1, 1, 0))
  # proporção: clamp(0,1); NA vira 0; >1 corta em 1; <0 corta em 0
  expect_equal(ivet_normalizar(c(0.3, 1.5, -0.2, NA), "proporcao"), c(0.3, 1, 0, 0))
  # contagem: razão contra o teto, clamp(0,1)
  expect_equal(ivet_normalizar(c(5, 10, 20, NA), "contagem", teto = 10), c(0.5, 1, 1, 0))
  # contagem exige teto
  expect_error(ivet_normalizar(5, "contagem"), "teto")
})

test_that("ivet_dimensao: média ponderada, NA vira 0", {
  # peso igual
  expect_equal(ivet_dimensao(c(1, 0)), 0.5)
  # pesos explícitos
  expect_equal(ivet_dimensao(c(1, 0), pesos = c(3, 1)), 0.75)
  # componente ausente entra como 0 (não some do denominador) — §4.1
  expect_equal(ivet_dimensao(c(1, NA)), 0.5)
  expect_error(ivet_dimensao(c(1, 2), pesos = c(1, 1, 1)), "tamanhos diferentes")
})

test_that("ivet_agregar: dimensão ausente sai do denominador — §4.3", {
  # peso igual entre as três disponíveis
  expect_equal(ivet_agregar(c(0.2, 0.5, 0.8)), 0.5)
  # a NA fica fora do numerador E do denominador
  expect_equal(ivet_agregar(c(0.2, NA, 0.8)), 0.5)
  # todas NA -> NA (não é 0)
  expect_true(is.na(ivet_agregar(c(NA_real_, NA_real_))))
  # pesos ignoram a ausente
  expect_equal(ivet_agregar(c(1, NA, 0), pesos = c(1, 5, 3)), 0.25)
})

test_that("ivet_v1: sem as dimensões territoriais mínimas, o agregado é NA — §4.3", {
  res <- ivet_v1(c(escola = 0.7, socioeconomico = 0.4))

  expect_equal(res$formula, "ivet-v1.2")
  expect_true(is.na(res$ivet))                    # não publicado
  expect_false(res$publicavel)
  expect_equal(res$bloco_escola, 0.7)             # bloco escola é publicado
  expect_setequal(res$territoriais_faltando, c("mobilidade", "saude", "seguranca"))
  expect_setequal(res$dimensoes_disponiveis, c("escola", "socioeconomico"))
})

test_that("ivet_v1: com C/D/E presentes, publica a média das disponíveis", {
  res <- ivet_v1(c(escola = 0.6, socioeconomico = 0.4, mobilidade = 0.2,
                   saude = 0.8, seguranca = 0.5, recursos = NA))

  expect_true(res$publicavel)
  expect_equal(res$ivet, mean(c(0.6, 0.4, 0.2, 0.8, 0.5)))  # recursos (NA) fora
  expect_length(res$territoriais_faltando, 0)
  expect_equal(res$bloco_escola, 0.6)
})

test_that("ivet_v1 exige blocos nomeados", {
  expect_error(ivet_v1(c(0.1, 0.2)), "nomeado")
})

test_that("ivet_dataset_version lê a chave de conteúdo do lockfile (#135)", {
  tmp <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"abc123","version":1,"tables":[]}', tmp)

  expect_equal(ivet_dataset_version(tmp), "abc123")

  # lockfile sem dataset_version
  tmp2 <- tempfile(fileext = ".json")
  writeLines('{"version":1,"tables":[]}', tmp2)
  expect_error(ivet_dataset_version(tmp2), "dataset_version")

  # caminho inexistente
  expect_error(ivet_dataset_version(tempfile()), "não encontrado")
})

test_that("ivet_v1 propaga dataset_version lido do lockfile", {
  tmp <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"deadbeef","transform_version":"cafe","version":2}', tmp)

  res <- ivet_v1(c(escola = 0.5), lock_path = tmp)
  expect_equal(res$dataset_version, "deadbeef")
  expect_equal(res$transform_version, "cafe")
})

test_that("ivet_v1: bloco escola ausente vira NA, não erro", {
  res <- ivet_v1(c(mobilidade = 0.5, saude = 0.5, seguranca = 0.5))
  expect_true(is.na(res$bloco_escola))
  expect_true(res$publicavel)
  expect_equal(res$ivet, 0.5)
})

test_that("ivet_transform_version lê a chave da transformação do lockfile (#137)", {
  tmp <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"abc","transform_version":"tr123","version":2}', tmp)
  expect_equal(ivet_transform_version(tmp), "tr123")

  tmp2 <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"abc","version":2}', tmp2)
  expect_error(ivet_transform_version(tmp2), "transform_version")

  expect_error(ivet_transform_version(tempfile()), "não encontrado")
})

test_that("ivet_vigencia: resultado que confere com o lockfile está vigente", {
  tmp <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"d1","transform_version":"t1","version":2}', tmp)

  res <- ivet_v1(c(escola = 0.5), lock_path = tmp)
  v <- ivet_vigencia(res, tmp)

  expect_true(v$vigente)
  expect_length(v$motivos, 0)
  expect_equal(v$dataset_version, "d1")
  expect_equal(v$transform_version, "t1")
  expect_equal(v$formula, ivet_versao())
})

test_that("ivet_vigencia: dado ou transformação que mudou -> não vigente (retreino)", {
  tmp <- tempfile(fileext = ".json")
  writeLines('{"dataset_version":"d1","transform_version":"t1","version":2}', tmp)

  res <- ivet_v1(c(escola = 0.5), dataset_version = "VELHO", transform_version = "t1")
  v <- ivet_vigencia(res, tmp)
  expect_false(v$vigente)
  expect_match(paste(v$motivos, collapse = "; "), "dataset_version")

  res2 <- ivet_v1(c(escola = 0.5), dataset_version = "d1", transform_version = "VELHO")
  v2 <- ivet_vigencia(res2, tmp)
  expect_false(v2$vigente)
  expect_match(paste(v2$motivos, collapse = "; "), "transform_version")

  res3 <- ivet_v1(c(escola = 0.5))
  v3 <- ivet_vigencia(res3, tmp)
  expect_false(v3$vigente)
  expect_match(paste(v3$motivos, collapse = "; "), "sem dataset_version")
  expect_match(paste(v3$motivos, collapse = "; "), "sem transform_version")
})
