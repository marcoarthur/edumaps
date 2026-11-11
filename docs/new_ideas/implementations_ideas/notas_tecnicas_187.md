# Nota técnica 187: dependências do edumapsr derivadas do DESCRIPTION

PR #364 (2026-11-10), fecha a #363.

## O que se descobriu

Ao validar o PR #362 na imagem `analytic` (R 4.4.1), a suíte não rodou: o
`testthat` não estava instalado. As dependências R eram listas mantidas à
mão em três lugares, e as três divergiam do `DESCRIPTION`:

| ambiente | faltava |
|---|---|
| imagem `analytic` (Dockerfile) | testthat, pkgload, devtools |
| LXC (`deploy_analytics_dev`) | testthat, pkgload, devtools (excluído de propósito) |
| CI `analytics-tests` | devtools |
| host `ubaxala` | plumber (por isso 10 testes eram pulados) |

## O que mudou

- **`inst/scripts/dependencias.R`** lê Depends, Imports e Suggests do
  `DESCRIPTION` e tem dois modos: `instalar` (do CRAN, só o que falta; os
  pacotes de `Remotes:` ficam com o passo próprio, em commit fixo) e
  `verificar` (sai com 1 e mostra o erro de carga de cada pacote).
- **A verificação carrega cada pacote num processo R novo.** Na primeira
  versão, feita na mesma sessão da instalação, o `devtools` recém-instalado
  aparecia como faltando sem mostrar o motivo. No processo novo o erro
  apareceu: o binário do `fs` exige a biblioteca de sistema `libuv1`.
- **`pkgload`** entrou em Suggests: o `testthat::test_local` depende dele.
- **Imagem `analytic`**: instala pelo script e o build **falha** se faltar
  algo. Ganhou as bibliotecas de sistema do devtools e dependências (libgit2,
  harfbuzz, fribidi, freetype, fontconfig, png, jpeg, tiff, libuv).
- **Rexfile** (`deploy_analytics_dev`): mesmas bibliotecas de sistema,
  instalação pelo script e `die` se a verificação falhar. Ficam à mão só as
  dependências do eduBR (dbplyr, parsnip, broom, remotes), que não estão no
  `DESCRIPTION`.
- **CI**: `devtools` nos pacotes extras e um passo `verificar` antes da suíte.
- **AGENTS.md**: regra de que toda dependência do `DESCRIPTION` fica
  instalada em todo ambiente.

## Validação

- Build da imagem: `OK: 16 dependências do DESCRIPTION instaladas`.
- Suíte dentro da imagem (R 4.4.1): **341 testes, 0 falhas, 0 pulados**.
- Contêiner `analytic` recriado: `/health` 200, `ivet_versao()` = `ivet-v1.3`
  (o #362 já está na imagem).
- `perl -c` do Rexfile OK. O deploy no LXC fica para 2026-11-12.

## Pendente

- **Host**: o `plumber` não instala porque falta a `libsodium-dev`, que exige
  `sudo` (`sudo apt-get install libsodium-dev`, depois
  `Rscript inst/scripts/dependencias.R instalar DESCRIPTION https://cloud.r-project.org`).
- **LXC**: o primeiro `deploy_analytics_dev` compila o devtools e dependências
  do código-fonte (o CRAN não tem binários para Linux); deve levar alguns
  minutos a mais.
