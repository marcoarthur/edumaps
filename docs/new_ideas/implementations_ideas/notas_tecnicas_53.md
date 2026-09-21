# Nota técnica — Buscar dados do SIOPE pelo Painel Financeiro

> Data: 2026-09-21 · Ciclo: backend (Mojolicious/Minion) + frontend (Svelte 5)

## 1. Contexto

O SIOPE (remuneração municipal) é a fonte dos dados financeiros das escolas
municipais. A task Minion `query_siope` já baixa a planilha do FNDE e popula
`clean.remuneracao_municipal` (testada em `t/05-tasks/siope.t`). Faltava dar ao
gestor o controle de **quando** baixar um ano que ainda não está na base, a
partir do **painel financeiro**.

Restrição de negócio: **só a rede municipal** tem dados no SIOPE (é o agregado
do município). O download é por **município** (código antigo do IBGE, 6 dígitos =
prefixo do `cod_inep`).

## 2. Decisões

- **Endpoint novo, school-scoped, sob a auth do gestor**:
  `POST /api/gestor/:cod_inep/financeiro/siope` (exige sessão; o painel é
  público, mas o **disparo** não).
- **SSE** para progresso (o helper `monitor_job` já existe), com **snapshot
  final** para detectar falha.
- Faixa **2020..ano atual**; exclusão de anos **por município** (unidade do
  download); rede com **fallback no censo** (`tp_dependencia=3`).
- Card **oculto** para quem não é o gestor autenticado da escola.

## 3. Solução

### Backend
- `Roles/Business/School/Finance.pm`:
  - `siope_status($cod_inep)` → `{ escola_existe, rede, habilitado, cod_municipio, anos_presentes }`
    (`_rede_escola` consulta `clean.escolas` e, se ausente, o censo; `anos_presentes`
    via `cod_municipio::text`).
  - `siope_disponivel($cod_inep, $ano)` → `{ ok, cod_municipio }` ou `{ error }`
    (`escola_inexistente` | `nao_municipal` | `ano_existente`).
  - `financial_summary` enriquecido: `escola.{dependencia_administrativa,cod_municipio}`
    e `siope.{habilitado,cod_municipio,ano_inicial,ano_atual,anos_presentes}`.
- `Controller/Gestor.pm#finance_siope`: valida `ano` (2020..atual), traduz os
  erros de `siope_disponivel` (404/422/409) e enfileira `get_siope` → 202.
- `Plugin/API/Gestor.pm`: rota sob o `$auth` (under `_require_gestor`).

### Frontend
- `features/schools/api/schoolApi.js`: `requestSchoolSiope(inep, ano)`,
  `getJobProgress(jobId)` e `watchJobProgress(jobId, {onProgress,onDone,onError})`.
- `SchoolFinancePage.svelte`: card SIOPE quando `siope.habilitado` **e** o
  `fetchMe` confirma o gestor daquela escola; `<select>` com os anos
  `2020..atual − anos_presentes`; botão dispara → SSE → recarrega. O card aparece
  mesmo sem `series` (para baixar o primeiro ano).

## 4. Armadilhas

- **SSE não emite falha**: `monitor_job` só envia eventos de `progress` e encerra
  o stream em `finished`; um job `failed` fecharia sem erro. Solução: no
  `EventSource.onerror`, ler o snapshot `GET /api/task/progress?job_id=` e decidir
  sucesso/erro.
- **`EventSource` não envia header `Authorization`** — por isso o progresso fica
  no endpoint público `/api/task/progress` (o disparo é que exige sessão).
- **Tipos**: `remuneracao_municipal.cod_municipio` varia (varchar/int) conforme o
  banco; comparar com `cod_municipio::text`. `ano` é texto no banco atual —
  normalizar com `+0`.
- **Não performar o job no smoke/teste**: enfileirar e remover (`remove_job` /
  `DELETE FROM minion_jobs`) para não raspar o FNDE.

## 5. Validação

- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **68/68 PASS**
  (`finance_siope.t`: 401, 403, 422, 202+job, 400 fora da faixa, 409 duplicado).
- Frontend (container): `SchoolFinancePage.test.js` — **4/4 PASS**; suite
  completa **300/304** (4 falhas pré-existentes).
- Smoke real (nginx): `siope.habilitado=1`; `POST` → **202** `job_id`; progresso
  `active`; sem sessão → **401**. Job removido em seguida.
- Deploy: `deploy_backend_dev` + `deploy_frontend_dev` → **PR #86** (merge
  `630c627`). Sem migração.
- Docs: capacidade `analise/financeiro` atualizada (novo passo do workflow).

## 6. Próximos passos

- Opcional: **SSE nativo com estado final** (emitir `failed` no stream) para
  dispensar o snapshot.
- Reaproveitar o mesmo padrão (drop list + SSE) para outros backfills
  assíncronos (ex.: OSM, clusters) no gestor.
- Avaliar rate-limit no disparo (é efeito colateral) e registrar quem disparou.
