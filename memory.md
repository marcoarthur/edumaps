# Memory — EduMaps

> Arquivo de restauração de sessão. Registrar aqui tudo que foi descoberto
> e/ou informado pelo usuário, para retomar o contexto em sessões futuras.
> As seções abaixo ficam em ordem cronológica reversa (sessão mais recente no topo).

## Sessão atual — fix uuid (crypto.randomUUID em contexto inseguro)

- **PR #65** (`fix/uuid-contexto-inseguro`) → `main`, merge commit **`d522d10`**
  (2026-09-16). Commit `cca4d76 fix(frontend): uuid sem contexto seguro`.
- **Bug**: `crypto.randomUUID()` só existe em **contexto seguro** (HTTPS/
  `localhost`); em dev por host/IP (`http://<host>:5173`) o `crypto` existe mas
  `randomUUID` é `undefined` → `TypeError: crypto.randomUUID is not a function`
  em `EventBus.emit` (`EventBus.js:72`).
- **Correção**: helper `src/shared/utils/uuid.js` (nativo, sem dependência):
  `crypto.randomUUID()` → `crypto.getRandomValues()` (UUID v4, funciona em
  contexto inseguro) → fallback final. Usado no `EventBus.js` e no
  `toastStore.js` (remove o `Math.random` duplicado). Teste `uuid.test.js`.
- **Deploy** `deploy_frontend_dev`; validado no container: bundle com
  `getRandomValues` presente; página HTTP 200. Testes shared: 30 passaram.
- Nota: `npm run build` local conclui (`✓ built`), porém o processo do vite não
  retorna no shell — usar o `deploy_frontend_dev` (build no container) como
  validação real.

## Sessão anterior — pgvector (similaridade escolar) + topologia do ambiente

### Topologia do ambiente (IMPORTANTE — ler antes de conectar em DB)
- `ubatexu.lan` (192.168.0.42) é o **host** dos containers LXC; as portas do
  host fazem forward para os containers.
- Da nossa máquina só alcançamos o **host**, nunca o container direto. O acesso
  aos containers é via SSH pelos forwards do host (`~/.ssh/config`):
  - `backend.edumaps` → `ubatexu.lan:2031`
  - `database.edumaps` → `ubatexu.lan:2032`
  - (os containers compartilham o IP do host; só mudam as portas)
- Existem **dois** clusters Postgres, ambos com `edumaps_dev` (confirmado por
  `system_identifier` distinto):
  - **Antigo** — `database.dev`; seu Postgres é exposto pelo host em
    `ubatexu.lan:5432`. É para ele que aponta o `~/.pg_service.conf` local
    (`[edumaps]` → host=ubatexu.lan, user `devel`). Logo, **R/eduBR/testes
    locais batem nesse banco ANTIGO, não no do app**. `sqitch status` local
    (alvo `dev_super` → ubatexu.lan) também olha esse cluster antigo.
  - **Atual (app)** — container `database.edumaps` (IP LXC `172.19.198.3`); é o
    que o `backend.edumaps` (Perl + nginx/frontend) usa via `host=Database`
    (ver `edu_maps.conf` no container). Só é acessível por SSH (porta 2032).
- **Deploy de banco:** `rex -H database.edumaps deploy_db_dev` (roda o sqitch
  **dentro do container atual**). NÃO confundir com `sqitch deploy dev_super`
  (roda contra `ubatexu.lan:5432` = cluster ANTIGO; lá o pgvector nem está
  instalado e a migration fica undeployed). Foi um engano inicial desta sessão.
- Para o R/eduBR local enxergar o banco ATUAL do app seria preciso um **túnel
  SSH** pelo host, ex.:
  `ssh -N -L 127.0.0.1:55432:localhost:5432 root@database.edumaps`
  (serviço com host=127.0.0.1 port=55432 dbname=edumaps_dev user=edumaps
  password=change_me). **Decisão do usuário: deixar como está** (sem túnel, sem
  repontar `[edumaps]`) — ele testa manualmente.

### Entregue nesta sessão — pgvector para similaridade escolar
- **PR #64** (`feat/pgvector-curadoria`) → `main`, merge commit **`a7466ad`**
  (2026-09-16). Agrupou 10 commits: pgvector (`b3c537a` db, `ede1ad7` backend),
  `column_descriptions` (`75e23fd` db), personas/Tech Lead/índice e memória
  (`678b0dd`, `177901d`, `7a38724`, `783cc19`, `52ef321`, `4f21638`, `e8c28b1`).
  Branch deletada; `main` == `origin/main` == `a7466ad`.
- Migration `school_embedding` (`data_pipeline/deploy|revert|verify` + plan):
  `CREATE EXTENSION vector`; `analytics.school_embedding(co_entidade PK,
  embedding vector(6))`; backfill dos 6 scores de `clean.mv_escolas_scores`;
  índice HNSW `vector_cosine_ops`.
- Backend: `Schema::Result/ResultSet::SchoolEmbedding`
  (`similar_to($id, $limit, $municipio)`, cosseno `<=>`); `Task::SchoolEmbedding`
  (job Minion `refresh_school_embeddings`, registrado em `EduMaps.pm` em
  `EduMaps::Task::$_`); `School::Profile::panel_info` usa pgvector como caminho
  principal e mantém o `find_similar_schools` (Manhattan em memória) como
  **fallback**; teste `t/02-models/school/embedding.t` (skip se a tabela não
  existir no ambiente).
- Rexfile `deploy_db_dev`: pacote `postgresql-16-pgvector`.
- Deploy: `rex prepare` + `rex -H database.edumaps deploy_db_dev` +
  `rex -H backend.edumaps deploy_backend_dev` + restart de `edumaps-minion` e
  `edumaps-minion-analytics`.
- Validação no container `database.edumaps`: pgvector 0.8.6; **180.540**
  embeddings; índice `idx_school_embedding_hnsw`; API
  `GET /api/school/35007656/panel/info` retorna `similar_schools` via pgvector
  (distância do 1º vizinho `0.001484` = query direta); job
  `refresh_school_embeddings` → `finished` (`refreshed: 180540`).
- Testes: `t/02-models/school/profile.t` OK; `searching.t` falha **idêntica sem
  as mudanças** (pré-existente/data). O harness do repo (`Imports.pm`) exige
  **Perl 5.38** — o container tem 5.36, então os testes rodam só localmente.
- Tentativa de `sqitch deploy dev_super` (cluster ANTIGO, `ubatexu.lan:5432`)
  falhou: `extension "vector" is not available` (pgvector não instalado lá). Sem
  estado parcial (transação abortada; segue undeployed). Não instalar pgvector
  no cluster antigo — o app usa o container atual.
- Migration `column_descriptions` (`75e23fd`): 46 `COMMENT ON COLUMN` (PT-BR,
  foco em porquê/uso) para `school_embedding`, `event_store`, `mv_escolas_scores`,
  `censo_escolas` (geometry/nro_etapas), `school_indicators` (geometry/nro_etapas)
  e `mv_rede_escolas` (26); `cluster_*` (runtime) via `DO` condicional
  (`information_schema.columns`). Deploy via `rex prepare` + `deploy_db_dev`;
  validado: 0 colunas sem descrição nas 6 tabelas.

## Sessão anterior — LandPage, logo SVG e navegação

### Entregue (direto em `main`, sem PR) + deploy
- Commits: `4fbbd4d feat(frontend): landpage, logo e navegação` e
  `8072027 docs: deploy obrigatório no workflow`.
- **Deploy rodado** (Rex `backend/script/deploy/Rexfile`): `rex prepare` (3 hosts)
  + `rex -H backend.edumaps deploy_frontend_dev` — OK. Validado no container:
  `GET /` 200 e `GET /favicon.svg` 200 (build com "Ferramentas analíticas" no
  bundle). **Fix**: `/favicon.svg` não existia (404) e era referenciado no
  `index.html` e no `includeAssets` do PWA.

