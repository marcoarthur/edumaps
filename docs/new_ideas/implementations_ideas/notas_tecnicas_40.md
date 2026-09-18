# Nota técnica — Busca por escolas similares no painel do gestor

> Data: 2026-09-18 · Ciclo: busca de escolas similares (pgvector on-the-fly)

## 1. Contexto

O painel do gestor (`/gestor/painel`) mostra o raio-x de uma escola (indicadores,
infraestrutura, acessibilidade). Faltava a ele uma **busca por escolas
similares**: encontrar escolas com perfil parecido e compará-las, para
entendimento de pares/referências e contextualização do desempenho.

A decisão de arquitetura (confirmada com o usuário) foi usar **pgvector**
(operador `<=>`, distância de cosseno) sobre um **vetor de características
montado on-the-fly na própria query SQL** — sem migration nova nem tabela
pré-computada. Decidiu-se também **não** misturar as 4 características com o
embedding de 6 scores (`analytics.school_embedding`): a similaridade considera
exclusivamente porte, localização (urbana/rural), INSE e etapas de ensino.

## 2. Problema

Não existia nenhuma rota no painel do gestor para encontrar escolas parecidas;
o conceito de "escola similar" tampouco estava definido para o gestor.

## 3. Solução — vetor de características (10 dimensões)

A query calcula, para cada escola candidata (ativa, mesmo ano censo Censo 2025),
um vetor com:

| Dim | Característica | Como é codificada |
|-----|----------------|-------------------|
| 1 | Porte | ordinal 0,0.2,..,1.0 pelas 6 categorias de `clean.escolas.porte_escola` (ausente → 0.5) |
| 2 | Localização | 1 = urbana, 0 = rural (censo `tp_localizacao` 1/2) |
| 3 | INSE | `INSE_alvo` normalizado `/10`; **0 quando o alvo não tem INSE** (comparação neutra) |
| 4–10 | Etapas (one-hot) | `in_comum_creche, in_comum_pre, in_comum_fund_ai, in_comum_fund_af, in_comum_medio_medio, in_eja, in_profissionalizante` (`COALESCE(x,0)`) |

Score = `1 - (vetor <=> vetor_alvo)`, ordenado decrescente. Escopo limita a
busca ao mesmo **município** (padrão), **estado** ou **região** IBGE. Limite
clampado em 1..50 (default 10). Armadilhas SQL validadas na prática:

- `ARRAY[...]::vector` quebra com NULLs ("array must not contain nulls") →
  `COALESCE` em todos os flags de etapa;
- `ROUND((1 - vetor <=> vetor)::numeric, 4)` no SQL causa erro de parse
  ("syntax error at or near AS") → similaridade é arredondada no Perl
  (`sprintf('%.4f', ...)`) sem cast;
- **`CASE WHEN ? IS NULL`** falha em prepared statement server-side
  ("could not determine data type of parameter $1") → cast explícito
  `?::numeric IS NULL`;
- `INSE ausente no alvo`: os dois binds do INSE são `undef` → dimensão 0,
  e o INSE da candidata (`COALESCE(i.media_inse, ?)` depois de `* 10`) nunca
  domina a comparação sem o átomo de contexto do alvo.

## 4. Implementação por camada

- **Backend**: nova role `EduMaps::Roles::Business::Gestor::SimilarSchools`
  (SQL raw via `dbh_do`, `$FEATURE_VECTOR`, `%ETAPA_LABEL`), composta em
  `Model/Gestor`; rota `GET /api/gestor/:cod_inep/similares` (`gestor_similares`);
  action `similar_schools` no `Controller::Gestor` (404 para INEP inválido).
- **Frontend**: `getSchoolSimilares` em `gestorApi.js`, `SCOPE_OPTIONS` em
  `constants/gestor.js`, componente `SimilarSchoolsSearch.svelte` (dropdown de
  escopo + botão Buscar + mapa Leaflet + tabela com link para o painel de cada
  escola), marcadores em `SimilarMarkers.svelte` (alvo azul `#2563eb`, similares
  laranja `#f97316`), seção `#escolas-similares` no `GestorPanel`.

## 5. Detalhes de implementação que merecem registro

- INSE cobre ~39% das escolas; quando ausente **no alvo**, a dimensão vira 0
  (o contexto socioeconômico não é cobrado das candidatas) — decisão de design
  documentada na UI ("INSE ausente é ignorado na comparação").
- A escola candidata recebe `INSE = FLOOR(INSE_alvo * 10)`; o INSE da candidata
  é neutralizado quando o alvo não tem INSE (a dimensão é 0 nos dois lados).
- Testes: `t/04-api/gestor/similares.t` (skip local sem pgvector, roda na app
  DB), `SimilarSchoolsSearch.test.js` (stub do `LeafletMap` via
  `__tests__/LeafletMapStub.svelte` para não tocar Leaflet em jsdom — o stub
  injeta `provideMapContext({map:null, ready:false})`).

## 6. Validação

- Backend: `prove -l t/04-api/gestor/` → 10 testes PASS; sintaxe OK.
- Frontend (container `backend.edumaps`): `npx vitest run src/features/gestor`
  → 20 testes PASS.
- E2E no container após deploy (`curl :3000/api/gestor/11000040/similares`):
  município/estado/região corretos; clamp `999→50`, `0→1`; similaridades no
  intervalo (0.8381..0.9921); região multi-UF (AM/PA/RR); 404 para INEP
  inexistente e formato curto.
  - Observação: `curl http://localhost/...` sem Host retorna 404; com
    `Host: ubatexu.lan` (o que o túnel envia) tudo responde 200 — o fallback
    SPA do nginx depende do `server_name`.

## 7. Commits do ciclo

- (a completar após merge)