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

## 7. Pós-ciclo: telemetria e dois fixes (PRs #316, #317)

| PR | Merge | Escopo |
|---|---|---|
| #316 | `65afc6c` | telemetria do tour (backend + frontend + painel admin) + fix do fechamento durante a animação |
| #317 | `fdc4a8c` | “?” só aparece quando o painel do gestor carregou |

**Telemetria.** Um evento `tour` (`tour_id`, `action` start/complete/dismiss,
`step` 1-based, `total`, `trigger` auto/button/link). O
`Controller::Session` passou a validar também os **valores** (padrão novo,
genérico: `valid`/`required`/`numeric` por tipo). Valor fora do padrão
descarta o evento inteiro, e um cliente adulterado não grava texto livre.
Retomada após reload não conta como abertura. O Painel de Administração
mostra, por tour, aberturas por gatilho, conclusões, fechamentos, taxa
(“—” sem abertura) e passo de maior abandono.

**Bug que a telemetria revelou (existia desde a fase 1).** O driver.js só
chama `onDestroyed` se já há elemento ativo, e esse estado só existe depois
da animação de cada passo (~0,6–1,2 s). Fechar nessa janela destruía o tour
sem avisar: `ativo` ficava preso, sem `dismiss` e sem limpar a sessão, e
**nenhum tour automático nem `?tour=` abria até recarregar a página**.
Correção: todo encerramento passa por `#finalizar()` (idempotente), acionado
por `onDestroyStarted` (chamado antes da checagem), `encerrar()` e conclusão.
`onDestroyed` não é mais usado. Lição: **ganchos de biblioteca de UI podem ser
condicionais. O dono do estado deve ter um caminho de encerramento próprio.**
O dublê de teste foi ajustado para imitar o driver real (`destroy()` da API
não chama ganchos; `fechar()` chama `onDestroyStarted`).

**“?” na tela de erro.** Para tour com `prontoQuando`, o `BotaoAjuda` só se
mostra quando o alvo existe no DOM (`MutationObserver` ativo só nessas
páginas). Fecha a pendência da fase 3.

## 8. Módulos do gestor, lote 1 (PR #319)

Merge `3177e78`. Tours de Relatórios (5 passos), Contatos (4), Listas (4),
Envios (3) e Listas dinâmicas (3), todos com `prontoQuando` no conteúdo
logado. O desenho saiu da **fase 3 sem mudança no `TourManager`**: tour novo
continua sendo dado + `data-tour`.

- **Envios espera a lista, não os limites.** Por `?novo=1` (botão “Enviar
  e-mail” de uma lista) a página abre direto no editor e a lista não existe.
  Com os limites como `prontoQuando`, o tour abriria sobre o editor com os
  passos sem alvo.
- **Componentes sem repasse de atributos** (`LimitesPainel`,
  `ExclusoesHistorico`…) descartam o `data-tour` em silêncio. Use `<div>`
  envoltório, sem mexer na raiz do componente, que pode ser usado em outras
  páginas.
- **Teste de contrato novo** (`features/gestor/pages/tourAlvos.test.js`): com
  sessão MSW, todo alvo de todo passo tem de existir no markup real; sem
  sessão, o `prontoQuando` não aparece. É a resposta ao maior risco de
  manutenção dos tours: perder um `data-tour` numa refatoração degradava o
  tour sem nenhum aviso.
- **Textos: ficha + código + tela.** Dois erros pegos no código antes do
  deploy: capítulos do relatório municipal são fixos, e o filtro de envios
  chama-se “Estado”.
- **Limite do e2e logado.** A injeção de um token de teste local na aba foi
  bloqueada pela política de permissões (materialização de credencial) e não
  foi contornada. O estado logado ficou coberto pelo teste de contrato (MSW) e
  pela validação visual do developer. A conta de teste da stack local está em
  `~/.config/edumaps/e2e_gestor_local`, fora do repositório.

## 9. Módulos do gestor, lote 2 (PR #320): os dez módulos cobertos