### O que foi feito
- **Logo** `src/shared/ui/components/Logo.svelte`: glifo SVG único (viewBox
  48×48) — pin de mapa + livro aberto + três barras ascendentes (mapas,
  educação, censo/análise). Props `size` e `variant` (`brand` azul p/ fundo
  claro; `light` pin branco p/ o nav). Sóbrio (azul `#1e40af` + branco), sem
  gradiente. `public/favicon.svg` = versão simplificada (pin + livro) para
  legibilidade a 16px.
- **LandPage** feature nova `src/features/home/` (`HomePage.svelte` + `index.js`
  + teste): hero com logo, tagline e CTAs (Buscar escola → `/escola/search`;
  Ver análises → `/cluster/geotag`) + 4 pilares (Mapas, Educação, Censo Escolar,
  Ferramentas analíticas).
- **Rotas/nav**: `routes.js` ganhou `/` → `HomePage`; removido o `$effect` de
  redirect `/`→`/about` no `App.svelte`; `NAV_LINKS` = Home · Busca Escola ·
  Análises · Sobre o Refactor; marca no nav com logo + "EduMaps".

### Testes
- `routes.test.js` (+2: `/` e `/cluster/geotag`) e `HomePage.test.js` (3).
  Suíte: **129/133** (4 falhas pré-existentes: `paginationStore` ×3,
  `SchoolRankingPage` ×1). `npm run build` OK.

### Convenção nova
- **AGENTS.md Workflow passo 4**: "Deploy (sempre)" — todo ciclo termina com o
  deploy via Rex, rodando de `backend/script/deploy` (`rex prepare` antes de
  qualquer task de código, pois `deploy_backend_dev` não faz rsync).

## Sessão anterior — Rótulos em linguagem natural e legenda clicável nos clusters

### Mergeado
- **PR #62** (`feat/cluster-rotulos-natural`) → `main`, merge commit **`b9cd252`**,
  merge em 2026-09-14. Commits: `4335430` (analysis), `b608d92` (backend),
  `1e1e82c` (frontend), `4f5564b` (docs: skill frontend-svelte), `fe06dd8`
  (docs: nota técnica 39 + regra de nota no workflow). Branch deletada; `main`
  == `origin/main` == `b9cd252`. **Working tree limpa.**

### Entregas
- **R (edumapsr)**: módulo `R/cluster-labels.R` (`.label_scale` com escala 2→
  baixa/alta, 3→baixa/média/alta, 4→muito baixa/baixa/alta/muito alta, 5→muito
  baixa…muito alta, **≥6→fallback inteiro** `Cluster 1..N` 1=baixo N=alto;
  `.cluster_scores` = média por feature min-max × polaridade; `.cluster_labels`);
  `analyze_cluster` lê `parameters$labeling` (`concept`/`gender`/`directions`) e
  gera `cluster_label`/`cluster_rank` em `tables$clusters` e `data`;
  `repository-postgres-cluster.R` grava as duas colunas in-place + `extra_metrics`
  (JSON). `DESCRIPTION` ganhou `cluster-labels.R` no `Collate`.
- **Backend**: `Presets.pm` com `concept`/`gender`/`directions` (única negativa:
  `prop_sem_especializacao` = −1); `request_cluster` injeta `labeling`;
  `Task::Clustering` repassa nos `parameters`; `Model::Cluster` expõe
  `cluster_label`/`cluster_rank` no GeoJSON + `cluster_summary` + rota
  `GET /api/cluster/summary`.
- **Frontend**: legenda com rótulo semântico e **clicável on/off por grupo**
  (`aria-pressed`, `hiddenIds` = `$state(new Set())` reatribuído); popup com
  rótulo; `ClusterSummaryTable.svelte` (rótulo + nº escolas + top indicadores);
  `getClusterSummary()`.

### Detalhes de implementação (importantes)
- `analytics.clustering_metadata.extra_metrics` é gravado pelo R como **ARRAY**
  `[{...}]` (não objeto) → no Perl normalizar (se ARRAY, pegar `->[0]`).
- JSON do banco vem utf8-flagged (`pg_enable_utf8=1`); decodificar com
  `$self->json->utf8(0)->decode(...)` (padrão do projeto — sem `utf8(0)`, "Média"
  quebra e o rótulo cai no fallback).
- Conceito/gênero por preset: infraestrutura "qualidade de infraestrutura" (f),
  docência "qualidade da docência" (f), desempenho "desempenho dos alunos" (m).

### Validação
- R: `test-cluster-labels.R` (12) + `test-cluster.R` verdes (`R CMD INSTALL` OK).
- Backend: `cluster.t` 10, `task.t` 19, `network/schools.t` 4 — verdes.
- Frontend: cluster-geotag 7/7; suíte 123/127 (4 pré-existentes). Build OK.
- E2E deploy (Ubatuba 3555406): infra k=3 → baixa/média/alta; desempenho
  k=3/2023 → baixo/médio/alto; infra k=6 → `Cluster 1..6`. `/api/cluster/summary`
  e GeoJSON com `cluster_label` OK.

### Convenções novas registradas
- **AGENTS.md Workflow passo 6**: gerar nota técnica (`notas_tecnicas_N.md` em
  `docs/new_ideas/implementations_ideas/`) ao fim de cada ciclo (1–2 PRs, 1–2 dias).
- **Skill `frontend-svelte`**: padrão de "marcadores acionáveis quando representam
  grupos" (legenda clicável) + dicas de teste (polling 1500ms → `timeout: 3000`).

## Sessão atual — Presets de indicadores na clusterização (censo + docentes + IDEB)

### Mergeado
- **PR #61** (`feat/presets-multitabela`) → `main`, merge commit **`cb5e8f4`**,
  merge em 2026-09-14. Commits: `08b891e` (db), `c42b58c` (backend),
  `779873a` (frontend). Branch deletada (remoto e local). `main` após FF =
  `cb5e8f4`.
- Fechamento: `03410cc` docs (memory), depois **`62aa757` chore: commit fontes
  pendentes e ignora artefatos R** — commitou os pendentes antigos
  (`EventBus/Middleware/SiopeTask.pm` info→error, `script/tasks/siope.pl`,
  `templates/osm/query/school.opq.ep`, `map_app/src/lib/js/city.js`) e
  gitignoreou `analysis/edumapsr/edumapsAnalytics.Rcheck/` e
  `edumapsAnalytics_*.tar.gz` (artefatos de R CMD check regeneráveis, não
  voltam a sujar o status). **Working tree limpa ao fim da sessão.**
- **Limpeza de branches obsoletas** (2026-09-14): removidas do remoto e local
  as mergeadas `feat/presets-multitabela`, `feat/cluster-geotag-map`,
  `feat/backend-analytics` e `dev/feat/frontend/toast`. Aprendizado: `git push
  origin --delete` com vários refs aborta se um deles não existir (refs já
  apagadas no PR merge ficam como "remote ref does not exist") — deletar um por
  vez. **Remanescentes com trabalho não mergeado (NÃO apagar sem acordo)**:
  `feat/deploy/docker` (`6c7d9ce` adapt edumaps for docker) e
  `fix/backend/schoolgrade` (`8d98de1` School code missing in School Grade).

### Entregas
- **db**: migration `school_indicators` (`deploy/revert/verify` + `sqitch.plan`):
  tabela denormalizada `clean.school_indicators` (censo + docentes + IDEB),
  com `col_description` (comments PT-BR) usados no autocomplete.
- **backend**: `EduMaps::Presets` (3 presets: infraestrutura, docência,
  desempenho; ordem fixa `@PRESET_IDS = qw(infraestrutura docencia desempenho)`;
  `INDICATORS_TABLE`); endpoints `GET /api/cluster/{presets,columns,years}`;
  `request_cluster` (POST /api/task/cluster) aceita `preset`/`ano_ideb` e valida:
  **400** p/ preset desconhecido e p/ preset `year_filter` sem `ano_ideb`; com
  preset força `schema=clean`, `table_name=school_indicators`,
  `id_column=co_entidade`; `Task::Clustering::_rebuild_indicators` faz
  TRUNCATE+INSERT na tabela para o `ano_ideb` escolhido (via `Mojo::Pg`,
  `->hash`/`->array` NÃO `->first`); `Model::Cluster` lê
  `clean.school_indicators` (existence check + `cluster_geojson_query`).
