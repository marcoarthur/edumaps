# Nota técnica — Landpage e acessos ao Painel do Gestor

> Data: 2026-09-21 · Ciclo: frontend (Svelte 5)

## 1. Contexto

Com o módulo do gestor maduro (pesquisas, reuniões, inventário, relações), a
landpage ainda comunicava apenas **busca** e **análise**. Esta mudança
reposiciona a plataforma para incluir **gestão** e cria caminhos naturais de
**cadastro/login** do gestor a partir da escola buscada.

Decisão explícita do usuário: **sem validação de titularidade** neste momento
(qualquer pessoa pode se cadastrar/entrar para uma escola). O backend já existe
(`POST /api/gestor/pesquisas/perfil`, `/api/gestor/login`, `/api/gestor/me`) —
nenhuma alteração de API.

## 2. Fluxos

```
Landpage "Sou gestor" ─┐
Banner "Gestor" ───────┼─► /gestor  (Já tenho conta | Criar conta)
Card "Você é o gestor?"┘        │
  (?inep=, modo=cadastro)       ├─ login   → /gestor/painel?inep=<me.cod_inep>
                                └─ cadastro→ (auto-login) /gestor/painel?inep=<inep>
/escola/panel?inep= ─► "Você é o gestor?" ─► /gestor?inep=
Busca (seção) ───────► "Você é o gestor?" ─► /gestor
```

## 3. Mudanças

| Arquivo | Papel |
|---------|-------|
| `features/gestor/pages/GestorAcessoPage.svelte` (novo) | página `/gestor`: login + cadastro; detecta sessão existente; auto-login pós-cadastro |
| `features/gestor/components/survey/GestorLoginCard.svelte` | props opcionais `titulo`/`descricao` (default preservado) |
| `app/routes.js` · `features/gestor/index.js` | rota `/gestor` + export |
| `app/App.svelte` | `NAV_LINKS` ganha **Gestor** |
| `features/home/pages/HomePage.svelte` | pilar **Gestão escolar** + CTA **Sou gestor** |
| `features/schools/components/SchoolCard.svelte` | link **Você é o gestor?** → cadastro com o INEP |
| `features/schools/pages/SchoolPanelPage.svelte` | link **Você é o gestor?** no painel público |
| `features/schools/pages/SchoolSearchPageRx.svelte` | link **Você é o gestor?** no cabeçalho da busca |

### Página `/gestor`
- Query `?inep=` pré-preenche o cadastro; `?modo=cadastro` abre direto no cadastro.
- **Já tenho conta**: `GestorLoginCard` (login) → painel com o `cod_inep` do `/me`.
- **Criar conta**: `upsertGestor` e, em seguida, `loginGestor` (auto-login) → painel.
- Sessão existente (`fetchMe` ok) → cartão "Você já está logado" com atalho ao
  painel e Sair (sem redirect automático).

## 4. Validação

- Frontend (container): 5 arquivos afetados → **30/30 PASS**; suite completa
  **296/300** (as 4 falhas são pré-existentes).
- Novos/atualizados: `GestorAcessoPage.test.js` (login, cadastro com INEP
  pré-preenchido, sessão existente), `HomePage.test.js`, `routes.test.js`
  (`/gestor`), `SchoolCard.test.js`, `SchoolSearchPageRx.test.js`.
- Build do frontend ok (`deploy_frontend_dev`) → **PR #84** (merge `29c72f1`).
- Sem migração e sem alteração de backend.

## 5. Observações / próximos passos

- **Sem guarda de rota**: `/gestor/painel` continua público e os módulos pedem
  login quando necessário. A validação de titularidade (e um fluxo de aprovação
  por escola) fica para quando o produto exigir.
- Possível evolução: busca de escola embutida na `/gestor` (hoje é campo de
  INEP), e um "modo gestor" no banner quando já houver sessão.
