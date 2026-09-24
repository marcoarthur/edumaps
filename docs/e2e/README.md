# Testes E2E via browser (CDP, sem headless)

Runbook dos testes e2e do EduMaps rodados **num browser real e visível** via
Chrome DevTools Protocol (plugin `opencode-chrome-devtools`). Cobrem a SPA
(`http://ubatexu.lan:8080`) e suas features — **exceto páginas unicamente de
documentação ou solo-backend**.

## Setup (uma vez por sessão)

```bash
# Chrome/Chromium com debug remoto numa porta liberada e profile dedicado.
# O Chrome moderno (>=136) IGNORA --remote-debugging-port no profile padrão:
# use sempre --user-data-dir próprio.
setsid nohup /opt/google/chrome/chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/edumaps-cdp \
  --no-first-run --no-default-browser-check \
  --ozone-platform=x11 about:blank >/tmp/edumaps-cdp.log 2>&1 < /dev/null &
```

Validar o endpoint:

```bash
curl -s http://127.0.0.1:9222/json/version   # espera JSON com webSocketDebuggerUrl
```

Quando o Chrome abre, o navegador real está VISÍVEL na tela — qualquer
interação/erro pode ser observado ao vivo.

## Ferramentas (plugin `opencode-chrome-devtools`)

| Tool | Uso |
|------|-----|
| `browser_list` | lista abas/targets; pegue o `target_id` |
| `browser_navigate` | navega para uma URL |
| `browser_snapshot` | árvore de acessibilidade com `[uid]` |
| `browser_click` / `browser_fill` | clicar/preencher por `uid` do snapshot |
| `browser_eval` | executa JS na página (asserts mais profundos) |
| `browser_screenshot` | PNG da tela (salvo em `/tmp/user/1000/`) |

`browser_url` padrão: `http://127.0.0.1:9222`.

## Fluxo padrão

1. `browser_navigate` para **`http://ubatexu.lan:8080/<rota>`**.
2. `sleep 2–4` (SPA hidrata; chamadas de API podem demorar).
3. Assert de conteúdo inicial via `browser_eval`
   (`document.querySelector('main,#app').innerText`).
4. Interagir (preencher/click) e confirmar resultado com novo eval/screenshot.
5. Registrar `PASS/FAIL` no arquivo de cobertura (`docs/e2e/cobertura.md`).

## Nuances críticas (aprendidas em campo)

- **O snapshot de acessibilidade costuma vir vazio** (`RootWebArea` só) nesta
  stack (SPA Svelte 5 sobre X11). Para preencher/ler, use `browser_eval` com
  o **setter nativo** — Svelte runes não captura `el.value = ...` simples +
  `input`; use `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,
  'value').set.call(el, valor)` e dispare `input` (bubbles). Ex.:
  ```js
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
  setter.call(input, 'Ubatuba');
  input.dispatchEvent(new Event('input', {bubbles:true}));
  ```
- Depois de preencher, clique no botão da ação (ex.: "Buscar Escolas") e aguarde
  o estado de carregando → resultado ("Buscando…" some, cards aparecem).
- Rotas de gestor forçam `GestorLoginCard` em 401 — para e2e com sessão, o
  login depende de credenciais reais do container; senão, testar o card de
  login e os fluxos públicos das mesmas páginas.
- `curl` no container exige `-H "Host: ubatexu.lan"`; no `browser_navigate`
  use a URL completa com porta (`http://ubatexu.lan:8080`).

## Onde manter os registros

- Runbook: **este arquivo** (`docs/e2e/README.md`).
- Cobertura por rota: `docs/e2e/cobertura.md` (tabela com PASS/FAIL por visita).
- Skill do agente: `.opencode/skills/browser-automation.md` (fluxo genérico).