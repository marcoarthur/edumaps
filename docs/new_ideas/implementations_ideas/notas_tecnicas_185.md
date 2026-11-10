# Nota técnica 185: escopo de perfis da ajuda (fecha a #304)

PR #361 (2026-11-10). Fecha o épico do sistema de ajuda (#304). Os PRs #332 e
#350 já tinham publicado o site e coberto as 26 funcionalidades ativas
(notas 163 e seguintes). Faltavam duas decisões de escopo.

## O que se verificou

- **Não existe conta docente.** `clean.gestores.access_role` só aceita
  `gestor` e `admin` (change `gestor_access_role`). O professor aparece
  apenas como contato cadastrado pelo gestor (grupos, reuniões, listas com QR,
  pesquisas) e, sem login, vê o mesmo que qualquer pessoa.
- **"Comunidade" já incluía famílias.** O README do perfil já dizia "famílias,
  responsáveis e qualquer cidadão", tudo sem login.
- **Lacuna não prevista na issue:** 16 fichas de `docs/funcionalidades/` têm
  `pesquisador` ou `investidor` em `audiencia`, e nenhum perfil da ajuda os
  atendia.

## Decisões (do usuário)

1. **Perfil professor encerrado.** `docs/ajuda/professor/` foi removido e o
   validador (`tools/help-wiki/export.py`) deixa de aceitar `professor` em
   `publico` e `modulo`: página nova com esse perfil quebra o CI. Um acesso
   docente futuro é funcionalidade nova, com issue própria.
2. **Comunidade = quem usa sem login**, incluindo professores, pesquisadores e
   investidores. As fichas de funcionalidades mantêm `pesquisador` e
   `investidor` em `audiencia` (descrevem o público do produto); o README da
   ajuda registra que, na ajuda, eles correspondem a `comunidade`.

## Validação

`python3 tools/help-wiki/export.py`: 44 arquivos, links e índices OK,
cobertura 26/26. Uma página de teste com `publico: [professor]` é recusada.

Sem deploy e sem rebuild de imagem: só `docs/` e `tools/`, que não vão aos
contentores.
