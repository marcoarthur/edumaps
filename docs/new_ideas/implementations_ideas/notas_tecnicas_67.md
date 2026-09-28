# Nota técnica 67 — CI Fase 2/3: frontend em GitHub Actions e a decisão Cloudflare

**Data**: 2026-09-28
**Escopo**: issue #1 (GH Actions) — Fases 2 e 3
**PRs**: #103 (`ci/frontend-tests`, mergeado em `80bd7e1`)
**Deploy**: `rex prepare` + `deploy_frontend_dev` (nginx reiniciado, exit 0)

## Fase 2 — frontend no CI

Workflow `.github/workflows/frontend-tests.yml`: `actions/setup-node@v4`
(node 22 + cache npm) → `npm ci --no-audit --no-fund` → `npx vitest run`.
Os testes da SPA são auto-suficientes: os mocks de API vêm do MSW
(`src/mocks/server.js`), sem banco e sem serviços externos — o job não
depende do backend.

### Fato duro: falso negativo do vitest

Na primeira rodada local (mesmo ambiente do CI, `node:22-slim`), todos os
337 testes passavam mas o processo **saía com exit 1**. Causa: o
`@carbon/charts` aplica zoom/pan lendo `el.transform.baseVal.consolidate()`
(`color-scale-utils` minificado); o jsdom **não implementa
`SVGElement.transform`** (`SVGAnimatedTransformList`), o acesso a `baseVal`
estourava a cada frame de animação e o vitest registra 1 *unhandled error*
mesmo sem teste falhar.

Correção: polyfill em `src/vitest-setup.js` — `Object.defineProperty(
SVGElement.prototype, "transform", ...)` devolvendo `baseVal.consolidate()`
→ `null` (matriz identidade). Resultado: exit 0, 62 arquivos / 337 testes,
**workflow verde no primeiro run do PR #103**.

> Lição: um *unhandled error* do jsdom num frame de animação vira falha de
> CI sem nenhum teste ter falhado — sempre conferir o exit code do `vitest
> run`, não só o contador de testes.

## Fase 3 — decisão sobre o check "Workers Builds: edumaps"

O app GitHub "Cloudflare Workers and Pages" está instalado no repo e o check
**falha em todo PR** (build id existe na dashboard, sem detalhe no output).

| Fato | Verificação |
|---|---|
| Existe configuração/trabalho de worker no repo? | **Não** — sem `wrangler.toml`, sem `workers/`, sem `_worker.js` em todo o histórico |
| O service `edumaps` na Cloudflare é usado? | Órfão — nada no repo o constrói (conta `07f55e66…`) |
| O check é required? | **Não** — nunca bloqueou merge (#60, #100–103 mergearam) |
| Dá para remover a integração via `gh`? | **Não** — `GET /repos/{owner}/{repo}/installation` exige JWT do app (401 com token de usuário); é ação de UI do admin |

**Decisão: desconectar.** O build é órfão e o vermelho permanente polui a
lista de checks, fazendo sombra aos checks reais agora verdes (backend e
frontend). Ação de UI (Settings → Integrations → GitHub Apps → Cloudflare
Workers and Pages → remover do repositório) — sem código, sem PR, sem deploy.

Alternativas descartadas:

- **`wrangler.toml` falso para passar o check** — validaria um CI fictício
  (pior que o ruído). Se um dia o projeto tiver um worker de verdade, a
  integração volta com configuração real.
- **Manter como está** — ruído permanente e desnecessário com CI real ativo.

## Estado final do CI (issue #1)

| Workflow | O que valida | Status |
|---|---|---|
| `backend-tests` | banco de fixtures (imagem + espelho + 64 migrations) + suíte Perl (`prove -r -l t/`, 71 arquivos / 302 testes / 17 skips) | 🟢 |
| `frontend-tests` | `npm ci` + `npx vitest run` (62 arquivos / 337 testes) | 🟢 |
| "Workers Builds: edumaps" (app CF) | nada de real (órfão) | 🔴 → **remover** |