# Nota técnica 162 — ajuda guiada interativa: o ciclo completo (fases 1–4)

Nota consolidada da feature **ajuda guiada** (product tour) no frontend.
Quatro PRs no mesmo dia (2026-11-01), cada um com deploy, e2e em Chrome real
contra `ubatexu.lan:8080` e validação visual do developer. As notas de fase
ficam como detalhe: [159](notas_tecnicas_159.md) (fase 1),
[160](notas_tecnicas_160.md) (fase 2), [161](notas_tecnicas_161.md) (fase 3).

## Entregas

| Fase | PR | Merge | Escopo |
|---|---|---|---|
| 1 | #311 | `a3011e7` | `driver.js` + `src/shared/tour/` (TourManager, botão “?”, tema) + tour `busca-escola` (multi-página) |
| 2 | #312 | `b8517ca` | tour `primeiro-acesso` (home + menu) |
| 3 | #313 | `4388f4b` | tour `painel-gestor` + `prontoQuando` no TourManager |
| 4 | #314 | `c7f493e` | tour `analises` (clusters) + causa da carga lenta pós-deploy |

Catálogo final:

| Tour | Página | Passos | Particularidade |
|---|---|---|---|
| `primeiro-acesso` | `/` | 7 | alvos no menu global |
| `busca-escola` | `/escola/search` | 7 | termina em `/municipio/compare` (multi-página) |
| `painel-gestor` | `/gestor/painel` | 8 | `prontoQuando` (página carrega dados) |
| `analises` | `/cluster/geotag` | 6 | ordem lógica ≠ ordem visual |

Testes: 1006 no total ao fim do ciclo, 30 deles da camada de tour.

## 1. Biblioteca: driver.js com camada própria

Levantamento no registry do npm e no GitHub (detalhe na nota 159):

- **Shepherd.js virou AGPL-3.0** (15.x). Fica descartado sem licença comercial.
- **`svelte-tourlight`** tem a melhor API (runes nativos, a11y completa), mas
  foi criado em 2026-10-24 (v0.1.5, ★0). Descartado só por imaturidade.
- **`driver.js` 1.10** (MIT, zero deps, ★27k): adotado.

O projeto não é SvelteKit (Vite + roteador próprio), e o argumento
“integra com `goto`” das libs Svelte não se aplicava. Seguiu-se o padrão que o
repositório já usa no roteador: JS estável por baixo, camada fina em runes por
cima, troca isolada em um diretório.

A lacuna de a11y do driver.js era menor do que a documentação sugeria. Lendo o
código, ele já tem `role="dialog"`, `aria-labelledby`/`describedby`, Tab preso
e setas/Esc. A camada só acrescentou `aria-modal`, devolução de foco e
`prefers-reduced-motion`.

## 2. Arquitetura

```
src/shared/tour/
  tourManager.svelte.js   TourManager: $state (ativo, passo), deps injetáveis
  index.js                instância única + registrar(...tours)
  BotaoAjuda.svelte       "?" no <nav>, só em páginas com tour
  tour.css                tema EduMaps do popover
  tours/*.js              definições (dados puros, PT-BR)
App.svelte                $effect → tourManager.aoNavegar(path) (resto em untrack)
```

Definição de um tour: `{ id, versao, titulo, rotaInicial, automatico,
prontoQuando?, passos: [{ alvo, titulo, texto, rota?, lado?, alinhamento? }] }`.
O `alvo` é sempre um `data-tour="..."`, separado dos `data-testid`.

**Medida do acerto da camada:** as fases 2 e 4 não tocaram no `TourManager`.
Cada tour novo foi um arquivo de dados, uma linha no `registrar` e atributos
nos alvos. A fase 3 acrescentou uma capacidade genérica (`prontoQuando`), não
um caso especial.

## 3. Decisões que valem para os próximos tours

1. **Multi-página pelo roteador**: o passo declara `rota`; o manager navega
   e o `waitForElement` espera o alvo. O `passo` é atualizado **antes** de
   navegar, porque é isso que permite encerrar o tour quando a pessoa sai por
   conta própria (voltar do navegador).
