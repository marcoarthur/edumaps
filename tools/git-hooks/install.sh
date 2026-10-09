#!/bin/sh
# Instala os git hooks do EduMaps apontando core.hooksPath para .githooks/.
# Uso: tools/git-hooks/install.sh   (a partir de qualquer diretório do repo)
set -e

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "git-hooks: não estou dentro de um repositório git" >&2
  exit 1
}

git -C "$root" config core.hooksPath .githooks
chmod +x "$root/.githooks/commit-msg" "$root/.githooks/pre-commit"

echo "git-hooks: instalados (core.hooksPath=.githooks)"
echo "git-hooks: bypass pontual: git commit --no-verify"
