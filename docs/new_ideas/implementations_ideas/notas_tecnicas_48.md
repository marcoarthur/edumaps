# Nota técnica — Relações Institucionais: Etapa 3 (Agenda institucional)

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) + frontend (Svelte 5)

## 1. Contexto

A Etapa 3 do módulo de Relações Institucionais dá ao gestor a **visão temporal**
das obrigações: o que vence, quando, e o que está atrasado. O documento de
origem (`~/Documents/Notas/gestor_relacoes.md`) descreve a "agenda
institucional" como a leitura de **obrigações futuras** (não só problemas já
ocorridos), agrupada por data.

Decisão de desenho: **não criar tabela**. A agenda é uma **visão derivada** de
`clean.relacoes` (prazo e próxima ação já estão lá).

## 2. Solução

### Backend
- `Roles/Business/Gestor/Relacoes.pm#agenda_relacoes($cod_inep, $filtros)`:
  - relações **abertas** (status ≠ concluída/cancelada) com `prazo` **ou**
    `proxima_acao`;
  - recorte opcional `de`/`ate` sobre `prazo` (`?::date`);
  - ordenação por `prazo NULLS LAST`, prioridade, id;
  - retorna `{de, ate, total, vencidas, itens (com prazo), sem_prazo}`;
  - `vencida` reaproveita o cálculo já existente em `_relacao_out`.
- `Controller/Gestor.pm#relacoes_agenda` + rota
  `GET /api/gestor/:cod_inep/relacoes/agenda` (literal registrada **antes** de
  `/:id`; o `:id` numérico já evitaria ambiguidade).

### Frontend
- `getAgenda(inep, {de, ate})` no `gestorRelacoesApi.js`.
- Aba **Agenda** em `RelacoesPage.svelte`:
  - agrupamento por mês (`agendaGrupos` derivado; rótulo "janeiro de 2020");
  - recorte por data (inputs `de`/`ate` recarregam a agenda);
  - resumo `N obrigação(ões) · X vencida(s)`;
  - destaque visual das vencidas e seção **"Sem prazo definido"**;
  - cada item permite "Editar" (abre o modal de relação já existente).

## 3. Validação

- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **59/59 PASS**
  (novo subteste: ordenação por prazo, flag `vencida`, separação `sem_prazo` e
  recorte `de=`).
- Frontend (container): `npx vitest run src/features/gestor` — **111/111 PASS**;
  suite completa 283/287 (4 falhas pré-existentes).
- Smoke real (nginx): `GET /relacoes/agenda` → `total=2`, `vencidas=1`, 1 item
  com prazo e 1 sem prazo.
- Deploy: **sem migração**; `deploy_backend_dev` + `deploy_frontend_dev` →
  **PR #81** (merge `cfb31ae`).

## 4. Armadilhas / observações

- **Rota literal antes de `:id`**: registrar `relacoes/agenda` antes de
  `relacoes/:id`. Aqui o `:id` tem constraint `qr/\d+/`, então `agenda` não
  casaria, mas manter a ordem é a defesa padrão.
- **Erro de sintaxe no Svelte só aparece no build**: um `}` sobrando passou
  despercebido até o `deploy_frontend_dev` (o `vite build` acusou
  `js_parse_error`); rodar o build/deploy é a validação real do frontend.
- **`getByText(/vencida/)` em teste**: casava o badge e o resumo
  ("0 vencida(s)") — usar texto exato ("vencida") para o badge.

## 5. Próximos passos

- **Etapa 4 — Interações + documentos**: timeline por relação e anexos
  (reusando `upload_dir` e `apiClient.upload/download`).
- **Etapa 5 — Tarefas + indicadores/rede**: checklist por relação e métricas
  datacêntricas (tempo de resposta, demandas vencidas, relações sem atividade),
  evoluindo para o grafo institucional.
