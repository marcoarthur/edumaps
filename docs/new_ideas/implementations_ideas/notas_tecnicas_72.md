# Nota técnica 72 — POIs OSM no entorno da escola (painel do gestor)

**Data**: 2026-09-29
**PRs**: #118 (feature), #119 (fix da sessão)
**Issues**: #105 (roadmap do perfil/painel)
**Áreas**: data_pipeline, backend, frontend

## Contexto

O ciclo anterior (#117) generalizou o OSM em `Services::OSM::Query`,
`Services::OSM` e `Model::OSM` (feature/query feature, catálogo de perfis,
buffer `around`/`poly`) mas só expunha wrappers de task. Faltava o caso de uso
do **Painel do Gestor**: consultar, por escola, os equipamentos públicos
(ex.: transporte, saúde, educação) num raio ao redor da escola e mostrar um
resumo por categoria.

Decisões de produto (alinhadas antes de codar):

- Catálogos (perfis) em **multi-seleção**, default `equipamentos_publicos`.
- Raio do buffer **100–10000 m**.
- **Upsert**: cada busca **substitui** a anterior da escola (qualquer
  raio/catálogo).
- Se já houver job **enfileirado/ativo** para a escola, a interface **trava** e
  anexa ao progresso (o `POST` é **idempotente**: devolve o mesmo `job_id`).
- Dados com **< 7 dias** → pedir **confirmação** antes de refazer.
- Progresso **visível** e falhas **imediatas**.

## A — Migração `school_osm_query` (data_pipeline)

Tabela `clean.school_osm_query` com PK `(co_entidade, nu_ano_censo)`:

| coluna       | tipo        | papel                                    |
|--------------|-------------|------------------------------------------|
| `raio`       | integer     | raio do buffer usado                     |
| `profiles`   | jsonb       | catálogos selecionados (array)           |
| `digest`     | text        | FK → `clean.osm_query.digest`            |
| `updated_at` | timestamptz | carimbo para o aviso de recência         |

`profiles` como **jsonb** (não `text[]`) para evitar inflators de array no
DBIx::Class: o `Model::OSM` faz `encode_json`/`decode_json`.

## B — Backend

### Task com progresso

`query_osm_school` usa o `Minion::Task::Generator` com a role `+Progress`:

```perl
$app->minion->add_task(
  query_osm_school => task {
    sub   => \&_query_osm_school,
    roles => { '+Progress' => { log => $app->log } },
  }
);
```

O handler constrói o `Model::OSM` e **encaminha** o evento `progress` do model
para as notes do job (`$job->progress($p->{percent}, $p->{message})`) — é o que
o `_monitor_minion_job` transmite por SSE em `/api/task/progress`.

### Progresso ponta a ponta

O `Services::OSM` emite `progress` com `phase` (`requesting osm`,
`download osm`, `geojson`); o `Model::OSM` mapeia para percentuais
(10 → 40 → 90) e emite marcos próprios (cache hit 80, persistência 92,
conclusão 98). A task abre em 2 e fecha em 100.

### Rotas do gestor

`POST/GET /api/gestor/:cod_inep/osm/pois`, autenticadas por `_require_gestor` +
`_gestor_inep_ok` (mesmo padrão do SIOPE):

- `POST` valida raio e catálogos; **dedup** via `_pending_osm_job` (itera os
  jobs `inactive/active` da task e compara `notes->{co_entidade}`); responde
  `202` com `Location` e o `job_id` (e `reused`).
- `GET` devolve seleção atual (`current_selection`), resumo por categoria
  (`school_pois_summary`) e `job_id` se houver job pendente.

### Nuances do Minion encontradas

- `minion->jobs(...)` devolve `Minion::Iterator` (não tem `first`).
- `Iterator->next` devolve o **hashref** do job (não `Minion::Job`).
- O filtro `notes => [...]` casa por **chave** do JSONB, não por valor.
- Nesta versão, `fail` grava em `result` (não há `error` separado).

### Serviço offline

O modo offline (`offline => 1`, `fixture => …`) passou a carregar a fixture
**sincronamente** no `run`. Um `die` dentro do `async sub run_p` viraria uma
*unhandled rejected promise* sem propagar ao `try/catch` da task; o carregamento
síncrono faz o erro do job ser registrado corretamente.

## C — Frontend

Componente `OsmPoisPanel.svelte` (feature `gestor`), integrado ao
`GestorPanel` + NAV:

- Catálogos em checkboxes ("Todos" é exclusivo), slider de raio, botão.
- Barra de progresso alimentada por SSE (`shared/api/taskProgress.js`,
  extraído de `schools/api/schoolApi.js`).
- **Confirmação modal** quando `updated_at` < 7 dias.
- **Trava** (botão desabilitado + "Buscando…") quando o status traz `job_id`.
- Erro exibido no ato; `addToast` em sucesso/falha.
- Eventos `gestor/osm-pois-{start,progress,done,error}` no EventBus — o
  middleware `logger` (registrado em `main.js`) dá o rastro em DEV.

### Fix da sessão (PR #119)

O `GestorPanelPage` é público e não chamava `restaurarSessao()`; com isso o
token não era reposto no `apiClient` e o `GET /osm/pois` retornava **401** mesmo
com o gestor logado. O componente passou a restaurar a sessão no mount — mesma
convenção das demais páginas do gestor.

## Testes

- **Backend** `t/04-api/gestor/osm_pois.t` (7 subtests): 401/403, `202`, 
  validações de raio/catálogo, **idempotência**, `GET` status e a **task com o
  Model offline** (progresso, finish, falha). A task é executada in-process
  numa **fila dedicada** (`osm_queue = osm_test` +
  `perform_jobs({ queues => ['osm_test'] })`) para não disputar com o worker do
  compose; os casos offline forçam `refresh => 1` para não pegar cache de runs
  anteriores.
- **Frontend** 381 testes; o novo cobre catálogos/raio, progresso, confirmação
  < 7 dias, job pendente, erro e 401.

## Validação

Deploy com `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
`deploy_minion_dev` + `deploy_frontend_dev` e rebuild do compose local. Rotas
respondem 401 sem sessão; validação visual do developer no `ubatexu.lan` PASS
(após o fix da sessão do PR #119).
