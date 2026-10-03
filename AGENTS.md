# AGENTS.md

## Project: EduMaps

Plataforma educacional de mapeamento de escolas públicas brasileiras.
Stack: **Perl (Mojolicious) / R / PostgreSQL (PostGIS) / Sqitch / Leaflet.js**.

## Repo layout

```
backend/       Perl (Mojolicious) — API, models, controllers, roles
data_pipeline/ Sqitch migrations, database config
analysis/      R package (edumapsr) — analytics: ranking, similarity, indicators
frontend/      Svelte + Leaflet.js — mapas interativos
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

**Onde rodar depende da máquina** (mesma regra do frontend):

- **No host `ubaxala`** o backend roda no **perlbrew do host** e aponta para o
  **Postgres do Docker** (`127.0.0.1:5432`, sobe com `docker compose up -d db`).
  O `env -u PERL5LIB` é **obrigatório**: o `PERL5LIB` do shell tem caminhos de
  uma máquina antiga e faz o `prove` abortar antes de rodar qualquer teste.

- **Nos demais hosts** (`backend.edumaps`, `database.edumaps`,
  `analytic.edumaps`) é **exclusivamente o deploy em `ubatexu.lan`**: subir a
  mudança com `rex prepare` + `rex -H backend.edumaps deploy_backend_dev` e só
  então rodar.

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
regressões. O mesmo vale para `t/04-api/municipio.t` (OSM features sem dados
carregados) e `t/04-api/network/schools.t` (dois subtestes com expectativas
contraditórias). Antes de atribuir uma falha a si mesmo, rodar o arquivo sem a
mudança, em `git stash`.

## Running tests (frontend)

**Onde rodar depende da máquina:**

- **No host `ubaxala`** (a máquina local) o ambiente de teste é
  **preferencialmente Docker**. Não há `node` no host, então build e `vitest`
  vão no container, com o repositório montado:

  ```bash
  sg docker -c 'docker run --rm -v "$PWD/frontend/edumaps:/src" -w /src node:22-slim \
    sh -c "npm ci --no-audit --no-fund && npx vitest run"'
  # feature isolada: troque por `npx vitest run src/features/<feature>`
  ```

  O `sg docker` é necessário porque o `sudo` pediria senha.

- **Nos demais hosts** (`backend.edumaps`, `database.edumaps`,
  `analytic.edumaps`) é **exclusivamente o deploy em `ubatexu.lan`**:

  ```bash
  ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npm run test:run'
  # feature isolada:
  ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npx vitest run src/features/<feature>'
  ```

O build do frontend segue pelo container (`rex -H backend.edumaps deploy_frontend_dev`).

## Running tests (frontend e2e — browser real via CDP)

Testes de integração/e2e da SPA rodam num **Chrome visível** (sem headless)
via plugin `opencode-chrome-devtools` (CDP), alvo `http://ubatexu.lan:8080`.

- **Cobertura**: todas as features da SPA, **exceto páginas unicamente de
  documentação ou solo-backend** (ver `docs/e2e/cobertura.md`).
- **Runbook**: setup do Chrome, fluxo padrão e nuances — `docs/e2e/README.md`.
- **Registro**: a cada rodada, atualizar `docs/e2e/cobertura.md` (PASS/FAIL +
  data).
- O plugin usa Chrome com `--remote-debugging-port=9222` e `--user-data-dir`
  dedicado (Chrome >=136 ignora a porta no profile padrão).

## Database

- Alvo dev: `edumaps_dev` (user: `devel`, pass: `senhaboa123`)
- Migrations em `data_pipeline/` (deploy/revert/verify)
- MVs em `analytics.*`, views limpas em `clean.*`

### ⚠️ `docker compose up` NÃO reconstrói as imagens — o serviço `sqitch` mente sobre a base de dados

`docker compose up` reutiliza a imagem já construída. O serviço `sqitch` faz
`COPY . /repo` no build (`data_pipeline/Dockerfile`), portanto o `sqitch.plan`
que ele lê é **uma fotografia de quando a imagem foi construída**, não o
working tree.

