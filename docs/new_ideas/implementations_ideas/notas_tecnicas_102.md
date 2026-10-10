# Nota técnica 102 — Busca Escola: toast espúrio "Nenhuma escola encontrada." na carga (PR #203)

## Resumo

O developer reportou que a busca de escolas ("Busca Escola") "não retorna
(vazia)" usando a imagem docker em `localhost:8080`. O smoke e2e (browser real
via CDP, drivers próprios sobre o Chrome `:9222`) mostrou que **a busca
funcionava**: por nome e por município, `/api/school/search/pageable` respondia
200 e os cards renderizavam. O sintoma era um **toast espúrio** "Nenhuma escola
encontrada." exibido **logo na carga** de `/escola/search`, antes de qualquer
busca — o que dá a impressão de que a página/busca está vazia.

Entrega: 1 commit na branch `fix/frontend-busca-toast-vazio` → **PR #203**
(merge `2f4e43d`), CI `vitest` verde.

## Causa raiz (medida no browser, confirmada no código)

O fluxo RX da busca monta um ciclo loading→pronto **na montagem da página**:

1. `createPaginationStore` (`shared/stores/paginationStore.js`) emite na
   assinatura: `startWith({ loading: true })` → `switchMap` → adaptador de
   `schoolPaginationStore.js`. Sem filtro válido (menos de 3 caracteres), o
   adaptador **nem chama a API** — devolve `of({ data: [], meta:
   { total_entries: 0 } })` (L27–33).
2. A página (`SchoolSearchPageRx.svelte`) detecta a transição
   loading→não-loading (`wasLoading`) e chama `notifySearchOutcome(state)`;
   com `total_entries === 0` ela emitia o toast `Nenhuma escola encontrada.`
   — **mesmo sem o usuário ter buscado nada**.

O toast legítimo de busca vazia real continuava correto (ex.: "E.M." — escola
com esse prefixo ausente da base local; retorna `[]` de forma consistente entre
curl, browser e deploy, com `tp_situacao_funcionamento = 1` filtrando inativas).

## Fix (decisão de design)

Guard de uma linha no topo de `notifySearchOutcome`
(`frontend/edumaps/src/features/schools/pages/SchoolSearchPageRx.svelte`):

```js
if (!hasSearched) return;
```

Escolha do **ponto de corte**: no componente (não no store, que é genérico e
compartilhável). O store corretamente emite o ciclo de montagem; é a página que
decide o que vira toast. `hasSearched` já existia na página (setado em
`handleSearch`/`handleClear`) — o guard apenas alinha o toast com o estado real
de "o usuário buscou". Efeitos:

- **Montagem**: silenciado (era o bug).
- **Limpar**: silenciado (também espúrio antes).
- **Busca real com 0 resultados**: continha o toast legítimo (usuário buscou).
- **Busca real com resultados e erro de API**: toasts preservados.

## Validação

- **Unitário**: `vitest run src/features/schools/` → **99/99** (21 arquivos).
  Teste de regressão novo — montagem sem busca → 0 toasts; **provado que falha
  sem o guard** (`to have length of +0 but got 1`).
- **E2E (browser real, CDP)**, imagem local `frontend` reconstruída
  (`localhost:8080`) **e** deploy (`ubatexu.lan:8080`):

  | Verificação | Resultado |
  |---|---|
  | Carga fresca de `/escola/search` | 🟢 `toasts=[]`; corpo "Informe um nome de escola ou município para começar" |
  | Busca por nome (`CENTRO EDUCACIONAL DE UBATUBA`) | 🟢 200 + toast "Busca concluída: 1 escola encontrada" |
  | Busca vazia real (`E.M.`) | 🟢 200 vazio + toast legítimo "Nenhuma escola encontrada." |
  | Deploy | 🟢 `rex prepare` + `deploy_frontend_dev`; md5 do bundle container == local (`b2263533…`) |

- **CI**: `vitest (jsdom + MSW)` verde no PR #203 (1m2s).

## Notas

- Nenhuma mudança de capacidade de negócio (a "Busca Escola" continua com o
  mesmo contrato) — sem atualização em `docs/funcionalidades/`; o registro da
  rodada foi em `docs/e2e/cobertura.md` (2026-10-10).
- Sem necessidade de `deploy_backend_dev`/novas imagens além da `frontend`
  (fix é frontend-only).