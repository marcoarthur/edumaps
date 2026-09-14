# Nota técnica — Clusterização multi-tabela com rótulos em linguagem natural

> Data: 2026-09-14 · Ciclo: presets de indicadores + descrição semântica dos clusters

## 1. Contexto

A clusterização de escolas evoluiu de uma única tabela para uma **tabela
denormalizada** (`clean.school_indicators`) que combina três fontes: **Censo
Escolar** (infraestrutura), **Docentes** (proporções de formação/vínculo) e
**IDEB/SAEB** (proficiências). Sobre essa tabela o usuário escolhe um **preset
curado** — `infraestrutura`, `docência` ou `desempenho` — e um recorte geográfico
(região → UF → município); o motor R (`edumapsr` via Plumber) roda
kmeans/dbscan/gmm/spectral e grava `cluster_id` de volta na tabela.

O fluxo completo: `Presets.pm` (Perl) → `POST /api/task/cluster` → job Minion
(`Task::Clustering`) → Plumber `/cluster` (`analyze_cluster`) → persistência em
`clean.school_indicators` + `analytics.clustering_metadata` → GeoJSON
(`GET /api/cluster/schools`) → frontend Svelte/Leaflet.

## 2. Problema

Os clusters saíam como `cluster_id` (1..N), um número arbitrário **sem
significado**: o mapa coloria escolas e a legenda mostrava "Cluster 1",
"Cluster 2"… sem dizer *o que* aquele grupo representa. O usuário não conseguia
responder, por exemplo, se uma escola era de **alta/média/baixa qualidade de
infraestrutura** — informação central para o uso educacional da ferramenta.

## 3. Solução — rótulos em linguagem natural

O rótulo é derivado de três ingredientes que o motor R não conhecia antes:

1. **Conceito** (`concept`) — a frase que descreve o que o cluster mede, por
   preset:
   - `infraestrutura` → "qualidade de infraestrutura" (gênero **f**)
   - `docência` → "qualidade da docência" (gênero **f**)
   - `desempenho` → "desempenho dos alunos" (gênero **m**)

2. **Polaridade** (`directions`) — por feature, se "maior é melhor" (+1) ou
   "maior é pior" (−1). Único caso negativo hoje: `prop_sem_especializacao`
   (proporção de docentes **sem** especialização = pior).

3. **Gênero** (`gender`) — controla a concordância do adjetivo
   ("alta qualidade" vs "alto desempenho").

### Score composto por cluster

Para ordenar os clusters e atribuir a gradação correta, calcula-se um score
por cluster a partir das **médias por feature** (centroides):

- cada feature é normalizada por **min-max entre os clusters** (→ [0,1]);
- aplica-se a **polaridade** (`directions`);
- o score do cluster é a **média** desses valores.

Os clusters são então ordenados pelo score (crescente = pior → melhor) e
recebem o rótulo da posição.

### Escala de gradação por nº de clusters

| k  | Rótulos (pior → melhor)                                  |
|----|----------------------------------------------------------|
| 2  | baixa, alta                                              |
| 3  | baixa, média, alta                                       |
| 4  | muito baixa, baixa, alta, muito alta                     |
| 5  | muito baixa, baixa, média, alta, muito alta              |
| ≥6 | **fallback inteiro** `Cluster 1..N` (1 = mais baixo, N = mais alto) |

Casos especiais: ruído do dbscan (`cluster_id == 0`) recebe o rótulo "Ruído"
e rank `NA`; `k == 1` (grupo único) ou ausência de `concept` (features
customizadas, sem preset) também caem no fallback inteiro.

## 4. Implementação por camada

### 4.1 R (`analysis/edumapsr`)

Novo módulo **`R/cluster-labels.R`** (funções internas):

```r
.label_scale(n, gender)      # vetor de adjetivos ordenado, ou NULL se n<2 ou n>5
.cluster_scores(means, features, directions)  # score composto por cluster
.cluster_labels(cluster_ids, scores, concept, gender)  # df(cluster_id, cluster_rank, cluster_label)
```

Integração em **`R/analysis-cluster.R`**: `analyze_cluster()` lê
`parameters$labeling` (`concept`, `gender`, `directions`), calcula as médias por
cluster a partir da matriz `x` (uniforme para os 4 algoritmos) e adiciona
`cluster_rank`/`cluster_label` tanto em `tables$clusters` quanto em `data`
(atribuição por entidade).

Persistência em **`R/repository-postgres-cluster.R`**: `.write_cluster_ids`
passa a gravar, junto do `cluster_id`, as colunas `cluster_label` (TEXT) e
`cluster_rank` (INTEGER) via `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` + UPDATE.
Os rótulos também vão para `analytics.clustering_metadata.extra_metrics` (JSON),
sem mudança de schema (decisão: **extra_metrics, não colunas novas**).

