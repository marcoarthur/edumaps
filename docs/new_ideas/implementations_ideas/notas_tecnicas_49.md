# Nota técnica — Relações Institucionais: Etapa 4 (interações + documentos)

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

A Etapa 4 fecha a "gestão" da relação (o terceiro nível do modelo do documento
de origem: **cadastro → relação → gestão**). O gestor passa a registrar o
**histórico** (interações) e a guardar **documentos** (ofícios, contratos,
notas, fotos) de cada relação — para que a escola não dependa da memória do
gestor atual.

## 2. Solução

### Migração `relacoes_gestao` (requires `relacoes_escolar`)
- `clean.relacoes_interacoes`: `relacao_id` (FK `ON DELETE CASCADE`), `gestor_id`
  (SET NULL), `data`, `canal`, `participante`, `assunto`, `descricao`,
  `resultado`, timestamps.
- `clean.relacoes_documentos`: `relacao_id` (FK CASCADE), `gestor_id` (SET NULL),
  `tipo`, `data`, `referencia`, `nome_original`, `caminho`, `mime`, `tamanho`.
  Arquivo físico no `upload_dir` (`<cod_inep>/relacoes/<relacao_id>/<uuid>.<ext>`).

### Backend
- `Roles/Business/Gestor/Relacoes.pm`: `list/create/update/delete_interacao_relacao`
  e `list/registrar/documento_row/delete_documento_relacao` +
  `documentos_relacao_caminhos`. Os nomes têm sufixo `_relacao` para evitar
  colisão com os helpers de anexo de Reuniões/Inventário (Role::Tiny).
- `relacao_detail` passou a incluir `interacoes` e `documentos` (o detalhe é uma
  chamada só).
- `relacoes_destroy` coleta os caminhos dos documentos e remove os arquivos do
  disco antes de excluir (o CASCADE apaga só as linhas).
- Rotas (constraints arrayref): `.../relacoes/:id/interacoes[/:interacao_id]` e
  `.../relacoes/:id/documentos[/:documento_id]`.

### Frontend
- `RelacaoDetailPage.svelte` em **`/gestor/relacoes/:id`**: resumo da relação,
  **timeline** de interações (add/editar/excluir) e **documentos**
  (anexar/baixar/remover). Botão "Abrir" na lista de relações.
- API: `getRelacao`, `createInteracao`, `updateInteracao`, `deleteInteracao`,
  `uploadDocumento`, `downloadDocumento`, `deleteDocumento`.
- `INTERACAO_CANAIS`/`DOCUMENTO_TIPOS` em `constants/relacoes.js`.

## 3. Validação

- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **61/61 PASS**
  (novos subtestes: timeline CRUD e documentos upload/download/extensão/exclusão).
- Frontend (container): `npx vitest run src/features/gestor` — **115/115 PASS**;
  suite completa 287/291 (4 falhas pré-existentes).
- Smoke real (nginx): interação `201`, documento anexado (`oficio.txt`) e detalhe
  com `interacoes`/`documentos`.
- Deploy: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev` → **PR #82** (merge `2cbbb90`).

## 4. Armadilhas / observações

- **Colisão de métodos de role**: manter o sufixo `_relacao` nos métodos de
  interação/documento evita que a role de Inventário/Reuniões "roube" a chamada
  (o Role::Tiny mantém a primeira role composta).
- **Exclusão com arquivos**: o `ON DELETE CASCADE` remove as linhas de
  documentos, mas **não** os arquivos em disco — é preciso coletar os caminhos e
  `unlink` antes de excluir a relação.
- **Erro de sintaxe no Svelte só no build**: um `}` sobrando em
  `RelacoesPage.svelte` passou pelo editor/testes e só o `vite build`
  (`deploy_frontend_dev`) acusou `js_parse_error`. O build é a validação real.

## 5. Próximo passo

- **Etapa 5 — Tarefas + indicadores/rede**: checklist por relação e métricas
  datacêntricas (tempo de resposta, demandas vencidas, relações sem atividade),
  evoluindo para o "grafo institucional" da rede.
