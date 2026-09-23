# Nota técnica — Documentos e planos escolares do gestor (fase 1)

> Data: 2026-09-23 · Ciclo: backend (Perl/DBIC) + data_pipeline (sqitch) + frontend (Svelte 5)

## 1. Contexto

O gestor precisa de um repositório confiável para os documentos e planos da
escola (PPP, atas, planejamentos) — hoje dispersos em drives e e-mails pessoais.
Difícil de achar (sem organização), sem histórico (sobrescreve-se o arquivo
antigo) e sem rastro de quem mudou.

## 2. Decisões de produto e design

- **Sobrescrever = nova versão.** Mesmo nome e mesma pasta mantêm as versões
  anteriores; qualquer versão pode ser baixada. O documento "atual" é a última.
- **Excluir pasta só se vazia** (409 com orientação); documento é excluído com
  unlink do arquivo.
- **Tags livres** reutilizam o padrão já existente de pesquisas/reuniões
  (`normalize_tags`, coluna `text[]` ao lado do `nome`).
- **Auditoria de tudo** (criação, atualização, tags, exclusão) com autor, data e
  detalhes — novo feed "atividade recente" no frontend.
- **Sem ACL** nesta fase: o escopo é sempre a escola do gestor logado
  (`_require_gestor` + `_gestor_inep_ok`); INEP de outro gestor → 403.
- **Validações na rota**: `cod_inep` inválido → **404** (convenção do EduMaps);
  extensão não permitida/arquivo ausente → 400; nome/pasta duplicada → 409.
- **Casos de borda normalizados**: `''` (raiz) é convertido para `undef` em
  `pasta_pai_id`/`pasta_id` ao mover para a raiz (tanto na API quanto no mock).

## 3. Implementação

### Banco (`data_pipeline`, migration `gestor_documentos`)
- `clean.pastas_escolares` (± `pasta_pai_id` para subpastas; constraint única
  `(cod_inep, pasta_pai_id, nome)` → 409; pasta circulada bloqueada por subpassas
  descendentes).
- `clean.escola_documentos` (nome, `pasta_id`, tags `text[]`) com constraint
  única `(cod_inep, pasta_id, nome)` (COALESCE p/ raiz) → sobrescrita = versão.
- `clean.escola_documentos_versoes` (mime, tamanho, caminho no upload_dir,
  gestor autor, `criado_em`).
- `clean.escola_documentos_auditoria` (tipo entidade, ação, detalhes JSONB).
- Gatilho de `updated_at`, índices de busca por `cod_inep`.

### Backend
- Role `EduMaps::Roles::Business::Gestor::DocumentosEscolares`: um único loop
  de "carimbar" gestor/inep, queries via `resultset as_hash`, `normalize_tags`
  público.
- `Controller/Gestor.pm`: 12 handlers (árvore, auditoria, CRUD de pastas,
  upload/atualização/tags/exclusão/versões/histórico/download por versão) com
  **eval guard** nas mutações → violação única vira 409 via `_render_db_error`
  (`uq_pastas_escolares_inep_pai_nome`, `uq_escola_documentos_inep_pasta_nome`
  mapeados). `_require_gestor` reusa a sessão de `/api/gestor/login`.
- `Plugin/API/Gestor.pm`: rotas literais antes de `/:id`; PATCH nas
  atualizações; validação de `id` numérico.

### Frontend
- `DocumentosPage.svelte` + `DocumentosArvore.svelte` (explorador plano
  indentado com expandir/recolher, ações por linha e editores inline de
  criar/renomear/mover/tags), `TagEditor`, `VersoesModal`, `HistoricoModal`.
- `api/gestorDocumentosApi.js` + `mocks` MSW com estado em memória (Bearer
  `SESSION_TOKEN`, literais antes de `/:id`).
- Rota `/gestor/documentos`, botão no `GestorPanelPage`, `apiClient.patch`
  adicionado ao client compartilhado.

## 4. Correções de bugs encontrados durante o ciclo

- **Duplo segmento na URL**: as rotas de documento montavam
  `/documentos/documentos/:id` — corrigido para `${BASE(inep)}/${id}` (identificado
  pelos handlers MSW "unhandled request").
- **`#each` duplicado**: nós de documentos sem `id` na chave (colisão
  `docundefined`) — adicionado `id` no nó.
- **Pastas não expandiam**: `abertas` capturava o valor inicial vazio das props
  (state referenced locally) — refatorado para o modelo "recolhidas" (raiz aberta
  por padrão).
- **Upload em teste MSW**: o `File` do jsdom perdia o nome ao cruzar o fetch do
  undici (virava `filename="blob"` e falhava a extensão) — convenção do repo:
  campo `_original_nome` no FormData, lido pelo handler.

## 5. Validação

- Backend local (ubatexu): `prove -l t/04-api/gestor/` — 10 arquivos, **67
  testes OK** (crud pastas, ciclo 409, upload v1/v2, download por versão, tags,
  histórico, feed, 401/403/400/404).
- Frontend (container): `gestorDocumentosApi.test.js` (7) + `DocumentosPage.test.js`
  (7) → **14/14 OK**; build e suite completa 327/331 (4 falhas pré-existentes:
  `paginationStore` espera `q:''` fixo e `SchoolRankingPage` "Voltar para busca").
- **E2E real** via curl no container (nginx + API + DB `database.edumaps`):
  perfil/login, GET árvore, criar pasta, duplicada 409, upload 201, download v1,
  tags/histórico/auditoria, delete doc/pasta 204 — tudo verde; dados temporários
  removidos.

## 6. Deploy

- `rex prepare` → `deploy_backend_dev`, `deploy_frontend_dev`,
  `deploy_db_dev` (database.edumaps; sqitch rodou — lá existe o pgvector).
- Migração também aplicada manualmente no banco local dos testes (`ubatexu.lan`).
- nginx: `client_max_body_size 12m;` libera uploads de documentos.