`DESCRIPTION` ganhou a entrada `cluster-labels.R` no campo `Collate` (ordem de
carregamento).

### 4.2 Backend (Perl)

- **`EduMaps/Presets.pm`** — cada preset ganhou `concept`, `gender` e
  `directions` (hashref feature → ±1), expostos no `GET /api/cluster/presets`.
- **`Controller/Task.pm`** (`request_cluster`) — com preset, injeta nos args do
  job:
  ```perl
  $args{labeling} = {
    concept    => $preset->{concept},
    gender     => $preset->{gender},
    directions => $preset->{directions},
  } if $preset->{concept};
  ```
- **`Task/Clustering.pm`** (motor http) — repassa `labeling` dentro de
  `parameters` para o `run_cluster`.
- **`Model/Cluster.pm`**:
  - `cluster_geojson_query` expõe `cluster_label` e `cluster_rank` nas
    `properties` do GeoJSON;
  - novo método `cluster_summary` lê o **run mais recente** de
    `analytics.clustering_metadata` (por `run_id` desc, filtrando
    `target_table = 'clean.school_indicators'`) e devolve por cluster:
    `cluster_id`, `cluster_size`, `is_noise`, `cluster_label`, `cluster_rank`
    e `indicators` (o centroide JSON).
- **Nova rota** `GET /api/cluster/summary` (`Controller::Cluster` +
  `Plugin::API::Cluster`).

### 4.3 Frontend (Svelte 5 / Leaflet)

- **`ClusterSchoolMap.svelte`** — a legenda passou a ser **clicável**: cada
  item é um `<button>` com `aria-pressed`; clicar alterna o grupo on/off e os
  markers daquele cluster somem/reaparecem (o `fitBounds` re-ajusta aos visíveis).
  Rótulo no popup e na legenda via `clusterLabel(label, id)`.
- **`ClusterSummaryTable.svelte`** (novo) — tabela Cluster | Escolas |
  Indicadores principais (top-N do centroide).
- **`constants/cluster.js`** — helper `clusterLabel()` com fallback `Cluster N`.
- **`api/clusterApi.js`** — `getClusterSummary()`.

## 5. Detalhes de implementação que merecem registro

- **`extra_metrics` é um ARRAY, não um objeto.** O R grava cada métrica extra
  como `jsonlite::toJSON(clusters_df[i, extra_cols, drop = FALSE])`, que produz
  `[{"within_ss":…,"cluster_label":"…","cluster_rank":N}]` (array de um
  elemento). No Perl, é preciso normalizar: se `ARRAY`, pegar o primeiro
  elemento; só então tratar como hashref.
- **UTF-8 dos acentos ("Média").** O `$self->json` do Model é um `JSON::XS`
  (`JSON::XS->new->canonical->utf8`). O banco devolve strings já
  utf8-flagged (`pg_enable_utf8=1`), então o padrão correto do projeto é
  decodificar com **`$self->json->utf8(0)->decode(...)`** (mesmo de
  `clustered_schools` / `Roles/Business/School/Clustering.pm`). Sem `utf8(0)`,
  a decodificação de "Média" falha e o rótulo cai no fallback.
- **Reatividade do `Set` no Svelte 5** — o estado de visibilidade é um
  `$state(new Set())` **reatribuído** a cada toggle (`hiddenIds = new Set(...)`),
  o que dispara o re-render de forma simples e robusta (padrão documentado na
  skill `frontend-svelte`).

## 6. Validação

- **R**: `tests/testthat/test-cluster-labels.R` (12 testes — escala por k,
  gênero, polaridade, ruído, fallback inteiro, sem conceito) + `test-cluster.R`
  (sem regressão). `R CMD INSTALL .` OK.
- **Backend**: `t/04-api/cluster.t` (10), `t/04-api/task.t` (19),
  `t/04-api/network/schools.t` (4) — verdes.
- **Frontend**: `cluster-geotag` 7/7; suíte total 123/127 (4 falhas
  pré-existentes não relacionadas). `npm run build` OK.
- **E2E** (deploy nos containers, Ubatuba 3555406):
  - infraestrutura, kmeans 3 → "Baixa / Média / Alta qualidade de infraestrutura";
  - desempenho, kmeans 3, ano 2023 → "Baixo / Médio / Alto desempenho dos alunos";
  - infraestrutura, kmeans 6 → fallback "Cluster 1..6".

## 7. Commits do ciclo

- `4335430` feat(analysis): rótulos semânticos de cluster
- `b608d92` feat(backend): rótulo e resumo de cluster
- `1e1e82c` feat(frontend): rótulo e legenda clicável
- `4f5564b` docs: skill frontend-svelte e legenda acionável
