# Nota técnica — Pesquisas do gestor (fase 1: cadastro + criação/gestão)

> Data: 2026-09-19 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

O Painel do Gestor (ciclo anterior) oferecia visão e escolas similares. Faltava
uma ferramenta de **ação**: o responsável de uma escola podia montar, em
segundos, uma **pesquisa para a comunidade** (pais, alunos, professores) —
sem login, sem formulários longos, com cara de app de celular.

Decisões do usuário para a **fase 1** (entregue):
- **Somente criação e gestão** — coleta de respostas, login e gráficos ficam
  para a fase 2.
- **Identidade anônima** via `?inep=` — o e-mail do gestor identifica a sessão
  (upsert por e-mail), gravada em `localStorage`.
- **1 gestor = 1 escola**; nome/e-mail obrigatórios, telefone/cargo/CPF
  opcionais. **LGPD:** CPF nunca retorna completo na API (mascarado).
- **Autosave no servidor** (debounce 600 ms), sem botão salvar; rascunho só
  publica com ≥1 pergunta (4 tipos: única, múltipla, dropdown, texto).

## 2. Problema / decisões de desenho

- **Schema** (`clean.*`, migração Sqitch `gestor_pesquisas`):
  `gestores`, `gestor_pesquisas`, `gestor_pesquisas_perguntas` (FK cascade;
  `opcoes` em JSONB; `status` com CHECK `rascunho|publicada|arquivada`;
  `ordem` reindexada no replace). Opções recebem **id de client** (uuid do
  wizard) que o backend preserva — estável para preview/reordenação.
- **API REST** em `Plugin/API/Pesquisa.pm` (base `/api/gestor/pesquisas`):
  `POST /perfil`, `GET /?inep=`, `POST /` (cria rascunho **com 0 perguntas** —
  o primeiro autosave acontece ao digitar o título), `GET|PUT|DELETE /:id`,
  `POST /:id/finalizar`.
- **Regras de negócio**: `publicada` é read-only (PUT/DELETE → 409);
  `finalizar` exige ≥1 pergunta; validações de tamanho/formato por campo
  (título 3..120, texto 1..500, opções 2..12 únicas, e-mail regex, CPF 11
  dígitos); respostas de erro `{error}` com 400/404/409.
- **Sem classes DBIC** para as tabelas novas: SQL raw via `dbh_do`/tuples
  (padrão de `SimilarSchools`), escritas em `txn_do`, leituras com
  `dbh->selectall_arrayref`.

## 3. Solução

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Migração | `data_pipeline/{deploy,revert,verify}/gestor_pesquisas.sql` | 3 tabelas em `clean` + índices + verify por `information_schema.columns` |
| Backend | `Roles/Business/Pesquisa/{Gestores,Surveys}.pm` | upsert de gestor (máscara de CPF), CRUD de pesquisas + replace de perguntas + finalizar |
| Backend | `Controller/Pesquisa.pm` · `Model/Pesquisa.pm` · `Plugin/API/Pesquisa.pm` | validação (Mojolicious), composição das roles, rotas |
| Frontend | `features/gestor/pages/{GestorPesquisasPage,GestorPesquisasWizardPage}.svelte` | listagem por status + carga do wizard |
| Frontend | `features/gestor/components/survey/{SurveyWizard,StepsIndicator,PhoneMockup,QuestionEditor}.svelte` | wizard 1 pergunta por tela, preview em moldura de celular, autosave |
| Frontend | `utils/pesquisaDraft.js` + `constants/pesquisas.js` + `utils/gestorSession.js` | modelo local do rascunho + limites + sessão |
| Frontend | `shared/api/client.js` (ganhou `put`/`delete`) · `api/gestorPesquisasApi.js` · `mocks/{handlers,fixtures}.js` | transporte + mocks MSW |

### Autosave (ponto crítico de UX)

O wizard escreve **no servidor** a cada edição (debounce 600 ms):
rascunho sem `id` → `POST /` (primeira vez que o título fica válido ≥3 chars);
com `id` → `PUT /:id`. O retorno do servidor re-hidrata o rascunho
(`surveyToDraft`), garantindo que os `ordem` e os ids das perguntas no banco
sejam os verdadeiros. `beforeunload` faz um flush final. O editor de pergunta
**muta** o objeto `$state` do rascunho (Svelte 5 rastreia a mutação) — a
validação por pergunta roda derivada, sem cópias.

## 4. Armadilhas encontradas (importante)

- **Mojolicious 9.49 não tem check `length`** — testamos `size(min, max)`
  (built-ins: `equal_to`, `in`, `like`, `num`, `size`, `upload`).
- **`txn_do` retorna a última expressão do bloco**: um `for (...)` final devolve
  falsy → `update_survey` não dependia do retorno da transação (faz o replace
  e relê o detail por conta própria).
- **`survey_detail`** montava `gestor` (nome/email) **depois** de apagar os
  campos do hash — reordenado.
- **DELETE 204** exige `render(status => 204, text => '')` (senão "Could not
  render a response").
- **`stepKeys` é `$derived` no wizard**: passar `step` por **índice** quebra
  quando a lista muda (ex.: após salvar o gestor, a etapa "Seus dados" sai das
  chaves). Solução: `goToKey('info'|'revisao'|'q<n>')` e `tick().then(...)`
  depois do `push` de pergunta (o derivado ainda não tinha recompilado).
- **Testes frontend**: `getByRole('heading', …)` para etapas cujo rótulo
  aparece no StepsIndicator e no `<h2>`; `vi.clearAllMocks()` entre testes
  (vitest não zera `vi.fn()` por padrão).

## 5. Validação

- Backend: `prove -l t/04-api/pesquisa.t` — **8/8 PASS** (local; tabelas
  aplicadas via psql no cluster local, já que `dev_super` não tem pgvector e
  não deploiou a cadeia).
- Frontend: `vitest src/features/gestor` — **49/49 PASS** no container.
- E2E via curl no container: perfil → pesquisa (0 perguntas) → PUT com 1
  pergunta → finalizar → lista; conferidos 409 em PUT/DELETE de `publicada` e
  400 para `inep` inválido. Dados de teste removidos.
- Deploy: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev` → PR #74 mergido (`1235494`).

## 6. Próximos passos (fase 2)

- **Coleta de respostas**: rota pública por `id`/token para a comunidade
  responder pelo celular (persistir respostas, validação por pergunta).
- **Login/vinculação de gestor** e troca segura de identidade (o `?inep=`
  anônimo continua como fallback).
- **Gráficos/analytis** por pesquisa (taxa de resposta, distribuição por
  pergunta, geral vs por escola).
- As 4 falhas pré-existentes da suite completa (`paginationStore`,
  `SchoolRankingPage`) seguem no backlog.