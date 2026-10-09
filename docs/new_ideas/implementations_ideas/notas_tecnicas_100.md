# Nota técnica 100 — Rejeições de promise do Radar do Carbon (#200)

## Resumo

A `/municipio/compare?codigo_ibge=…` registrava **4 rejeições de promise não
tratadas** no console por execução (`Uncaught (in promise) "Infantil"`), sem
stack, sem impacto visual. Rastreada na issue #200 e resolvida neste ciclo no
wrapper `RadarChart.svelte` (boundary app — o defeito vive no `@carbon/charts`
1.22.18, em `node_modules`).

- Causa raiz medida por CDP (`Debugger.setPauseOnExceptions` + source maps +
  `evaluateOnCallFrame` nos locals da pausa), não por inspeção de código.
- Entrega: 1 commit, branch `fix/frontend-radar-rejeicoes-200` → **PR #201**
  (merge `9c26dcc`), + testes unitários do guarda (3 novos).

## Causa raiz (como foi descoberta)

1. **`Debugger.paused` (reason `promiseRejection`)** deu 5 frames — todas
   dentro de d3 (dispatch/timer/transition) do bundle do Carbon, sem frame da
   app. `Runtime.exceptionThrown` vinha **sem stackTrace**.
2. **`Debugger.setAsyncCallStackDepth(64)`** destravou a cadeia async: Svelte
   `$effect` → Carbon `update()` → `render` → `transition` → rAF → dispatch.
3. **`evaluateOnCallFrame`** no frame da pausa revelou o essencial: o dispatch
   era `call("interrupt", that, "Infantil", 0, [SVGText…])` — os *argumentos*
   eram o rótulo de etapa; e os listeners do tipo `interrupt` eram o cleanup do
   serviço de transições do Carbon + 2 funções `[native code]` (bound).
4. **Inspeção do bundle** fechou o ciclo: o componente **Radar** do Carbon
   anima os rótulos do eixo X com
   `transition(...).end().finally(...)` (`radar_x_labels_update`). `.end()`
   devolve uma promise que **rejeita com o datum do elemento** (uma string: o
   rótulo) quando a transição é interrompida; o `.finally()` do Carbon **não
   trata** a rejeição. (O `update()` geral do Carbon usa `.end().catch(err =>
   err)` — tratado; o do radar é o único sem catch.)

O estímulo das interrupções era o próprio wrapper app: `syncSize`
(ResizeObserver) e o `$effect` re-atribuíam `chartOptions` com conteúdo
idêntico → o wrapper Svelte do Carbon chamava `update()` → re-render →
interrupção das transições em curso.

## Decisões de design

- **Corrigir no wrapper, não no Carbon.** O `@carbon/charts` não é nosso; o
  boundary app é `RadarChart.svelte`. Upgrade da lib foi descartado (risco alto
  para bug de console, prioridade baixa).
- **Duas camadas complementares:**
  1. **Sem churn** — `syncSize` só aplica quando `dims` mudam de facto
     (primeira medição sempre aplica) e o ResizeObserver é coalescido em
     `requestAnimationFrame`; `chartOptions` só é re-atribuído quando o
     **conteúdo** muda (snapshot não-reativo `lastChart` + `sameOptions`). Isto
     mata a interrupção no mount (o repro do issue).
  2. **Guarda de `unhandledrejection`** — enquanto o radar está montado,
     `preventDefault()` apenas quando `typeof event.reason === "string"` (o
     datum do eixo). Erros reais (`Error`/objeto) propagam. Cobre a troca de
     modo do radar, interrupção **legítima** que continuaria a rejeitar.
- **String como reason é anomalia.** Todo `throw`/`reject` da app usa
  `Error`/`DOMException` (verificado por grep em `src/`); a guarda não esconde
  erros de verdade. Suprimidas ficam visíveis em `console.debug`.
- **Sem `docs/funcionalidades/`** — nenhuma capacidade muda (comportamento
  visual idêntico, higiene de console).

## Validação

- Unit: `charts.test.js` **9/9** (3 novos: suprime string, propaga Error,
  remove listener no unmount); `network-compare` + `shared/ui` **41/41**.
- `vite build` OK.
- E2E CDP (dev server e depois o build de produção após deploy):
  **0 rejeições no load** (eram 4× "Infantil"), **0 após troca de modo**,
  radar renderiza (246 paths SVG), toggle Perfil → Volume funciona.
- Deploy: `rex prepare` + `rex -H backend.edumaps deploy_frontend_dev` +
  imagem local `frontend` reconstruída.