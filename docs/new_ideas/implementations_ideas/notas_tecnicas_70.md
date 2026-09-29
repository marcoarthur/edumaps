# Nota técnica 70 — Perfil da Escola Fase 2: referências pré-computadas e read-through

**Data**: 2026-09-29
**PR**: #108 (`feat/analytics-school-profile-fase2`) · **Issue**: #107 (derivada do #105)
**Áreas**: analytics (`analysis/edumapsr`), backend (`backend/`), frontend, infra de deploy

## Contexto

O #105 (PR #106) entregou o `POST /school_profile` on-demand. A escola típica
levava ~2s e a com cluster persistido ~3,4s, porque **cada request** varria a
população do Censo para as médias comparativas (município/rede/Brasil) e
recomputava os percentis do cluster. São dados que mudam raramente (por ano do
censo / por execução de clusterização) e são compartilhados entre escolas.

O #107 separa **cálculo** de **leitura**: materializa as referências e os
percentis, e o endpoint passa a devolver o perfil materializado quando o ano do
censo bate, só calculando quando não há nada em cache.

## Arquitetura

```
Censo (ano) ─► compute_and_save_school_profile_reference ─► analytics.school_profile_reference
Cluster run ─► compute_and_save_school_cluster_profile   ─► analytics.school_cluster_profile
Escolas     ─► compute_and_save_school_profiles          ─► analytics.school_profile
                                                                ▲
GET /school_profile (read-through) ─────────────────────────────┘
  materializado (ano bate) → devolve; senão calcula (lendo referência/
  percentis quando existem) e persiste
```

Tabelas self-provisioning (mesmo padrão do `repository-postgres-school-profile.R`):

- `analytics.school_profile_reference (nu_ano_censo, scope, chave, indicador, valor, n_escolas)`.
- `analytics.school_cluster_profile (cluster_id, indicador, run_id, nu_ano_censo, p25, p50, p75, media, n)`.
- `analytics.school_profile (co_entidade, nu_ano_censo, profile_data jsonb)` — do #106.

O DataSource tem `prefer_reference` (default `TRUE`): lê as referências por
escopo e o perfil de cluster; onde faltar, cai no cálculo **live escopado**
(população inteira só é varrida no fallback). O `metadata` carrega
`cluster_run_id` e `reference_source_{municipio,rede,brasil}`, para rastrear a
origem de cada número.

## Resultado de desempenho

| Caminho | Antes (#106) | Depois (#107) |
|---|---|---|
| Escola típica (sem cluster) | ~1,7–2,4s | ~0,1–0,4s (read-through) |
| Escola com cluster persistido | ~3,4s | ~0,1–0,4s |
| Cold (escola nova) | ~1–2s | ~1s (e passa a persistir) |

Batch (uma passada, fora do request): referências **7,6s**; percentis de
cluster **2,2s**; perfis por escola ~0,7s cada. O timer diário mantém o
materializado fresco; `scope=pending` torna a atualização incremental.

## Decisões e armadilhas

- **UPSERT em lote não pode usar `unnest` com bind vetorial** no RPostgres
  (o driver exige parâmetro escalar). Solução: `dbWriteTable(temporary=TRUE)`
  (COPY) + `INSERT ... SELECT ... ON CONFLICT`.
- **Read-through e JSON**: o payload persistido é parseado e re-serializado;
  os marcadores `jsonlite::unbox` não sobrevivem ao round-trip JSON, então
  escalares viravam arrays. O handler fixa
  `serializer_json(auto_unbox = TRUE, na = "null", null = "null")`, que
  preserva escalares e mantém listas como arrays.
- **`scale()`/`daisy` com indicadores constantes** devolviam NaN (0/0) e o
  kmeans/Gower estourava (`NA/NaN/Inf in foreign function call`), quebrando o
  batch nas escolas pequenas. Fix: remover features sem variância (mantendo a
  escola alvo no conjunto).
- **Corpo JSON no controller**: o Mojolicious não mescla corpo JSON nos
  `params` da validação; o timer enviava JSON e `mode`/`scope`/`limit` eram
  ignorados (limit caía no default 500). Normalizado como em
  `request_cluster` (JSON ou form).
- **Invariante do endpoint**: só devolve materializado cujo `nu_ano_censo`
  bate; `refresh=true` força recálculo. O perfil também carrega
  `cluster_run_id` para rastrear a run de clusterização.

## Backend e agendamento

- `EduMaps::Task::SchoolProfile` (Minion, fila `analytics`, `analytics_engine
  = http`): modos `reference`, `cluster`, `profiles` (escopo
  pending/município/uf/all, limit). Helper `apply_school_profile`.
- Rota `POST /api/task/school_profile` (202 + Location).
- `systemd` service + timer diário (03:20) que chama
  `backend/script/tasks/school_profile_refresh.sh` (curl na rota) —
  instalado no `deploy_backend_dev`.

## Frontend

`transformProfileData` mapeia `cached`/`computed_at`/`cluster_run_id` e o
painel mostra "Perfil atualizado em … · cluster <run>".

## Testes

- R: 372 passam (única falha, `test-cluster.R:154`, **pré-existente**).
- Backend: `t/04-api/task.t` (25), incluindo leitura de corpo JSON; subtests do
  client (mock Plumber) para reference/cluster/batch.
- Frontend: 355 testes / 65 arquivos.

## Deploy e validação

`rex prepare` + `deploy_analytics_dev` + `deploy_backend_dev` +
`deploy_minion_dev` + `deploy_analytics_worker_dev` + `deploy_frontend_dev`.
Validação em `ubatexu.lan`: read-through warm ~0,1–0,4s; job batch de ponta a
ponta (`school_profile` 0→424, `limit` respeitado); timer `enabled`; validação
visual do developer PASS.

## Pendências e próximos passos

- Documentar os endpoints batch no `api.json` (hoje só o `/school_profile`).
- Disparo **event-driven** após a clusterização (hoje só o timer diário).
- Roadmap do #105 ainda aberto: `school_evolution`, `/network_profile`, `/ask`
  sobre o perfil — issues futuros.
