# Nota técnica 65 — e2e do histórico de conversas: 10 bugs numa página sem teste

**Data:** 2026-09-28 · **PR:** `fix/chat-historico-e2e` · **Escopo:** frontend
(chat), backend (export de conversas), ambiente local com Docker

## Contexto

`/chat/historico` foi entregue em `9fd4a0e` ("feat(chat): histórico de conversas
com salvamento, busca e export .md") com a página **inteiramente inútil**: a
lista nunca carregava, e os botões de exportar e excluir não faziam nada. A
rota não tem `*.test.js` nem handler MSW, então nada pegou.

A rodada foi uma verificação e2e em Chrome real (CDP) contra build de produção,
com o Postgres em Docker, o backend no perlbrew do host e a SPA servida por
nginx. O resultado está em `docs/e2e/cobertura.md`: **16 achados**, dos quais
10 viraram mudança de código.

## Achados que bloqueavam o uso

Todos do mesmo commit original, todos independentes:

| # | Onde | Sintoma |
|---|------|---------|
| 1 | `ChatCalendar.svelte` | `$effect` com o retorno da função quebra o `onMount` da página |
| 2 | `ChatConversaItem.svelte` | `{snippet}` em vez de `conversa.snippet` |
| 3 | `ChatHistoricoPage.svelte` | `searchResults` preenchido e nunca lido |
| 4 | `ChatConversaList.svelte` | exportar/excluir/`onOpen` são `() => {}` |
| 5 | `chatApi.js` | `exportConversas` fora do `apiClient` → 401 |
| 6 | `ChatHistoricoPage.svelte` | `revokeObjectURL` no mesmo tick cancela o download |
| 7 | `ChatConversaItem.svelte` | overlay `inset-0` torna exportar/excluir inclicáveis |
| 8 | `ChatConversaList.svelte` | `bind:value` em prop não bindável |
| 9 | — | não havia UI de seleção, logo "exportar selecionadas" era inalcançável |
| 10 | — | "Ver conversa" não tem destino (lacuna de produto) |

### O padrão do nº 1

`$effect` do Svelte 5 espera uma **função**. O código fazia
`$effect(buildCalendar())`, ou seja passava o retorno (`undefined`):

```js
// antes — quebra
$effect(buildCalendar());
// depois
$effect(() => { buildCalendar(); });
```

O detalhe que vale registrar: o `TypeError: Object.defineProperty called on
non-object` acontece no **flush** do Svelte, e um erro no flush **aborta o
`onMount` da página**. O efeito visível é "nenhuma conversa encontrada", com
resposta 200 da API e conversas no banco — o que aponta para o banco, não para
o frontend. Faltava o `requestAnimationFrame` ou o `$effect` ter ficado no
caminho errado.

### O padrão do nº 7

O item da lista tem um botão "Ver conversa" implementado como overlay
`absolute inset-0` cobrindo o card inteiro — o truque de transformar o card
inteiro em área clicável. Esse overlay é irmão da linha do cabeçalho e vem
**depois** no DOM, então ganha o empilhamento e intercepta o clique dos botões
de exportar e excluir. Os handlers desses botões já tinham `stopPropagation`,
o que engana: o clique nem chega neles, então nada impede.

`document.elementFromPoint` na coordenada do centro do botão mostra o alvo real
em uma linha. A correção é `relative z-10` na linha do cabeçalho.

## O lado do servidor só apareceu depois

Nada do backend de export foi exercitado enquanto os botões eram stubs. Ligados
os botões, `?ids[]=41` devolveu **todas** as conversas do gestor, em silêncio —
e o teste existente passava, porque usava justamente a forma quebrada e
conferia o corpo de uma resposta que vinha com tudo.

Dois defeitos independentes:

1. **`?ids[]=` não é lido.** `Mojo::Parameters->to_hash` **não** converte a
   notação de colchete: o nome da chave fica literalmente `ids[]` e
   `to_hash->{ids}` volta `undef`. Sem ids, o filtro era pulado e o resultado
   eram todas as conversas. A forma que o backend de fato lê é `?ids=1&ids=2`.
2. **Com o filtro aplicado, 500.** `prefetch => mensagens` fazia JOIN e `id`
   existe em `chat_conversas` e `chat_mensagens` →
   `ERROR: column reference "id" is ambiguous`.

O prefetch, aliás, era **descartado**: o loop embaixo já fazia
`$c->mensagens->search({}, { order_by => 'created_at' })`. Removê-lo resolveu a
ambiguidade e eliminou uma consulta inútil.

Correção: o controller passou a coletar `ids` e `ids[]` e filtrar para inteiro
(assim a forma de colchete nunca mais é confundida com "sem filtro", que
significa exportar tudo).

## Armadilhas que custaram tempo

- **O `to_hash` do Mojolicious e os colchetes.** `?ids[]=1` e `?ids=1` parecem
  equivalentes e não são. Vale checar `Mojo::Parameters->new($qs)->to_hash` num
  one-liner antes de usar o resultado.
- **Teste que afirma o que não testa.** O subteste passava por uma conversa que
  não era a pedida. Ao corrigir o filtro, ele **começou a falhar** — porque a
  conversa mais recente do banco só tinha mensagem de `user`, e o export só
  numera `Resposta N` para `assistant`. Corrigido para criar a própria conversa,
  contar as seções e conferir que a outra não vaza.
- **`{#each}` com key + id repetido derruba a tela** (`each_key_duplicate`). A
  busca devolve a mesma conversa mais de uma vez, porque o `snippet` entra no
  `DISTINCT` do SQL. O sintoma — "a busca não filtra nada" — é parecido com o do
  `searchResults` não lido, e manda o diagnóstico para o lado errado.
- **A autenticação é por header, não cookie.** `_require_gestor` só lê
  `Authorization: Bearer`; `credentials: "include"` sozinho dá 401 mesmo com
  sessão válida. Toda chamada nova tem de passar por `apiClient`.
- **`POST /api/chat/conversas` espera `messages`** (inglês), não `mensagens`.

## Decisões de escopo

- **"Ver conversa" continua sem implementação.** A `ChatPage` não sabe reabrir
  uma conversa salva: não lê id nem query param, a rota é estática e
  `getConversa()` não é chamado por ninguém. Implementar exige rota/param e
  carga da conversa no chat — é produto, não correção. O clique passou a mostrar
  um aviso em vez de não fazer nada.
- **Os 3 achados da busca (`search_conversas`) ficaram só documentados.**
  Duplicidade por mensagem, `ts_headline` emitindo `<b>` que é renderizado como
  texto, e ausência de `unaccent`. A página deduplica no cliente para o `{#each}`
  com key não quebrar; o conserto no SQL fica para outra rodada.
- **A chave de admin em `edu_maps.conf`** (gitignored) foi o que permitiu
  exercitar a rota autenticada de verdade. Sem ela, o e2e pararia no 401.

## Ambiente

Como `ubatexu.lan`, `backend.edumaps` e `analytic.edumaps` estavam fora do ar, a
rodada rodou 100% local:

- **Postgres** em Docker (`docker-compose.yml`), PostGIS 3 + pgvector sobre
  `pgvector/pgvector:pg16-bookworm` — a imagem `postgis/postgis:16-3.5` é Debian
  11, com curl 7.74, que não lia a resposta do jsdelivr, e tinha curl/ca-cert
  fora do pool do apt.
- **Backend** no perlbrew do host, em `prefork` na 3000.
- **SPA** em build de produção, servido por nginx com `/api` por proxy para o
  backend.
- **Chrome** via CDP, em perfil dedicado, com `Input.dispatchMouseEvent` para os
  cliques reais.

Um detalhe do ambiente que custou tempo: `docker run` precisa de `sg docker -c`
(sudo pediria senha), e limpar o diretório que o nginx monta transforma toda rota
em 500.

## Verificação

- `t/04-api/chat/` — 11/11. As falhas em `t/04-api/municipio.t` (subteste 8) e
  `t/04-api/network/schools.t` (subteste 3) são **pré-existentes**: reproduzidas
  idênticas com as mudanças guardadas.
- `vitest` — 62 arquivos / 337 testes. Os erros não tratados vêm todos do
  `SchoolFinancePage.test.js` (animação do Carbon em jsdom) e a contagem varia
  entre execuções; nenhum toca o chat.
- No browser, build de produção: 0 exceções, 3 conversas na lista, busca
  filtrando nos dois campos, calendário filtrando por dia, exportar (todas,
  selecionadas e uma) baixando `.md` com o número certo de seções, e excluir
  removendo da tela e do servidor (204 → 404).
