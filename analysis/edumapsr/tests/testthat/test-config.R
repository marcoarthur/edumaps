# Testes de chat_config(): defaults de env + override do Painel de Configuração.
# Garantem que o override (api_key/provider/model/url) sobrepõe a env e que o
# engine derivado acompanha o provider efetivo.

withr_loc <- new.env(parent = emptyenv())

local_env <- function(...) {
  vals <- list(...)
  old <- lapply(names(vals), function(n) Sys.getenv(n, unset = NA))
  names(old) <- names(vals)
  withr_loc$old <- old
  do.call(Sys.setenv, vals)
  reg.finalizer(withr_loc, function(e) {
    for (n in names(withr_loc$old)) {
      if (is.na(withr_loc$old[[n]])) Sys.unsetenv(n)
      else do.call(Sys.setenv, stats::setNames(list(withr_loc$old[[n]]), n))
    }
  }, onexit = TRUE)
}

test_that("chat_config usa defaults de env", {
  local_env(
    EDUMAPS_LLM_PROVIDER = "ollama",
    EDUMAPS_LLM_MODEL = "qwen2.5:3b",
    EDUMAPS_LLM_URL = "http://localhost:11434",
    EDUMAPS_LLM_API_KEY = ""
  )
  Sys.unsetenv("EDUMAPS_CHAT_ENGINE")
  cfg <- edumapsAnalytics:::chat_config()
  expect_equal(cfg$provider, "ollama")
  expect_equal(cfg$model, "qwen2.5:3b")
  expect_equal(cfg$engine, "tool")
  expect_equal(cfg$url, "http://localhost:11434")
  expect_equal(cfg$api_key, "")
})

test_that("chat_config override sobrepõe campos e recalcula o engine (groq)", {
  cfg <- edumapsAnalytics:::chat_config(list(
    api_key = "gsk_abc",
    provider = "groq",
    model = "openai/gpt-oss-120b"
  ))
  expect_equal(cfg$provider, "groq")
  expect_equal(cfg$api_key, "gsk_abc")
  expect_equal(cfg$model, "openai/gpt-oss-120b")
  # engine derivado segue o provider efetivo (single para groq, free TPM)
  expect_equal(cfg$engine, "single")
})

test_that("chat_config override não apaga campos não informados", {
  cfg <- edumapsAnalytics:::chat_config(list(api_key = "sk-teste"))
  expect_equal(cfg$provider, "ollama")
  expect_equal(cfg$model, "qwen2.5:3b")
  expect_equal(cfg$api_key, "sk-teste")
})

test_that("chat_config ignore override vazio/null", {
  base <- edumapsAnalytics:::chat_config()
  cfg <- edumapsAnalytics:::chat_config(list(api_key = "", provider = NULL))
  expect_equal(cfg$api_key, base$api_key)
  expect_equal(cfg$provider, base$provider)
  expect_identical(cfg, base)
})