Depois de mexer em `data_pipeline/` (qualquer change nova, ou uma correcção ao
`sqitch.plan`), é **obrigatório**:

```bash
docker compose build sqitch   # antes de `up`, ou `up` com `--build`
```

Sem isto, o contentor corre com um plano antigo e falha com:

```
Nothing to deploy (up-to-date)
Cannot find change <id> (<change>) in sqitch.plan
```

A mensagem **aponta para a base de dados e está errada**: é o build que está
obsoleto. Antes de investigar o registry, confirmar o plano dentro da imagem:

```bash
docker run --rm --entrypoint sh leaflet-sqitch:latest -c 'wc -l < /repo/sqitch.plan'
git grep -cE '^[a-z0-9_]+ ' -- data_pipeline/sqitch.plan
```

O mesmo se aplica a `backend`/`minion` (imagens de 4 dias correm código de 4
dias, sem o dizer): `docker compose build backend minion`.

### ⚠️ Existem DOIS contentores de base de dados em `ubatexu.lan`

Existem **dois** contentores de base de dados em `ubatexu.lan`, e ambos se
identificam como `Database` (`hostname` e prompt do psql são iguais). Só um
deles é o que o backend usa, e é o inverso do que o nome do target Sqitch
sugere.

| Contentor | SSH (porta) | IP | Acedido por | `pgvector` |
|---|---|---|---|---|
| `database.edumaps` | 2032 | `172.19.198.3` | **O backend real.** Alvo do `deploy_db_dev` do Rexfile. | disponível |
| `database.dev` | 2026 | `172.31.51.4` | O target Sqitch `dev_super`, isto é `ubatexu.lan:5432`. | **ausente** |

Nada resolve `database.edumaps` por DNS — os dois nomes vivem no `~/.ssh/config`
com portas diferentes. É por isso que a confusão passa despercebida.

Confirmação rápida de qual base se está a usar (não usar `getent`, que não
resolve os nomes):

```bash
# do backend: mostra a quem está ligado de facto
ssh root@backend.edumaps 'ss -tnp | grep :5432'      # deve apontar para 172.19.198.3
```

Regra: **antes de medir o estado dos dados, confirmar qual base se está a
medir.** O relatório de fontes foi escrito contra `database.dev` e mediu um
estado que não é o do produto.

### ⚠️ `sqitch change_id` é irreversível: nunca editar `requires` nem reordenar changes já deployadas

O `change_id` de uma change é o SHA-1 dos seus metadados, que incluem a lista
`requires` **e o `change_id` do pai** (a change anterior no plano). Logo:

- adicionar/remover uma dependência numa change já deployada **muda o seu id**
  e, em cascata, o de todas as changes seguintes do plano;
- mover uma change já deployada para outra posição no plano **também** quebra
  a cadeia.

`sqitch` deixa de encontrar as changes deployadas e aborta com
`Cannot find change <id> (<nome>) in sqitch.plan`. O registry não se
repara sozinho, e o `sqitch rewrite` **não existe** em Sqitch 1.6.1.

Isto já aconteceu: os commits `a13718c` (editou `requires` de 10 changes já
deployadas) e `83a77c5` (moveu `import_metadata_fase0` no plano) partiram o
`sqitch deploy` em todas as bases. Foram reparados a 2026-10-01 — ver
`memory.md`.

**Antes de tocar no `sqitch.plan`:**

1. `sqitch status --target <t>` está limpo?
2. Alguma das changes a editar já está deployada em algum alvo?
3. Se sim: **não editar.** Criar uma change nova.

Dependência nova entre changes já deployadas resolve-se com `requires`
apenas se **nenhuma** delas foi deployada; caso contrário, a resposta certa é
uma change nova.

### `sqitch verify` não é um gate fiável

Dois factos medidos, não presumidos:

