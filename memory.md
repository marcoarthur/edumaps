# Memory — EduMaps

> Arquivo de restauração de sessão. Registrar aqui tudo que foi descoberto
> e/ou informado pelo usuário, para retomar o contexto em sessões futuras.
> As seções abaixo ficam em ordem cronológica reversa (sessão mais recente no topo).

## Sessão atual — Migração das análises R::Pipe → Plumber (edumapsr), Fase 3 concluída

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

### Estado
- F1, F2, F3 e F4 concluídas e commitadas em `main`.
- **Fase 5**: rotas web `POST /api/task/{cluster,summary,similarity}`.
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