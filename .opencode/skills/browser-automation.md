# Skill: browser-automation

## Purpose
Automação de browser via Chrome DevTools Protocol (CDP) direto — testes e2e
**visíveis** (sem headless) e navegação controlada. Use quando precisar clicar,
preencher, tirar screenshot ou validar um fluxo em um Chrome real — em especial
os **e2e da SPA EduMaps** (cobertura em `docs/e2e/cobertura.md`).

## Testes e2e do EduMaps (resumo)

- App: `http://ubatexu.lan:8080` (SPA Svelte 5; rotas em
  `frontend/edumaps/src/app/routes.js`).
- Executar contra **todas as features** da SPA, exceto páginas unicamente de
  documentação ou solo-backend. Registrar PASS/FAIL em `docs/e2e/cobertura.md`.
- Runbook completo (setup Chrome, fluxo, nuances): `docs/e2e/README.md`.

## Como funciona

- Chrome/Chromium precisa rodar com debug remoto: `--remote-debugging-port=9222`.
- Conexão explícita em `browser_url` (não há browser singleton oculto).
- Usa os UIDs de `browser_snapshot` para `browser_click`/`browser_fill`.
- Confirma cada ação com um novo `browser_snapshot` ou `browser_eval`.

## Fluxo recomendado

1. Inspecionar alvos com `browser_list({ browser_url })`.
2. Escolher um `target_id`, ou omitir para usar a primeira aba.
3. Navegar com `browser_navigate` se necessário.
4. Descrever candidatos com `browser_snapshot`.
5. Clicar/preencher usando um UID do snapshot mais recente.
6. Confirmar com `browser_snapshot` ou `browser_eval`.

### Nuances na SPA Svelte 5 (EduMaps)

- O `browser_snapshot` tende a vir **vazio** (`RootWebArea` só) — preferir
  `browser_eval` para ler `document.querySelector('main,#app').innerText` e
  para interagir.
- Preencher input Svelte runes exige **setter nativo** (o `el.value = x` +
  `input` simples não é capturado):
  ```js
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
  setter.call(input, 'Ubatuba');
  input.dispatchEvent(new Event('input', {bubbles:true}));
  ```
- Após a ação, aguarde (SPA+API) e re-avalie até o estado esperado.

`browser_url` padrão: `http://127.0.0.1:9222` (ou env `OPENCODE_BROWSER_URL`).

## Debug via CLI (fora do opencode)

```bash
npx opencode-chrome-devtools tools
npx opencode-chrome-devtools tool browser_list --args '{"browser_url":"http://127.0.0.1:9222"}'
npx opencode-chrome-devtools tool browser_snapshot --args '{"browser_url":"http://127.0.0.1:9222"}'
OPENCODE_BROWSER_URL=http://127.0.0.1:9222 npx opencode-chrome-devtools status
```

## Ferramentas disponíveis

- `browser_list`, `browser_navigate`, `browser_snapshot`
- `browser_click`, `browser_fill`, `browser_eval`, `browser_screenshot`

## Solução de problemas

- Se `browser_list` falhar, confirme que o Chrome foi iniciado com
  `--remote-debugging-port` e que `http://127.0.0.1:9222/json/list` responde.
- Se `browser_click`/`browser_fill` não acharem um UID, refaça o snapshot.
- Use `browser_eval` para checagens que não aparecem na árvore de acessibilidade.
- Confirme o resultado depois de cada ação.