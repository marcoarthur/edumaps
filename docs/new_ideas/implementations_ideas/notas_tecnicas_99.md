# Nota técnica 99 — Convenções do repo viram git hooks (#136)

## Resumo

As convenções do `AGENTS.md` existiam declaradas e nada as verificava antes do
commit. Este ciclo transforma-as em hooks versionados: um `commit-msg` que
bloqueia o que é barato e determinístico, e um `pre-commit` que só avisa.

- **Hooks versionados** em `.githooks/`, instalados com
  `tools/git-hooks/install.sh` (`git config core.hooksPath .githooks`).
- Lógica sem dependências externas (só core Perl) em
  `tools/git-hooks/lib/GitHooks/`, com testes (`prove tools/git-hooks/t`,
  28 asserções).
- Entrega: 1 commit, branch `chore/infra-git-hooks-136` → **PR #199**
  (merge `b02c104`).

## Decisões de design

- **Bloquear o barato, avisar o caro.** O risco da própria issue é explícito:
  "hook que quebra o fluxo é pior que hook ausente". Só o que é determinístico e
  de custo zero bloqueia — **formato** e **`type`**. Tudo o mais (scope
  desconhecido, comprimento, estilo) **avisa**.
- **O limite de 50 chars virou aviso, com número.** A medição no histórico
  (últimos 300 commits) mostrou que **192 passam dos 50** na linha toda e
  **119** mesmo contando só o subject; só **108 (36%)** cumprem. Bloquear seria
  rejeitar ~64% do estilo real. O número é o argumento, não a opinião.
- **Scope também é aviso, e a lista foi alargada.** Os scopes realmente usados
  (`data`, `memory`, `docker`, `deploy`, `diagramas`, `e2e`, …) excedem a lista
  documentada, e o type `ci` nem estava listado. Em vez de brigar com o
  histórico, a lista foi alargada e o scope passou a ser opcional + aviso.
- **Mensagens do git são isentas.** `Merge …`, `Revert …`, `fixup! …`,
  `squash! …` não seguem a convenção e não devem bloquear. Sem isto, qualquer
  merge vindo de PR falharia.
- **Linters condicionais, sem instalar.** `perlcritic`/`lintr` correm apenas se
  estiverem no `PATH` e houver ficheiros staged da área; sem a ferramenta, o
  hook salta em silêncio. Isso evita transformar "faltar uma ferramenta de
  desenvolvimento" em "não conseguir commitar".
- **Nada de rodar `t/`.** `t/05-tasks` e boa parte de `analysis/` são pré-falhos
  por dependerem de serviço externo — um hook que rode a suíte bloquearia
  commits por falha alheia. `Test::Vars` **não** foi ligado: é biblioteca de
  teste, não linter de linha de comando; pertenceria ao conjunto de testes que
  deliberadamente não corre.
- **Frontend não existe para lint.** A issue supunha husky/`npm run lint`, mas
  o repo não tem nem `lint` script nem eslint. Não se adicionou eslint (seria
  scope creep); o `pre-commit.pl` deixa o gancho pronto para quando existir.

## Medições e validação

- `prove tools/git-hooks/t` → **28/28 PASS** (canónico, sem scope, breaking,
  isenções Merge/Revert/fixup/squash, comentários, rejeições, avisos de scope,
  comprimento e ponto final; aviso de docs por área).
- **Ponta a ponta real**: `install.sh` → `git commit` com mensagem fora do
  formato **bloqueado** (exit 1); mensagem boa **aceita** (smoke com
  `--allow-empty`, reset feito em seguida). `pre-commit` com um ficheiro falso
  em `backend/` staged **imprimiu o aviso de docs e saiu 0**.
- Scripts diretos: `foo(backend):` → type inválido; `feat(backend): ` + 55
  chars → aviso de comprimento, exit 0.

## Deploy

- **Nenhum.** `tools/`, `.githooks/` e `AGENTS.md` não entram em nenhum `build:`
  do `docker-compose.yml` (contextos `db`, `data_pipeline`, `backend`,
  `analysis/edumapsr`, `frontend`), e `tools/` é explicitamente local
  ("sem tools/ no deploy"). Nada de runtime mudou, portanto também não houve
  `rex prepare` nem task de deploy.

## Notas

- Os hooks ficaram **instalados no clone local** (`core.hooksPath=.githooks`):
  commits futuros neste repo passam pelo validador. Desinstalar com
  `git config --unset core.hooksPath`.
- `docs/funcionalidades/` **não** foi tocado — isto é infraestrutura de
  repositório, não capacidade de produto.
- Bypass documentado (`git commit --no-verify`) como escape, não caminho normal.

## Pendências

- Se um dia existir lint de frontend, ligar no `pre-commit.pl` como os restantes.
- Registar achados de hooks no `AGENTS.md` (feito) e manter a lista de scopes
  alinhada com o uso real.