Merge `50e427e`. Pesquisas (2 passos), Reuniões (4), Inventário (3),
Relações (4) e Documentos (4). Com o lote 1, os **dez módulos do gestor**
têm tour; o catálogo fecha em 14 tours.

- **Pesquisas não tem login** (lista pública, exige `?inep=`) e alterna entre
  lista e estado vazio. O mesmo `data-tour="pesq-conteudo"` foi posto nos
  dois elementos (só um existe por vez), o que evitou reestruturar o
  `{#if}`. O texto do 1º passo teve de servir aos dois estados.
- **Abas**: Inventário e Relações só destacam a aba padrão. As outras não
  existem antes de um clique, e o tour não opera a página.
- **Fix de navegação no `TourManager`**: com um tour aberto, sair da página
  fechava o tour e retornava cedo, e o automático da página de destino
  nunca abria. Agora fecha e segue a avaliação.
- **E2E logado sem credencial**: o Chrome de automação já tinha a sessão de
  gestor que o developer abriu ao validar o lote 1. Com ela, os 5 tours foram
  percorridos logado (só leitura), e o `?novo=1` de Envios (lote 1) foi
  confirmado no estado real.
- **Interface corrigida de passagem**: o painel “Como funciona” de Documentos
  (alvo de um passo) dizia “Enviar arquivo público”. **Não corrigido**, por ser
  bug de comportamento: a confirmação de excluir pasta promete preservar o
  conteúdo, mas o backend recusa pasta não vazia.

## 10. Assistente do Censo (PR #322)

Tour `assistente-censo` (4 passos), `prontoQuando` no painel de escopo, que só
existe com o gestor logado. Catálogo: 15 tours.

- **Layout flex**: o histórico e a caixa de pergunta vivem num contêiner
  `flex-1 min-h-0 flex flex-col`. Um `<div>` em volta do `ChatHistory`
  quebraria o flex, então o alvo da conversa ficou no próprio contêiner.
  Regra: antes de envolver um componente para pôr `data-tour`, ver se ele é
  filho de flex/grid com papel de layout.
- **Ficha corrigida pelo código**: `historico-conversas.md` dizia “salvar
  automaticamente”. A única gravação é o `POST /api/chat/conversas` do botão
  “Salvar conversa”. É o terceiro caso no ciclo de ficha que diverge do
  código; os tours acabaram servindo também de auditoria das fichas.
- **E2E sem custo**: percorrido logado sem enviar pergunta, porque cada uma
  consome o serviço de IA da instalação.

## Pendências

- ~~**gzip dos assets** no nginx~~ — **resolvido no PR #315** (`0a91b85`):
  bundle 1030→304 KB, 1ª carga pós-deploy 12,6→1,5 s.
- ~~Telemetria do tour~~ — **PR #316** (§7).
- ~~“?” na tela de erro do painel~~ — **PR #317** (§7).
- ~~A abertura automática afeta e2e em perfil limpo~~ — **PR #318**
  (`c479d72`): `?tour=off` (marca `edumaps.tour.automatico=off` no
  `localStorage` do profile) suprime só o automático; `?tour=on` religa.
  Passo obrigatório no Setup de `docs/e2e/README.md`. Descartados: pré-gravar
  chaves de “visto” (quebra a cada tour/versão) e `navigator.webdriver` (não é
  ligado via `--remote-debugging-port`).
- ~~Tours dos módulos do gestor~~: lote 1 (PR #319) e lote 2 (PR #320).
  ~~Assistente do Censo~~ (PR #322). **Administração** e telas secundárias
  (assistentes de criação, detalhes), se houver demanda.
- ~~Documentos: confirmação de excluir pasta contradiz o backend~~ —
  **PR #321**: pasta com conteúdo é barrada antes, com aviso do que há
  dentro; a vazia pede confirmação honesta; o 409 segue tratado para a corrida.
- Reavaliar `svelte-tourlight` quando amadurecer. A troca fica restrita a
  `src/shared/tour/`.
