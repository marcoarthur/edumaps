# AGENTS.md

## Project: EduMaps

Plataforma educacional de mapeamento de escolas públicas brasileiras.
Stack: **Perl (Mojolicious) / R / PostgreSQL (PostGIS) / Sqitch / Leaflet.js**.

## Repo layout

```
backend/       Perl (Mojolicious) — API, models, controllers, roles
data_pipeline/ Sqitch migrations, database config
analysis/      R package (edumapsr) — analytics: ranking, similarity, indicators
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

## Running tests (frontend)

**SEMPRE rodar no container `backend.edumaps` — NUNCA na máquina local:**

```bash
ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npm run test:run'
# feature isolada:
ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npx vitest run src/features/<feature>'
```

O build do frontend também roda no container (`rex -H backend.edumaps deploy_frontend_dev`).

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
| frontend-svelte | `frontend-svelte.md` | UI Svelte 5/Leaflet: mapas, legendas, padrões reutilizáveis |

## Personas de curadoria

Arquivos de perfil **e memória** em `docs/personas/`. Diferente das skills
(instruções estáticas), as personas usam um **modelo com memória**: registram
inputs e mantêm um loop de perguntas → respostas → follow-ups.

Três personas avaliam o pacote `eduBR` (repo separado em `~/Projects/eduBR`):

| Persona | Arquivo | Foco |
|---------|---------|------|
| Pesquisadora educacional | `docs/personas/pesquisadora-educacional.md` | ML p/ questões nacionais/regionais/municipais |
| Especialista em ML | `docs/personas/especialista-ml.md` | ML clássico + modelagem avançada |
| Gestora escolar | `docs/personas/gestora-escolar.md` | Acompanhamento da escola vs painel municipal/estadual |

Uma quarta persona atua sobre **todo o projeto** (não só o `eduBR`):

| Persona | Arquivo | Foco |
|---------|---------|------|
| Tech Lead | `docs/personas/tech-lead.md` | Organiza o acervo (`docs/` + Zotero) e propõe direções/oportunidades técnicas |

### Protocolo do loop (curadoria eduBR)

1. **Ativar**: ler o perfil + memória da persona (`docs/personas/<slug>.md`).
2. **Pendências**: as perguntas da rodada são as canônicas + os follow-ups abertos.
3. **Responder**: executar o `eduBR` (via `Rscript`, `service = "edumaps"`) ou
   ler o código/README e registrar `Pergunta → Resposta`.
4. **Classificar**: `✓ atendido` / `lacuna` / `sugestão`.
5. **Follow-up**: gerar a próxima pergunta e registrá-la em "Pendências".
6. **Sugestões**: atualizar "Sugestões priorizadas" (`[alta]`/`[média]`/`[baixa]`).
7. **Veredito**: ao zerar pendências, registrar `aprova` / `aprova com ressalvas`
   / `reprova` com data.

Cada rodada acrescenta uma entrada datada (mais recente no topo) no arquivo da
persona e alimenta o backlog do `eduBR`.

### Loop do Tech Lead (acervo do projeto)

1. **Ativar**: ler `docs/personas/tech-lead.md` + o mapa `docs/indice.md`.
2. **Inventariar**: varrer `docs/` e a coleção Zotero `EduMaps`
   (`~/Code/perl/DBIX/zotero.sqlite`, **read-only**).
3. **Diferenciar**: apontar duplicatas, órfãos, lacunas e artefatos desatualizados.
4. **Priorizar**: direções `[alta]`/`[média]`/`[baixa]` **com rastro** à fonte
   (`Z:<itemID>` ou caminho em `docs/`).
5. **Atualizar** `docs/indice.md` e registrar a passada (entrada datada) em
   `tech-lead.md`.
6. **Veredito** por passada.

## Documentação funcional (`docs/funcionalidades/`)

Catálogo central das **funcionalidades** do EduMaps, em markdown, de **alto
nível** (capacidades de negócio — não rotas, arquivos ou funções). Serve para
sintetizar o produto (PDF, wiki, apresentações) e entender rapidamente o que a
plataforma faz.

- **Estrutura**: um arquivo por **capacidade**, agrupado por módulo —
  `busca/`, `analise/`, `gestor/`, `comunidade/`, `plataforma/`.
- **Índice/síntese**: `docs/funcionalidades/README.md` (tabela Módulo ·
  Capacidade · resumo · status).
- **Template**: `docs/funcionalidades/_template.md` (copie para criar uma nova
  capacidade).
- **Front-matter YAML**: `titulo`, `modulo`, `status`, `audiencia`,
  `relacionadas` — facilita gerar outros formatos.
- **Status**: 🟢 ativo · 🟡 parcial · ⚪ planejado · 🔴 descontinuado.
- **Regra de manutenção**: mudou uma funcionalidade ou nasceu uma nova →
  atualize o arquivo da capacidade e o `README.md` (passo 3 do Workflow).
- **Anti-padrão**: não documentar implementação (rotas, classes, funções). Escreva
  a capacidade, ex.: "Sistema pode gerir o processo de compra via cadastro de
  fornecedores e iterações com o parceiro fornecedor."

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
3. **Documentação funcional**: sempre que uma **funcionalidade mudar** ou uma
   **nova for criada**, atualizar o arquivo da capacidade em
   `docs/funcionalidades/<módulo>/` e o índice `docs/funcionalidades/README.md`
   (ver seção "Documentação funcional" abaixo). Alto nível: descreva a
   **capacidade de negócio**, não rotas/arquivos/funções. Mudanças só de
   documentação não deployam.
4. **Aprovação**: só pedir PR após a validação visual do usuário (frontend)
   ou a aceite explícito da implementação.
5. **Deploy (sempre que houver código)**: todo ciclo que altere **artefato de
   código** termina com o deploy via Rex (`backend/script/deploy/Rexfile`).
   Mudanças **só de documentação** (`docs/`, `*.md` como `AGENTS.md`/`memory.md`,
   `.opencode/`, comentários) **não deployam** — não há o que sincronizar nos
   containers. O deploy é "as-is" — o working tree local é a fonte de verdade
   (rsync direto). Rodar sempre a partir de `backend/script/deploy`:

   ```bash
   rex prepare                                  # rsync do working tree p/ os 3 hosts
   rex -H <host> deploy_frontend_dev            # (ou a task afetada)
   ```

   Deploy por área alterada:

   | Área alterada | Task |
   |---------------|------|
   | `frontend/edumaps/` | `deploy_frontend_dev` |
   | `backend/` | `deploy_backend_dev` (+ `deploy_minion_dev` se jobs/Minion) |
   | `analysis/edumapsr/` | `deploy_analytics_dev` |
   | `data_pipeline/` | `deploy_db_dev` |
   | `docs/`, `*.md`, `.opencode/` | — (sem deploy) |

   **Atenção**: `deploy_backend_dev` NÃO faz rsync (quem faz é o `prepare`) —
   rodar `rex prepare` antes de qualquer task de código.
6. **PR + merge (via `gh`)**: após a aprovação e o deploy validado, criar o
   pull request para `main` com a ferramenta de linha de comando do GitHub:

   ```bash
   git push -u origin <branch>
   gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
   gh pr merge <n> --merge --delete-branch   # merge commit (padrão do repositório)
   ```

   Depois do merge: `git checkout main && git fetch origin && git merge --ff-only origin/main`.
   Mudanças não commitadas e não relacionadas ao trabalho NUNCA entram no PR.
7. **Memória**: sempre que houver PR criado e/ou merge, atualizar `memory.md`
   (estado, commits, decisões, pendências) e commitar junto.
8. **Nota técnica**: ao fim de cada ciclo de desenvolvimento (tipicamente 1–2
   PRs, ao longo de 1–2 dias), gerar uma nota técnica em
   `docs/new_ideas/implementations_ideas/notas_tecnicas_N.md` (próximo número
   sequencial), documentando o que foi construído e as decisões de design
   relevantes.

## Ambiente de teste (execução)

- **Autorização concedida**: executar **qualquer comando** neste ambiente de
  teste, incluindo comandos via **SSH da máquina local** para os containers
  LXC (`backend.edumaps`, `database.edumaps`, `analytic.edumaps` — rede LXC com
  hosts `Backend`, `Database`, `Analytic`).
- O deploy é "as-is" (rsync do working tree local), voltado a desenvolvimento
  local — não produção. Sem deploy automático para produção.