- **Os `verify/*.sql` deste repositório nunca falham.** Terminam em
  `SELECT 1 FROM ...`, e o Sqitch considera a verificação bem-sucedida se o
  script não produzir **erro**. Uma query que devolve `f` conta como sucesso.
  Um teste de regressão escrito à mesma forma passaria com o defeito
  presente.
- **`sqitch verify` global falha com 45 "Out of order"**, porque
  `import_metadata_fase0` foi movida no plano depois de já estar deployada.
  Reflecte um facto histórico e não é corrigível sem reverter a
  reordenação.

Para escrever um `verify` que **falha mesmo**, usar
`DO $$ … RAISE EXCEPTION '…' $$;` — é o que a change
`analytics_ausencia_visivel` faz.

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
| browser-automation | `browser-automation.md` | Testes e2e da SPA em Chrome real via CDP (runbook em `docs/e2e/`) |
| perl-mojolicious | `perl-mojolicious.md` | Código backend Perl/DBIC/Mojolicious |
| postgres-postgis | `postgres-postgis.md` | Queries SQL, MVs, PostGIS, schema |
| sqitch-migrations | `sqitch-migrations.md` | Criar/revisar migrations Sqitch |
| r-analytics | `r-analytics.md` | Scripts R, edumapsr, clustering, SIOPE |
| frontend-svelte | `frontend-svelte.md` | UI Svelte 5/Leaflet: mapas, legendas, padrões reutilizáveis |
| edumaps-requirements | `edumaps-requirements.md` | Engenharia de requisitos: entrevista, formalização (RF) e issue no GitHub — apenas no **modo planning** (não no modo build) |

## Personas de curadoria

Arquivos de perfil **e memória** em `docs/personas/`. Diferente das skills
(instruções estáticas), as personas usam um **modelo com memória**: registram
inputs e mantêm um loop de perguntas → respostas → follow-ups.

⚠️ **A curadoria está dividida entre dois repositórios.** O `eduBR` tem o
acervo e o loop dele; aqui só fica o Tech Lead. Ver os dois blocos abaixo.

### Personas do `eduBR` — curadoria mudou de repo

O loop de curadoria do pacote `eduBR` **mudou para o próprio repositório dele**
(`~/Projects/eduBR`, AGENTS.md lá tem o protocolo). Este repositório **não
mantém mais o loop**: aqui o `eduBR` é só **fonte de dados** (via
`service = "edumaps"`), não um objeto de curadoria.

🔴 **O repositório `eduBR` é somente-leitura para este projeto.** NUNCA escrever
nele — nem arquivo de persona, nem `AGENTS.md`, nem `memory.md`, nem backlog;
NUNCA rodar rodada de curadoria lá; NUNCA abrir PR, issue ou commit naquele
repositório. Qualquer achado sobre o `eduBR` é registrado **aqui**, neste
repositório.

| Persona | Foco | Onde está (leitura) |
|---------|------|---------------------|
| Pesquisadora educacional | ML p/ questões nacionais/regionais/municipais | `eduBR/docs/personas/pesquisadora-educacional.md` |
| Especialista em ML | ML clássico + modelagem avançada | `eduBR/docs/personas/especialista-ml.md` |
| Gestora escolar | Acompanhamento da escola vs painel municipal/estadual | `eduBR/docs/personas/gestora-escolar.md` |

⚠️ As cópias em `docs/personas/` deste repositório são **histórico congelado**:
ficaram para trás quando o acervo foi movido, e já divergiram das do repo
`eduBR`. Permanecem aqui **de propósito**, como registro do que já foi curado —
não editar, não apagar, não usar como fonte da verdade. Para o perfil ou a
memória correntes, ler no repo `eduBR`.

### Persona ativa neste repositório

Uma persona atua sobre **todo o projeto** (não sobre o `eduBR`):

