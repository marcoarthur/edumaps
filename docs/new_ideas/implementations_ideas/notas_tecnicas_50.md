# Nota técnica — Relações Institucionais: Etapa 5 (tarefas + indicadores)

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

A Etapa 5 fecha o módulo de **Relações Institucionais** completando o terceiro
nível do modelo (cadastro → relação → **gestão**): além do histórico
(interações) e dos documentos, o gestor ganha **tarefas** (checklist) e uma
**visão gerencial** da sua carteira de relações.

## 2. Solução

### Migração `relacoes_tarefas` (requires `relacoes_gestao`)
- `clean.relacoes_tarefas`: `relacao_id` (FK `ON DELETE CASCADE`), `gestor_id`
  (SET NULL), `descricao`, `responsavel`, `prazo`, `status`
  (`pendente|concluida`), `concluida_em`, timestamps. Índices por `relacao_id` e
  `status`.
- **Indicadores não têm tabela**: são derivados de `relacoes`/`interacoes`/
  `tarefas` (mesma filosofia da agenda da Etapa 3).

### Backend
- `list/create/update/delete_tarefa_relacao` (sufixo `_relacao` para evitar
  colisão de métodos entre roles). Ao concluir, `concluida_em` é preenchido;
  ao reabrir, é zerado (`CASE WHEN ? = 'concluida' THEN COALESCE(concluida_em,
  NOW()) ELSE NULL END`).
- `relacao_detail` passou a incluir `tarefas`.
- `indicadores_relacoes($cod_inep)`:
  - **resumo**: relações abertas/vencidas/concluídas, entidades, tarefas
    pendentes/vencidas;
  - **por_grupo**: demandas e vencidas por grupo da entidade;
  - **sem_atividade**: relações abertas sem interação nos últimos 60 dias
    (`HAVING MAX(i.data) IS NULL OR < CURRENT_DATE - 60d`), top 10;
  - **tempo_medio_primeira_interacao_dias**: `AVG(MIN(interacao.data) −
    relacao.created_at::date)`.
- Rotas (constraints arrayref): `.../relacoes/:id/tarefas[/:tarefa_id]` e
  `GET /relacoes/indicadores` (literal antes de `/:id`).

### Frontend
- **Checklist de tarefas** no detalhe (`/gestor/relacoes/:id`): adicionar,
  marcar/desmarcar (concluída com `line-through`) e excluir.
- **Aba Indicadores** em `/gestor/relacoes`: cards de resumo, "Demandas por
  grupo" e "Relações sem atividade recente (60 dias)".
- API: `getIndicadores`, `createTarefa`, `updateTarefa`, `deleteTarefa`.

## 3. Validação

- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **63/63 PASS**
  (novos subtestes: checklist CRUD/conclusão e indicadores derivados).
- Frontend (container): `npx vitest run src/features/gestor` — **118/118 PASS**;
  suite completa 290/294 (4 falhas pré-existentes).
- Smoke real (nginx): tarefa `201`; indicadores `abertas=1`, `vencidas=1`,
  `tarefas_pendentes=1`, agrupado por grupo.
- Deploy: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev` → **PR #83** (merge `0226819`).

## 4. Decisão de escopo — grafo institucional

O documento de origem sugere evoluir para um **grafo institucional da rede**
("quais fornecedores atendem várias escolas", "quais escolas compartilham
parceiros"). Isso foi **deixado fora** deste ciclo: cruzar entidades entre
escolas expõe informação de terceiros e exige uma **política de
agregação/anonimização** (e consentimento) antes de virar produto. Os
indicadores entregues são estritamente **por escola**.

## 5. Status do módulo

Etapas **1–5 concluídas**: cadastro de entidades, relações (o centro), agenda,
interações + documentos, tarefas + indicadores. Backlog técnico segue zerado.
