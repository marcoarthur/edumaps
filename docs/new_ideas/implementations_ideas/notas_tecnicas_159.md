# Nota técnica 159 — ajuda guiada interativa (product tour) no frontend

Ciclo da ajuda guiada: pesquisa de biblioteca, camada própria em runes e prova
de conceito no tour da busca de escolas. Um PR (**#311**, `a3011e7`), com e2e
em Chrome real contra `ubatexu.lan:8080`.

## Entregas

| Commit | Escopo |
|---|---|
| `d4b9643` | `driver.js` + `src/shared/tour/` (TourManager, botão “?”, tema) + tour `busca-escola` + `data-tour` |
| `6612d64` | ficha `plataforma/ajuda-guiada.md` + página `ajuda/comunidade/ajuda-guiada.md` |
| `7dbe268` | fix: foco não voltava ao botão “?” (achado no e2e) |
| `0849b52` | rodada e2e em `docs/e2e/cobertura.md` |

## 1. Escolha da biblioteca: maturidade > binding nativo

Levantamento no registry do npm e no GitHub (2026-11-01):

| Biblioteca | Situação | Decisão |
|---|---|---|
| `driver.js` 1.10.2 | MIT, zero deps, desde 2018, ★27k, ~9,5M downloads/mês | **adotada** |
| `svelte-tourlight` 0.1.5 | runes nativo, a11y completa — mas criada em 2026-10-24, ★0, um autor | reavaliar no futuro |
| Shepherd.js 15.3 | **AGPL-3.0** (já não é MIT) | descartada por licença |
| `@docentjs/svelte`, `@guideflow/svelte` | v0.x, ★1–2 | imaturas |
| flowbite-svelte (Tour) | 9 dependências (apexcharts, flowbite…) | peso desproporcional |

Três fatos do projeto pesaram:

- **Não é SvelteKit** (Vite + Svelte 5.56, roteador próprio de ~60 linhas). Não
  há SSR a contornar; o argumento “integra com `goto`” das libs Svelte não se
  aplica.
- O projeto **já recusou** uma dependência Svelte imatura (`svelte-routing`,
  ver comentário em `router.svelte.js`) e escreveu uma camada fina. A ajuda
  guiada segue o mesmo padrão: JS estável por baixo, runes por cima.
- A lacuna de a11y do driver.js era menor do que a documentação sugeria: lendo
  o código da 1.10, o popover já tem `role="dialog"`, `aria-labelledby`/
  `describedby`, Tab preso entre popover e elemento destacado, foco inicial e
  setas/Esc. Faltavam só `aria-modal` e a devolução do foco.

## 2. A camada `TourManager`

`src/shared/tour/tourManager.svelte.js` — classe com `$state` (`ativo`,
`passo`) e dependências injetadas (driver, roteador, storages). Os testes usam
dublês e não dependem de layout no jsdom.

- **Multi-página**: cada passo tem `rota` (herdada do anterior quando omitida).
  `onNextClick`/`onPrevClick` são sobrescritos: se o passo de destino é de outra
  rota, chama `router.navigate()` e então `drive(i)`; o `waitForElement` do
  driver.js (1.10+) espera o alvo montar. O `passo` é atualizado **antes** de
  navegar, porque a navegação dispara `aoNavegar()`, que encerra o tour se a
  rota não bate com o passo — é assim que o voltar do navegador fecha o tour
  sem deixar overlay órfão.
- **Disparo** (`aoNavegar`, chamado por um `$effect` em `App.svelte` que só
  depende de `router.path`; o resto vai em `untrack`, senão o fim do tour
  re-dispararia o efeito): `?tour=<id>` (removido da URL com `replaceState`),
  retomada da sessão, ou tour `automatico` na primeira visita.
- **Persistência**: “visto” é gravado **na abertura** (o automático aparece uma
  vez, mesmo se fechado no passo 1) e nunca rebaixa “concluido”. A chave inclui
  a versão do tour: revisou o conteúdo, sobe `versao`. Todo acesso a storage é
  `try/catch` — sem storage, o tour funciona, só não lembra.
- **Interação bloqueada no destaque** (`disableActiveInteraction`): o tour
  explica, não opera. Sem isso, clicar em “Comparar Redes” durante o passo 6
  navegaria com o tour apontando para um elemento desmontado.
- **Alvos por `data-tour`**, separados dos `data-testid`: refatorar o visual ou
  os testes não quebra a ajuda, e o catálogo de alvos fica buscável
  (`git grep data-tour`).

## 3. O bug que só o e2e achou

O botão “?” ficava `disabled` com o tour aberto. Botão desabilitado **perde o
foco**, e no `onDestroyed` o Svelte ainda não tinha reabilitado o botão no DOM
— o `focus()` de devolução caía no vazio. O teste unitário não pegava porque
usava um botão comum. Correção: sem `disabled` (o overlay já bloqueia o clique).
Regra geral: **gatilho de diálogo não se desabilita enquanto o diálogo está
aberto.**

## 4. Leaflet e camadas

O overlay do driver.js fica acima de tudo (z-index na casa de 10⁹); panes e
controles do Leaflet vão até 1000 e os nossos toasts/diálogos usam `z-50`. Para
os próximos tours sobre mapa: destacar o **contêiner** do mapa ou os
**controles**, nunca marcadores (mudam com zoom e cluster).

## Pendências

- Tours de primeiro acesso (menu), painel do gestor (exige sessão no e2e) e
  análises (mapa).
- A abertura automática afeta e2e da busca em perfil limpo; se incomodar,
  pré-marcar a chave `edumaps.tour.busca-escola.v1` no setup do e2e.
- Telemetria de uso do tour (iniciado/concluído/abandonado por passo) via
  `eventBus`, respeitando a política de agregados.
- Reavaliar `svelte-tourlight` quando amadurecer; a troca fica restrita a
  `src/shared/tour/`.
