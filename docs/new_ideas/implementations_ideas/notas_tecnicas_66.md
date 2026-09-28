# Nota técnica 66 — CI Fase 1: banco de fixtures e suíte Perl em GitHub Actions

**Data**: 2026-09-28
**Escopo**: issue #1 (GH Actions) — Fase 1
**PRs**: #102 (`ci/backend-tests`, mergeado em `d4344dd`)
**Deploy**: `rex prepare` + `deploy_backend_dev` (rede voltou; `rex` instalado
no host via `cpanm` + header `expat.h` extraído localmente, sem sudo)

## O que foi construído

O CI do backend agora roda a **mesma suíte de `backend/t/`** contra um banco
Postgres/PostGIS criado do zero, sem depender do dataset real (765 MB) nem da
rede:

1. **`db/fixtures/`** — subconjunto *real* dos datasets IBGE/INEP: 12 CSVs com
   headers verbatim (18 municípios, 182 escolas), shapefile
   `BR_Municipios_2024.zip`, `countries.geo.json`, scripts de regeneração
   (`gerar.py`, `gerar_zip_municipios.sh`) e `fix-manifest.json`.
2. **Espelho HTTPS local** (`mirror_countries.py`) — resolve a migration
   `raw_countries`, que lê `/vsicurl/https://cdn.jsdelivr.net/...` e não pode
   mudar (checksum Sqitch).
3. **Guardas de CI** (`backend/t/lib/CI.pm`) — 17 testes que exigem R, rede ou
   o schema `staging` se auto-pulam com `# SKIP CI/fixtures: <motivo>` quando
   `EDUMAPS_FIXTURES=1`; em dev são no-op.
4. **`.github/workflows/backend-tests.yml`** — build da imagem `db/Dockerfile`,
   rede Docker, espelho com `--network-alias cdn.jsdelivr.net`, container do
   Postgres com `db/fixtures:/data:ro` + `CURL_CA_BUNDLE`, `sqitch deploy` das
   64 migrations (via container) e `prove -r -l t/`.
5. **Correções de testes latentes** (bugs de teste, não do fixture): INEPs
   fixos inexistentes em `grades.t`, seleção de escola sem `rede => 'Estadual'`
   em `rank.t` (modelo + API), helper de clustering por tabela errada
   (`ideb_notas_escolas` em vez de `clean.inep.vl_observado_2023`), amostras
   duplicadas em `Utils.pm`.

## Decisões de design

| Decisão | Por quê |
|---|---|
| Fixture **por baixo** das migrations (`/data`) | Nenhuma migration alterada → checksum Sqitch intacto nos bancos já implantados |
| Espelho local em vez de consertar o CDN | A migration não pode mudar; Cloudflare responde `chunked` sem `Content-Length` e o callback de escrita do `/vsicurl` recusa — sem knob do GDAL confiável |
| `ci_db.sh` (script) + workflow fino | O mesmo caminho roda local e no runner — o banco do CI é reproduzível e depurável |
| Guardas na própria suíte, não suite paralela | CI roda exatamente os mesmos testes de dev; flag `EDUMAPS_FIXTURES` |
| `plan(skip_all => ...)`, nunca `skip_all(...)` | No Test::Builder do Test2, `skip_all()` sai 255 e o prove reclama "No plan found"; `plan(skip_all => ...)` sai 0 nos dois frameworks |
| Guardas em `BEGIN` nos 4 arquivos com `use ok` | `use ok` emite testes em tempo de compilação; skip_all precisa vir antes, senão "You planned 0 tests but ran N" |
| Deps do Perl via `apt` + `sudo cpanm --notest --installdeps .` | `actions/setup-perl` **não existe** (404 na API): nunca foi do org `actions/`, e `perl-actions/setup-perl` também não resolve neste mirror |
| Perímetro do fixture guiado pelos testes | `INEPS_EXIGIDOS` (escolas nomeadas), 1 escola por `TP_DEPENDENCIA` e cobertura máxima entre as 10 fontes por escola |

## Fatos duros (não repetir)

- O `vsicurl` do GDAL recusa corpo `chunked`; exige `Range` (206 +
  `Content-Range`) e aceita framing HTTP/1.0 com `Connection: close`.
- `clean.school_indicators` é populada pelo job de análise (R), nunca por
  migration → fica vazia no fixture.
- Três INEPs citados por testes são inalcançáveis no fixture (`23027010`
  ausente de todas as fontes; `33064164`/`33069395` só no IDEB do Rio) →
  resolvido test-side.
- `clean.censo_escolas.co_municipio` é varchar; `codigo_ibge` integer →
  `CAST(... AS text)` (mesmo padrão da relação DBIC).
- O workflow dispara um run por push do PR (mesmo com path filters) — o
  `concurrency` com `cancel-in-progress` segura a fila.

## Validação

- Suíte no banco de fixture recriado do zero: **PASS** — 71 arquivos, 302
  testes, exit 0, 17 skips com motivo.
- Cluster tests ×8 execuções: estáveis.
- Dev sem a flag: guardas no-op, arquivos com lógica nova passam.
- **Workflow GitHub Actions: VERDE** no primeiro run válido (o primeiro tentou
  `actions/setup-perl` e falhou em 8s; corrigido).

## Pendências

- Fase 2: frontend CI (`actions/setup-node` existe + `npm ci` + `npx vitest
  run`; vitest 4/jsdom/MSW 2 já configurados no frontend).
- Fase 3: decisão sobre o check do Cloudflare Workers (configurar vs.
  desconectar) — vermelho em todo PR.