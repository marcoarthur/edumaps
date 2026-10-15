# testes do núcleo reprodutível do IVET v1.0 (R/ivet.R)

test_that("ivet_versao carimba a versão da fórmula", {
  expect_equal(ivet_versao(), "ivet-v1.0")
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

  expect_equal(res$formula, "ivet-v1.0")
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
  writeLines('{"dataset_version":"deadbeef","version":1,"tables":[]}', tmp)

  res <- ivet_v1(c(escola = 0.5), lock_path = tmp)
  expect_equal(res$dataset_version, "deadbeef")
})

test_that("ivet_v1: bloco escola ausente vira NA, não erro", {
  res <- ivet_v1(c(mobilidade = 0.5, saude = 0.5, seguranca = 0.5))
  expect_true(is.na(res$bloco_escola))
  expect_true(res$publicavel)
  expect_equal(res$ivet, 0.5)
})
