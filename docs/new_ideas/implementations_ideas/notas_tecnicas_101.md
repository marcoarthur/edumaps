# Nota técnica 101 — CI backend blindado contra 429/504 do Docker Hub (PR #202)

## Resumo

O `backend-tests` (workflow `.github/workflows/backend-tests.yml`) passou a falhar
no passo "sobe o banco de CI": a construção de `edumaps-db:ci` (`db/Dockerfile`)
morria na resolução da base `pgvector/pgvector:pg16-bookworm`, recusada pelo
Docker Hub — **429 Too Many Requests** (rate limit anónimo por IP nos IPs
partilhados dos runners do GitHub) e **504 Gateway Timeout** em
`auth.docker.io/token` (auth instável). Medido por ~40 min: o throttle era
**sustentado**, não uma rajada — retry simples não resolve. Não era (e não é)
bug de código da aplicação: nenhum teste do backend chegava a rodar.

Entrega: 3 commits na branch `fix/ci-retry-build-429` → **PR #202** (merge
`6cd5097`), sem credencial, em três camadas complementares.

## Causa raiz (medida, não deduzida)

- Runs 37992118533 (push), 37993517730/37994673009/37994965426 (PR): o
  `docker build` falhava com `unexpected status from HEAD request …
  429 Too Many Requests` na resolução do manifest, e em dois runs com
  `POST https://auth.docker.io/token: 504 Gateway Timeout`.
- O 429 do Docker Hub é por **IP** (pull anónimo, ~100/6h); os runners
  `ubuntu-latest` do GitHub são **compartilhados**, então o egress de cada job
  pode chegar já estourado por outros jobs do mesmo range de IPs. O 504 era o
  serviço de auth do próprio Docker Hub instável. As duas coisas juntas
  derrubam o build mesmo com retry de ~2 min.

## Solução (3 camadas em `db/fixtures/ci_db.sh` + workflow)

1. **Retry com backoff** — `imagem()` repete o `docker build` (3 tentativas por
   fonte, espera 10s→20s). Cobre rajadas; o build é idempotente.
2. **Fallback para `mirror.gcr.io`** — espelho público do Google do Docker Hub,
   sem os limites anónimos por IP. Se o Docker Hub esgotar, o script puxa
   `mirror.gcr.io/pgvector/pgvector:pg16-bookworm`, taggeia com o nome canónico
   e o BuildKit resolve o `FROM` localmente (sem nova consulta ao registry).
3. **Cache da imagem no GitHub Actions** — `actions/cache` com key
   `edumaps-db-ci-${{ hashFiles('db/Dockerfile') }}`; o script carrega o tarball
   (`docker load`) via `EDUMAPS_CI_IMAGE_TARBALL_IN` e, quando construiu, grava
   o tarball (`docker save | gzip`) via `EDUMAPS_CI_IMAGE_TARBALL_OUT`.
   Em cache quente o CI **não toca no registry**; só reconstrói quando o
   Dockerfile muda. Variáveis só existem no CI — o uso local (`ci_db.sh up`)
   fica inalterado.

Opcional (por completo, sem depender do estado do Docker Hub): secrets
`DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` ativam o passo `docker/login-action`
(v3) já presente no workflow — sem secret o passo é pulado.

## Aprendizado de workflow (custou um run vermelho)

`secrets` **não** está na lista de contextos permitidos em
`jobs.<job_id>.steps.if` (a tabela de disponibilidade de contextos do GitHub
só permite `github, needs, strategy, matrix, job, runner, env, vars, steps,
inputs` para `if`). `if: ${{ secrets.DOCKERHUB_TOKEN != '' }}` invalida o
workflow inteiro — o run morre antes de começar ("This run likely failed
because of a workflow file issue"). O padrão correto é repassar o secret por
`env:` do step e condicionar no `env`:

```yaml
- name: login no Docker Hub (opcional)
  if: env.DOCKERHUB_TOKEN != '' && env.DOCKERHUB_USERNAME != ''
  env:
    DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
    DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
  uses: docker/login-action@v3
```

## Validação

- Harnesses locais sobre a função `imagem()` real (extraída do script):
  retry 2× 429 + sucesso; Docker Hub esgotado → espelho resolve; ambos
  esgotados → exit 1 com mensagem; early-return com imagem presente (4/4).
- Harness do cache com docker real (imagem `edumaps-db:ci` do host): load do
  tarball sem build e sem re-escrita do cache; save com gzip válido e
  re-carregável (6/6).
- CI do PR: **verde em 7m24s** — build na 1ª tentativa (o Docker Hub já tinha
  recuperado para aquele IP), sqitch deploy das 60+ migrations, gate `verify`,
  compilação dos módulos e suíte completa.
- Cache populado no 1º run verde: `edumaps-db-ci-abc685f5…` (231 MiB) — as
  próximas execuções com o mesmo Dockerfile restauram a imagem sem registry.

## Ressalvas

- **Escopo do cache por evento (aprendido na prática)**: um cache criado por um
  run de `pull_request` fica no merge ref (`refs/pull/N/merge`) e **não** é
  visível aos pushes de `main` — regra documentada do `actions/cache`
  ("limited scope… cannot be restored by the base branch"). O 1º push de main
  pós-merge reconstrói de frio (o retry + espelho cobrem o caso de o Docker Hub
  estar instável) e re-grava o cache no escopo de main; dali em diante main e
  PRs restauram. Provado por rerun de main: log `carregando edumaps-db:ci de
  …/edumaps-db-ci.tar.gz`, sem build e sem tocar no registry.

- **Mudança em `db/Dockerfile`** muda a key do cache (o hash vira parte dela),
  e a construção volta a depender do registry — nesse cenário volta a valer o
  retry + espelho. Se o developer quiser eliminar a dependência de vez: criar
  os secrets do Docker Hub (detalhes no cabeçalho do workflow).