- **frontend**: `PresetSelector`, `FeatureSelect` (autocomplete com comments +
  tags de fonte `SOURCE_LABELS`/`featureLabel`), seletor de ano IDEB/SAEB;
  página cluster/geotag com preset default `infraestrutura`, guarda de ano p/
  desempenho, payload com preset/features/ano_ideb.

### Dados/descobertas
- **IDEB**: `clean.ideb_notas_escolas` tem múltiplos rows por `(id_escola, ano)`
  por etapa (814.448 linhas; 58.884 pares escola/ano; 84.555 escolas; 97.615 em
  2023) → o rebuild agrega por escola com `AVG(ideb)` entre etapas. `id_escola`
  é a coluna do IDEB (não `co_entidade`). Contagens do rebuild: total 214.192,
  com_docentes 178.473, com_ideb_2023 **68.923**, ideb_médio 5.14, lic_media 0.796.
- Censo escolar/docentes só têm `nu_ano_censo = 2025`; docentes join por
  `co_entidade + nu_ano_censo`; IDEB por `i.id_escola = e.co_entidade AND i.ano = ?`.
- **Ambiente duplo**: o container usa DB separado — `backend` conf conecta em
  `Database` LXC (`postgresql://edumaps:change_me@Database/edumaps_dev`), que é
  **diferente** do `edumaps_dev@ubatexu.lan` (devel). Migration aplicada via
  `sqitch deploy db:pg://edumaps:change_me@localhost/edumaps_dev` no
  `database.edumaps` (estava 2 changes atrás).
- Falhas pré-existentes do frontend seguem: `paginationStore ×3` e
  `SchoolRankingPage ×1` (rota `/escola/search` vs `/busca`). Cluster-geotag 6/6.

### Validação
- Testes backend: `cluster.t` 9, `task.t` 19, `network/schools.t` 4 — PASS.
- E2E no deploy: jobs Minion Ubatuba 3555406 — desempenho/2023 (job 5865)
  → rebuild 214.192 e clusters 1-5 (47/3/18/7/9 + 2 sem nota); infraestrutura
  (job 5866) sem ano → clusters 1/3/4. GeoJSON com `cluster_id` OK.
  `/api/cluster/presets|columns|years` OK. `edumaps-analytic.service` (backend)
  segue failed (legado; Plumber real roda em `analytic.edumaps:8000`, ativo).

## Sessão atual — Fix lite app nos scripts dev/entrypoint

- **Problema**: usuário reportou que a "App lite" `backend/edu_maps.pl`
  (Mojolicious::Lite, sem `/api/network`, `/api/task/cluster` e cluster geotag)
  subiu novamente na instância do backend. O fix anterior só corrigiu as units
  systemd no Rexfile; **`backend/dev_run.sh` (líneas 59-60) e
  `backend/docker-entrypoint.sh` (28,30) ainda iniciavam `edu_maps.pl`**
  (`morbo ./edu_maps.pl` e `./edu_maps.pl minion worker`) → qualquer subida via
  dev_run/entrypoint (manual ou Docker) voltava a expor a lite app.
- **Verificação nos containers**: `edumaps-web` segue correto — morbo em :3000 é
  `/opt/edumaps/backend/script/edumaps.pl` (sha256 == repo,
  `Mojolicious::Commands->start_app('EduMaps')`); `/api/network/3551702/summary`
  → 200; rota lite `/api/query-osm` → 404. Daemon local `127.0.0.1:3999`
  (classe app) intacto.
- **Fix**: `dev_run.sh` e `docker-entrypoint.sh` passam a usar
  `script/edumaps.pl` (morbo e worker). `bash -n` OK; sincronizado também em
  `/opt/edumaps/backend` no container.
- **Commit**: `edbdf3d fix(backend): dev scripts sobem classe app` — direto em
  `main` (sem PR), push para `origin/main` (a6acae7..edbdf3d) em 2026-09-14.
- **Obs.**: `edumaps-analytic.service` apareceu **failed** no backend.edumaps —
  ainda não investigado (usuário não pediu).

## Sessão anterior — Mapa de cluster por geotag (R + API + frontend)

### Mergeado
- **PR #60** (`feat/cluster-geotag-map`) → `main`, merge commit **`b290caa`**, merge em
  2026-09-14. Commits: `958b10e` (analysis), `877fb16` (backend), `9a224c6` (frontend).
- Deployado (as-is) e validado nos containers: `rex prepare` + restart
  `edumaps-web`/`edumaps-minion`/`edumaps-minion-analytics`/`edumaps-analytic` +
  `deploy_frontend_dev`. E2E no container: POST /api/task/cluster (Ubatuba
  3555406) → 202 → poll REST active→finished → GET /api/cluster/schools 200,
  78 features, cluster_ids [1,2,3].

### Bug de contrato: job_progress era SSE, frontend esperava JSON
- `GET /api/task/progress` usava `monitor_job` (SSE `text/event-stream`,
  `write_sse`) — frontends antigos (map_app) consomem via EventSource. A página
  nova (Svelte) fazia `fetch`+`json()` e parseava a stream → "Erro ao gerar os
  clusters." **Fix**: `Controller/Task.pm::job_progress` detecta `Accept`; sem
  `text/event-stream` retorna **JSON** `{state, error?}` por poll (state
  `inactive|active|finished|failed`; `failed` expõe `job.error // job.result`,
  com suporte a hashref `{error}`). EventSource legado permanece no caminho SSE.
  Job inexistente → 404.
- Teste: `Minion::Job->fail` em job `inactive` retorna **undef** (backend exige
  job `active`/dono worker). Para testar `failed` de forma determinística:
  `worker->register` + `worker->dequeue(0, {queues=>[...]})` (in-process) e
  depois `$job->fail(...)`. Fila descartável `zzz_progress_test` isola de
  workers de dev ao vivo (um worker local rodando consumia os jobs dos testes e
  marcava "Invalid arguments!").
- No dev local existe Postgres em `localhost:5432` (DB `edumaps`, user
  edumaps) — serviço pg `edumaps_local` do libpq. O Plumber **local** escrevia
  nele, mas o backend lê `edumaps_dev@ubatexu.lan` (serviço `edumaps`) →
  `cluster_id` nunca aparecia. Fix no `package.json` dev: o R sobe com
  `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps` (e `ACCEPT` prefixado com `env`, pois
  entr executa via execvp e não passa env de outros comandos do pipe). Nos
  containers o pg_service `edumaps_local` aponta pro Database, então não há
  mismatch lá.

### R analytics — robustez e filtro
- `analyze_cluster` ganhou `filter` (igualdade por coluna — ex. `{co_regiao:
  3, co_uf: 35, co_municipio: 3555406}`), suportado no api.json/endpoint.R e
  no `Client`/`Task::Clustering` (repassado ao motor). Backend converte
  `codigo_regiao/uf/ibge` → `co_regiao/co_uf/co_municipio`.
- Bug NA: kmeans com 2/86 linhas NA em Ubatuba → `NA/NaN/Inf in foreign
  function call (arg 1)`. `analyze_cluster` agora dropa linhas incompletas
  (`complete.cases`, alinhado com entity_ids), descarta colunas com variância
  zero e valida `nrow<2`, 0 features, `clusters >= n`. Erro do Plumber
  mascarava detalhe: `_post` do `Analytics::Client` concatenava `ARRAY(0x...)`;
  agora join de `ARRAY` de erros (`; `).

### Deploy: pacote reinstalado no container analytic
- `rex prepare` só rsync a **fonte**; o serviço `edumaps-analytic` roda
  `Rscript inst/plumber/run.R` com `library(edumapsAnalytics)` → as funções vêm
  do pacote **instalado** (site-library `/usr/local/lib/R/site-library`), que
  estava defasado (o mesmo NA bug aparecia no container). Redeploy do código R
  exige `R CMD INSTALL .` (env `R_LIBS` + `LC_ALL=C.UTF-8`) e `stop/start`
  (verificar MainPID). Container volume em 8000.

