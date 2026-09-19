# Nota técnica — Pesquisas do gestor (fase 2: link público, login e resultados)

> Data: 2026-09-19 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

A fase 1 entregou criação/gestão de pesquisas (wizard celular, autosave). A
fase 2 fecha o ciclo: a comunidade responde por um **link público**, o gestor
faz **login** e vê **resultados agregados** com gráficos — tudo sem
bibliotecas externas de chart.

Decisões do usuário para a **fase 2** (entregue):
- **URL pública `/p/<token-uuid>`** — token aleatório por pesquisa (não o `id`
  numérico) para impedir enumeração.
- **Bloqueio leve por dispositivo**: UUID anônimo em `localStorage`
  (`edumaps_dispositivo_id`); servidor usa UNIQUE `(pesquisa, dispositivo)`.
- **Login de gestor** com senha opcional no cadastro; **escrever/publicar não
  exige login**, mas **visualizar resultados exige sessão do gestor da mesma
  escola** (403 se `cod_inep` divergir).
- **Gráficos SVG puro custom** (componente `OpcaoBars`) — descartado
  `@carbon/charts`.

## 2. Problema / decisões de desenho

- **Schema** (migração `gestor_respostas`): `gestor_pesquisas.token` (uuid
  unique), `gestores.senha_hash` (HMAC-SHA256 + salt por gestor, formato
  `<salt32hex>:<hash64hex>`), `clean.sessoes` (bearer uuid, expira `NOW()+30
  days`), `gestor_pesquisas_respostas` (+ `_itens`: uma linha por opção ou
  texto livre). Ids de opção referenciam o JSONB de `opcoes`.
- **API** (em `Controller/Pesquisa.pm`): `POST /api/gestor/login`,
  `GET/POST /api/gestor/me|logout` (sob `under` `_require_gestor`),
  `GET/POST /api/gestor/pesquisas/publica/:token[(:resposta)]`,
  `GET /api/gestor/pesquisas/:id/resultados`.
- **Hash de senha**: nunca em claro; `_verify_senha` compara em tempo
  constante por schema (`salt:hash`); senha opcional → `senha_hash` NULL
  mantém gestores legados funcionando (só sem login).
- **Resultados agregados**: contagem por opção + `pct` (nas perguntas de
  escolha) e últimos textos livres com `respondida_em`.

## 3. Solução

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Migração | `data_pipeline/{deploy,revert,verify}/gestor_respostas.sql` | token, senha_hash, sessoes, respostas + itens |
| Backend | `Roles/Business/Pesquisa/Respostas.pm` (novo) | `survey_for_public`, `register_answer` (validação por pergunta + bloqueio dispositivo), `survey_results` |
| Backend | `Roles/Business/Pesquisa/{Gestores,Surveys}.pm` | login/me/logout/sessões (HMAC), `token` no detail/list |
| Backend | `Controller/Pesquisa.pm` | autenticação bearer, publica form/resposta, resultados c/ 403 por escola |
| Frontend | `features/resposta/` (novo) | página `/p/:token` full-bleed sem nav (App.svelte) |
| Frontend | `features/gestor/components/survey/{OpcaoBars,GestorLoginCard}.svelte` | gráfico SVG puro + cartão de login |
| Frontend | `features/gestor/pages/GestorPesquisasResultadosPage.svelte` | resultados (login se 401, sair, volta à lista) |
| Frontend | `shared/api/client.js` (`setApiToken`) · `utils/gestorSession.js` · `utils/dispositivo.js` | bearer global + sessão + fingerprint anônimo |
| Frontend | `mocks/{handlers,fixtures}.js` | MSW: login/me/logout/publica/resultados com auth exigida |

### Roteamento `/p/:token` (frontend)

Trocamos o match exato do array por `matchRoute()` segmento a segmento
(retorna `{path, component, params}`). `App.svelte` renderiza `/p/:token`
sem `Nav`/`Toast` e injeta `...(match.params ?? {})`. O `publica/:token` vem
**antes** de `:id/resultados` nos handlers MSW (especificidade).

## 4. Armadilhas encontradas (importante)

- **Role::Tiny "last wins"**: os helpers `_rows/_row/_decode_opcoes` existem
  em mais de uma role — manter cópias idênticas ao compor `Model/Pesquisa.pm`.
- **`_require_gestor`**: depois de `_render_unauthorized` deve `return 0` para
  quebrar a cadeia do `under` (senão "A response has already been rendered").
- **Mojolicious injeta o `qr` de requirement como capture** quando o segmento
  vem vazio (ex.: `/publica/`): binding de um `qr` no DBI estoura
  **"Cannot bind a reference"** (500). Fix com `_valid_public_token` que exige
  string uuid de 36 chars e devolve 404 (coberto por teste).
- **Testes frontend MSW**: `answeredDispositivos` é `Set` a nível de módulo —
  limpar `localStorage` entre testes (o uuid do device muda e não cruza 409).
- **`create` exige `perguntas: []`** no corpo (o `_survey_payload` valida o
  array) — padronizado no client da fase 1 (`gestor_id` + `titulo`).

## 5. Validação

- Backend: `prove -l t/04-api/pesquisa.t` — **12/12 PASS** (migração aplicada
  localmente via psql; registro sqitch local desyncado — passada manual).
- Frontend (container): venues novas — `routes`, `client`,
  `gestorPesquisasApi`, `SurveyWizard`, `PublicaRespostaPage`,
  `GestorPesquisasResultadosPage`, `GestorPesquisasPage` — todas **PASS**;
  suite completa 230/234 (mesmas 4 falhas pré-existentes).
- E2E curl no container: perfil → login ok/401 → create+PUT+finalizar →
  publica form → resposta (ok/409) → resultados 401 (sem token) → resultados
  200 com agregação correta → logout invalida `/me`.
- Deploy: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev` (build OK) → PR cria/merge.

## 6. Próximos passos

- **Reuso do gráfico**: `OpcaoBars` é específico de pesquisa — avaliar
  extrair para `shared/ui/components/charts` ao consolidar o Painel do Gestor.
- **Métricas derivadas**: taxa de resposta (respostas↔alunos/IBGE), exportação
  CSV, comparação entre pesquisas da mesma escola.
- **Sessão ainda mais segura** (se for a produção): HttpOnly cookie em vez de
  bearer no `localStorage`; rate-limit no login.
- As 4 falhas pré-existentes da suite completa ficam no backlog.