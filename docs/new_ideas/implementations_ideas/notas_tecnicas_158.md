# Nota técnica 158 — a #296 fecha: IVET materializado e isócrona na UI

Ciclo de execução da **#296** (expor o IVET e a isócrona na interface web).
Fechada em **três PRs** (#298, #299, #300), todos com E2E no LXC. A lógica do
IVET continua **só no `edumapsr`**; o que entra em cada camada é a *entrega* do
resultado, não o cálculo.

## Entregas

| PR / commit | Escopo |
|---|---|
| **PR #298** (`0b4660b`) | `analytics.ivet_escola` + task Minion `refresh_ivet` + `GET /api/school/:cod_inep/ivet` |
| **PR #299** (`01de865`) | `GET /api/school/:cod_inep/isocrona` (células H3) |
| **PR #300** (`cab49ce`) | card do IVET + camada de isócrona no Leaflet + LGPD + docs |

Commits: `850efa1`, `21f5f9b`, `6321474`, `2884d1a` (PR1); `00940f1` (PR2);
`21d8c1b`, `4bd0f2b` (PR3).

## 1. O IVET virou artefato de entrega — e a API só lê o snapshot vigente

O plano aprovado pedia tabela de resultado servida pela API, refreshada por
job — o mesmo contrato do bloco B (`analytics.ranking_escola`). A escolha
resolve dois problemas de uma vez:

- **A API não carrega a lógica do R.** `Model::Ivet::Escola::latest()` lê a
  linha vigente e nada mais; a fórmula fica onde os testes dela vivem
  (`edumapsr`).
- **Histórico de graça.** A PK inclui `dt_snapshot`, então cada dia de refresh
  é uma geração nova; a leitura filtra `max(dt_snapshot)` por escola — a mesma
  regra da view nacional do IVET, o que evita que duas partes do sistema
  discordem sobre "qual é o número de hoje".

O `refresh_ivet` fala com o Plumber por um **client dedicado com
`inactivity_timeout` de 1 h**. O default de 300 s mede o **silêncio entre
bytes**, não a duração total — e o painel nacional passa minutos sem emitir
nada antes de responder. Com o timeout default, o POST morreria no meio.

## 2. Ausência ≠ 0 atravessou as três camadas (#154)

A regra não é cosmética: `0` no IVET significa "sem barreira de acesso", que é
o oposto de "não medido". Ela foi propagada em cada fronteira:

- **R**: `NA` no data frame, nunca `0`; o upsert grava `NULL`.
- **Backend**: `NULL` do banco vira `undef` no modelo e **JSON `null`** na
  resposta (não `0`); `publicavel` vira booleano JSON de verdade.
- **Frontend**: bloco nulo → **"n/d"**; escola nunca medida → "ainda não teve o
  índice calculado"; faixa de isócrona 100% sem população → `populacao_total:
  null`.

Os testes fixam a regra nos três níveis (R, `t/04-api`, vitest) com asserção
sobre o **texto JSON** (`"ivet":null`), que é o único jeito de distinguir
`null` de `false`/`0` depois do decode.

## 3. O mapa desenha H3 no cliente; o backend entrega a grade

O backend não tem H3 e não precisa ter: `/isocrona` devolve `grid_id` +
população, e o frontend converte cada célula em polígono com `h3-js`
(`cellToBoundary`). A camada segue o padrão de legenda clicável da skill
(`aria-pressed` + `Set` reatribuído), então ligar/desligar 15 min e 45 min não
recarrega os dados.

Isso mantém a fronteira limpa: **quem sabe desenhar é quem desenha**, e a API
não vira um servidor de tiles.

## 4. LGPD: medido não é o mesmo que publicável

O card não mostra valores quando `publicavel` é `false` — informa que a
medição existe, mas resguarda o dado (amostra insuficiente ou dado sensível).
É uma capacidade de produto, não um detalhe de UI, e por isso está em
`docs/funcionalidades/`.

## 5. Dois tropeços que valem registro

- **`$app->helper('nome')` com 1 argumento NÃO é getter** em Mojolicious: é
  `add_helper($nome, undef)`, que **destrói o helper** e o dynamic method do
  controller (o erro é `Can't locate object method`). O getter real é
  `$app->renderer->get_helper('nome')`. Um teste que "verificava" a existência
  do helper com a forma errada passava **e** quebrava o helper para o resto do
  arquivo.
- **`git checkout -b <branch>` falha se a branch já existe** — e o
  `add`/`commit` seguinte cai em `main`, gerando dois PRs vazios ("No commits
  between main and …"). Conferir `git branch --show-current` antes de commitar
  ao abrir branch.

## 6. Resultado

Materializado (snapshot `2026-10-20`): **180.540 escolas**, 145.732
publicáveis, 34.808 com `ivet` `NULL`. Rota servindo escola MG real
(`31000019`) com blocos A–G e isócrona (15 min: 19 células; 45 min: 491
células, pop 4,82 mi). Suítes: R `filter="ivet"` verde, `t/04-api/school`
verde, frontend **115 arquivos/975 testes** verdes.

O ciclo fecha a #296; a **#295** segue aberta para a rodada 2 (RJ/SP e BA).
