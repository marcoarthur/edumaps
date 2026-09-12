# AGENTS.md

## Project: EduMaps

Plataforma educacional de mapeamento de escolas públicas brasileiras.
Stack: **Perl (Mojolicious) / R / PostgreSQL (PostGIS) / Sqitch / Leaflet.js**.

## Repo layout

```
backend/       Perl (Mojolicious) — API, models, controllers, roles
data_pipeline/ Sqitch migrations, database config
analysis/      R package (edumapsr) — analytics: ranking, similarity, indicators
analytics/     Git submodule: R scripts rodados via Event-Bus → Task
frontend/      Lua (LÖVE 2D) + Leaflet.js — mapas interativos
db/            Scripts auxiliares de banco
```

## Commit conventions (git-message)

```
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `perf`
Scopes: `backend`, `frontend`, `data_pipeline`, `analytics`, `analysis`, `db`

Máx. 50 chars no subject. Mensagem de commit em **PT-BR**.

## Running tests (backend)

```bash
cd backend
prove -vl t/02-models/SchoolNetwork.t   # modelo isolado
prove -vl t/04-api/network/             # API
prove -rl t/05-tasks                     # jobs R/Siope (depende de serviços externos)
yath -l t/02-models/SchoolNetwork.t     # runner moderno (preferido)
```

**IMPORTANTE**: sempre incluir `-l` (ou `-Ilib`) e rodar de `backend/`.
Sem `-l`, o módulo `EduMaps` não é encontrado e os testes falham com
"Can't find application class EduMaps in @INC".

Muitos testes em `t/05-tasks` e `analysis/` dependem de serviços externos
(R, schema staging, jobs agendados) e são **previamente falhos** — não são
regressões.

## Database

- Alvo dev: `edumaps_dev` em `ubatexu.lan` (user: `devel`, pass: `senhaboa123`)
- Sqitch target: `dev_super`
- Migrations em `data_pipeline/` (deploy/revert/verify)
- MVs em `analytics.*`, views limpas em `clean.*`

## Key conventions (Perl/Mojolicious)

- ResultSets herdam de `EduMaps::Schema::ResultSet::Base` (compõe SearchHelpers, Geo, Aggregates, etc.)
- `ResultSet->as_hash->get_all` retorna `Mojo::Collection` de hashrefs
- `geojson_features()` (role `Geo`) retorna coluna `feature` (JSON string)
- Controller: `render(json => $hashref)` para objetos, `render(text => $str, format => 'json')` para GeoJSON strings
- Credenciais de teste/db NUNCA commitadas; manter em `edu_maps.conf` (não versionado)
- Validação de `codigo_ibge` na rota retorna **404** (não 400) para formato inválido

## Skills

Arquivos de skill em `.opencode/skills/`:

| Skill | Arquivo | Quando usar |
|-------|---------|-------------|
| agent-persona | `agent-persona.md` | Sempre (persona e anti-padrões) |
| perl-mojolicious | `perl-mojolicious.md` | Código backend Perl/DBIC/Mojolicious |
| postgres-postgis | `postgres-postgis.md` | Queries SQL, MVs, PostGIS, schema |
| sqitch-migrations | `sqitch-migrations.md` | Criar/revisar migrations Sqitch |
| r-analytics | `r-analytics.md` | Scripts R, edumapsr, clustering, SIOPE |

## Code style

- `use utf8;` em todos os módulos
- `Mojo::Base -role, -signatures` para roles; `Mojo::Base 'DBIx::Class::Core'` para Results
- PT-BR em comentários e docs; identifiers em inglês

## Workflow

```
plano → execução → aprovação
```

1. **Plano**: propor o plano e alinhar decisões antes de tocar em código.
2. **Execução**: implementar e validar (testes/lint/build) conforme as
   convenções acima. Commits em PT-BR seguindo `<type>(<scope>): <subject>`.
3. **Aprovação**: só pedir PR após a validação visual do usuário (frontend)
   ou a aceite explícito da implementação.
4. **PR + merge (via `gh`)**: após a aprovação, criar o pull request para
   `main` com a ferramenta de linha de comando do GitHub:

   ```bash
   git push -u origin <branch>
   gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
   gh pr merge <n> --merge --delete-branch   # merge commit (padrão do repositório)
   ```

   Depois do merge: `git checkout main && git fetch origin && git merge --ff-only origin/main`.
   Mudanças não commitadas e não relacionadas ao trabalho NUNCA entram no PR.