| Persona | Arquivo | Foco |
|---------|---------|------|
| Tech Lead | `docs/personas/tech-lead.md` | Organiza o acervo (`docs/` + Zotero) e propõe direções/oportunidades técnicas |

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
6. **PR + merge (via `gh`) — REGRA OBRIGATÓRIA**: **toda `feat` e `fix`**
   (qualquer artefato de código) entra no repositório **somente** via
   **branch novo → PR → merge**. **NUNCA** dar push direto em `main` com
   feature/fix. Após a aprovação e o deploy validado, criar o pull request para
   `main` com a ferramenta de linha de comando do GitHub:

   ```bash
   git checkout -b <tipo>/<escopo>-<descricao> main   # branch novo: feat/, fix/, refactor/, test/…
   git push -u origin <branch>
   gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
   gh pr merge <n> --merge --delete-branch   # merge commit (padrão do repositório)
   ```

   - **Permitido em `main` direto (exceção)**: apenas mudanças **só de
     documentação** (`docs/`, `*.md` como `AGENTS.md`/`memory.md`, `.opencode/`,
     comentários) — não são deployáveis e não têm o que "entrar" como feature.
   - **Exceção de infra Docker local (`docker-compose.yml`, `docker/` no
     `ubaxala`)**: são código, então também passam por branch → PR → merge.
   - Depois do merge: `git checkout main && git fetch origin && git merge --ff-only origin/main`.
   - Mudanças não commitadas e não relacionadas ao trabalho NUNCA entram no PR.
   - Flag de bloqueio: se por qualquer motivo o fluxo tentar dar push direto em
     `main` com `feat`/`fix`, **parar e notificar** o developer, não seguir.
   - **Urgência não isenta** (CI quebrado, hotfix, incidente): a regra vale
     igual. Um push direto inevitável é uma contingência, não um atalho — nesse
     caso: (a) avisar o developer no mesmo instante, (b) comentar no
     PR/issue **pertencente ao trabalho**, (c) abrir o PR retroativo na
     sequência para registrar o que foi mergeado. Commitar direto e seguir
     como se nada tivesse acontecido é o comportamento proibido.
   - **Registrar a exceção não a torna precedente.** Concessões pontuais já
     dadas (ex.: commits `a13718c`, `83a77c5`, `812f36d` em 2026-10-01, ver
     `memory.md`) não criam precedente para o próximo ciclo.
7. **Memória**: sempre que houver PR criado e/ou merge, atualizar `memory.md`
   (estado, commits, decisões, pendências) e commitar junto.
8. **Nota técnica**: ao fim de cada ciclo de desenvolvimento (tipicamente 1–2
   PRs, ao longo de 1–2 dias), gerar uma nota técnica em
   `docs/new_ideas/implementations_ideas/notas_tecnicas_N.md` (próximo número
   sequencial), documentando o que foi construído e as decisões de design
   relevantes.
9. **Notificar (push)**: avisar o developer sobre o andamento via
   `tools/notify/notify.sh` (Telegram; em bloqueios também comenta no
   PR/issue via `gh` → GitHub mobile). Disparar **sempre**:

   | Momento | Comando |
   |---------|---------|
   | fim de **etapa/fase** em implementação longa | `tools/notify/notify.sh --event stage --title "Etapa N/M pronta" --msg "..."` |
   | **bloqueio** esperando permissão do developer | `tools/notify/notify.sh --event blocked --title "..." --msg "..."` |
   | **fim de ciclo** (após merge + memory + nota técnica) | `tools/notify/notify.sh --event done --title "Ciclo concluído" --msg "PR #N mergeado"` |

   O script degrada em silêncio se não configurado (setup em
   `tools/notify/README.md`) — nunca bloqueia o ciclo. Sem `tools/` no
   deploy: scripts locais.

## Ambiente de teste (execução)

- **Autorização concedida**: executar **qualquer comando** neste ambiente de
  teste, incluindo comandos via **SSH da máquina local** para os containers
  LXC (`backend.edumaps`, `database.edumaps`, `analytic.edumaps` — rede LXC com
  hosts `Backend`, `Database`, `Analytic`).
- O deploy é "as-is" (rsync do working tree local), voltado a desenvolvimento
  local — não produção. Sem deploy automático para produção.
