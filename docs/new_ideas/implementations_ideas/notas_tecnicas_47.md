# Nota técnica — Relações Institucionais da escola (entidades + relações)

> Data: 2026-09-20 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

O gestor escolar mantém relações com atores externos (MEC, Secretaria,
Prefeitura, outras escolas, fornecedores, famílias, comunidade, parceiros,
conselhos). A discussão em `~/Documents/Notas/gestor_relacoes.md` propõe
organizar isso como **Gestão de Relações Institucionais e Comunitárias** em três
níveis: **cadastro** (quem são), **relação** (por que) e **gestão** (demandas,
tarefas, prazos, interações, documentos). O ponto central: **a relação é o
centro**, não a entidade — a escola não "possui um fornecedor", ela tem *uma
relação* com ele (contrato, problema, prazo, histórico).

Este ciclo entrega o **MVP (Etapas 1+2)**: cadastro de entidades e CRUD das
relações. **Não é um CRM** (sem leads/oportunidades/pipeline).

## 2. Decisões de desenho

- **Taxonomia editável**: `relacoes_categorias` com `eixo`
  (`entidade`|`finalidade`) e nome livre, semeada por escola (7 grupos + 10
  finalidades do doc) e editável. `tipo`/`finalidade` dos itens são texto livre
  apoiados por essa taxonomia — nada de `ALTER TABLE` para criar uma categoria.
- **Campos extras em `atributos jsonb`** (GIN) nas entidades e relações.
- **Enums fixos com CHECK** para `status` (`aberta, em_andamento, aguardando,
  concluida, cancelada`) e `prioridade` (`baixa, media, alta, urgente`) — facilita
  UI e filtros.
- **Responsável interno em texto livre** (a escola tem vários profissionais além
  do gestor).
- **Fornecedores separados** do `inventario_fornecedores` (decisão do usuário;
  um "importar" pode vir depois).
- **`vencida` derivado** (prazo < hoje e status não concluída/cancelada), sem
  coluna.
- **Anexos só na Etapa 4**; agenda (Etapa 3), tarefas e indicadores/rede
  (Etapa 5) ficam para depois.

## 3. Solução

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Migração | `data_pipeline/{deploy,revert,verify}/relacoes_escolar.sql` | categorias, entidades, relações |
| Backend | `Roles/Business/Gestor/Relacoes.pm` (novo) | taxonomia semeada, CRUD, filtros |
| Backend | `Controller/Gestor.pm` | ações `relacoes_*`, validação e guarda de erros |
| Backend | `Plugin/API/Gestor.pm` | rotas `/api/gestor/:cod_inep/relacoes[/...]` |
| Frontend | `features/gestor/api/gestorRelacoesApi.js` | cliente do módulo |
| Frontend | `features/gestor/pages/RelacoesPage.svelte` | abas Relações/Entidades, filtros, modais |
| Frontend | `features/gestor/{constants,mocks}/relacoes*` | status/prioridade + MSW |
| Frontend | `app/routes.js`, `features/gestor/index.js`, `GestorPanelPage.svelte` | rota `/gestor/relacoes` + link |

### Modelo de dados
- `relacoes_categorias(id, cod_inep, gestor_id, eixo, nome, origem)` —
  `UNIQUE (cod_inep, eixo, lower(nome))`.
- `relacoes_entidades(id, cod_inep, gestor_id, tipo, nome, identificador,
  responsavel_externo, email, telefone, site, endereco, observacoes,
  atributos jsonb)` — `UNIQUE (cod_inep, lower(nome))`.
- `relacoes(id, cod_inep, gestor_id, entidade_id, finalidade, assunto,
  descricao, status, prioridade, responsavel_interno, inicio, proxima_acao,
  prazo, atributos jsonb)` — FK entidade `ON DELETE RESTRICT`.

### API
- `GET /relacoes` → `{categorias, entidades, relacoes}` com filtros
  (`status`, `prioridade`, `vencidas`, `entidade_id`, `finalidade`, `q`).
- CRUD em `/relacoes/categorias`, `/relacoes/entidades` e `/relacoes[/:id]`.
- Tudo sob `_require_gestor` + `_gestor_inep_ok`; constraints **arrayref**.

## 4. Armadilha encontrada (importante)

**Colisão de métodos entre roles**: `list_categorias`/`create_categoria`/
`update_categoria`/`delete_categoria` do módulo Relações colidiam com
`Inventario.pm`. A expectativa era "last wins" (Relações composta depois), mas na
prática as chamadas caíram na versão do **inventário** (comportamento já
observado com `registrar_anexo` em Reuniões). Sintoma: o seed de categorias
gravava em `relacoes_categorias`, mas o `list` lia `inventario_categorias` → 0.
Correção: renomear para `*_relacoes_categoria(s)`. **Regra**: ao compor várias
roles no mesmo Model, métodos de negócio precisam ter **nomes únicos por
módulo**; helpers genéricos (`_rows/_row/_txn/_encode_atributos`) devem ser
cópias idênticas.

## 5. Validação

- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **58/58 PASS**
  (`relacoes.t`: taxonomia, CRUD, filtros, RESTRICT, ownership, validação).
- Frontend (container): `npx vitest run src/features/gestor` — **109/109 PASS**;
  suite completa 281/285 (4 falhas pré-existentes).
- Smoke real (nginx): 17 categorias semeadas; entidade e relação criadas (201).
- Deploy: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev` → **PR #80** (merge `2c2b54b`).

## 6. Próximos passos (etapas do plano)

- **Etapa 3 — Agenda institucional**: visão temporal por `prazo`/`proxima_acao`
  (agrupada por mês/semana, destacando vencidas), sem nova tabela.
- **Etapa 4 — Interações + documentos**: timeline por relação e anexos
  (reusando `upload_dir` e `apiClient.upload/download`).
- **Etapa 5 — Tarefas + indicadores/rede**: checklist por relação e métricas
  datacêntricas (demandas vencidas, tempo de resposta, relações sem atividade),
  evoluindo para o "grafo institucional" da rede.
