# Git hooks do EduMaps

Hooks versionados em `.githooks/` que transformam as convenções do `AGENTS.md`
em checagem automática. Vivem em `tools/` (local, **não** vai ao deploy).

## Instalação

Uma vez por clone:

```bash
tools/git-hooks/install.sh
```

O que ele faz: `git config core.hooksPath .githooks` (local ao repositório) e
`chmod +x` nos hooks. Para desinstalar: `git config --unset core.hooksPath`.

## Hooks

### `commit-msg` — bloqueia o que é barato e determinístico

Valida a convenção `<type>(<scope>): <subject>` (ver `AGENTS.md`).

| Verificação | Efeito |
|---|---|
| Formato `<type>(<scope>): <subject>` | **bloqueia** |
| `type` fora de `feat fix test refactor docs chore perf ci` | **bloqueia** |
| `scope` fora da lista conhecida | avisa |
| Subject com mais de 50 caracteres | avisa |
| Subject termina em ponto final | avisa |

- O `scope` é **opcional** (conviver com os `docs:` do histórico).
- Mensagens do próprio git — `Merge …`, `Revert …`, `fixup! …`, `squash! …` —
  são isentas.
- O limite de 50 é **aviso**, não bloqueio: só ~36% do histórico cumpre os 50
  caracteres; bloquear seria pior que não ter hook (risco apontado na #136).

Lógica em `lib/GitHooks/CommitMsg.pm`. Testes:

```bash
prove tools/git-hooks/t
```

### `pre-commit` — só avisa, nunca bloqueia

1. **Documentação funcional**: se o commit toca `backend/`, `frontend/`,
   `analysis/` ou `data_pipeline/` e não toca `docs/funcionalidades/`, imprime um
   aviso (passo 3 do Workflow do `AGENTS.md`).
2. **Linters condicionais**: corre `perlcritic` (ficheiros `backend/*.pm|*.pl`
   staged) e `lintr` (ficheiros `analysis/*.R` staged) **apenas se estiverem
   instalados**. Sem a ferramenta, salta em silêncio.

Não roda a suíte de testes: `t/05-tasks` e boa parte de `analysis/` são
pré-falhos por dependerem de serviço externo — um hook que rode tudo bloquearia
commits por falha alheia.

Lógica em `lib/GitHooks/PreCommit.pm`; testes em `prove tools/git-hooks/t`.

## Linters (opcionais)

Sem instalá-los os hooks funcionam normalmente (o lint é só pulado). Para os ter:

```bash
# Perl (no perlbrew do backend)
cpanm --notest Perl::Critic Test::Vars

# R
Rscript -e 'install.packages("lintr")'
```

O frontend **não** tem `npm run lint` nem eslint neste repositório; se um dia
existir, liga-se no `pre-commit.pl` como os restantes.

## Bypass

`git commit --no-verify` e `git push --no-verify` saltam os hooks. É **escape
pontual**, não caminho normal (ex.: corrigir um commit cujo formato só o hook
detectou, ou trabalhar offline sem as ferramentas).