### Backend
- `POST /api/task/cluster` aceita corpo `application/json` (validação
  normalizada: `validator->validation` + `$v->input($input)`, gate `has_error`,
  `features` lido direto do array — `param` achata arrays). Form continua
  suportado.
- Novas rotas `GET /api/cluster/schools|regions|ufs|municipalities`
  (`EduMaps::Controller/Model::Cluster` + plugin API). `clustered_schools`
  lê coluna dinâmica `cluster_id` (criada pelo R via `ADD COLUMN IF NOT
  EXISTS`) via SQL raw + `bigquery json` → GeoJSON FeatureCollection.
- `frontend/edumaps`: página `/cluster/geotag` (cascata região→UF→município,
  12 indicadores default, kmeans/gmm/spectral/dbscan, polling 1.5s, mapa
  Leaflet cor por `cluster_id`), MSW + testes. `DEFAULT_FEATURES` valida
  contra schema — `qt_prof_docentes` não existe; usa `qt_prof_pedagogia`.

### Pendências / fora do escopo (não entraram no PR)
- `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (M), untracked:
  `analysis/edumapsr/edumapsAnalytics.Rcheck/`, `edumapsAnalytics_0.1.0.tar.gz`,
  `backend/script/tasks/`, `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`.
- Check "Workers Builds: edumaps" no GitHub **falha** e deve ser **desconsiderado**:
  a conta Cloudflare NÃO está configurada neste projeto (não há integração
  real; o build é órfão). Não é required → nunca bloqueia merge (estado
  UNSTABLE, não BLOCKED). PR #60 mergeou normalmente.
- Limitação legada do R: `/summary` com sub-análises (score_distributions,
  school_clusters) aceita mas não persiste (repo só faz full_summary).

## Sessão anterior — Deploy e2e do motor http (Plumber) nos containers

### Implantado e validado
- `rex prepare` + `deploy_analytics_worker_dev` (worker fila `analytics`
  ativo no backend) + `deploy_analytics_dev` no container analytic.
- Primeiro `deploy_analytics_dev` falhou: `R CMD INSTALL` sem `dbscan`,
  `mclust`, `kernlab` (deps de algoritmos de clustering). Corrigido no
  `Rexfile` (install.packages) — commit **`4ba80e9` feat(deploy): engine
  http padrao e deps dbscan mclust kernlab** (também flippa
  `analytics_engine: http` no template `files/edumaps_db.conf`).
- Container backend: `analytics_url => http://analytic:8000`, engine `http`
  (manual na config deployada). Serviços `edumaps-web`/`edumaps-minion`/
  `edumaps-minion-analytics` ativos.

### Correções no edumapsr (deploy)
- **`e0e9d56` fix(analysis): escopo do pacote no Plumber**:
  - `run.R` usava só `requireNamespace` → exports NÃO estavam na search path
    e os handlers do Plumber não achavam funções do pacote. Adicionado
    `library(edumapsAnalytics)` no branch do pacote instalado.
  - `analytics_db_connection()` é **interna (não exportada)** — qualificada
    com `edumapsAnalytics:::` no `endpoint.R` (3 chamadas: /cluster,
    /summary, /similarity/db).
  - `Sys.setlocale("LC_ALL", "C.UTF-8")` no run.R p/ silenciar warnings
    "cannot be translated to UTF-8" (strings marcadas como native no parse).
    Na prática, só removeu os warnings após re-instalar o pacote com
    `LC_ALL=C.UTF-8 R CMD INSTALL`.
- **`d885787` fix(analysis): serializa metricas com tabelas R em JSON**:
  - `analyze_city_summary` usava `table(data$dependencia)` em metrics; o
    repositório `persist_city_summary` serializava `result$metrics` direto
    com `jsonlite::toJSON` → **"No method asJSON S3 class: table"** → 500 em
    /summary. Correção na raiz: `as.list(table(...))` (lista nomeada).
  - `view-json.R::as_json_scalar` agora converte objects `table` em objetos
    JSON nomeados (defesa). Sem isso os testes de `/summary` quebrariam se
    alguma métrica voltasse a ser `table`.

### E2E validado (via curl nos containers)
- `POST http://analytic:8000/cluster` (staging.test_cluster, 500 escolas)
  → JSON com `data`, `metrics`, `tables`; persiste `cluster_id` na tabela e
  3 linhas em `analytics.clustering_metadata` (run_id `run_<ts>`).
- `POST /api/task/cluster` (backend, form-encoded) → job Minion **finished**
  (job 5858, fila `analytics`, worker dedicado). O server Plumber responde mas
  pode levar >120 s em tabelas grandes (kmeans sobre clean.escolas inteiro
  estourou timeout — usar tabela reduzida ou aumentar `analytics_timeout`).
- `POST /summary` (clean.escolas 3106200, full_summary) → 200, persiste em
  `analytics.city_school_analytics` (summary_data jsonb, distribuicao por
  dependência como objeto).
- `POST /similarity/db` (staging.test_cluster, k=5, gower) → 200, persiste em
  `analytics.similarity_pairs` (append por run).
