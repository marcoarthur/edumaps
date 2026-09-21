# Nota técnica — Fix: download do SIOPE + monitor de job que falha

> Data: 2026-09-21 · Ciclo: backend (Mojolicious/Minion) + frontend (Svelte 5)

## 1. Contexto

Após o fix do código do município (PR #87), o teste manual continuou falhando
para Caçapava, Taubaté e outros anos. Os logs do Minion mostravam:

```
Cannot open /tmp/<mun>_<ano>.xlsx.Planilha.csv file: No such file or directory
  at EduMaps/Task/Siope/Scrap/SpreadSheet/Gastos.pm line 282.
```

E, no frontend, o job já `failed` mas a UI permanecia em "Enfileirando… (0%)".

## 2. Bug 1 — content-type do FNDE (`Gastos.pm`)

A verificação era `$content =~ /excel/i`. O FNDE responde:

```
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
```

A palavra "excel" **não aparece** nesse MIME → a requisição era tratada como
erro, o xlsx não era salvo e o `xlsx2csv_fast` falhava.

**Fix**: aceitar também `spreadsheetml`/`officedocument` (e `octet-stream`
como tolerância):

```perl
unless ($content =~ m{excel|spreadsheetml|officedocument|octet-stream}i) { ... }
```

*(A verba "município" do PR #87 continua correta — o INEP não começa com o
código do município. O download é que estava quebrado.)*

## 3. Bug 2 — monitor de job em `failed` (`Plugin::Helpers`)

`_monitor_minion_job`:
- abortava só em `state eq 'finished'` (linha de guarda);
- no loop, só chamava `$c->finish` em `finished`.

Em `failed`, o stream SSE **nunca era encerrado** → o `EventSource` ficava
aberto e o frontend não saía do estado inicial.

**Fix**:
- guarda e encerramento consideram **`finished` e `failed`**;
- o evento de progresso **não** é emitido no estado terminal (evita 100% falso);
- `on_finish` recebe `result`; em `failed` o job tem `error` (não `result`),
  então sintetizamos `{ error => ... }` para o callback.

## 4. Frontend (`watchJobProgress`)

- Ao fechar o stream (`onerror`), lê o snapshot `GET /api/task/progress?job_id=`
  e decide `onDone`/`onError` (`state === 'failed'`).
- Guarda `encerrado` evita `onerror` duplicado. Assim a UI sai de
  "Enfileirando…" e mostra o erro real.

## 5. Validação

| Caso | Resultado |
|------|-----------|
| Scraper real Caçapava `350850/2026` | **5152 linhas** |
| Scraper real Taubaté `355410/2026` | **17753 linhas** |
| SSE de job `failed` | encerra de imediato (antes: pendurado) |
| `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t t/01-app/helpers.t` | **70 ok** |
| `SchoolFinancePage.test.js` | 4 ok |

`t/05-tasks/siope.t` subtest 2 (SSE) **já falhava no HEAD** (job rápido termina
antes do SSE conectar; sem worker local) — verificado com `git stash`, não é
regressão. O subteste 1 (download real) passa.

Deploy: `deploy_backend_dev` + `deploy_frontend_dev` → **PR #88** (merge `efd3961`).

## 6. Lições

- **Content-type de planilha xlsx não contém "excel"** — o MIME oficial é
  `...officedocument.spreadsheetml.sheet`. Validar por essa família, não por
  "excel".
- **Monitores devem cobrir todos os estados terminais** (`finished` **e**
  `failed`), senão streams/consumidores ficam pendurados justamente no caminho
  de erro.
- O padrão do frontend (SSE + snapshot final) é robusto porque o SSE não emite
  erro; manter esse snapshot ao mexer no monitor.
- Teste pré-existente falhando: sempre confirmar com `git stash` antes de
  atribuir a regressão ao próprio diff.
