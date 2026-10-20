# Nota técnica 157 — a isócrona vira regional: ES+MG no mesmo snapshot e o teto de 45 min triplica

Ciclo de execução da **#295** (rodada 1: ES re-run + MG + recalibração dos
tetos). A issue fica aberta para a rodada 2 (RJ/SP e BA); a **#296** (expor
IVET/isócrona na interface) iniciará no próximo ciclo com o plano já
aprovado e comentado na issue.

## Entregas

| PR / commit | Escopo |
|---|---|
| **PR #297** (`3275b95`) | driver regionalizado (`SETORES_UFS`, `SNAPSHOT`/`TILESET_BUILD_DATE`), retomada `--retomar`, recalibração dos tetos, docs |

Commits: `3f66ee9` (driver), `96f4957` (retomada), `5e7265c` (tetos),
`a622245` (docs analises), `ba59db9` (README do pipeline).

## 1. O viés de fronteira tinha DUAS raízes — e só uma era óbvia

A medição da nota 156 apontou 2,90% das células `NULL` e 125 escolas >20%
subestimadas, culpando os setores de MG/BA não carregados. Na expansão,
apareceu a **segunda raiz**: o próprio **tileset** era só do ES — o Valhalla
sem estradas de MG/RJ/SP cortava os anéis de 45 min na divisa. Por isso a
solução foi dupla:

- **Tiles do Sudeste inteiro** (extract Geofabrik 1,1G → 1.546 tiles,
  container `valhalla-sudeste` na :8003) — corta anéis corretamente;
- **Setores da região** (`SETORES_UFS=ES,MG,RJ,SP`, `string_to_array` na
  query de export) — a arealização soma população do outro lado da divisa.

Resultado: células com população **97,3% → 99,72%** e escolas >20% `NULL`
**125 → 5** (restam as da borda MG↔BA, pendente do extract do Nordeste).

## 2. O run do MG morreu em silêncio; a retomada é agora padrão

9.455/13.900 escolas e SIGKILL sem traceback — provável OOM (o host tem
15 Gi e o load de setores da região é grande). Duas decisões:

- **Escrita incremental do CSV** (`--retomar` lê o que já existe e faz
  append) — o custo por escola é constante e a morte no meio perde no
  máximo a escola em curso. O driver passa `--retomar` sempre.
- A causa raiz do SIGKILL **não foi determinada** (o RSS do python na
  retomada era 0,84 GB). A retomada transforma o problema de "mata o job"
  em "atrasa 25 minutos".

## 3. Mesmo `dt_snapshot` em todas as UF não é estética — é sobrevivência

A view nacional do IVET filtra por `max(dt_snapshot)`. Se o MG carregasse
com snapshot novo e o ES ficasse com o antigo, **o ES sumiria do painel**.
Por isso o re-run do ES (2.897 escolas, 14 min com tiles novos) foi
obrigatório na mesma rodada, e `SNAPSHOT` virou variável do driver. O
`carregar.sql` não precisou mudar: o `DELETE ... USING tmp_isocrona` é
idempotente **por escola do CSV** — nunca apaga as linhas das outras UF.

## 4. O teto de 45 min triplicou — e a recalibração é uma propriedade, não um evento

| teto | p99 do piloto (ES) | p99 ES+MG | teto novo |
|---|---|---|---|
| 15 min a pé | 40.590 | 39.339 | 40.000 (mantido) |
| 45 min de carro | 1.765.458 | **4.889.715** | **5.000.000** |

O p99 do MG triplicou o do ES: MG tem anéis de carro enormes em área rural
e o metro de BH no raio. p50 ES+MG 169.471 / p90 4.567.800. O teto provisório
é sempre **≈ p99 do que está carregado** (mesma prática do #255 no bloco F);
à medida que RJ/SP/BA entram, ele recalibra de novo — o card e as docs
carregam essa ressalva. Validação no produto: comp 45 min med **0,966** nas
duas UF, saturados no teto 0,0%, publicáveis 145.732 (80,7%).

## 5. O que já está pronto para a #296

O painel agora tem os dois dados que a interface vai expor: `bloco_C`/
`ivet` com 80,7% de publicação e a isócrona de 16.796 escolas em
`clean.isocrona_escolar`. O plano aprovado da #296 (comentado na issue)
parte do `ivet_medir_nacional()` — que hoje **não** materializa nada; a
tabela `analytics.ivet_escola` + task `refresh_ivet` + rota
`GET /api/school/:cod_inep/ivet` são o PR 1.