- Limitação descoberta: `/summary` com `type=score_distributions`/
  `school_clusters` retorna 500 ("repository espera um resultado
  city_summary") — o repo só persiste `full_summary`; sub-análises
  (SKIPPED) não são persistidas. Endpoint aceita, mas não persiste.

### Descobertas de operação
- Serviço `edumaps-analytic` roda `Rscript inst/plumber/run.R` com
  `WorkingDirectory=/opt/edumaps/analysis/edumapsr` (FONTE rsyncada), NÃO o
  pacote instalado (site-library). Depois de `R CMD INSTALL` é obrigatório
  `systemctl stop/start` (só `restart` mantém MainPID antigo às vezes) e não
  esconder o erro: **verificar `systemctl show ... --property=MainPID`**.

## Sessão anterior — Migração das análises R::Pipe → Plumber (edumapsr), Fase 3 concluída

### Fase 1 completa (commits)
- **`d79d427` feat(analysis): endpoints plumber cluster/summary e repos** —
  edumapsr ganhou POST `/cluster`, `/summary`, `/similarity/db` + facades e
  repos S3 persistentes (staging cluster_id via temp table, upsert
  `city_school_analytics`, append `similarity_pairs`). 147 testes testthat PASS.

### Fase 2 completa (commits)
- **`5f110c6` feat(backend): connector Perl <-> Plumber**:
  - `EduMaps::Analytics::Client` — chamadas HTTP **síncronas** (`Mojo::UserAgent`
    bloqueante), endpoints `/cluster|summary|similarity/db|chart|health`.
  - Cache compartilhado `analytics.analysis_cache` com chave **canônica**
    (`JSON::PP->canonical` + `Mojo::Util::sha1_hex` de `{analysis, params,
    source_version}`), estável entre processos (hash ordering do Perl era
    aleatória por processo!). **Escopo do cache inclui dados afetam o resultado**:
    `/summary` keyed por `codigo_ibge+schema+parameters`; `/cluster` por
    `schema+table_name+id_column+features+parameters` (NÃO `output_schema`).
    Read-through p/ cluster e city_summary; similaridade (pares O(n²))
    **nunca é cacheada**.
  - Descobertas Mojo nesta versão (site_perl 5.42.0):
    - `Mojo::Util::sha1_hex` existe mas NÃO está em `@EXPORT_OK` — chamar
      **fully-qualified** (`Mojo::Util::sha1_hex(...)`), senão
      `use Mojo::Util qw(sha1_hex)` falha em `perl -c`.
    - `use Mojo::JSON qw(encode_json decode_json)` numa classe com
      `Mojo::Base -base, -signatures` dispara **prototype mismatch** — usar
      `use Mojo::JSON;` + chamadas `Mojo::JSON::encode_json(...)`.
    - `Mojo::Server::Daemon` embutido + `ua->get(...)->result` bloqueante NÃO
      funcionam no mesmo processo nesta versão (eventloop): para emular o
      serviço no teste, o server roda em um **fork** (loop dedicado) e o
      `port` chega por arquivo temp (`/tmp/user/1000/opencode/...`); polling de
      prontidão via `IO::Socket::INET`. Test2 usa `$?` p/ o exit code → após
      `waitpid` do filho (killed por TERM) é **obrigatório `$? = 0`**, senão o
      teste sai com exit 15.
  - **Plugin** `EduMaps::Plugin::Analytics` registrado no startup (`EduMaps::
      Plugin::Helpers` + `Analytics`); helper `analytics` (client singleton com
      `app` fraco). Config keys: `analytics_url` (default
      `http://analytic:8000`), `analytics_timeout` (300),
      `analytics_source_version` ('edumapsr-0.1.0'), `analytics_cache_enabled` (1).
      **TODO**: adicioná-las ao `edu_maps.conf` (não versionado) na F6.
  - Teste `backend/t/03-plugins/analytics.t` — **9 subtests PASS** (server fork,
    run_cluster/summary/similarity_db/health, croak em 500, chave canônica,
    escopo por codigo_ibge/table/features, read-through s/ DB = no-op).
  - Verificações: `perl -c` OK nos 3 arquivos; `t/01-app/basic.t` (boot da app)
    e `t/03-plugins` PASS.

### Fase 3 completa (commits)
- **`deedd23` feat(backend): tasks R com analytics_engine http|pipe**:
  - `EduMaps::Plugin::Analytics` ganhou `DEFAULT_ENGINE ('pipe')` e nova config
    key **`analytics_engine`** (`'http'` Plumber via Client | `'pipe'` legado),
    exposta pelo helper `$app->analytics_engine` (lida no register, default
    `pipe` — mantém prod e `t/05-tasks` estáveis).
  - `EduMaps::Task::Clustering`: dispatch por engine. HTTP →
    `$job->app->analytics->run_cluster({schema, table_name, id_column,
    features, parameters => {algorithm, clusters, eps, min_pts}})`. Validação
    ganhou campo opcional `features`. Pipe intacto (Rscript via R::Pipe).
  - `EduMaps::Task::Similarity`: HTTP → `run_similarity_db` (gower), com
    **falha explícita** p/ métricas não-gower no motor http (mensagem instrui
    usar `pipe`); pipe mantido p/ demais métricas.
  - `EduMaps::Task::CityAnalytics`: HTTP → `run_summary({codigo_ibge, schema,
    parameters => {type}})`. O contrato `{meta, cluster_info|similarity_info|
    analytics_info{r_meta}}` é preservado; `r_meta` = resposta JSON do endpoint
    (o serviço Plumber já persiste cluster_id/summary/pairs no banco).
  - Contrato de job preservado em todos os motores (query_args/inject_args
    iguais; só `r_meta` muda de origem: R::Pipe → HTTP).
  - Teste **`backend/t/05-tasks/analytics_engine.t`** — **5 subtests PASS**
    (server-fork emulando /cluster, /summary, /similarity/db):
    - `analytics_engine` helper reflete config; cluster via http engine
      (r_meta.analysis = 'cluster_kmeans', run_id do endpoint); similarity
      gower ok; similarity não-gower → job `failed` com mensagem; city_analytics
      via http (r_meta.analysis = 'city_summary').
    - Lição: `apply_city_analytics` enfileira na fila **'speculative'**
      (prioridade 0), que `minion->perform_jobs` NÃO processa (só fila
      'default') — no teste, enfileirar direto com
      `minion->enqueue(city_analytics => [$args])` para a fila padrão.
  - `perl -c` OK nos 4 módulos alterados.

### Fase 4 completa (commits)
- **`f195898` feat(data_pipeline): analytics.analysis_cache** — migration
  sqitch `analytics_analysis_cache` (`deploy/revert/verify` + `sqitch.plan`,
  dep `[schemas]`): tabela no schema `analytics` com PK `cache_key` (text,
  sha-1 canônico do Client), `analysis`, `params` jsonb, `payload` jsonb,
  `source_version`, `created_at`/`updated_at`/`expires_at` timestamptz;
  índices (analysis, source_version) e parcial em expires_at. Comentários PT-BR
  em todas as colunas. **Deployado e verificado em dev_super** (`edumaps_dev`);
  upsert real validado em psql com o mesmo SQL do `Client::_cache_write`.

### Fase 5 em aberto
- Rotas web `POST /api/task/{cluster,summary,similarity}`.

### Fase 5+6 completas (commits)
- **`0fcc56e` feat(backend): rotas web POST /api/task/{cluster,summary,
  similarity}**:
  - `EduMaps::Controller::Task` ganhou `request_cluster/request_summary/
    request_similarity` (padrão de `request_siope`: valida → enfileira →
    202 + `Location: /api/task/progress?job_id=X`).
  - Validações espelhadas nas tasks: cluster (table_name/id_column/schema/
    algorithm/clusters/eps/min_pts/features), summary (codigo_ibge 7 dígitos/
    analysis/schema), similarity (table_name/id_column/schema/metric — 5
    métricas, inclusive aitchison/dtw).
  - **Fila dedicada `analytics`**: rotas web enfileiram por
    `minion->enqueue(...)` direto em `{queue => 'analytics'}` — worker
    analítico separado do worker geral (Siope/OSM). `apply_*` seguem na fila
    default (t/05-tasks intactos). `/summary` NÃO usa `apply_city_analytics`
    (fila 'speculative' + CHI) por ser user intent.
  - Teste `backend/t/04-api/task.t` — 7 subtests PASS (202+job_id+Location+
    queue analytics p/ os 3; 400 p/ validações).
- **`7381eef` feat(deploy): worker fila analytics + pg_service.conf +
  config**:
  - systemd `files/edumaps-minion-analytics.service` + task Rex
    `deploy_analytics_worker_dev`: worker `minion worker -q analytics`.
  - `files/pg_service.conf` (deploy em `/root/.pg_service.conf`): serviços
    `[edumaps]` e `[edumaps_local]` — R codifica `service="edumaps_local"`
    por default/`EDUMAPS_ANALYTICS_DB_SERVICE`; antigamente o arquivo só
    tinha `[edumaps]` (conexão R falharia p/ `edumaps_local`).
  - `files/Renviron` + `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps_local`.
  - **Config `analytics_*`** adicionada ao template `files/edumaps_db.conf`
    (backend dos containers) e ao `backend/edu_maps.conf` local (não
    versionado): `analytics_url` (`http://analytic:8000`, env-overridable
    `ANALYTICS_URL`), `analytics_timeout` (300), `analytics_source_version`
    ('edumapsr-0.1.0'), `analytics_cache_enabled` (1), **`analytics_engine`
    ('pipe'** — OPCIONAL, trocar p/ 'http' p/ ativar o Plumber).
  - Validações: Rexfile syntax OK; suite verde (t/01-app, t/03-plugins,
    t/04-api, t/05-tasks/analytics_engine); **clustering.t (pipe) PASS** —
    motor legado intacto após F3.

### Estado
- F1–F6 concluídas e commitadas em `main`.
- **Aplicar no ambiente** (pendente de validação/acordo): rodar
  `rex prepare` (rsync) + `deploy_analytics_worker_dev` (novo worker) +
  `deploy_analytics_dev` (pg_service.conf/Renviron) no backend/analytic e, se
  for ativar Plumber, flippar `analytics_engine: http` na config dos
  containers.
- **Fase 6/7**: infra `pg_service.conf` + worker fila `analytics` + docs.

### Fora de commits (segue)
- WIP `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info→error).
- untrackeds: `backend/script/tasks/siope.pl`,
  `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`, e artefatos R CMD check
  (`analysis/edumapsr/edumapsAnalytics.Rcheck/`,
  `analysis/edumapsr/edumapsAnalytics_0.1.0.tar.gz`).
- Commit: hook post-commit quebrado (`GIT_DIR: unbound variable`) — esperado.

## Ciclo anterior — limpeza: gitignore + reorganização docs (concluído)

### Fechamento do ciclo anterior (2026-09-13)
- PR #57 mergeado em `main` (commit de merge `9361604`; branch
  `fix/deploy-backend-class-app` removida local e no remote). Ciclo de deploy
  encerrado após validação ponta a ponta nos containers.

### Limpeza — `.gitignore`
- Adicionados (artefatos de build/gerados e config local):
  `analysis/edumapsr/man/*.Rd` (roxygen2), `backend/cover_db/` (Devel::Cover),
  `data_pipeline/config/local.ini`.
- Apagado `backend/t/05-tasks/edumaps-analysis/similarity.t` (0 bytes).
- `frontend/*/node_modules` e `dist` já cobertos pelos `.gitignore` aninhados.

### Limpeza — reorganização de `docs/`
- **Estrutura nova**: `docs/archive/` (com `README.md` índice 1 linha/arquivo) e
  `docs/new_ideas/{implementations_ideas,concepts}`. Decisões do usuário:
  "recentes" = notas de 16-07 a 16-08; arquivar (não excluir) as datadas;
  `nvim.md` excluído; versionar os docs (eram untrackeds).
- **→ `new_ideas/implementations_ideas/`**: `notas_tecnicas_20` (score IQE),
  `_24` (Painel do Diretor), `_26` (plotly/ggplot2 via Perl), `_29` (EventBus
  frontend sem RxJS), `_32` (Stats::Model), `_34` (pré-computação especulativa).
- **→ `new_ideas/concepts/`**: `notas_tecnicas_17` (arquiteturas maduras),
  `_18` (similaridade por domínio).
- **→ `archive/`**: todas as demais notas (mais de 40) + idea antigas
  (`ideas.md`, `IA/*`, `analytics/*`), incluindo as 5 datadas
  (`deep.md`, `system_cloud_administration.md`, `random_forest.md`,
  `notebook-analises-censo-rankings.md`, `prompt/claude/clusterization.md`).
- **Atenção**: recuperei via container (`backend.edumaps:/opt/edumaps/docs`)
  7 arquivos apagados por engano do meu `rm -rf dev` (loop abortou por
  `mv dev/prompt`): `refactor.md`, `refactor_ui.md`, `testes.md`,
  `regressao_linear.md`, `system_cloud_administration.md`, `user_history_1.md`
  e `prompt/claude/clusterization.md`. Todos restaurados em `archive/dev/` com
  mtimes originais. Lição: `mv` de dir com loop tem que tolerar "dir not empty".
- **Ajustadas** referências: `.opencode/skills/r-analytics.md`
  (`docs/IA/clusters.md` → `docs/archive/IA/clusters.md`).

## Sessão anterior — Deploy/validação dos containers após remoção do submodule (concluída)

### Fechamento (2026-09-12)
- **Backend do container agora roda a classe `EduMaps`** (`script/edumaps.pl`)
  com todos os deps do `cpanfile` instalados (CHI, Strptime, RxPerl, Data::Fake,
  PDL, PDL::Stats::Kmeans etc. via cpanm/metacpan; PDL::Stats build OK no
  container). Units `edumaps-web`/`edumaps-minion` ativos; boot loga
  "EduMaps inicializado com sucesso [v0.001]".
- **DB do container atualizado**: faltava `analytics.mv_rede_escolas` (roda o
  `sqitch deploy` no banco do container — `rex -H database.edumaps
  deploy_db_dev`); MV populada (15.352 linhas). `/api/network/3551702/summary`
  passou de 500 (relation não existe) → 200 JSON com dados.
- **`/api/analytics/cities/search`**: endpoint espera param `q` (mapa
  `term => [qw/q query/]` do Model City via ctx params). O controller não
  validava ausência de `q` → 500 (`No value to wrap` na croak de
  `_wrap_percent`). Corrigido com validação `required('q','trim')` + regex de
  acentos e subteste novo (sem `q` → 400). `use utf8;` adicionado ao controller.
- **Validação ponta a ponta (container, direto :3000 e via nginx `Host:
  ubatexu.lan`)**: `/api/network/{summary,schools,performance,markers}` 200;
  `/api/network/123/summary` 404 (validação ibge OK); `cities/search?q=` 200
  (incl. acentos), sem `q` 400, `?term=` 400; `/api/city/suggestions?q=` 200;
  `/api/analytics/city/3551702/details` 404 (dado ausente — esperado); SPA
  nginx 200; `/analytic-api/health` e `openapi.json` 200; analytic (Plumber)
  responde `{"status":["ok"]}`.
- **PDL::Stats::Kmeans instalado em background no container** (logo
  `/tmp/pdl_install.log`, PID 4113) — concluído OK (PDL-2.106 + PDL::Stats).
- **Testes locais**: `t/04-api/{network,search-analytic,search-municipio,
  municipio}` ok. Falhas PRÉ-EXISTENTES (verificadas com stash, fora do escopo):
  `municipio.t` #8 OSM features (falta dado OSM) e `school/clustering.t`
  (mensagem do controller "Dados não encontrados..." ≠ "Não encontrado").
- **Commits nesta sessão** (branch `fix/deploy-backend-class-app` → PR):
  `fix(backend): completa deps no cpanfile`,
  `fix(backend): deploy usa script/edumaps.pl p/ app classe`,
  `fix(backend): valida param q em cities/search`,
  `fix(analysis): run.R aceita pacote instalado`,
  `fix(frontend): remove import uuid no toastStore`.
- **Atenção workflow**: `deploy_backend_dev` **não** roda rsync (é o `prepare`);
  em mudanças de código rodar `rex prepare` antes para o container pegar o
  working tree.

### Objetivo desta sessão
- Validar o deploy adaptado (Rex `backend/script/deploy/Rexfile`) após a remoção
  do submodule `analytics`, deixando backend/frontend/analytics funcionando
  de ponta a ponta nos containers LXC.

### Estado atual (em progresso)
- **Diagnóstico do backend FECHADO** — o deploy sobe **outra app** que não a que
  tem `/api/network`:
  - O serviço `edumaps-web` roda `edu_maps.pl` (app **Mojolicious::Lite** com
    rotas inline /api/city, /api/analytics, /api/school, map_svelte, tasks OSM/
    Siope) — **SEM `/api/network` e SEM `/api/city/suggestions`**.
  - As rotas novas vivem na **classe `EduMaps`** (`backend/script/edumaps.pl` →
    `Mojolicious::Commands->start_app('EduMaps')`), registradas via plugins
    (SchoolNetwork, City c/ `/suggestions`, School, Task, Rank). É o que
    `t/04-api/network/*` testa (`Test::Mojo->new('EduMaps')`) e o que o frontend
    novo chama (grep do SPA: `/api/network`, `/api/city/suggestions`,
    `/api/school/search|suggestions`, `/api/analytics/cities/search`).
- **`backend/cpanfile` está incompleto** p/ a classe app:
  - falta `CHI` (usado em `lib/EduMaps/Plugin/Helpers.pm:6`) → classe app NÃO
    boots no container (`Can't locate CHI.pm`).
  - falta `DateTime::Format::Strptime` (em
    `lib/EduMaps/Roles/Business/School/Finance.pm:5`) → `Model::City` não
    compila → `/api/analytics/cities/search` retorna 500
    (`Can't locate object method "search_for_complete"`).
  - Ambas estão instaladas local (perl do sistema); verificado também SHA do
    container == repo p/ os plugins API.
- Evidências: `carton exec perl edu_maps.pl routes` no container mostra a lista
  completa de rotas do Lite (sem network); grep `api/network/:codigo_ibge` na
  pág 404 = 0; boot do Lite loga `Error loading EduMaps::Model::City: Can't
  locate DateTime/Format/Strptime.pm` e `✓ Loaded: Model::SchoolNetwork`.
- 404 do `/api/network/3551702/*` no backend do container = rota inexistente
  (não é 500 nem controller). O antigo processo (841) também não tinha network.

### Decisão pendente (aguardando usuário)
- **Trocar alvo do deploy p/ a classe app** (`script/edumaps.pl`) + adicionar
  deps ao cpanfile + redeploy (plano proposto na sessão), **OU** registrar as
  rotas novas no Lite `edu_maps.pl`. Recomendado e alinhado aos testes: **classe
  app**. Observação: rotas legadas do Lite (/api/query-osm, /api/jobs/siope,
  map_svelte) não são usadas pelo frontend novo; SPA estático é servido pelo
  nginx (frontend deploy), não pelo backend.

### Plano proposto (aguardando OK do usuário)
1. `backend/cpanfile`: adicionar `CHI` e `DateTime::Format::Strptime`.
2. `backend/script/deploy/Rexfile`: apontar morbo **e** worker Minion para
   `script/edumaps.pl` (no lugar de `edu_maps.pl`).
3. `rex -H backend.edumaps deploy_backend_dev` (roda carton install ≈ contêiner
   reinstala deps, reescreve unit, reinicia) + restart do worker Minion.
4. Validar no container: `/api/network/3551702/{summary,markers,schools,
   performance}` (200), `/api/analytics/cities/search`, `/api/analytics/city/
   3551702/details`, `/api/city/suggestions`; SPA via nginx `Host: ubatexu.lan`.

### Deploy já rodado (esta sessão)
- `rex prepare` OK (3 hosts) — rsync do working tree (preserva mtime → **morbo
  não recarrega sozinho**; precisa `deploy_backend_dev`/restart explícito).
- `rex -H analytic.edumaps deploy_analytics_dev` OK (~15 min): pacote R
  `edumapsr`/`edumapsAnalytics` 0.1.0 instalado; Plumber 1.3.3;
  **`devtools` NÃO instala** no analytic (falha systemfonts/ragg — não é mais
  necessário em runtime). `edumaps-analytic` ACTIVE, porta 8000
  (`EDUMAPS_R_PORT=8000`), `openapi.json` HTTP 200 (/chart, /similarity).
- `rex -H backend.edumaps deploy_frontend_dev` OK após fix (abaixo). nginx
  serve o SPA via `Host: ubatexu.lan` (`/municipio/compare` 200).
- Backend `deploy_backend_dev` rodou mas ficou com 404/500 (causa acima:
  app errada + deps faltando).

### Correções locais FEITAS nesta sessão (NÃO commitadas ainda)
- `analysis/edumapsr/inst/plumber/run.R` — reescrito: usa o pacote instalado
  (`system.file("plumber/endpoint.R")`) com fallback `devtools::load_all`
  (antigo morria no container por falta de devtools). scp manual p/ container.
- `frontend/edumaps/src/shared/stores/toastStore.js` — removido import de
  `uuid` (não instalado); usa `crypto.randomUUID?.() || Math.random().toString(36)`.
  Build local `npm run build` OK; já replicado no container.
- WIP pré-existente segue intacto: `backend/lib/EduMaps/EventBus/Middleware/
  SiopeTask.pm` (1 linha); untrackeds `analysis/edumapsr/man/*.Rd`.

### Commits desta sessão (na ordem)
- `0b3bcf1` chore(deploy): adaptar Rexfile (frontend/edumaps, edumapsr,
  deploy_analytic_models & disable_frontend_vite removidos, POD 3 hosts).
- `0a8bb77` docs: atualizar memory + regra 5 do workflow (atualizar memory.md
  em todo PR/merge e commitar junto).

### Fatos do ambiente (descobertos/confirmados)
- Containers: `backend.edumaps`, `database.edumaps`, `analytic.edumaps`
  (hosts de rede `Backend`, `Database`, `analytic`). SSH OK da máquina local.
- Backend: node 22.22.3, nginx 1.22.1; morbo :3000 (`MOJO_MODE=development`,
  `MOJO_LISTEN=http://0.0.0.0:3000`, `MOJO_REVERSE_PROXY=1`); worker Minion
  `perl edu_maps.pl minion worker`; perl do container 5.36, carton exec via
  `/bin/carton`, deps em `/opt/edumaps/backend/local/lib/perl5`.
- Analytic: R 4.2.2, serviço em `files/edumaps-analytic.service`
  (WorkingDirectory=/opt/edumaps/analysis/edumapsr, `Rscript inst/plumber/run.R`,
  `EDUMAPS_R_PORT=8000`).
- `/opt/edumaps/analytics` (stale do antigo submodule) removido dos 3 containers.
- Observado **processo R `renv-watchdog`** (10:09) no backend container —
  provável lixo; pode ignorar por ora.
- Rex: binary `/home/itaipu/perl5/perlbrew/perls/perl-5.42.0/bin/rex`, rodar de
  `backend/script/deploy`. Rex `deploy_backend_dev` usa `carton install` + gera
  unit morbo via template (paths agora p/ `script/edumaps.pl`).

## Sessões anteriores — SchoolNetwork (backend)

### Escopo desta sessão
- Implementação full stack do **SchoolNetwork** (rede de escolas por município):
  backend + migration + página de comparação de redes `/municipio/compare`.

## Estado atual (final da sessão)
- Branch de trabalho `feat/backend/school-network` **mergeada em `main`** via
  **PR #56** (merge commit `62def60`) e **deletada** (remoto e local).
- Branch local/integração atual: **`main`** (tracking `origin/main`).
- Repo Github: `marcoarthur/edumaps`; `gh` autenticado como `marcoarthur`
  (protocolo SSH). Merge via **merge commit** `gh pr merge <n> --merge --delete-branch`.

### Commits desta sessão (na ordem)
- `8eda2f7` feat(backend): SchoolNetwork (Result/ResultSet RedeEscolas, Model,
  roles Profile/Analytic/Geo, Controller + Plugin API, registro em EduMaps.pm).
- `3b6c54a`, `aee26d9` docs: skills/AGENTS.md, docs do frontend.
- (work acumulado da branch na frente: EventBus, autocomplete, cache, middlewares,
  ranking, analytics/similarity — entrou junto no PR.)
- `be98345` feat(data_pipeline): etapas na `mv_rede_escolas`.
- `411c73f` feat(backend): summary com `total_etapas` e `media_etapas`.
- `45e2e9f` feat(frontend): página de comparação de redes por município.
- `dd99860` docs: workflow de PR e merge com `gh` → seção nova no `AGENTS.md`.
- **`62def60`** = Merge pull request #56 (feature completa na main).
- `9bd89c7` chore(analytics): remove submodule `analytics` deprecado
  (substituído por `analysis/edumapsr`).
- `07efdfc` chore: remove `.gitmodules` vazio (sem submodules restantes).

## O que foi entregue / estado
- [x] Migration Sqitch (`analytics_rede_escolas`) aplicada com sucesso no
      alvo `dev_super` (também aplicou pendentes `ranking_escolas` e
      `event_store`).
- [x] MV `analytics.mv_rede_escolas` populado: 15.352 linhas / 5.571 municípios.
  - Ex.: SP `3550308` rede federal: total_escolas=5, total_matriculas=3480,
    ideb_fund_i=6.50, ano_ideb=2023.
- [x] Migration `rede_escolas_etapas`: MVs agora expõem `total_etapas`
      (SUM de nro_etapas) e `media_etapas` (1 decimal). Aplicada no dev;
      validação via psql (sqitch verify lento).
- [x] Backend completo: Result/ResultSet `RedeEscolas`, Model `SchoolNetwork`,
      roles `Profile`/`Analytic`/`Geo`, Controller + Plugin API, registro em `EduMaps.pm`.
- [x] Testes modelo (`t/02-models/SchoolNetwork.t`) e API
      (`t/04-api/network/`) — **PASS**.
- [x] Frontend completa (feature `network-compare`):
  - Wrappers reativos de `@carbon/charts-svelte` (Radar/Line/BarChartGrouped/Donut)
    com ResizeObserver + polyfill em `vitest-setup.js`.
  - Página `/municipio/compare` (`frontend/edumaps/src/features/network-compare/`):
    banner por rede, KPIs, radar Perfil/Volume, barras agrupadas, donuts,
    timeline IDEB, tabela sortable, mapa Leaflet com `circleMarker` por rede
    + toggle de filtro; URL compartilhável `?codigo_ibge=`.
  - Entrada via SchoolSearchForm ("Comparar Redes do Município", pré-seleciona
    município) + autocomplete interno.
  - MSW handlers/fixtures com dados reais de Sertãozinho/SP (3551702).
- [x] Testes frontend: 18 novos (transformNetworkData, NetworkComparePage com MSW,
      smoke dos wrappers) — PASS. Build vite OK. 4 falhas pré-existentes não
      relacionadas (paginationStore ×3, SchoolRankingPage ×1).
- [x] Validação visual **aprovada** pelo usuário em
      `/municipio/compare?codigo_ibge=3551702`.
- [x] Submodule `analytics` (gitlab.com/marcoarthur/edumaps) **removido** da
      árvore — deprecado, substituído por `analysis/edumapsr`. Commit local
      `3de80d0` descartado; repo remoto no GitLab deixado intacto.

## Endpoints implementados
`/api/network/:codigo_ibge/{summary,schools,performance,markers}` (regex `\d{7}`):
- summary — rede por tipo de administração (federal/estadual/municipal/privada),
  agora com `total_etapas` e `media_etapas`
- schools — escolas do município + somas de matrículas
- performance — série IDEB/SAEB
- markers — GeoJSON FeatureCollection

## Correções feitas durante o ciclo (importantes)
1. `Geo.pm` (markers):
   - `not_null('me.geometry')` — `geometry` puro ficava ambíguo nos JOINs.
   - Propriedades do GeoJSON **qualificadas** (`me.municipio`, etc.) para evitar
     ambigüidade com o join de `municipio`.
   - Retorno com `encode('UTF-8', ...)` — necessário, pois `decode_json` do Mojo
     falha em strings utf8-flagged vindas do Postgres via `pg_enable_utf8`.
2. `Analytic.pm`: ResultSet não tem `each`; iterar com
   `->as_hash->get_all->each(sub { $_->{col} })`.
3. `Profile.pm` (schools):
   - `columns` com `-as` explícito nos SUMs (senão o alias não é gerado).
   - `limit` no lugar de `rows` (helper existente em SearchHelpers).
   - filtro `matricula.nu_ano_censo` no WHERE (não em `search_related`).
4. `Controller/SchoolNetwork.pm` (markers): usar
   `render(text => $result, format => 'json')` e não `render(json => ...)`
   (o retorno já é string GeoJSON; `render(json)` duplicava encoding —
   padrão seguido: `City` controller).
5. Testes: `maybe()` **não existe** no `Test2::Tools::Compare` (verificado).
   Substituído por asserts mais simples (`exists`). `number_gt` existe.

## Informações fornecidas pelo usuário (IMPORTANTE)
- **Rodar testes**: usar `prove -l` (equivale a `-I lib`) a partir de
  `backend/`, ou `yath` (runner mais moderno, preferido).
  Ex.: `prove -rl t/05-tasks` (o `-r` é recursivo).
  Sem `-l`, testes como `event_logger.t` falham com
  "Can't find application class EduMaps in @INC" — **não** é falha real.
- **Falhas restantes da suíte são previstas / pré-existentes** — os testes são
  complexos e dependem de serviços externos (R scripts, Siope scraping,
  schema `staging`, jobs gower/similarity). **Não modificar agora.**
  Há um ciclo futuro previsto de **cleanup da suíte** (não iniciar sem pedido).
- **Workflow do projeto** (registrado no AGENTS.md):
  plano → execução → aprovação → validação visual → PR + merge via `gh`
  (`gh pr create --base main` ... `gh pr merge <n> --merge --delete-branch`).
- **Autorização concedida de executar qualquer comando** neste ambiente de
  teste, inclusive via SSH da máquina local para os containers LXC
  (`backend.edumaps`, `database.edumaps`, `analytic.edumaps` — hosts de rede
  `Backend`, `Database`, `Analytic`).
- **Deploy**: Rex em `backend/script/deploy/Rexfile`, "as-is" (rsync do working
  tree). 3 containers: Backend (Perl + Minion + nginx/frontend estático),
  Database (PostgreSQL/PostGIS/Sqitch em `Database`), Analytic (R `edumapsr`,
  Plumber na porta 8000 via `EDUMAPS_R_PORT`). Frontend atual: `frontend/edumaps`
  (Svelte 5/Vite), não mais `frontend/map_app`.

## Comportamento / convenções do repo (descobertas)
- Idioma: PT-BR (comentários, docs e mensagens).
- Commit: `<type>(<scope>): <subject>` (máx. 50 chars, PT-BR). Scopes:
  `backend`, `frontend`, `data_pipeline`, `analytics` (= schema Postgres
  `analytics.mv_*`), `analysis`, `db`.
- Validações de formato de `codigo_ibge` invalid (`abc`, `123`, 8 dígitos)
  retornam **404** (convenção do `City`), não 400. 400 é só p/ params de query
  inválidos.
- `EduMaps::Schema::ResultSet::Base` compõe
  `EduMaps::Roles::DB::{PrettyPrint Formats SearchHelpers Scaling Stats Geo
  Joins Derived SQLUtils Aggregates ProcessedJob Pageable}`.
- ResultSet tem `as_hash`/`get_all` (Mojo::Collection), **não** tem `each` direto.
- `clean.ideb_notas_escolas.rede` e `clean.escolas.dependencia_administrativa`
  usam valores capitalizados: `Estadual/Federal/Municipal/Privada`.
  `clean.ideb_notas_escolas.etapa` ∈ `fundamental_i`, `fundamental_ii`,
  `ensino_medio`.
- Credenciais (dev): `PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel
  -d edumaps_dev`. Sqitch target: `dev_super`. Check "Workers Builds: edumaps"
  (deploy Cloudflare) falha em PRs — infran, não bloqueia merge (UNSTABLE).
- Frontend: `frontend/edumaps` (Svelte 5, Vite, Carbon, Leaflet, MSW, Vitest).
  Rotas em `src/app/routes.js`; `App.svelte` faz `matchRoute(router.path.split("?")[0])`.

## Pendências / fora do escopo desta sessão
- Falhas de teste PRÉ-EXISTENTES (não são regressões): `municipio.t` #8 (OSM
  features sem dado) e `school/clustering.t` (mensagem "Não encontrado").
- Mudanças NÃO commitadas da sessão atual:
- **Hook post-commit quebrado**: `.git/hooks/post-commit` linha 32
  `GIT_DIR: unbound variable` (assinatura de shell com `set -u` sem exportar
  GIT_DIR). O commit funciona; o hook erra depois. Não consertado (não pedido).
- Mudanças pré-existentes NÃO commitadas (mantidas fora de commits/PRs):
  - `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info → error)
  - untrackeds (fontes reais, commitar em ciclo próprio):
    `backend/script/tasks/siope.pl`,
    `backend/templates/osm/query/school.opq.ep`,
    `frontend/map_app/src/lib/js/city.js`.
  - Obs.: `analysis/edumapsr/man/*.Rd`, `backend/cover_db/` e
    `data_pipeline/config/local.ini` agora são GITIGNORADOS; `docs/*` foi
    versionado na reorganização (ciclo de limpeza).
- Próximo ciclo: cleanup da suíte de testes (quando o usuário pedir).

## Comandos úteis para retomar
```bash
cd /home/itaipu/Code/Data/leaflet/backend
prove -vl t/02-models/SchoolNetwork.t        # modelo
prove -vl t/04-api/network/                  # API
prove -rl t/05-tasks                         # (falhas previstas p/ análises R/Siope)

cd /home/itaipu/Code/Data/leaflet/frontend/edumaps
npm run test:run                             # vitest (18 testes da feature inclusos)
npm run build                                # build vite

# PR + merge
git push -u origin <branch>
gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
gh pr merge <n> --merge --delete-branch
```