2. **Persistência em dois níveis**: “visto/concluído” por versão no
   `localStorage` (subir `versao` reapresenta) e passo em andamento no
   `sessionStorage` (retoma após reload). Todo acesso a storage fica em
   `try/catch`.
3. **“Visto” gravado na abertura**: o automático aparece uma vez, mesmo se
   fechado no passo 1. Nunca rebaixa “concluído”.
4. **`prontoQuando` para páginas que carregam dados**: o automático só abre
   quando o alvo monta. Se não montar (erro), não abre e **não marca**. O “?”
   não espera.
5. **O destaque não recebe clique** (`disableActiveInteraction`): o tour
   explica, não opera. Sem isso, clicar em um botão de navegação deixaria o
   tour apontando para um elemento desmontado.
6. **Gatilho de diálogo não se desabilita** enquanto o diálogo está aberto.
   O botão desabilitado perdia o foco, e a devolução falhava (bug da fase 1,
   achado no e2e).
7. **Leaflet**: destacar a seção que contém o mapa, nunca marcadores.
   z-index medido: overlay 10000 contra 400/1000 do Leaflet.

## 4. Textos: ficha + tela

Erros de texto achados no ciclo, todos antes do merge:

| Fase | Erro | Achado por |
|---|---|---|
| 2 | Assistente do Censo “responde com a fonte” (falso; é só de gestor com login) | leitura da ficha |
| 3 | Matrículas sem a faixa etária | e2e (a ficha também não citava) |
| 4 | “O mapa mostra…” sobre o espaço ainda vazio | e2e |

**Regra**: escrever o passo a partir da ficha da funcionalidade e
conferi-lo na tela renderizada, no estado em que o tour aparece.

## 5. Achado colateral: bundle principal sem gzip

A “tela em branco na primeira carga após o deploy” apareceu nas fases 1, 2
e 4. O primeiro diagnóstico (“o navegador não pediu o bundle”, notas 160/161)
**estava errado**: o nginx registra a requisição quando ela termina, e o log
foi lido cedo demais. A Resource Timing API mostrou a causa real:

- `index-*.js` com 1030 KB transferidos, levando **10,6 s**; navegação completa
  em 12,6 s;
- `gzip on`, mas `gzip_types` comentado: só HTML é comprimido. O JS sai cru
  (~310 KB se comprimido);
- o bundle muda de hash a cada deploy e não vem do cache. Os `vendor-*`
  vêm.

Afeta qualquer usuário na primeira carga após cada deploy. Nenhuma das duas
configs do repositório habilita os tipos
(`backend/script/deploy/files/edumaps-frontend-nginx.conf`,
`frontend/nginx.conf`). A correção fica em PR próprio.

Lição de método: **medir no cliente antes de concluir pelo log do servidor**.

## 6. Limites do e2e

- O estado logado do painel do gestor (área de influência com mapa) foi
  validado pelo developer. O agente não digita credenciais em `ubatexu.lan`,
  que não é host local nem de teste.
- O mapa de clusters gerado depende do motor R e não foi exercitado no tour.
- Teclas apertadas durante a animação do driver.js são ignoradas. Isso só
  aparece em automação.

## Pendências

- ~~**gzip dos assets** no nginx~~ — **resolvido no PR #315** (`0a91b85`):
  bundle 1030→304 KB, 1ª carga pós-deploy 12,6→1,5 s.
- Telemetria do tour (iniciado/concluído/abandonado por passo, só agregados).
- O “?” aparece na tela de erro do painel e os passos caem no popover
  centralizado. Caso raro.
- A abertura automática afeta e2e em perfil limpo. Pré-marcar
  `edumaps.tour.<id>.v1` no setup se incomodar.
- Tours para módulos do gestor, assistente e administração, se houver demanda.
- Reavaliar `svelte-tourlight` quando amadurecer. A troca fica restrita a
  `src/shared/tour/`.
