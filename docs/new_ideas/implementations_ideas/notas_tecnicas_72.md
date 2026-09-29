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

## D — Mapa dos POIs OSM (PR #120)

Segunda parte da feature: além do resumo, os equipamentos são desenhados num
mapa junto à escola.

- **Endpoint** (mesmo `GET /api/gestor/:cod_inep/osm/pois`): passa a devolver
  - `escola` — nome/latitude/longitude (de `clean.censo_escolas`);
  - `geojson` — `FeatureCollection` com o **centroide** de cada feição
    (`ST_PointOnSurface`, leve para o mapa), mais `category`, `nome` (tag
    `name`, quando houver) e `distance_m`; ordenado por distância.
  - `Model::OSM::school_location` e `Model::OSM::school_pois_geojson`
    (via `_dbh`); `_load_school` passou a selecionar `no_entidade`.
- **`OsmPoisMap.svelte`**: marcador da escola, **círculo do buffer** (raio) e
  um `L.circleMarker` por equipamento, **colorido por categoria** (paleta
  estável por hash), com popup (nome em destaque + categoria + distância). O
  resumo do painel virou **legenda com toggle**: o `OsmPoisPanel` mantém
  `hidden` (categoria → oculta) e o mapa aplica a visibilidade.
- **Categorias em PT**: `categoryLabel` (`constants/osm.js`) traduz as tags do
  catálogo curado (`amenity=bus_station` → "Terminal de ônibus"), com fallback
  formatado. `formatCategory` continua como base do fallback.

### Lição: efeito que lê e escreve o mesmo estado

A primeira versão usava um contador reativo (`tick += 1`) dentro do efeito de
desenho para avisar o efeito de visibilidade. `tick += 1` **lê e escreve** o
mesmo `$state`, então o efeito se auto-invalidava → `effect_update_depth_exceeded`
(o erro aparecia ao re-renderizar o painel, p.ex. ao interagir com escolas
similares). A correção: `layersByCategory` é `$state`, **escrito** pelo efeito
de desenho (que não o lê) e **lido** pelo efeito de visibilidade (que não o
escreve). Regra prática: um efeito não deve ler o estado que ele próprio escreve.

### Topologia (para validação)

`ubatexu.lan` (192.168.0.42) é o LXC `backend.edumaps` — a validação visual usa
o deploy LXC, cujo `database.edumaps.edumaps_dev` guarda os dados de OSM da
escola de teste (35246177). O compose local roda no host `ubaxala`
(192.168.0.13) com o Postgres Docker próprio (`DB_HOST=db`) — bases separadas.

O build do compose local falhou antes por disco cheio; `docker builder prune -af`
liberou ~13 GB (cache de build).

## E — Worker Minion local + propagação de erro no OSM (PR #121)

Ao testar o fluxo OSM no build Docker local apareceram dois problemas.

### 1. O worker Minion não consumia jobs no localhost

O `ENTRYPOINT` da imagem já é o `docker-entrypoint.sh`, mas o `command` do
compose repetia o caminho do script:

```yaml
command: ["/usr/local/bin/docker-entrypoint.sh", "minion"]
```

Com isso o processo final vira
`docker-entrypoint.sh docker-entrypoint.sh minion` → `$1` = o próprio script →
o entrypoint caía no `else` e subia o **morbo (web)**. Nenhum job era
consumido. Correção: `command: ["minion"]`.

Sintoma: o container `edumaps-minion` ficava "Up" e logava
`Web application available at http://127.0.0.1:3000` (mensagem do morbo); o
worker saudável loga `Worker <id> started` e
`performing job "<id>" with task "<task>"`.

### 2. Falha silenciosa do OSM (Overpass 504 → 0 POIs "com sucesso")

Com o worker funcionando, jobs `query_osm_school` terminavam `finished` com
`related: 0` e `raw_results: null` **sem erro**, quando o Overpass devolvia
`HTTP 504`.

Causa raiz (dupla):

- `die` dentro de um `async sub` (via `-async_await`) vira uma promise
  **rejeitada**; o `await`/`wait` não a relança.
- `Mojo::Promise::wait` **engole a rejeição** (`catch(sub { })` interno) e ainda
  retorna imediatamente quando o IOLoop já está rodando — exatamente o contexto
  do worker Minion.

Resultado: `run` seguia com `geojson` indefinido; `_store_features`/`_relate_*`
gravavam nada e o job "concluía".

Correção: o `_request` passa a usar `Mojo::UserAgent` **síncrono**
(`$ua->post(...)`), o mesmo padrão do `EduMaps::Analytics::Client` (usado em
tasks). No worker o IOLoop não está `is_running` (o worker usa ticks), então a
chamada bloqueante funciona — confirmado: com Overpass disponível o job
`finished` com `related: 1` e a feição gravada. Erros de conexão/HTTP agora
propagam (`die`): job **failed** com
`{"error":"Overpass retornou HTTP 504..."}`. `run_p` vira um wrapper de promise
que preserva o erro; `related` sai numérico (`0 + ($n // 0)`, pois `$dbh->do`
devolve `"0E0"` quando 0 linhas).

Regra prática: em task Minion, **não** use `->wait`/`async sub` para HTTP; use o
UA síncrono (ou awaits com tratamento explícito de erro).


