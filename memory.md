# Memory — EduMaps

> Arquivo de restauração de sessão. Registrar aqui tudo que foi descoberto
> e/ou informado pelo usuário, para retomar o contexto em sessões futuras.
> As seções abaixo ficam em ordem cronológica reversa (sessão mais recente no topo).

> **Convenções duráveis (valem para toda sessão)**:
> - **Testes de frontend** (`vitest` / `npm run test:run`): rodar **SOMENTE no
>   container** `backend.edumaps` — **NUNCA na máquina local**:
>   `ssh root@backend.edumaps 'cd /opt/edumaps/frontend/edumaps && npm run test:run'`
>   (ou `npx vitest run src/features/<feature>`). Idem para o build (via
>   `deploy_frontend_dev`).
> - **Componente com LeafletMap em teste (jsdom)**: NUNCA instanciar o
>   `LeafletMap` real — usar o stub `features/<feature>/components/__tests__/LeafletMapStub.svelte`
>   (importa o `provideMapContext` real de `features/map/context.js` e injeta
>   `{map:null, ready:false}`, assim os filhos como `SimilarMarkers` não tocam
>   Leaflet). Padrão em `SimilarSchoolsSearch.test.js`.
> - **`curl` no container via nginx**: o fallback SPA depende do `server_name`;
>   `curl http://localhost/...` (Host localhost) devolve 404 mesmo para rotas
>   válidas. Usar `-H "Host: ubatexu.lan"`.
> - **Constraints de rota no Mojolicious**: passar hashref depois do path
>   (`$r->get('/:x' => {x => qr/\d+/})`) vira **defaults**, não constraint — a
>   rota casa qualquer valor. Use **arrayref**: `$r->get('/:x' => [x => qr/\d+/])`.
> - **Validação (Mojolicious::Validator)**: `$v->error($campo)` devolve
>   `[$check, $result, @args]`; `->[0]` é o **nome do check** (`like`, `size`…),
>   não mensagem. Mapear para texto legível antes de renderizar.
> - **Dois bancos em dev**: o backend em container usa `Database` (LXC, user
>   `edumaps`/`change_me`, `ssh root@database.edumaps`); os testes locais (`t/`)
>   usam `ubatexu.lan` (user `devel`/`senhaboa123`). Migrações manuais precisam
>   ser aplicadas nos **dois**. `num` do Validator só aceita inteiro — decimais
>   exigem `like(qr/\d+(?:[.,]\d+)?/)` + normalizar vírgula.

> **Pendências / correções futuras (backlog técnico)**:
> - _(vazio no momento — os 3 itens anteriores foram resolvidos no PR #79,
>   2026-09-20: `info_enrollment` somava turno como deficiência; timestamps
>   `null` no upsert de gestor; `?inep=abc` devolvia 400 em vez de 404.)_

## Sessão — eduBR: perfil modal de diretores (censo_gestor)

- **Repo** `~/Projects/eduBR`; branch **`feat/edubr-perfil-gestor`**; commits
  `7e13343` `feat(edubr): perfil modal de diretores (censo_gestor)`,
  `2ec38b7` `docs(edubr): report de perfil modal de diretores` e `589d582`
  `docs(edubr): skill com perfil de gestores`. **PR #3 criado** (2026-09-21),
  aguardando aprovação/merge. `main` local == branch apontando p/ PR.
- **Fonte**: `~/Documents/Notas/gestor_edumaps_perfil.md` é **referência à
  parte** — decidido: nossos números primeiro, literatura não é assertada.
  Decisões do usuário: só análise no eduBR (sem API/UI); unidade **gestor**
  (principal) + **escola** (sensibilidade); base válida por dimensão (cor/raça
  "não declarada" fora do denominador; vínculo só públicas; escola privada sem
  forma de acesso público); Brasil/rede/região/UF.
- **`R/gestor.R`**: `censo_gestor()` (catálogo +`clean.censo_gestor`),
  `gestores()` (lazy; filtra/rotula no SQL via `eduBR_case_when_lookup` —
  `case_when` a partir de vetor nomeado; **evitar** indexação R e `.env$fn()`
  dentro de `filter`/`mutate` em tbl dbplyr), `perfil_gestor()` (9 dimensões;
  materializa e agrega **em R**; retorna `$proporcoes`/`$modal` com
  Herfindahl/`$n`; `composicao=FALSE` marca categorias fora da composição do
  modal).
- **Pegadinhas da rodada**: colunas reais de `clean.censo_gestor`/`censo_escolas`
  são **minúsculas** (`tp_dependencia`, `no_municipio`), não o `UPPER_CASE` do
  deplay `.sql` (desatualizado); `dplyr::select(tbl, "co_entidade")` sem
  `all_of()` gera NOTE no check; lint non-ASCII no código → escapar literais
  com `\uXXXX` (comentários ficam UTF-8); fixture de teste precisa de TODAS as
  colunas de contagem das dimensões testadas; `.env$fn()` dentro de `filter`
  não traduz (pré-computar o valor).
- **Números reais (2025)**: 190.641 diretores / 180.540 escolas. Feminino em
  todas (municipal 82,1%, privada 83,9%, estadual 65,6%); **federal 73,7%
  masculino**. Cor/raça modal branca em todas; municipal na borda (45,6%).
  Acesso ao cargo separa redes: proprietário/sócio privada 52,1%, eleição
  federal 81,6%, municipal processo seletivo 33,8% + indicação 32,9% + eleição
  15,2%, estadual três vias ≈ 20–26%. Formação continuada em gestão 7,2%
  (federal) a 27,0% (municipal). Sensibilidade gestor→escola: **zero** trocas
  de categoria modal (só variação ≤3,3pp).
- **Report**: `analysis/perfil_gestor.Rmd` renderizado no container
  `rstudio.dev` (html ~9MB, gitignored); snapshot `analysis/capturar_gestor.R`
  → `analysis/dados_gestores.rds` (180.540 linhas × 77 col). Render exige
  `devtools::load_all()` (a cópia instalada do eduBR no container é
  desatualizada e `install_local` não funciona).
- **Testes/check**: `devtools::test()` 282 ok (+1 skip smoke) e
  `devtools::check()` **0/0/0**, no container. Após o 2º commit o rsync
  post-commit falhou uma vez (`code 255`) — re-sync manual confirmou.
- **Repo `edumaps`**: sem mudanças de código neste ciclo (só docs: NOTA 51,
  este memory).

## Sessão — Relações Institucionais: Etapa 5 (tarefas + indicadores)

- **Repo** `edumaps`; branch `feat/relacoes-tarefas` (a partir de `origin/main`);
  commits `f06d2b8` (data_pipeline), `5f8ce06` (backend), `5760c1f` (frontend).
  **PR #83** → `main`, merge commit **`0226819`** (2026-09-21). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `relacoes_tarefas` (checklist por relação: descrição,
    responsável, prazo, status `pendente|concluida`, `concluida_em`; FK CASCADE).
  - backend: CRUD de tarefas por relação (o detalhe passa a incluir `tarefas`);
    `GET /relacoes/indicadores` (derivado, sem tabela) com resumo, demandas por
    grupo, relações sem atividade (60 dias) e tempo médio até a 1ª interação.
  - frontend: checklist de tarefas no detalhe e aba **Indicadores** em
    `/gestor/relacoes`.
- **Fora do escopo (documentado)**: **grafo institucional cross-escola**
  ("fornecedores atendem várias escolas") — exige política de
  agregação/anonimização entre escolas; os indicadores entregues são por escola.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (63 ok);
  frontend (container) `npx vitest run src/features/gestor` (118 ok); suite
  completa 290 ok (4 falhas pré-existentes). Smoke real: tarefa 201, indicadores
  `abertas=1`/`vencidas=1`/`tarefas_pendentes=1`.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Status do módulo de Relações Institucionais**: Etapas 1–5 concluídas.

## Sessão — Relações Institucionais: Etapa 4 (interações + documentos)

- **Repo** `edumaps`; branch `feat/relacoes-gestao` (a partir de `origin/main`);
  commits `aa3e788` (data_pipeline), `083f368` (backend), `8c5c2c7` (frontend).
  **PR #82** → `main`, merge commit **`2cbbb90`** (2026-09-21). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `relacoes_gestao` — `relacoes_interacoes` (timeline:
    data/canal/participante/assunto/descrição/resultado) e `relacoes_documentos`
    (tipo/data/referência + arquivo no `upload_dir`), FK `relacoes` `ON DELETE
    CASCADE`.
  - backend: CRUD de interações e documentos (upload/download/delete) por
    relação; `relacao_detail` devolve `interacoes` e `documentos`; excluir a
    relação remove os arquivos do disco. Rotas `.../relacoes/:id/interacoes[/:interacao_id]`
    e `.../relacoes/:id/documentos[/:documento_id]` (constraints arrayref).
  - frontend: `RelacaoDetailPage.svelte` em `/gestor/relacoes/:id` (resumo,
    timeline de interações, documentos anexar/baixar/remover) + link "Abrir" na
    lista.
- **Armadilha**: um `}` sobrando no `.svelte` só apareceu no `vite build` (o
  build/deploy é a validação real do frontend).
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (61 ok);
  frontend (container) `npx vitest run src/features/gestor` (115 ok); suite
  completa 287 ok (4 falhas pré-existentes). Smoke real: interação 201,
  documento anexado, detalhe com `interacoes`/`documentos`.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Pendência/próxima etapa**: Etapa 5 (tarefas + indicadores/rede).

## Sessão — Relações Institucionais: Etapa 3 (Agenda institucional)

- **Repo** `edumaps`; branch `feat/relacoes-agenda` (a partir de `origin/main`);
  commits `5475720` (backend), `c2ab6e0` (frontend). **PR #81** → `main`, merge
  commit **`cfb31ae`** (2026-09-21). `main` == `origin/main`.
- **Sem tabela nova**: a agenda é **derivada** de `clean.relacoes`.
- **backend**: `agenda_relacoes` — relações abertas com prazo e/ou próxima ação,
  ordenadas por prazo, recorte `de`/`ate`, separação das **sem prazo** e contagem
  de **vencidas**. Rota `GET /api/gestor/:cod_inep/relacoes/agenda` (literal
  antes de `/:id`).
- **frontend**: aba **Agenda** em `/gestor/relacoes` — agrupamento por mês,
  destaque de vencidas, recorte por data e seção "Sem prazo definido";
  `getAgenda` + handler MSW.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (59 ok);
  frontend (container) `npx vitest run src/features/gestor` (111 ok); suite
  completa 283 ok (4 falhas pré-existentes). Smoke real: `total=2`,
  `vencidas=1`, 1 com prazo e 1 sem prazo.
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev` (sem migração).
- **Pendências/próximas etapas**: Etapa 4 (interações + documentos/anexos) e
  Etapa 5 (tarefas + indicadores/rede).

## Sessão — Relações Institucionais da escola (entidades + relações, MVP)

- **Repo** `edumaps`; branch `feat/relacoes-gestor` (a partir de `origin/main`);
  commits `dfed292` (data_pipeline), `27629a6` (backend), `31db7bc` (frontend).
  **PR #80** → `main`, merge commit **`2c2b54b`** (2026-09-20). `main` == `origin/main`.
- **Fonte**: `~/Documents/Notas/gestor_relacoes.md` (discussão de categorias,
  taxonomias e operações). **Decisões do usuário**: MVP = Etapas 1+2; taxonomia
  editável semeada; responsável interno em texto livre; fornecedores separados do
  inventário; anexos só na Etapa 4; status/prioridade enums fixos; painel
  "Relações da escola" em `/gestor/relacoes` com link "🤝 Relações".
- **Entregas**:
  - data_pipeline: `relacoes_categorias` (eixo `entidade|finalidade`, origem
    `padrao|manual`, UNIQUE `cod_inep+eixo+lower(nome)`), `relacoes_entidades`
    (atores externos + `atributos jsonb`) e `relacoes` (centro: entidade →
    assunto/finalidade/responsável/próxima ação/prazo; `status` e `prioridade`
    com CHECK; FK entidade `ON DELETE RESTRICT`).
  - backend: `Roles::Business::Gestor::Relacoes` — `sincronizar_categorias_padrao`
    (7 grupos + 10 finalidades), CRUD de categorias/entidades/relações e filtros
    (`status`, `prioridade`, `vencidas`, `entidade_id`, `q`); `vencida` derivado.
    Rotas `/api/gestor/:cod_inep/relacoes[/...]` (constraints arrayref).
  - frontend: `/gestor/relacoes` (abas Relações/Entidades externas, filtros,
    badges, destaque de vencidas, modais) + link no painel.
- **Armadilha (Role::Tiny "last wins" é falso na prática)**: `list_categorias`/
  `create_categoria`/`update_categoria`/`delete_categoria` do módulo Relações
  colidiam com `Inventario.pm` (composto **antes**) e as chamadas caíam na versão
  do inventário. Renomeados para `*_relacoes_categoria(s)`. **Ao compor várias
  roles no mesmo Model, use nomes de método únicos por módulo** — ou confira qual
  role vence. (O mesmo vale para helpers `_rows/_row/_txn`/`_encode_atributos`:
  manter cópias idênticas.)
- **Não é CRM**: o centro é a relação; sem leads/oportunidades/pipeline.
- **Testes**: backend `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` (58 ok);
  frontend (container) `npx vitest run src/features/gestor` (109 ok); suite
  completa 281 ok (4 falhas pré-existentes). Smoke real: 17 categorias, entidade
  e relação criadas (201).
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Pendências/próximas etapas**: Etapa 3 (Agenda institucional), Etapa 4
  (interações + documentos/anexos), Etapa 5 (tarefas + indicadores/grafo da rede).

## Sessão — Limpeza do backlog técnico (turno, timestamps, 404)

- **Repo** `edumaps`; branch `fix/backlog-tecnico` (a partir de `origin/main`);
  commits `87f0d27` (data_pipeline), `80c7eea` (backend). **PR #79** → `main`,
  merge commit **`f8c3312`** (2026-09-20). `main` == `origin/main`.
- **[alta] `info_enrollment` somava TURNO como deficiência**:
  `deficiencia_basica` = `qt_mat_bas_d + dm + dv`, mas `_d/_dm/_dv/_n` são
  **Diurno/Matutino/Vespertino/Noturno** (validado: `dm+dv=d` e `d+n=total` em
  **100%** das linhas; `avg(d/bas)=0,934`, `avg(esp/bas)=0,056`). Removido o
  campo e adicionado o bloco **`turno`** (diurno/matutino/vespertino/noturno/
  integral). Educação especial fica em `especial`/`esp_cc_total`/`esp_ce_total`
  (`qt_mat_esp*`). `info_enrollment` **não é exposta por controller** — só o
  teste `t/02-models/school/matricula.t` a usa.
- **Comentários das 60 colunas de turno** estavam rotulados como "Deficiência"
  pelo loader. Nova migração **`censo_turno_comments`** (60 `COMMENT ON COLUMN`)
  + POD de `Schema/Result/CensoMatriculas.pm` (replace global).
- **[média] `upsert_gestor`**: `RETURNING` agora inclui `created_at, updated_at`.
- **[baixa] `Pesquisa#index`**: `?inep` ausente → 400; formato inválido → 404
  (padrão do projeto p/ `codigo_ibge`, via constraint de rota).
- **Correção de registro**: a observação do PR #78 sobre `scores_view.sql`/
  `badge_functions.sql` usarem `in_in_*` era **falsa** (usam
  `in_material_ped_*`); corrigida no corpo do PR #78.
- **Testes**: `prove -vl t/02-models/school/matricula.t t/04-api/pesquisa.t`
  (PASS; novos asserts de `turno`/`DNE`/timestamps/404) e
  `prove -rl t/04-api/gestor/` (41 ok). Smoke real: `?inep=abc`→404, sem
  `inep`→400, `POST /perfil` com timestamps.
- **Deploy**: migração em `ubatexu.lan` + `Database` (verify ok);
  `deploy_backend_dev` (sem frontend).

## Sessão — Painel de Inventário Escolar (recursos e serviços)

- **Repo** `edumaps`; branch `feat/inventario-escolar` (a partir de `origin/main`);
  commits `eb574c7` (data_pipeline), `331a236` (backend), `a547c20` (frontend).
  **PR #78** → `main`, merge commit **`dc16c3c`** (2026-09-20). `main` == `origin/main`.
- **Decisões do usuário**: baseline **derivado do Censo ao vivo** (nunca copiado
  no banco); itens/serviços **unificados** (tipo vem da categoria); **semear a
  taxonomia do Censo** (9 categorias); **importar do Censo**; **anexos no v1**
  (vários por item); obrigatórios `nome`+`categoria` (`quantidade`/`valor`
  opcionais); **qualquer gestor** edita; sem catálogo global (por escola).
- **Entregas**:
  - data_pipeline: `inventario_categorias` (tipo recurso/servico, origem
    censo/manual, UNIQUE `cod_inep+tipo+lower(nome)`), `inventario_fornecedores`,
    `inventario_itens` (recursos e serviços, `atributos jsonb` + GIN,
    `censo_ref` UNIQUE parcial p/ import idempotente) e `inventario_anexos`
    (vários por item).
  - backend: `Roles::Business::Gestor::Inventario` — `inventario_censo` (lê
    `clean.censo_escolas`, 6 grupos), `sincronizar_categorias_censo` (lazy),
    `importar_censo` (idempotente por `censo_ref`), CRUD de
    categorias/itens/fornecedores e anexos. Rotas
    `/api/gestor/:cod_inep/inventario[/...]` (constraints arrayref).
  - frontend: `/gestor/inventario` (abas Do Censo/Recursos/Serviços/
    Fornecedores, modais, atributos livres chave-valor, anexos) + link no painel.
- **Técnica de flexibilidade**: nenhuma coluna nova para criar categoria/item —
  categorias livres + `atributos jsonb`; arquivos de anexo em `upload_dir`.
- **Armadilhas**: (1) colisão de métodos de role — `registrar_anexo`/`anexo_row`
  do Inventário colidiam com Reuniões (Role::Tiny mantém o da **primeira** role);
  renomeados para `registrar_anexo_item`/`anexo_item_row`/etc. (2) `$anexo_check`
  com arrayref aninhado quebra constraints (deve ser lista plana). (3) `num` só
  inteiro (ver convenção). (4) backend de container usa banco `Database` (ver
  convenção) — migração aplicada em `ubatexu.lan` **e** `Database`.
- **Testes**: backend `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` (53 ok);
  frontend (container) `npx vitest run src/features/gestor` (102 ok); smoke real
  `GET /inventario` (9 categorias + baseline), `POST /importar-censo` → 39 itens,
  reimport → 0.
- **Deploy**: migração em `ubatexu.lan` + `Database`; `deploy_backend_dev` +
  `deploy_frontend_dev`.

## Sessão — Reuniões e atas do gestor (agenda, contatos e anexos)

- **Repo** `edumaps`; branch `feat/reunioes-gestor` (a partir de `origin/main`);
  commits `196497d` (data_pipeline), `6bc6d4f` (backend), `0974a5a` (frontend).
  **PR #77** → `main`, merge commit **`fde99b2`** (2026-09-20). `main` == `origin/main`.
- **Entregas**:
  - data_pipeline: `gestor_reunioes` (contato_grupos, contatos, reunioes,
    reunioes_participantes, reuniao_anexos) e `gestor_reunioes_grupos_folha`
    (origem folha/manual, `gestor_id` opcional).
  - backend: módulo Reuniões & Atas (CRUD de contatos/grupos, agenda, ata e
    anexos em `upload_dir`), `perfil_escola`/`transferencia` (gestor responsável
    pela agenda = criador da 1ª reunião), auto-cadastro governado (409 para
    e-mail novo em escola com agenda) e task `GruposFolha` (seed idempotente).
  - frontend: páginas de contatos e reuniões (lista com filtros, wizard de 4
    passos, detalhe com ata/anexos), `apiClient.upload/download` (multipart +
    blob) e link "Reuniões da escola" no painel do gestor.
- **Decisões**:
  - Rotas novas usam **arrayref** de constraints — hashref vira defaults (ver
    convenção durável); foi a causa do 401 em `/api/gestor/pesquisas`.
  - `QUANDO_RE` aceita `[ T]` (o `buildReuniaoPayload` do frontend envia espaço).
  - `_render_validation` (Gestor e Pesquisa) mapeia o check para mensagem PT-BR
    (antes expunha `like`/`size`); correção do "❌ like" no botão "Agendar".
  - Edição preenche o `datetime-local` com `T` (formato válido do input).
- **Testes**: backend `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` (46 ok);
  frontend (container) `npx vitest run src/features/gestor` (94 ok); smoke real
  `POST /api/gestor/:inep/reunioes` com data do frontend → 201.
- **Deploy**: `deploy_frontend_dev` + `deploy_backend_dev` (dev).
- **Pendências**: `_reuniao_validation` calcula `$input->{__duracao}`/`__aviso`
  que o controller ignora (código morto; default aplicado no model). O diretório
  `docs/clients/` do branch `docs/clients-apresentacao` ficou fora deste PR.

## Sessão — Pesquisas do gestor (fase 2: link público + login + resultados)

- **Repo** `edumaps`; branch `feat/pesquisas-gestor-fase2`; commits:
  `7c17a06` (data_pipeline: migração `gestor_respostas`), `6fdd9d5` (backend:
  coleta pública/login/resultados), `ff00633` (frontend fase 2), `14b683f`
  (fix backend: `/publica/` sem token → 404 em vez de 500). **PR #75** →
  `main`, merge commit **`837c573`** (2026-09-19). `main` == `origin/main`.
  memory+nota técnica no commit `52553be`. Números: backend 12/12 PASS;
  frontend novo 53 PASS; suite completa 230/234 (4 falhas pré-existentes).
- **Escopo fase 2** (decisões do usuário): link público **`/p/<token-uuid>`**
  (UUID aleatório por pesquisa — impede enumeração por id); bloqueio leve
  "já respondeu" por dispositivo (`edumaps_dispositivo_id` em localStorage +
  UNIQUE no servidor, 409); **login do gestor** (`POST /api/gestor/login`,
  `GET /me`, `POST /logout`; senha no `POST /perfil` 6..64, hash
  HMAC-SHA256+salt em `clean.gestores.senha_hash`); sessão bearer em
  `clean.sessoes` (expira 30 dias); escrever/publicar **não** exigem login;
  **resultados exigem sessão do gestor da mesma escola** (403 se `cod_inep`
  diverge); gráficos em **SVG puro** (componente `OpcaoBars`, sem charts lib).
- **Schema**: nova migração `gestor_respostas [gestor_pesquisas]`
  (`token` uuid, `senha_hash`, `clean.sessoes`, `clean.gestor_pesquisas_respostas`
  + `_itens`). Aplicada em `database.edumaps` via `deploy_db_dev` e local
  via psql manual (sqitch registry local desyncado — passada manual como na
  fase 1).
- **Backend**: `Roles/Business/Pesquisa/Respostas.pm` (novo) — `survey_for_public`,
  `register_answer` (valida por pergunta: exatamente uma opção p/ unica/dropdown,
  texto 1..500, UNIQUE dispositivo → 409 `already_answered`), `survey_results`
  (contagem/pct + textos livres). `Gestores.pm` ganhou login/me/logout/sessão.
  `Controller/Pesquisa.pm`: `_require_gestor` (under bearer; **retorna 0** após
  render de 401), `publica_form/publica_resposta`, `resultados` (403 por escola),
  `_valid_public_token` (guarda contra `qr` injetado por Mojolicious no segmento
  vazio → "Cannot bind a reference").
- **Frontend**: `routes.js` agora faz match segmento a segmento (`matchRoute`
  retorna `{path, component, params}`); `App.svelte` renderiza `/p/:token` sem
  nav/Toast (full-bleed) e injeta os params. `client.js` ganhou
  `setApiToken/getApiToken` (injeta `Authorization: Bearer` em toda request).
  Feature `resposta/` (página pública) + `GestorLoginCard` + `OpcaoBars` +
  `GestorPesquisasResultadosPage` (login se 401, "Sair", volta à lista).
  `GestorPesquisasPage`: "Copiar link" + "Resultados" para publicadas.
  MSW com auth exigida (`Authorization: Bearer 88888888-…`).
- **E2E (container)**: fluxo completo passou — perfil→login(ok/401)→
  create(`perguntas:[]`)/PUT/finalizar→publica form→resposta(ok/409)→
  resultados(401/200)→logout invalida `/me`. `/p/<uuid>` servido pelo nginx
  (fallback SPA 200). Deploy: `rex prepare` + `deploy_db_dev` +
  `deploy_backend_dev` + `deploy_frontend_dev`.
- **Nota técnica**: `docs/new_ideas/implementations_ideas/notas_tecnicas_43.md`.

## Sessão anterior — Pesquisas do gestor (fase 1: cadastro + criação/gestão)

- **Repo** `edumaps`; **PR #74** (`feat/gestor-pesquisas`) → `main`, merge commit
  **`1235494`** (2026-09-19). Commit único `67ba676` (33 files, +2877). `main` ==
  `origin/main`. **Migração Sqitch** `gestor_pesquisas [schemas]` aplicada nos
  dois alvos: `database.edumaps` (containers, via `rex deploy_db_dev`) e local
  (`ubatexu.lan/edumaps_dev`, via psql manual — o alvo `dev_super` NÃO tem
  pgvector e não consegue deploiar a cadeia completa).
- **Escopo fase 1** (decisões do usuário): apenas criação/gestão; identidade
  anônima `?inep=` (sem login); autosave no servidor (debounce 600ms, sem botão
  salvar); 1 gestor = 1 escola (`cod_inep`); nome/e-mail obrigatórios (e-mail
  identifica a sessão → upsert), telefone/cargo/CPF opcionais; **LGPD: CPF
  sempre mascarado na API** (`***.***.***-123`, `cpf_masc`); sessão via
  localStorage (`edumaps_gestor_<inep>`). Coleta de respostas, login e
  gráficos → **fase 2**.
- **Schema**: `clean.gestores`, `clean.gestor_pesquisas`,
  `clean.gestor_pesquisas_perguntas` (FK cascade; `opcoes` JSONB; `id` de opção
  preservado do uuid do wizard; `status` com CHECK `rascunho|publicada|arquivada`).
- **Backend** `Plugin/API/Pesquisa.pm` (base `/api/gestor/pesquisas`):
  `POST /perfil` (upsert por e-mail), `GET /` (`?inep=`), `POST /` (cria
  **rascunho com 0 perguntas** — autosave ao digitar o título), `GET|PUT|DELETE
  /:id`, `POST /:id/finalizar`. Regras: `publicada` é **read-only** (PUT/DELETE →
  409); `finalizar` exige ≥1 pergunta; `_survey_payload` valida 0..30 no
  create/update; formato inválido de `inep` → 400 (decidido). Model compõe
  Roles `Gestores` + `Surveys` (Role::Tiny, SQL raw via `dbh_do`).
- **Armadilhas de implementação no backend**:
  - Mojolicious 9.49 **não tem check `length`** — validar tamanho com
    `size(min, max)` (built-ins: `equal_to/in/like/num/size/upload`).
  - `txn_do` retorna o valor da **última expressão do bloco**; um `for (...)`
    como última expressão devolve falsy → `update_survey` dá resultado próprio
    (re-registra o survey e relê o detail) em vez de depender do retorno.
  - `survey_detail` monta `gestor` (nome/email) **antes** de remover os campos
    do hash (senão sumiam do join).
  - DELETE 204 exige `render(status => 204, text => '')` (senão "Could not
    render a response").
- **Frontend** (pastas em `features/gestor/`):
  - `pages/GestorPesquisasPage.svelte` (`/gestor/pesquisas?inep=` — lista por
    status, excluir rascunho com `confirm`, banner do gestor/sessão) e
    `pages/GestorPesquisasWizardPage.svelte` (nova/editar; `readonly` se
    `publicada`).
  - `components/survey/{SurveyWizard,StepsIndicator,PhoneMockup,QuestionEditor}.svelte`
    — wizard: passo gestor → dados → **1 pergunta por tela** → revisão/finalizar;
    preview em moldura de celular; autosave `PUT`/`POST`; `beforeunload` flush.
  - `utils/pesquisaDraft.js` (modelo local: `emptyDraft/newPergunta/
    surveyToDraft/draftToPayload/perguntaErros/tituloValido/
    draftValidoParaFinalizar`) e `utils/gestorSession.js` (localStorage);
    `constants/pesquisas.js` (ANSWER_TYPES, LIMITS); `api/gestorPesquisasApi.js`;
    `mocks/{handlers,fixtures}.js` registrados no barrel `src/mocks/handlers.js`.
  - `apiClient` ganhou `put`/`delete` (`src/shared/api/client.js`).
  - **Pitfalls do wizard (Svelte 5)**: `stepKeys` é `$derived` — navegar por
    chave (`goToKey('info'/'revisao'/'q<n>')` com `tick()` após `push`) em vez
    de índices; `addPergunta` usa `tick().then()` porque o derivado ainda não
    recompilou ao setar `step`.
  - **`questionIndex`/`QuestionEditor` mutam o objeto `pergunta` do
    `$state` do rascunho** (não copiar — Svelte 5 rastreia a mutação).
- **Testes**: backend `prove -l t/04-api/pesquisa.t` **8/8 PASS** (local; push
  de fixtures via SQL manual no `ubatexu` porque o cluster local não tem
  pgvector). Frontend `vitest src/features/gestor` **49/49 PASS** (container);
  as 4 falhas de `paginationStore`/`SchoolRankingPage` na suite completa são
  **pré-existentes** (confirmado stashando minhas mudanças no container).
  Testing-library: usar `getByRole('heading', …)` quando o passo aparece no
  StepsIndicator E no `<h2>` (multi-match); resetar mocks manuais entre testes
  (`vi.clearAllMocks()` — vitest não limpa `vi.fn()` por padrão).
- **Deploy**: `rex prepare` (rsync) + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev`. E2E via curl **dentro do container**
  (`ssh root@backend.edumaps 'curl -H "Host: ubatexu.lan" http://127.0.0.1:3000/...'`
  — `:3000`/morbo não é exposto ao host; `backend.edumaps` vindo do host não
  resolve). Fluxo completo validado e **dados de teste removidos** (psql no
  `database.edumaps` user `edumaps`). O container roda **Perl 5.36** (testes
  backend rodam só local, precisam de 5.38+ p/ `feature ':5.38'`).

## Sessão — eduBR: random forest p/ classificar desempenho (fund. I/II)

- **Repo** `~/Projects/eduBR`; **PR #2** (`feat/edubr-random-forest-desempenho`)
  → `main`, merge commit **`cdd741f`** (2026-09-18). Dois commits: `b070451`
  `feat(edubr): random forest p/ desempenho` + `02e3878`
  `docs(edubr): report RF de desempenho (fund I/II)`. `main` == `origin/main`.
- **Modelo**: classificar **escolas públicas** (fund. I/II) em
  **alto/médio/baixo** pelos **terços globais** de `nota_media` (SAEB
  matemática+português, IDEB 2023) com **Random Forest (ranger)** sobre a MV
  `analytics.escola_features` (`analytics.prepare_school_data()`: censo 2025 ×
  nota 2023 → **associativa/diagnóstica**, não previsão). Referências:
  `~/Documents/Notas/pesquisa.md` (Fusco et al. 2025; Cechinel et al. 2026,
  *Scientific Reports* — RF + importância p/ reduzir dimensão).
- **`R/desempenho.R`**: `features_escola()` (lazy; `tp_dependencia ∈ {1,2,3}`),
  `classificar_desempenho()` (tercis por etapa → fator ordenado `baixo/medio/alto`),
  `limites_desempenho()` (vetor simples se 1 grupo, senão lista nomeada).
- **`R/floresta.R`**: `dividir_dados()` (estratificado), `treinar_floresta()`
  (ranger `classification+probability+importance="permutation"`; **exclusão
  padrão inclui identificadores espaciais** `sg_uf/uf/co_municipio/...` — UF
  é rótulo de agregação, nunca preditor — pegadinha corrigida no meio da
  rodada), `importancia_floresta()`, `predizer_floresta()`
  (`nivel_pred` + `p_<classe>`), `metricas_floresta()` (acuracia, F1/AUC macro
  por postos/Wilcoxon, `baseline_acerto`; attrs `confusao`/`f1_classe`/
  `auc_classe`). `ranger` em **Suggests** (não usar `vip`: só instala no
  container; daria NOTA no check).
- **Resultados reais**: tercis fund. I = 5,42/6,26; fund. II = 4,72/5,33.
  Com acc. 0.594/0.566 vs baseline 0.333; AUC macro 0.78/0.76; **top-15
  features preserva desempenho** (0.575/0.541); variante **sem INSE** cai
  ~0.05 (NSE domina, mas sobra sinal estrutural). N da base: 41.229 (fund. I)
  e 31.078 (fund. II) públicas com nota.
- **Report**: `analysis/classificacao_desempenho_rf.Rmd` (pipeline por etapa,
  confusão, importância top-20, perfil por nível, % por UF via
  `clean.ideb_notas_escolas.id_escola == co_entidade`). Snapshot de dados em
  `analysis/capturar_dados_rf.R` → `analysis/dados_classificados_rf.rds`
  (`analysis/*.rds` e `tests/testthat/_problems/` gitignored).
- **Execução/testes SEMPRE no container `rstudio.dev` (rsuser)** — nunca
  local. Suite verde (só smoke requer `EDUBR_SMOKE=1`, que também passa);
  `devtools::check()` 0/0/0. Sync via `tools/sync-rstudio.sh` (post-commit).
- **Limites do container**: enlace c/ `Database` intermitente (pulls grandes
  às vezes morrem sem rastro) → **snapshot RDS**; treino com base completa
  estoura memória (**OOM `Killed`**, host ~8 GB) → **amostra estratificada de
  15k escolas/etapa** (`n_amostra`), `num.threads = 2`, `trees = 250`; render
  em background (`nohup /tmp/render_rf.sh`, log em `/tmp/render_rf.log`).
  knitr não renderiza ggplot dentro de listas de `map()` → `|> lapply(print)`.
- **Pendências**: `analytics.view_escolas_ml` é o caminho futuro p/ previsão
  (forecasting) — report documenta que a análise atual é associativa.

## Sessão atual — Busca por escolas similares no painel do gestor

- **PR #72** (`feat/escolas-similares`) → `main`, merge commit **`5e55dfa`**
  (2026-09-18). Commits `e85a8d5` (backend), `bf8f9c5` (frontend), `5f3ba49`
  (docs: nota técnica 40).
- **Backend**: rota **`GET /api/gestor/:cod_inep/similares`** — nova role
  `Roles::Business::Gestor::SimilarSchools` (`similar_schools`, SQL raw via
  `dbh_do`, `$FEATURE_VECTOR`). Similaridade = cosseno pgvector (`<=>`) **on-the-fly**
  (sem migration), **10 dims**: porte (ordinal 0..1 das 6 categorias de
  `clean.escolas.porte_escola`), localização (urbana 1/rural 0 via
  `tp_localizacao`), INSE (`media_inse_alvo/10`; **0 quando o alvo não tem INSE** =
  comparação neutra), 7 etapas one-hot (`in_comum_creche/pre/fund_ai/fund_af/
  medio_medio`, `in_eja`, `in_profissionalizante`). Escopo município/estado/região
  (default município); limit clamp 1..50 (default 10); 404 para INEP inválido.
- **Armadilhas SQL (validado na prática)**:
  - `ARRAY[...]::vector` quebra com NULLs → `COALESCE` nos flags de etapa;
  - `ROUND((1 - (v <=> v))::numeric, 4)` no SQL dá "syntax error at or near AS" →
    arredondar no Perl (`sprintf('%.4f', ...)`), sem cast no SQL;
  - **`CASE WHEN ? IS NULL`** falha em prepared statement server-side
    ("could not determine data type of parameter $1") → cast explícito
    `?::numeric IS NULL`;
  - clamp: `$limit = 10 if $limit < 1 || $limit > 50` trocava `999` por 10 (deveria
    ser 50) → corrigido para `$limit = 1 if $limit < 1; $limit = 50 if $limit > 50`.
- **Frontend**: `SimilarSchoolsSearch.svelte` (dropdown `SCOPE_OPTIONS` + botão
  Buscar + `LeafletMap` + `SimilarMarkers` — alvo azul `#2563eb`, similares laranja
  `#f97316` — + tabela com links `/escola/panel?inep=`); seção `#escolas-similares`
  no `GestorPanel`; `getSchoolSimilares(codInep, {scope, limit})` em `gestorApi.js`.
  INSE ausente na UI → "—" e texto "INSE ausente é ignorado na comparação".
- **Testes**: backend `prove -l t/04-api/gestor/` (painel+similares) 10 PASS;
  frontend gestor 20 PASS no container. `t/04-api/gestor/similares.t` skip local
  (cluster antigo sem pgvector) — happy path só no container app.
- **Deploy**: `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev`.
- **E2E (container, `-H "Host: ubatexu.lan"`)**: município/estado/região corretos;
  região multi-UF (AM/PA/RR); similaridades 0.8381..0.9921; clamp 999→50, 0→1;
  SPA `/gestor/painel` 200.
- Dados úteis: `clean.inse` cobre só ~39% (69.756) das escolas; INSE ausente no alvo
  neutraliza a dimensão (não cobra das candidatas).

## Sessão anterior — Painel do Gestor (`/gestor/painel`)

- **PR #71** (`feat/painel-gestor`) → `main`, merge commit **`82ccb80`**.
  Commits `9e743d4` (backend), `63dc345` (frontend), `45c9d96` (memória).
- **O quê**: nova rota **`/gestor/painel?inep=…`** com **API isolada**
  `GET /api/gestor/:cod_inep/painel`. Raio-x da escola para leitura em ~2 min:
  matrículas por **etapa, turno, modalidade e faixa etária**; salas; docentes
  por **formação, vínculo e disciplina**; **infraestrutura**, **equipamentos**
  e **acessibilidade**.
- **Arquitetura isolada** (sem tocar em módulos pré-existentes além dos pontos
  de integração): `Roles::Business::Gestor::Overview` (lógica), `Model::Gestor`,
  `Controller::Gestor`, `Plugin::API::Gestor` (path `/api/gestor`); registrado
  com **1 linha** em `EduMaps.pm`. Reusa os ResultSets genéricos `CensoEscolas`,
  `CensoMatriculas`, `CensoDocentes` e a `Model::Base`/`Controller::Base`.
- **Descoberta importante (dados)**: as colunas `qt_mat_bas_d / _dm / _dv / _n`
  são **TURNO** (Diurno / Matutino / Vespertino / Noturno), **não deficiência** —
  os comentários do loader (`Deficiência – …`) estão errados. Confirmado em
  todas as ~178,7 mil linhas: `d + n = bas` e `dm + dv = d`. `qt_mat_bas_int`
  (integral) e `qt_mat_bas_ead` são dimensões à parte. **Atenção**: o
  `Profile.pm` (pré-existente) soma `d+dm+dv` como "deficiência" — bug latente,
  não mexido nesta sessão.
- **Limitação "turmas"**: o Censo agregado **não** traz o número de turmas.
  Usamos **salas de aula utilizadas** como referência e expomos `turmas.nota`
  explicando. `alunos_por_sala = matrículas / salas_utilizadas`.
- **Frontend**: feature nova `features/gestor/` (api, constants, utils puros,
  componentes, ícones). Ícones reaproveitam o acervo de `features/schools` e
  acrescentam novos (turno, modalidade, faixa etária, formação, vínculo,
  equipamentos, acessibilidade). Único módulo pré-existente alterado:
  `app/routes.js` (rota nova) e `routes.test.js`.
- **Testes**: backend `prove -l t/04-api/gestor/painel.t` → 6/6; frontend **no
  container** → 19/19 (`transformGestorData`, `GestorPanel`, `gestorApi`,
  `routes`).
- **Deploy**: `deploy_backend_dev` + `deploy_frontend_dev`. E2E:
  `/api/gestor/11000040/painel` 200; SPA `/gestor/painel` 200; bundle OK.

## Sessão anterior — Painel Financeiro da escola (folha/remuneração)

- **PR #70** (`feat/painel-financeiro-escola`) → `main`, merge commit **`99c0573`**
  (2026-09-17). Commits `ec525fe` (backend), `3964643` (frontend), `8cc5663`
  (docs regra), `692a3ca` (memória).
- **O quê**: nova **página separada** `/escola/financeiro` (look-and-feel do
  painel), linkada do `SchoolPanel` ("Painel financeiro →"). Mostra: custo total
  mensal (LineChart), profissionais por mês (LineChart), custo por categoria
  (DonutChart + lista com **ícones**), e um dropdown de competência que leva à
  folha completa (`/escola/payroll?inep=…&date=MM-YYYY`). **Sem nomes** de
  profissionais no painel (só na folha/detalhes).
- **Fonte**: `clean.remuneracao_municipal` (~30,9M linhas, índice por `cod_inep`).
  `categoria` = texto longo; `tipo` = 2 valores (com encoding zoado); `mes` =
  nome PT ("Janeiro"…"Dezembro", "Março" corrompido).
- **Backend**: `GET /api/school/:cod_inep/finance` (`Finance::financial_summary`)
  devolve `escola`, `series` (por ano/mes, com `mes_num` derivado por LIKE de
  prefixo p/ ordenar) e `categorias` (agregado do período todo). Registrado em
  `Plugin::API::School` + `Controller::School#finance`.
- **Frontend**: `schoolApi.getSchoolFinance`; `constants/finance.js` (buckets
  curados Docentes/Administrativo/Alimentação/Multimeios + fallback, com ícones
  novos em `icon-data.js` categoria `finance`); `utils/transformFinanceData.js`
  (puro, testado); `components/panel/SchoolFinance.svelte`;
  `pages/SchoolFinancePage.svelte`; rota em `routes.js`/`schools/index.js`.
  `SchoolPayrollPage` passou a aceitar `?date=`.
- **Bugs corrigidos**: (1) `map { ... } LIST, 'x'` em Perl engolia os itens
  seguintes na LIST (`$_->[0]` em string → 500); corrigido guardando o `map` num
  array. (2) rodei `vitest` local indevidamente — corrigido (regra acima).
- **Validação**: `GET /api/school/11000040/finance` → 200 (12 competências,
  2 categorias); SPA `/escola/financeiro` 200; bundle com "Painel Financeiro".
  Testes de frontend **no container**: 25/25.
- **Commits**: `ec525fe` (backend), `3964643` (frontend), `8cc5663` (docs regra).

## Sessão anterior — seção Desempenho (IDEB) no painel da escola

- **PR #69** (`feat/desempenho-painel-escola`) → `main`, merge commit **`2803421`**
  (2026-09-17). Commits `606a66e` (backend) e `6661691` (frontend).
- **O quê**: nova seção **"Desempenho"** no painel da escola, **abaixo de
  "Escolas semelhantes"**, só quando a escola tem histórico. Um `LineChart`
  (Carbon) com **uma linha por etapa** (`Fundamental I/II`, `Ensino Médio`),
  x = ano, y = **IDEB observado**.
- **Backend**: `School::Profile::panel_info` ganhou o campo `desempenho` lido de
  **`clean.ideb_notas_escolas`** (`IdebNotasEscolas`), ordenado por etapa/ano.
  **NÃO** usar `clean.inep` / `clean.inep_notas_desagregadas` (deprecated).
  Nota: as rotas `/grades` e `/full_grades` do controller são stubs vazios.
- **Frontend**: `transformPanelData.js` normaliza `desempenho`; `SchoolPanelPage`
  repassa; `SchoolPanel` renderiza a seção; novo `SchoolPerformance.svelte`.
- **Dados**: etapas em `clean.ideb_notas_escolas` = `fundamental_i` (2005–2023),
  `fundamental_ii` (2005–2023), `ensino_medio` (2017–2023).
- **Testes**: `SchoolPerformance` (2), `SchoolPanel` (+2), `transformPanelData`
  (2) — 13/13. Deploy backend + frontend; E2E `GET /api/school/35011162/panel/info`
  com `desempenho` (13 itens).

## Sessão anterior — autocomplete de indicadores (cluster) + build no container

- **Autocomplete do cluster (`FeatureSelect`)** — commit `d8a58f7`
  (`fix(frontend): autocomplete de indicadores do cluster`). Dois bugs:
  1. `filtered` usava `$derived(() => {...})`: a função virava o **valor** da
     derived (não o retorno), então `filtered.length === 0` e o dropdown nunca
     renderizava. Corrigido para **`$derived.by(() => {...})`**.
  2. Race `onblur` × clique: o `mousedown` na opção roubava o foco do input →
     `blur` → `open = false` → a lista desmontava antes do `click` → `select()`
     nunca rodava. Corrigido com `onmousedown={(e) => e.preventDefault()}` nas
     opções.
  Além disso: a busca exige **mínimo 2 caracteres** (com dica), `title` com o
  `comment` (metadado do banco) e o `column_name` fica visível. Teste
  `FeatureSelect.test.js` (5 casos). Deployado (`deploy_frontend_dev`).
- **BUILD DO FRONTEND — rodar no container `backend.edumaps`** (via
  `rex -H backend.edumaps deploy_frontend_dev`, que executa `npm run build` lá):
  é **mais robusto e rápido**. O `npm run build` **local** conclui
  (`✓ built in ~25s`), porém o processo do Vite **não retorna** no shell (fica
  pendurado; só encerra com `timeout`). Usar o build do container como validação
  real.

## Sessão — eduBR (pacote R): regiões, INSE e camada declarativa

- **Repo** `~/Projects/eduBR` (GitHub `marcoarthur/eduBR`, repo separado do
  `edumaps`). Pacote R de acesso de alto nível à base do EduMaps (objetos S3
  + consultas `dbplyr` preguiçosas).
- **PR #1** (`feat/edubr-analises-declarativas`) → `main`, merge commit
  **`c7e8e80`** (2026-09-16). 10 commits (`b7f4898`..`9a498cb`): setup +
  região/tendência + INSE + camada declarativa + sync + docs.
  `main` == `origin/main` == `c7e8e80`; branch deletada.
- **Setup**: `AGENTS.md` + skills `.opencode/skills/{agent-persona,r-edubr,postgres-postgis}.md`.
  Curadoria das personas em `docs/personas/especialista-ml.md` (rodadas 2–4).
- **Região/tendência**: `ideb_regiao()` (macrorregião derivada da UF via
  `case_when`; helpers em `R/regiao.R`) e `tendencia_regiao()` (parsnip
  `ideb_medio ~ ano` por região×etapa). Report
  `analysis/tendencia_ideb_regiao.Rmd`.
- **INSE**: `clean.inse` só tem **2023** e só **públicas** (69.756 escolas).
  `inse()`, `ideb_inse()` (join por `id_escola` e `ano = nu_ano_saeb`) e
  `regressao_inse()` (transversal, nível escola). Report
  `analysis/regressao_inse_regiao.Rmd`. Gradiente (fund. II): CO 1,22 > SE 1,13
  > N 1,09 > S 1,03 > **NE 0,61**.
- **Camada declarativa**: `especificar_regressao()` / `ler_espec()` /
  `ler_especs()` (YAML) + `executar_regressao(con, espec, dados = NULL)`
  (mesma regressão para N combinações de `cuts`, com **pushdown** de colunas
  antes do `collect`), `coeficientes()`, `metricas()` (logit: `auc` +
  `mcfadden`) e `coletar(x, n =)` (limite + aviso de custo). Exemplo
  `analysis/regressoes_censo.{yaml,Rmd}` (81 modelos UF×etapa em ~48 s).
- **Sync RStudio**: `tools/sync-rstudio.sh` → `rstudio.dev:/home/rsuser/projetos/eduBR`
  (sem `--delete`; `chown -R rsuser:rsuser`), disparado por
  `.git/hooks/post-commit` (symlink para o script). Hook é **local** —
  reinstalar após clonar: `ln -sf ../../tools/sync-rstudio.sh .git/hooks/post-commit`.
- **Dados**: `clean.ideb_notas_escolas` tem `sg_uf`, `co_municipio`, `etapa`,
  `rede`; IDEB↔censo/scores casam por `id_escola == co_entidade`. Base remota
  (`ubatexu.lan:5432`, cluster **ANTIGO**) com picos de lentidão (~2k linhas/s),
  daí o pushdown de colunas.
- **Validação**: `devtools::test()` 0 fail / 0 warn; `R CMD check` 0/0/0.
- **Pendências** (backlog em `docs/personas/especialista-ml.md`): dicionário do
  Censo, reprodutibilidade dos `scores()`, `as_sf()`/PostGIS,
  `registrar_relacao()`, INSE histórico p/ painel, PDF nos reports, join
  escola→município por código.

## Sessão atual — sw.js (PWA app shell offline)

- **PR #66** (`feat/sw-app-shell`) → `main`, merge commit **`9fb0d9c`**
  (2026-09-16). Commit `548bf7e feat(frontend): sw.js basico app shell offline`.
- **Contexto**: o frontend não tinha service worker próprio (só o `sw.js`
  opaco gerado pelo Workbox em `generateSW`).
- **`src/sw.js`** (novo, vanilla, sem Workbox em runtime): app shell offline —
  `install` precacheia shell + assets com hash injetados (`self.__WB_MANIFEST`
  → `.url`) + `skipWaiting`; `activate` limpa caches + `clients.claim`; `fetch`
  navegação network-first com fallback offline, `/api/` network-only, estáticos
  stale-while-revalidate.
- **`vite.config.js`**: `VitePWA` de `generateSW` → **`injectManifest`**
  (`srcDir: "src"`, `filename: "sw.js"`); removido o `runtimeCaching` do `/api/`
  e o `robots.txt` inexistente do `includeAssets`.
- **Deploy/validação**: `npm run build` gera `dist/sw.js` (nosso código, 7
  entradas de precache); `deploy_frontend_dev`; no container `/sw.js` 200 e
  `registerSW.js` 200.
- **Pendências**: ícones `public/icons/icon-*.png` e `robots.txt` inexistentes —
  PWA ainda não instalável.
- Nota: no build, `injectManifest` exige o ponto de injeção
  `self.__WB_MANIFEST` no sw de origem (erro "Unable to find a place to inject
  the manifest" se faltar).

## Sessão anterior — fix uuid (crypto.randomUUID em contexto inseguro)

- **PR #65** (`fix/uuid-contexto-inseguro`) → `main`, merge commit **`d522d10`**
  (2026-09-16). Commit `cca4d76 fix(frontend): uuid sem contexto seguro`.
- **Bug**: `crypto.randomUUID()` só existe em **contexto seguro** (HTTPS/
  `localhost`); em dev por host/IP (`http://<host>:5173`) o `crypto` existe mas
  `randomUUID` é `undefined` → `TypeError: crypto.randomUUID is not a function`
  em `EventBus.emit` (`EventBus.js:72`).
- **Correção**: helper `src/shared/utils/uuid.js` (nativo, sem dependência):
  `crypto.randomUUID()` → `crypto.getRandomValues()` (UUID v4, funciona em
  contexto inseguro) → fallback final. Usado no `EventBus.js` e no
  `toastStore.js` (remove o `Math.random` duplicado). Teste `uuid.test.js`.
- **Deploy** `deploy_frontend_dev`; validado no container: bundle com
  `getRandomValues` presente; página HTTP 200. Testes shared: 30 passaram.
- Nota: `npm run build` local conclui (`✓ built`), porém o processo do vite não
  retorna no shell — usar o `deploy_frontend_dev` (build no container) como
  validação real.

## Sessão anterior — pgvector (similaridade escolar) + topologia do ambiente

### Topologia do ambiente (IMPORTANTE — ler antes de conectar em DB)
- `ubatexu.lan` (192.168.0.42) é o **host** dos containers LXC; as portas do
  host fazem forward para os containers.
- Da nossa máquina só alcançamos o **host**, nunca o container direto. O acesso
  aos containers é via SSH pelos forwards do host (`~/.ssh/config`):
  - `backend.edumaps` → `ubatexu.lan:2031`
  - `database.edumaps` → `ubatexu.lan:2032`
  - (os containers compartilham o IP do host; só mudam as portas)
- Existem **dois** clusters Postgres, ambos com `edumaps_dev` (confirmado por
  `system_identifier` distinto):
  - **Antigo** — `database.dev`; seu Postgres é exposto pelo host em
    `ubatexu.lan:5432`. É para ele que aponta o `~/.pg_service.conf` local
    (`[edumaps]` → host=ubatexu.lan, user `devel`). Logo, **R/eduBR/testes
    locais batem nesse banco ANTIGO, não no do app**. `sqitch status` local
    (alvo `dev_super` → ubatexu.lan) também olha esse cluster antigo.
  - **Atual (app)** — container `database.edumaps` (IP LXC `172.19.198.3`); é o
    que o `backend.edumaps` (Perl + nginx/frontend) usa via `host=Database`
    (ver `edu_maps.conf` no container). Só é acessível por SSH (porta 2032).
- **Deploy de banco:** `rex -H database.edumaps deploy_db_dev` (roda o sqitch
  **dentro do container atual**). NÃO confundir com `sqitch deploy dev_super`
  (roda contra `ubatexu.lan:5432` = cluster ANTIGO; lá o pgvector nem está
  instalado e a migration fica undeployed). Foi um engano inicial desta sessão.
- Para o R/eduBR local enxergar o banco ATUAL do app seria preciso um **túnel
  SSH** pelo host, ex.:
  `ssh -N -L 127.0.0.1:55432:localhost:5432 root@database.edumaps`
  (serviço com host=127.0.0.1 port=55432 dbname=edumaps_dev user=edumaps
  password=change_me). **Decisão do usuário: deixar como está** (sem túnel, sem
  repontar `[edumaps]`) — ele testa manualmente.

### Entregue nesta sessão — pgvector para similaridade escolar
- **PR #64** (`feat/pgvector-curadoria`) → `main`, merge commit **`a7466ad`**
  (2026-09-16). Agrupou 10 commits: pgvector (`b3c537a` db, `ede1ad7` backend),
  `column_descriptions` (`75e23fd` db), personas/Tech Lead/índice e memória
  (`678b0dd`, `177901d`, `7a38724`, `783cc19`, `52ef321`, `4f21638`, `e8c28b1`).
  Branch deletada; `main` == `origin/main` == `a7466ad`.
- Migration `school_embedding` (`data_pipeline/deploy|revert|verify` + plan):
  `CREATE EXTENSION vector`; `analytics.school_embedding(co_entidade PK,
  embedding vector(6))`; backfill dos 6 scores de `clean.mv_escolas_scores`;
  índice HNSW `vector_cosine_ops`.
- Backend: `Schema::Result/ResultSet::SchoolEmbedding`
  (`similar_to($id, $limit, $municipio)`, cosseno `<=>`); `Task::SchoolEmbedding`
  (job Minion `refresh_school_embeddings`, registrado em `EduMaps.pm` em
  `EduMaps::Task::$_`); `School::Profile::panel_info` usa pgvector como caminho
  principal e mantém o `find_similar_schools` (Manhattan em memória) como
  **fallback**; teste `t/02-models/school/embedding.t` (skip se a tabela não
  existir no ambiente).
- Rexfile `deploy_db_dev`: pacote `postgresql-16-pgvector`.
- Deploy: `rex prepare` + `rex -H database.edumaps deploy_db_dev` +
  `rex -H backend.edumaps deploy_backend_dev` + restart de `edumaps-minion` e
  `edumaps-minion-analytics`.
- Validação no container `database.edumaps`: pgvector 0.8.6; **180.540**
  embeddings; índice `idx_school_embedding_hnsw`; API
  `GET /api/school/35007656/panel/info` retorna `similar_schools` via pgvector
  (distância do 1º vizinho `0.001484` = query direta); job
  `refresh_school_embeddings` → `finished` (`refreshed: 180540`).
- Testes: `t/02-models/school/profile.t` OK; `searching.t` falha **idêntica sem
  as mudanças** (pré-existente/data). O harness do repo (`Imports.pm`) exige
  **Perl 5.38** — o container tem 5.36, então os testes rodam só localmente.
- Tentativa de `sqitch deploy dev_super` (cluster ANTIGO, `ubatexu.lan:5432`)
  falhou: `extension "vector" is not available` (pgvector não instalado lá). Sem
  estado parcial (transação abortada; segue undeployed). Não instalar pgvector
  no cluster antigo — o app usa o container atual.
- Migration `column_descriptions` (`75e23fd`): 46 `COMMENT ON COLUMN` (PT-BR,
  foco em porquê/uso) para `school_embedding`, `event_store`, `mv_escolas_scores`,
  `censo_escolas` (geometry/nro_etapas), `school_indicators` (geometry/nro_etapas)
  e `mv_rede_escolas` (26); `cluster_*` (runtime) via `DO` condicional
  (`information_schema.columns`). Deploy via `rex prepare` + `deploy_db_dev`;
  validado: 0 colunas sem descrição nas 6 tabelas.

## Sessão anterior — LandPage, logo SVG e navegação

### Entregue (direto em `main`, sem PR) + deploy
- Commits: `4fbbd4d feat(frontend): landpage, logo e navegação` e
  `8072027 docs: deploy obrigatório no workflow`.
- **Deploy rodado** (Rex `backend/script/deploy/Rexfile`): `rex prepare` (3 hosts)
  + `rex -H backend.edumaps deploy_frontend_dev` — OK. Validado no container:
  `GET /` 200 e `GET /favicon.svg` 200 (build com "Ferramentas analíticas" no
  bundle). **Fix**: `/favicon.svg` não existia (404) e era referenciado no
  `index.html` e no `includeAssets` do PWA.

### O que foi feito
- **Logo** `src/shared/ui/components/Logo.svelte`: glifo SVG único (viewBox
  48×48) — pin de mapa + livro aberto + três barras ascendentes (mapas,
  educação, censo/análise). Props `size` e `variant` (`brand` azul p/ fundo
  claro; `light` pin branco p/ o nav). Sóbrio (azul `#1e40af` + branco), sem
  gradiente. `public/favicon.svg` = versão simplificada (pin + livro) para
  legibilidade a 16px.
- **LandPage** feature nova `src/features/home/` (`HomePage.svelte` + `index.js`
  + teste): hero com logo, tagline e CTAs (Buscar escola → `/escola/search`;
  Ver análises → `/cluster/geotag`) + 4 pilares (Mapas, Educação, Censo Escolar,
  Ferramentas analíticas).
- **Rotas/nav**: `routes.js` ganhou `/` → `HomePage`; removido o `$effect` de
  redirect `/`→`/about` no `App.svelte`; `NAV_LINKS` = Home · Busca Escola ·
  Análises · Sobre o Refactor; marca no nav com logo + "EduMaps".

### Testes
- `routes.test.js` (+2: `/` e `/cluster/geotag`) e `HomePage.test.js` (3).
  Suíte: **129/133** (4 falhas pré-existentes: `paginationStore` ×3,
  `SchoolRankingPage` ×1). `npm run build` OK.

### Convenção nova
- **AGENTS.md Workflow passo 4**: "Deploy (sempre)" — todo ciclo termina com o
  deploy via Rex, rodando de `backend/script/deploy` (`rex prepare` antes de
  qualquer task de código, pois `deploy_backend_dev` não faz rsync).

## Sessão anterior — Rótulos em linguagem natural e legenda clicável nos clusters

### Mergeado
- **PR #62** (`feat/cluster-rotulos-natural`) → `main`, merge commit **`b9cd252`**,
  merge em 2026-09-14. Commits: `4335430` (analysis), `b608d92` (backend),
  `1e1e82c` (frontend), `4f5564b` (docs: skill frontend-svelte), `fe06dd8`
  (docs: nota técnica 39 + regra de nota no workflow). Branch deletada; `main`
  == `origin/main` == `b9cd252`. **Working tree limpa.**

### Entregas
- **R (edumapsr)**: módulo `R/cluster-labels.R` (`.label_scale` com escala 2→
  baixa/alta, 3→baixa/média/alta, 4→muito baixa/baixa/alta/muito alta, 5→muito
  baixa…muito alta, **≥6→fallback inteiro** `Cluster 1..N` 1=baixo N=alto;
  `.cluster_scores` = média por feature min-max × polaridade; `.cluster_labels`);
  `analyze_cluster` lê `parameters$labeling` (`concept`/`gender`/`directions`) e
  gera `cluster_label`/`cluster_rank` em `tables$clusters` e `data`;
  `repository-postgres-cluster.R` grava as duas colunas in-place + `extra_metrics`
  (JSON). `DESCRIPTION` ganhou `cluster-labels.R` no `Collate`.
- **Backend**: `Presets.pm` com `concept`/`gender`/`directions` (única negativa:
  `prop_sem_especializacao` = −1); `request_cluster` injeta `labeling`;
  `Task::Clustering` repassa nos `parameters`; `Model::Cluster` expõe
  `cluster_label`/`cluster_rank` no GeoJSON + `cluster_summary` + rota
  `GET /api/cluster/summary`.
- **Frontend**: legenda com rótulo semântico e **clicável on/off por grupo**
  (`aria-pressed`, `hiddenIds` = `$state(new Set())` reatribuído); popup com
  rótulo; `ClusterSummaryTable.svelte` (rótulo + nº escolas + top indicadores);
  `getClusterSummary()`.

### Detalhes de implementação (importantes)
- `analytics.clustering_metadata.extra_metrics` é gravado pelo R como **ARRAY**
  `[{...}]` (não objeto) → no Perl normalizar (se ARRAY, pegar `->[0]`).
- JSON do banco vem utf8-flagged (`pg_enable_utf8=1`); decodificar com
  `$self->json->utf8(0)->decode(...)` (padrão do projeto — sem `utf8(0)`, "Média"
  quebra e o rótulo cai no fallback).
- Conceito/gênero por preset: infraestrutura "qualidade de infraestrutura" (f),
  docência "qualidade da docência" (f), desempenho "desempenho dos alunos" (m).

### Validação
- R: `test-cluster-labels.R` (12) + `test-cluster.R` verdes (`R CMD INSTALL` OK).
- Backend: `cluster.t` 10, `task.t` 19, `network/schools.t` 4 — verdes.
- Frontend: cluster-geotag 7/7; suíte 123/127 (4 pré-existentes). Build OK.
- E2E deploy (Ubatuba 3555406): infra k=3 → baixa/média/alta; desempenho
  k=3/2023 → baixo/médio/alto; infra k=6 → `Cluster 1..6`. `/api/cluster/summary`
  e GeoJSON com `cluster_label` OK.

### Convenções novas registradas
- **AGENTS.md Workflow passo 6**: gerar nota técnica (`notas_tecnicas_N.md` em
  `docs/new_ideas/implementations_ideas/`) ao fim de cada ciclo (1–2 PRs, 1–2 dias).
- **Skill `frontend-svelte`**: padrão de "marcadores acionáveis quando representam
  grupos" (legenda clicável) + dicas de teste (polling 1500ms → `timeout: 3000`).

## Sessão atual — Presets de indicadores na clusterização (censo + docentes + IDEB)

### Mergeado
- **PR #61** (`feat/presets-multitabela`) → `main`, merge commit **`cb5e8f4`**,
  merge em 2026-09-14. Commits: `08b891e` (db), `c42b58c` (backend),
  `779873a` (frontend). Branch deletada (remoto e local). `main` após FF =
  `cb5e8f4`.
- Fechamento: `03410cc` docs (memory), depois **`62aa757` chore: commit fontes
  pendentes e ignora artefatos R** — commitou os pendentes antigos
  (`EventBus/Middleware/SiopeTask.pm` info→error, `script/tasks/siope.pl`,
  `templates/osm/query/school.opq.ep`, `map_app/src/lib/js/city.js`) e
  gitignoreou `analysis/edumapsr/edumapsAnalytics.Rcheck/` e
  `edumapsAnalytics_*.tar.gz` (artefatos de R CMD check regeneráveis, não
  voltam a sujar o status). **Working tree limpa ao fim da sessão.**
- **Limpeza de branches obsoletas** (2026-09-14): removidas do remoto e local
  as mergeadas `feat/presets-multitabela`, `feat/cluster-geotag-map`,
  `feat/backend-analytics` e `dev/feat/frontend/toast`. Aprendizado: `git push
  origin --delete` com vários refs aborta se um deles não existir (refs já
  apagadas no PR merge ficam como "remote ref does not exist") — deletar um por
  vez. **Remanescentes com trabalho não mergeado (NÃO apagar sem acordo)**:
  `feat/deploy/docker` (`6c7d9ce` adapt edumaps for docker) e
  `fix/backend/schoolgrade` (`8d98de1` School code missing in School Grade).

### Entregas
- **db**: migration `school_indicators` (`deploy/revert/verify` + `sqitch.plan`):
  tabela denormalizada `clean.school_indicators` (censo + docentes + IDEB),
  com `col_description` (comments PT-BR) usados no autocomplete.
- **backend**: `EduMaps::Presets` (3 presets: infraestrutura, docência,
  desempenho; ordem fixa `@PRESET_IDS = qw(infraestrutura docencia desempenho)`;
  `INDICATORS_TABLE`); endpoints `GET /api/cluster/{presets,columns,years}`;
  `request_cluster` (POST /api/task/cluster) aceita `preset`/`ano_ideb` e valida:
  **400** p/ preset desconhecido e p/ preset `year_filter` sem `ano_ideb`; com
  preset força `schema=clean`, `table_name=school_indicators`,
  `id_column=co_entidade`; `Task::Clustering::_rebuild_indicators` faz
  TRUNCATE+INSERT na tabela para o `ano_ideb` escolhido (via `Mojo::Pg`,
  `->hash`/`->array` NÃO `->first`); `Model::Cluster` lê
  `clean.school_indicators` (existence check + `cluster_geojson_query`).
- **frontend**: `PresetSelector`, `FeatureSelect` (autocomplete com comments +
  tags de fonte `SOURCE_LABELS`/`featureLabel`), seletor de ano IDEB/SAEB;
  página cluster/geotag com preset default `infraestrutura`, guarda de ano p/
  desempenho, payload com preset/features/ano_ideb.

### Dados/descobertas
- **IDEB**: `clean.ideb_notas_escolas` tem múltiplos rows por `(id_escola, ano)`
  por etapa (814.448 linhas; 58.884 pares escola/ano; 84.555 escolas; 97.615 em
  2023) → o rebuild agrega por escola com `AVG(ideb)` entre etapas. `id_escola`
  é a coluna do IDEB (não `co_entidade`). Contagens do rebuild: total 214.192,
  com_docentes 178.473, com_ideb_2023 **68.923**, ideb_médio 5.14, lic_media 0.796.
- Censo escolar/docentes só têm `nu_ano_censo = 2025`; docentes join por
  `co_entidade + nu_ano_censo`; IDEB por `i.id_escola = e.co_entidade AND i.ano = ?`.
- **Ambiente duplo**: o container usa DB separado — `backend` conf conecta em
  `Database` LXC (`postgresql://edumaps:change_me@Database/edumaps_dev`), que é
  **diferente** do `edumaps_dev@ubatexu.lan` (devel). Migration aplicada via
  `sqitch deploy db:pg://edumaps:change_me@localhost/edumaps_dev` no
  `database.edumaps` (estava 2 changes atrás).
- Falhas pré-existentes do frontend seguem: `paginationStore ×3` e
  `SchoolRankingPage ×1` (rota `/escola/search` vs `/busca`). Cluster-geotag 6/6.

### Validação
- Testes backend: `cluster.t` 9, `task.t` 19, `network/schools.t` 4 — PASS.
- E2E no deploy: jobs Minion Ubatuba 3555406 — desempenho/2023 (job 5865)
  → rebuild 214.192 e clusters 1-5 (47/3/18/7/9 + 2 sem nota); infraestrutura
  (job 5866) sem ano → clusters 1/3/4. GeoJSON com `cluster_id` OK.
  `/api/cluster/presets|columns|years` OK. `edumaps-analytic.service` (backend)
  segue failed (legado; Plumber real roda em `analytic.edumaps:8000`, ativo).

## Sessão atual — Fix lite app nos scripts dev/entrypoint

- **Problema**: usuário reportou que a "App lite" `backend/edu_maps.pl`
  (Mojolicious::Lite, sem `/api/network`, `/api/task/cluster` e cluster geotag)
  subiu novamente na instância do backend. O fix anterior só corrigiu as units
  systemd no Rexfile; **`backend/dev_run.sh` (líneas 59-60) e
  `backend/docker-entrypoint.sh` (28,30) ainda iniciavam `edu_maps.pl`**
  (`morbo ./edu_maps.pl` e `./edu_maps.pl minion worker`) → qualquer subida via
  dev_run/entrypoint (manual ou Docker) voltava a expor a lite app.
- **Verificação nos containers**: `edumaps-web` segue correto — morbo em :3000 é
  `/opt/edumaps/backend/script/edumaps.pl` (sha256 == repo,
  `Mojolicious::Commands->start_app('EduMaps')`); `/api/network/3551702/summary`
  → 200; rota lite `/api/query-osm` → 404. Daemon local `127.0.0.1:3999`
  (classe app) intacto.
- **Fix**: `dev_run.sh` e `docker-entrypoint.sh` passam a usar
  `script/edumaps.pl` (morbo e worker). `bash -n` OK; sincronizado também em
  `/opt/edumaps/backend` no container.
- **Commit**: `edbdf3d fix(backend): dev scripts sobem classe app` — direto em
  `main` (sem PR), push para `origin/main` (a6acae7..edbdf3d) em 2026-09-14.
- **Obs.**: `edumaps-analytic.service` apareceu **failed** no backend.edumaps —
  ainda não investigado (usuário não pediu).

## Sessão anterior — Mapa de cluster por geotag (R + API + frontend)

### Mergeado
- **PR #60** (`feat/cluster-geotag-map`) → `main`, merge commit **`b290caa`**, merge em
  2026-09-14. Commits: `958b10e` (analysis), `877fb16` (backend), `9a224c6` (frontend).
- Deployado (as-is) e validado nos containers: `rex prepare` + restart
  `edumaps-web`/`edumaps-minion`/`edumaps-minion-analytics`/`edumaps-analytic` +
  `deploy_frontend_dev`. E2E no container: POST /api/task/cluster (Ubatuba
  3555406) → 202 → poll REST active→finished → GET /api/cluster/schools 200,
  78 features, cluster_ids [1,2,3].

### Bug de contrato: job_progress era SSE, frontend esperava JSON
- `GET /api/task/progress` usava `monitor_job` (SSE `text/event-stream`,
  `write_sse`) — frontends antigos (map_app) consomem via EventSource. A página
  nova (Svelte) fazia `fetch`+`json()` e parseava a stream → "Erro ao gerar os
  clusters." **Fix**: `Controller/Task.pm::job_progress` detecta `Accept`; sem
  `text/event-stream` retorna **JSON** `{state, error?}` por poll (state
  `inactive|active|finished|failed`; `failed` expõe `job.error // job.result`,
  com suporte a hashref `{error}`). EventSource legado permanece no caminho SSE.
  Job inexistente → 404.
- Teste: `Minion::Job->fail` em job `inactive` retorna **undef** (backend exige
  job `active`/dono worker). Para testar `failed` de forma determinística:
  `worker->register` + `worker->dequeue(0, {queues=>[...]})` (in-process) e
  depois `$job->fail(...)`. Fila descartável `zzz_progress_test` isola de
  workers de dev ao vivo (um worker local rodando consumia os jobs dos testes e
  marcava "Invalid arguments!").
- No dev local existe Postgres em `localhost:5432` (DB `edumaps`, user
  edumaps) — serviço pg `edumaps_local` do libpq. O Plumber **local** escrevia
  nele, mas o backend lê `edumaps_dev@ubatexu.lan` (serviço `edumaps`) →
  `cluster_id` nunca aparecia. Fix no `package.json` dev: o R sobe com
  `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps` (e `ACCEPT` prefixado com `env`, pois
  entr executa via execvp e não passa env de outros comandos do pipe). Nos
  containers o pg_service `edumaps_local` aponta pro Database, então não há
  mismatch lá.

### R analytics — robustez e filtro
- `analyze_cluster` ganhou `filter` (igualdade por coluna — ex. `{co_regiao:
  3, co_uf: 35, co_municipio: 3555406}`), suportado no api.json/endpoint.R e
  no `Client`/`Task::Clustering` (repassado ao motor). Backend converte
  `codigo_regiao/uf/ibge` → `co_regiao/co_uf/co_municipio`.
- Bug NA: kmeans com 2/86 linhas NA em Ubatuba → `NA/NaN/Inf in foreign
  function call (arg 1)`. `analyze_cluster` agora dropa linhas incompletas
  (`complete.cases`, alinhado com entity_ids), descarta colunas com variância
  zero e valida `nrow<2`, 0 features, `clusters >= n`. Erro do Plumber
  mascarava detalhe: `_post` do `Analytics::Client` concatenava `ARRAY(0x...)`;
  agora join de `ARRAY` de erros (`; `).

### Deploy: pacote reinstalado no container analytic
- `rex prepare` só rsync a **fonte**; o serviço `edumaps-analytic` roda
  `Rscript inst/plumber/run.R` com `library(edumapsAnalytics)` → as funções vêm
  do pacote **instalado** (site-library `/usr/local/lib/R/site-library`), que
  estava defasado (o mesmo NA bug aparecia no container). Redeploy do código R
  exige `R CMD INSTALL .` (env `R_LIBS` + `LC_ALL=C.UTF-8`) e `stop/start`
  (verificar MainPID). Container volume em 8000.

### Backend
- `POST /api/task/cluster` aceita corpo `application/json` (validação
  normalizada: `validator->validation` + `$v->input($input)`, gate `has_error`,
  `features` lido direto do array — `param` achata arrays). Form continua
  suportado.
- Novas rotas `GET /api/cluster/schools|regions|ufs|municipalities`
  (`EduMaps::Controller/Model::Cluster` + plugin API). `clustered_schools`
  lê coluna dinâmica `cluster_id` (criada pelo R via `ADD COLUMN IF NOT
  EXISTS`) via SQL raw + `bigquery json` → GeoJSON FeatureCollection.
- `frontend/edumaps`: página `/cluster/geotag` (cascata região→UF→município,
  12 indicadores default, kmeans/gmm/spectral/dbscan, polling 1.5s, mapa
  Leaflet cor por `cluster_id`), MSW + testes. `DEFAULT_FEATURES` valida
  contra schema — `qt_prof_docentes` não existe; usa `qt_prof_pedagogia`.

### Pendências / fora do escopo (não entraram no PR)
- `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (M), untracked:
  `analysis/edumapsr/edumapsAnalytics.Rcheck/`, `edumapsAnalytics_0.1.0.tar.gz`,
  `backend/script/tasks/`, `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`.
- Check "Workers Builds: edumaps" no GitHub **falha** e deve ser **desconsiderado**:
  a conta Cloudflare NÃO está configurada neste projeto (não há integração
  real; o build é órfão). Não é required → nunca bloqueia merge (estado
  UNSTABLE, não BLOCKED). PR #60 mergeou normalmente.
- Limitação legada do R: `/summary` com sub-análises (score_distributions,
  school_clusters) aceita mas não persiste (repo só faz full_summary).

## Sessão anterior — Deploy e2e do motor http (Plumber) nos containers

### Implantado e validado
- `rex prepare` + `deploy_analytics_worker_dev` (worker fila `analytics`
  ativo no backend) + `deploy_analytics_dev` no container analytic.
- Primeiro `deploy_analytics_dev` falhou: `R CMD INSTALL` sem `dbscan`,
  `mclust`, `kernlab` (deps de algoritmos de clustering). Corrigido no
  `Rexfile` (install.packages) — commit **`4ba80e9` feat(deploy): engine
  http padrao e deps dbscan mclust kernlab** (também flippa
  `analytics_engine: http` no template `files/edumaps_db.conf`).
- Container backend: `analytics_url => http://analytic:8000`, engine `http`
  (manual na config deployada). Serviços `edumaps-web`/`edumaps-minion`/
  `edumaps-minion-analytics` ativos.

### Correções no edumapsr (deploy)
- **`e0e9d56` fix(analysis): escopo do pacote no Plumber**:
  - `run.R` usava só `requireNamespace` → exports NÃO estavam na search path
    e os handlers do Plumber não achavam funções do pacote. Adicionado
    `library(edumapsAnalytics)` no branch do pacote instalado.
  - `analytics_db_connection()` é **interna (não exportada)** — qualificada
    com `edumapsAnalytics:::` no `endpoint.R` (3 chamadas: /cluster,
    /summary, /similarity/db).
  - `Sys.setlocale("LC_ALL", "C.UTF-8")` no run.R p/ silenciar warnings
    "cannot be translated to UTF-8" (strings marcadas como native no parse).
    Na prática, só removeu os warnings após re-instalar o pacote com
    `LC_ALL=C.UTF-8 R CMD INSTALL`.
- **`d885787` fix(analysis): serializa metricas com tabelas R em JSON**:
  - `analyze_city_summary` usava `table(data$dependencia)` em metrics; o
    repositório `persist_city_summary` serializava `result$metrics` direto
    com `jsonlite::toJSON` → **"No method asJSON S3 class: table"** → 500 em
    /summary. Correção na raiz: `as.list(table(...))` (lista nomeada).
  - `view-json.R::as_json_scalar` agora converte objects `table` em objetos
    JSON nomeados (defesa). Sem isso os testes de `/summary` quebrariam se
    alguma métrica voltasse a ser `table`.

### E2E validado (via curl nos containers)
- `POST http://analytic:8000/cluster` (staging.test_cluster, 500 escolas)
  → JSON com `data`, `metrics`, `tables`; persiste `cluster_id` na tabela e
  3 linhas em `analytics.clustering_metadata` (run_id `run_<ts>`).
- `POST /api/task/cluster` (backend, form-encoded) → job Minion **finished**
  (job 5858, fila `analytics`, worker dedicado). O server Plumber responde mas
  pode levar >120 s em tabelas grandes (kmeans sobre clean.escolas inteiro
  estourou timeout — usar tabela reduzida ou aumentar `analytics_timeout`).
- `POST /summary` (clean.escolas 3106200, full_summary) → 200, persiste em
  `analytics.city_school_analytics` (summary_data jsonb, distribuicao por
  dependência como objeto).
- `POST /similarity/db` (staging.test_cluster, k=5, gower) → 200, persiste em
  `analytics.similarity_pairs` (append por run).
- Limitação descoberta: `/summary` com `type=score_distributions`/
  `school_clusters` retorna 500 ("repository espera um resultado
  city_summary") — o repo só persiste `full_summary`; sub-análises
  (SKIPPED) não são persistidas. Endpoint aceita, mas não persiste.

### Descobertas de operação
- Serviço `edumaps-analytic` roda `Rscript inst/plumber/run.R` com
  `WorkingDirectory=/opt/edumaps/analysis/edumapsr` (FONTE rsyncada), NÃO o
  pacote instalado (site-library). Depois de `R CMD INSTALL` é obrigatório
  `systemctl stop/start` (só `restart` mantém MainPID antigo às vezes) e não
  esconder o erro: **verificar `systemctl show ... --property=MainPID`**.

## Sessão anterior — Migração das análises R::Pipe → Plumber (edumapsr), Fase 3 concluída

### Fase 1 completa (commits)
- **`d79d427` feat(analysis): endpoints plumber cluster/summary e repos** —
  edumapsr ganhou POST `/cluster`, `/summary`, `/similarity/db` + facades e
  repos S3 persistentes (staging cluster_id via temp table, upsert
  `city_school_analytics`, append `similarity_pairs`). 147 testes testthat PASS.

### Fase 2 completa (commits)
- **`5f110c6` feat(backend): connector Perl <-> Plumber**:
  - `EduMaps::Analytics::Client` — chamadas HTTP **síncronas** (`Mojo::UserAgent`
    bloqueante), endpoints `/cluster|summary|similarity/db|chart|health`.
  - Cache compartilhado `analytics.analysis_cache` com chave **canônica**
    (`JSON::PP->canonical` + `Mojo::Util::sha1_hex` de `{analysis, params,
    source_version}`), estável entre processos (hash ordering do Perl era
    aleatória por processo!). **Escopo do cache inclui dados afetam o resultado**:
    `/summary` keyed por `codigo_ibge+schema+parameters`; `/cluster` por
    `schema+table_name+id_column+features+parameters` (NÃO `output_schema`).
    Read-through p/ cluster e city_summary; similaridade (pares O(n²))
    **nunca é cacheada**.
  - Descobertas Mojo nesta versão (site_perl 5.42.0):
    - `Mojo::Util::sha1_hex` existe mas NÃO está em `@EXPORT_OK` — chamar
      **fully-qualified** (`Mojo::Util::sha1_hex(...)`), senão
      `use Mojo::Util qw(sha1_hex)` falha em `perl -c`.
    - `use Mojo::JSON qw(encode_json decode_json)` numa classe com
      `Mojo::Base -base, -signatures` dispara **prototype mismatch** — usar
      `use Mojo::JSON;` + chamadas `Mojo::JSON::encode_json(...)`.
    - `Mojo::Server::Daemon` embutido + `ua->get(...)->result` bloqueante NÃO
      funcionam no mesmo processo nesta versão (eventloop): para emular o
      serviço no teste, o server roda em um **fork** (loop dedicado) e o
      `port` chega por arquivo temp (`/tmp/user/1000/opencode/...`); polling de
      prontidão via `IO::Socket::INET`. Test2 usa `$?` p/ o exit code → após
      `waitpid` do filho (killed por TERM) é **obrigatório `$? = 0`**, senão o
      teste sai com exit 15.
  - **Plugin** `EduMaps::Plugin::Analytics` registrado no startup (`EduMaps::
      Plugin::Helpers` + `Analytics`); helper `analytics` (client singleton com
      `app` fraco). Config keys: `analytics_url` (default
      `http://analytic:8000`), `analytics_timeout` (300),
      `analytics_source_version` ('edumapsr-0.1.0'), `analytics_cache_enabled` (1).
      **TODO**: adicioná-las ao `edu_maps.conf` (não versionado) na F6.
  - Teste `backend/t/03-plugins/analytics.t` — **9 subtests PASS** (server fork,
    run_cluster/summary/similarity_db/health, croak em 500, chave canônica,
    escopo por codigo_ibge/table/features, read-through s/ DB = no-op).
  - Verificações: `perl -c` OK nos 3 arquivos; `t/01-app/basic.t` (boot da app)
    e `t/03-plugins` PASS.

### Fase 3 completa (commits)
- **`deedd23` feat(backend): tasks R com analytics_engine http|pipe**:
  - `EduMaps::Plugin::Analytics` ganhou `DEFAULT_ENGINE ('pipe')` e nova config
    key **`analytics_engine`** (`'http'` Plumber via Client | `'pipe'` legado),
    exposta pelo helper `$app->analytics_engine` (lida no register, default
    `pipe` — mantém prod e `t/05-tasks` estáveis).
  - `EduMaps::Task::Clustering`: dispatch por engine. HTTP →
    `$job->app->analytics->run_cluster({schema, table_name, id_column,
    features, parameters => {algorithm, clusters, eps, min_pts}})`. Validação
    ganhou campo opcional `features`. Pipe intacto (Rscript via R::Pipe).
  - `EduMaps::Task::Similarity`: HTTP → `run_similarity_db` (gower), com
    **falha explícita** p/ métricas não-gower no motor http (mensagem instrui
    usar `pipe`); pipe mantido p/ demais métricas.
  - `EduMaps::Task::CityAnalytics`: HTTP → `run_summary({codigo_ibge, schema,
    parameters => {type}})`. O contrato `{meta, cluster_info|similarity_info|
    analytics_info{r_meta}}` é preservado; `r_meta` = resposta JSON do endpoint
    (o serviço Plumber já persiste cluster_id/summary/pairs no banco).
  - Contrato de job preservado em todos os motores (query_args/inject_args
    iguais; só `r_meta` muda de origem: R::Pipe → HTTP).
  - Teste **`backend/t/05-tasks/analytics_engine.t`** — **5 subtests PASS**
    (server-fork emulando /cluster, /summary, /similarity/db):
    - `analytics_engine` helper reflete config; cluster via http engine
      (r_meta.analysis = 'cluster_kmeans', run_id do endpoint); similarity
      gower ok; similarity não-gower → job `failed` com mensagem; city_analytics
      via http (r_meta.analysis = 'city_summary').
    - Lição: `apply_city_analytics` enfileira na fila **'speculative'**
      (prioridade 0), que `minion->perform_jobs` NÃO processa (só fila
      'default') — no teste, enfileirar direto com
      `minion->enqueue(city_analytics => [$args])` para a fila padrão.
  - `perl -c` OK nos 4 módulos alterados.

### Fase 4 completa (commits)
- **`f195898` feat(data_pipeline): analytics.analysis_cache** — migration
  sqitch `analytics_analysis_cache` (`deploy/revert/verify` + `sqitch.plan`,
  dep `[schemas]`): tabela no schema `analytics` com PK `cache_key` (text,
  sha-1 canônico do Client), `analysis`, `params` jsonb, `payload` jsonb,
  `source_version`, `created_at`/`updated_at`/`expires_at` timestamptz;
  índices (analysis, source_version) e parcial em expires_at. Comentários PT-BR
  em todas as colunas. **Deployado e verificado em dev_super** (`edumaps_dev`);
  upsert real validado em psql com o mesmo SQL do `Client::_cache_write`.

### Fase 5 em aberto
- Rotas web `POST /api/task/{cluster,summary,similarity}`.

### Fase 5+6 completas (commits)
- **`0fcc56e` feat(backend): rotas web POST /api/task/{cluster,summary,
  similarity}**:
  - `EduMaps::Controller::Task` ganhou `request_cluster/request_summary/
    request_similarity` (padrão de `request_siope`: valida → enfileira →
    202 + `Location: /api/task/progress?job_id=X`).
  - Validações espelhadas nas tasks: cluster (table_name/id_column/schema/
    algorithm/clusters/eps/min_pts/features), summary (codigo_ibge 7 dígitos/
    analysis/schema), similarity (table_name/id_column/schema/metric — 5
    métricas, inclusive aitchison/dtw).
  - **Fila dedicada `analytics`**: rotas web enfileiram por
    `minion->enqueue(...)` direto em `{queue => 'analytics'}` — worker
    analítico separado do worker geral (Siope/OSM). `apply_*` seguem na fila
    default (t/05-tasks intactos). `/summary` NÃO usa `apply_city_analytics`
    (fila 'speculative' + CHI) por ser user intent.
  - Teste `backend/t/04-api/task.t` — 7 subtests PASS (202+job_id+Location+
    queue analytics p/ os 3; 400 p/ validações).
- **`7381eef` feat(deploy): worker fila analytics + pg_service.conf +
  config**:
  - systemd `files/edumaps-minion-analytics.service` + task Rex
    `deploy_analytics_worker_dev`: worker `minion worker -q analytics`.
  - `files/pg_service.conf` (deploy em `/root/.pg_service.conf`): serviços
    `[edumaps]` e `[edumaps_local]` — R codifica `service="edumaps_local"`
    por default/`EDUMAPS_ANALYTICS_DB_SERVICE`; antigamente o arquivo só
    tinha `[edumaps]` (conexão R falharia p/ `edumaps_local`).
  - `files/Renviron` + `EDUMAPS_ANALYTICS_DB_SERVICE=edumaps_local`.
  - **Config `analytics_*`** adicionada ao template `files/edumaps_db.conf`
    (backend dos containers) e ao `backend/edu_maps.conf` local (não
    versionado): `analytics_url` (`http://analytic:8000`, env-overridable
    `ANALYTICS_URL`), `analytics_timeout` (300), `analytics_source_version`
    ('edumapsr-0.1.0'), `analytics_cache_enabled` (1), **`analytics_engine`
    ('pipe'** — OPCIONAL, trocar p/ 'http' p/ ativar o Plumber).
  - Validações: Rexfile syntax OK; suite verde (t/01-app, t/03-plugins,
    t/04-api, t/05-tasks/analytics_engine); **clustering.t (pipe) PASS** —
    motor legado intacto após F3.

### Estado
- F1–F6 concluídas e commitadas em `main`.
- **Aplicar no ambiente** (pendente de validação/acordo): rodar
  `rex prepare` (rsync) + `deploy_analytics_worker_dev` (novo worker) +
  `deploy_analytics_dev` (pg_service.conf/Renviron) no backend/analytic e, se
  for ativar Plumber, flippar `analytics_engine: http` na config dos
  containers.
- **Fase 6/7**: infra `pg_service.conf` + worker fila `analytics` + docs.

### Fora de commits (segue)
- WIP `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info→error).
- untrackeds: `backend/script/tasks/siope.pl`,
  `backend/templates/osm/query/school.opq.ep`,
  `frontend/map_app/src/lib/js/city.js`, e artefatos R CMD check
  (`analysis/edumapsr/edumapsAnalytics.Rcheck/`,
  `analysis/edumapsr/edumapsAnalytics_0.1.0.tar.gz`).
- Commit: hook post-commit quebrado (`GIT_DIR: unbound variable`) — esperado.

## Ciclo anterior — limpeza: gitignore + reorganização docs (concluído)

### Fechamento do ciclo anterior (2026-09-13)
- PR #57 mergeado em `main` (commit de merge `9361604`; branch
  `fix/deploy-backend-class-app` removida local e no remote). Ciclo de deploy
  encerrado após validação ponta a ponta nos containers.

### Limpeza — `.gitignore`
- Adicionados (artefatos de build/gerados e config local):
  `analysis/edumapsr/man/*.Rd` (roxygen2), `backend/cover_db/` (Devel::Cover),
  `data_pipeline/config/local.ini`.
- Apagado `backend/t/05-tasks/edumaps-analysis/similarity.t` (0 bytes).
- `frontend/*/node_modules` e `dist` já cobertos pelos `.gitignore` aninhados.

### Limpeza — reorganização de `docs/`
- **Estrutura nova**: `docs/archive/` (com `README.md` índice 1 linha/arquivo) e
  `docs/new_ideas/{implementations_ideas,concepts}`. Decisões do usuário:
  "recentes" = notas de 16-07 a 16-08; arquivar (não excluir) as datadas;
  `nvim.md` excluído; versionar os docs (eram untrackeds).
- **→ `new_ideas/implementations_ideas/`**: `notas_tecnicas_20` (score IQE),
  `_24` (Painel do Diretor), `_26` (plotly/ggplot2 via Perl), `_29` (EventBus
  frontend sem RxJS), `_32` (Stats::Model), `_34` (pré-computação especulativa).
- **→ `new_ideas/concepts/`**: `notas_tecnicas_17` (arquiteturas maduras),
  `_18` (similaridade por domínio).
- **→ `archive/`**: todas as demais notas (mais de 40) + idea antigas
  (`ideas.md`, `IA/*`, `analytics/*`), incluindo as 5 datadas
  (`deep.md`, `system_cloud_administration.md`, `random_forest.md`,
  `notebook-analises-censo-rankings.md`, `prompt/claude/clusterization.md`).
- **Atenção**: recuperei via container (`backend.edumaps:/opt/edumaps/docs`)
  7 arquivos apagados por engano do meu `rm -rf dev` (loop abortou por
  `mv dev/prompt`): `refactor.md`, `refactor_ui.md`, `testes.md`,
  `regressao_linear.md`, `system_cloud_administration.md`, `user_history_1.md`
  e `prompt/claude/clusterization.md`. Todos restaurados em `archive/dev/` com
  mtimes originais. Lição: `mv` de dir com loop tem que tolerar "dir not empty".
- **Ajustadas** referências: `.opencode/skills/r-analytics.md`
  (`docs/IA/clusters.md` → `docs/archive/IA/clusters.md`).

## Sessão anterior — Deploy/validação dos containers após remoção do submodule (concluída)

### Fechamento (2026-09-12)
- **Backend do container agora roda a classe `EduMaps`** (`script/edumaps.pl`)
  com todos os deps do `cpanfile` instalados (CHI, Strptime, RxPerl, Data::Fake,
  PDL, PDL::Stats::Kmeans etc. via cpanm/metacpan; PDL::Stats build OK no
  container). Units `edumaps-web`/`edumaps-minion` ativos; boot loga
  "EduMaps inicializado com sucesso [v0.001]".
- **DB do container atualizado**: faltava `analytics.mv_rede_escolas` (roda o
  `sqitch deploy` no banco do container — `rex -H database.edumaps
  deploy_db_dev`); MV populada (15.352 linhas). `/api/network/3551702/summary`
  passou de 500 (relation não existe) → 200 JSON com dados.
- **`/api/analytics/cities/search`**: endpoint espera param `q` (mapa
  `term => [qw/q query/]` do Model City via ctx params). O controller não
  validava ausência de `q` → 500 (`No value to wrap` na croak de
  `_wrap_percent`). Corrigido com validação `required('q','trim')` + regex de
  acentos e subteste novo (sem `q` → 400). `use utf8;` adicionado ao controller.
- **Validação ponta a ponta (container, direto :3000 e via nginx `Host:
  ubatexu.lan`)**: `/api/network/{summary,schools,performance,markers}` 200;
  `/api/network/123/summary` 404 (validação ibge OK); `cities/search?q=` 200
  (incl. acentos), sem `q` 400, `?term=` 400; `/api/city/suggestions?q=` 200;
  `/api/analytics/city/3551702/details` 404 (dado ausente — esperado); SPA
  nginx 200; `/analytic-api/health` e `openapi.json` 200; analytic (Plumber)
  responde `{"status":["ok"]}`.
- **PDL::Stats::Kmeans instalado em background no container** (logo
  `/tmp/pdl_install.log`, PID 4113) — concluído OK (PDL-2.106 + PDL::Stats).
- **Testes locais**: `t/04-api/{network,search-analytic,search-municipio,
  municipio}` ok. Falhas PRÉ-EXISTENTES (verificadas com stash, fora do escopo):
  `municipio.t` #8 OSM features (falta dado OSM) e `school/clustering.t`
  (mensagem do controller "Dados não encontrados..." ≠ "Não encontrado").
- **Commits nesta sessão** (branch `fix/deploy-backend-class-app` → PR):
  `fix(backend): completa deps no cpanfile`,
  `fix(backend): deploy usa script/edumaps.pl p/ app classe`,
  `fix(backend): valida param q em cities/search`,
  `fix(analysis): run.R aceita pacote instalado`,
  `fix(frontend): remove import uuid no toastStore`.
- **Atenção workflow**: `deploy_backend_dev` **não** roda rsync (é o `prepare`);
  em mudanças de código rodar `rex prepare` antes para o container pegar o
  working tree.

### Objetivo desta sessão
- Validar o deploy adaptado (Rex `backend/script/deploy/Rexfile`) após a remoção
  do submodule `analytics`, deixando backend/frontend/analytics funcionando
  de ponta a ponta nos containers LXC.

### Estado atual (em progresso)
- **Diagnóstico do backend FECHADO** — o deploy sobe **outra app** que não a que
  tem `/api/network`:
  - O serviço `edumaps-web` roda `edu_maps.pl` (app **Mojolicious::Lite** com
    rotas inline /api/city, /api/analytics, /api/school, map_svelte, tasks OSM/
    Siope) — **SEM `/api/network` e SEM `/api/city/suggestions`**.
  - As rotas novas vivem na **classe `EduMaps`** (`backend/script/edumaps.pl` →
    `Mojolicious::Commands->start_app('EduMaps')`), registradas via plugins
    (SchoolNetwork, City c/ `/suggestions`, School, Task, Rank). É o que
    `t/04-api/network/*` testa (`Test::Mojo->new('EduMaps')`) e o que o frontend
    novo chama (grep do SPA: `/api/network`, `/api/city/suggestions`,
    `/api/school/search|suggestions`, `/api/analytics/cities/search`).
- **`backend/cpanfile` está incompleto** p/ a classe app:
  - falta `CHI` (usado em `lib/EduMaps/Plugin/Helpers.pm:6`) → classe app NÃO
    boots no container (`Can't locate CHI.pm`).
  - falta `DateTime::Format::Strptime` (em
    `lib/EduMaps/Roles/Business/School/Finance.pm:5`) → `Model::City` não
    compila → `/api/analytics/cities/search` retorna 500
    (`Can't locate object method "search_for_complete"`).
  - Ambas estão instaladas local (perl do sistema); verificado também SHA do
    container == repo p/ os plugins API.
- Evidências: `carton exec perl edu_maps.pl routes` no container mostra a lista
  completa de rotas do Lite (sem network); grep `api/network/:codigo_ibge` na
  pág 404 = 0; boot do Lite loga `Error loading EduMaps::Model::City: Can't
  locate DateTime/Format/Strptime.pm` e `✓ Loaded: Model::SchoolNetwork`.
- 404 do `/api/network/3551702/*` no backend do container = rota inexistente
  (não é 500 nem controller). O antigo processo (841) também não tinha network.

### Decisão pendente (aguardando usuário)
- **Trocar alvo do deploy p/ a classe app** (`script/edumaps.pl`) + adicionar
  deps ao cpanfile + redeploy (plano proposto na sessão), **OU** registrar as
  rotas novas no Lite `edu_maps.pl`. Recomendado e alinhado aos testes: **classe
  app**. Observação: rotas legadas do Lite (/api/query-osm, /api/jobs/siope,
  map_svelte) não são usadas pelo frontend novo; SPA estático é servido pelo
  nginx (frontend deploy), não pelo backend.

### Plano proposto (aguardando OK do usuário)
1. `backend/cpanfile`: adicionar `CHI` e `DateTime::Format::Strptime`.
2. `backend/script/deploy/Rexfile`: apontar morbo **e** worker Minion para
   `script/edumaps.pl` (no lugar de `edu_maps.pl`).
3. `rex -H backend.edumaps deploy_backend_dev` (roda carton install ≈ contêiner
   reinstala deps, reescreve unit, reinicia) + restart do worker Minion.
4. Validar no container: `/api/network/3551702/{summary,markers,schools,
   performance}` (200), `/api/analytics/cities/search`, `/api/analytics/city/
   3551702/details`, `/api/city/suggestions`; SPA via nginx `Host: ubatexu.lan`.

### Deploy já rodado (esta sessão)
- `rex prepare` OK (3 hosts) — rsync do working tree (preserva mtime → **morbo
  não recarrega sozinho**; precisa `deploy_backend_dev`/restart explícito).
- `rex -H analytic.edumaps deploy_analytics_dev` OK (~15 min): pacote R
  `edumapsr`/`edumapsAnalytics` 0.1.0 instalado; Plumber 1.3.3;
  **`devtools` NÃO instala** no analytic (falha systemfonts/ragg — não é mais
  necessário em runtime). `edumaps-analytic` ACTIVE, porta 8000
  (`EDUMAPS_R_PORT=8000`), `openapi.json` HTTP 200 (/chart, /similarity).
- `rex -H backend.edumaps deploy_frontend_dev` OK após fix (abaixo). nginx
  serve o SPA via `Host: ubatexu.lan` (`/municipio/compare` 200).
- Backend `deploy_backend_dev` rodou mas ficou com 404/500 (causa acima:
  app errada + deps faltando).

### Correções locais FEITAS nesta sessão (NÃO commitadas ainda)
- `analysis/edumapsr/inst/plumber/run.R` — reescrito: usa o pacote instalado
  (`system.file("plumber/endpoint.R")`) com fallback `devtools::load_all`
  (antigo morria no container por falta de devtools). scp manual p/ container.
- `frontend/edumaps/src/shared/stores/toastStore.js` — removido import de
  `uuid` (não instalado); usa `crypto.randomUUID?.() || Math.random().toString(36)`.
  Build local `npm run build` OK; já replicado no container.
- WIP pré-existente segue intacto: `backend/lib/EduMaps/EventBus/Middleware/
  SiopeTask.pm` (1 linha); untrackeds `analysis/edumapsr/man/*.Rd`.

### Commits desta sessão (na ordem)
- `0b3bcf1` chore(deploy): adaptar Rexfile (frontend/edumaps, edumapsr,
  deploy_analytic_models & disable_frontend_vite removidos, POD 3 hosts).
- `0a8bb77` docs: atualizar memory + regra 5 do workflow (atualizar memory.md
  em todo PR/merge e commitar junto).

### Fatos do ambiente (descobertos/confirmados)
- Containers: `backend.edumaps`, `database.edumaps`, `analytic.edumaps`
  (hosts de rede `Backend`, `Database`, `analytic`). SSH OK da máquina local.
- Backend: node 22.22.3, nginx 1.22.1; morbo :3000 (`MOJO_MODE=development`,
  `MOJO_LISTEN=http://0.0.0.0:3000`, `MOJO_REVERSE_PROXY=1`); worker Minion
  `perl edu_maps.pl minion worker`; perl do container 5.36, carton exec via
  `/bin/carton`, deps em `/opt/edumaps/backend/local/lib/perl5`.
- Analytic: R 4.2.2, serviço em `files/edumaps-analytic.service`
  (WorkingDirectory=/opt/edumaps/analysis/edumapsr, `Rscript inst/plumber/run.R`,
  `EDUMAPS_R_PORT=8000`).
- `/opt/edumaps/analytics` (stale do antigo submodule) removido dos 3 containers.
- Observado **processo R `renv-watchdog`** (10:09) no backend container —
  provável lixo; pode ignorar por ora.
- Rex: binary `/home/itaipu/perl5/perlbrew/perls/perl-5.42.0/bin/rex`, rodar de
  `backend/script/deploy`. Rex `deploy_backend_dev` usa `carton install` + gera
  unit morbo via template (paths agora p/ `script/edumaps.pl`).

## Sessões anteriores — SchoolNetwork (backend)

### Escopo desta sessão
- Implementação full stack do **SchoolNetwork** (rede de escolas por município):
  backend + migration + página de comparação de redes `/municipio/compare`.

## Estado atual (final da sessão)
- Branch de trabalho `feat/backend/school-network` **mergeada em `main`** via
  **PR #56** (merge commit `62def60`) e **deletada** (remoto e local).
- Branch local/integração atual: **`main`** (tracking `origin/main`).
- Repo Github: `marcoarthur/edumaps`; `gh` autenticado como `marcoarthur`
  (protocolo SSH). Merge via **merge commit** `gh pr merge <n> --merge --delete-branch`.

### Commits desta sessão (na ordem)
- `8eda2f7` feat(backend): SchoolNetwork (Result/ResultSet RedeEscolas, Model,
  roles Profile/Analytic/Geo, Controller + Plugin API, registro em EduMaps.pm).
- `3b6c54a`, `aee26d9` docs: skills/AGENTS.md, docs do frontend.
- (work acumulado da branch na frente: EventBus, autocomplete, cache, middlewares,
  ranking, analytics/similarity — entrou junto no PR.)
- `be98345` feat(data_pipeline): etapas na `mv_rede_escolas`.
- `411c73f` feat(backend): summary com `total_etapas` e `media_etapas`.
- `45e2e9f` feat(frontend): página de comparação de redes por município.
- `dd99860` docs: workflow de PR e merge com `gh` → seção nova no `AGENTS.md`.
- **`62def60`** = Merge pull request #56 (feature completa na main).
- `9bd89c7` chore(analytics): remove submodule `analytics` deprecado
  (substituído por `analysis/edumapsr`).
- `07efdfc` chore: remove `.gitmodules` vazio (sem submodules restantes).

## O que foi entregue / estado
- [x] Migration Sqitch (`analytics_rede_escolas`) aplicada com sucesso no
      alvo `dev_super` (também aplicou pendentes `ranking_escolas` e
      `event_store`).
- [x] MV `analytics.mv_rede_escolas` populado: 15.352 linhas / 5.571 municípios.
  - Ex.: SP `3550308` rede federal: total_escolas=5, total_matriculas=3480,
    ideb_fund_i=6.50, ano_ideb=2023.
- [x] Migration `rede_escolas_etapas`: MVs agora expõem `total_etapas`
      (SUM de nro_etapas) e `media_etapas` (1 decimal). Aplicada no dev;
      validação via psql (sqitch verify lento).
- [x] Backend completo: Result/ResultSet `RedeEscolas`, Model `SchoolNetwork`,
      roles `Profile`/`Analytic`/`Geo`, Controller + Plugin API, registro em `EduMaps.pm`.
- [x] Testes modelo (`t/02-models/SchoolNetwork.t`) e API
      (`t/04-api/network/`) — **PASS**.
- [x] Frontend completa (feature `network-compare`):
  - Wrappers reativos de `@carbon/charts-svelte` (Radar/Line/BarChartGrouped/Donut)
    com ResizeObserver + polyfill em `vitest-setup.js`.
  - Página `/municipio/compare` (`frontend/edumaps/src/features/network-compare/`):
    banner por rede, KPIs, radar Perfil/Volume, barras agrupadas, donuts,
    timeline IDEB, tabela sortable, mapa Leaflet com `circleMarker` por rede
    + toggle de filtro; URL compartilhável `?codigo_ibge=`.
  - Entrada via SchoolSearchForm ("Comparar Redes do Município", pré-seleciona
    município) + autocomplete interno.
  - MSW handlers/fixtures com dados reais de Sertãozinho/SP (3551702).
- [x] Testes frontend: 18 novos (transformNetworkData, NetworkComparePage com MSW,
      smoke dos wrappers) — PASS. Build vite OK. 4 falhas pré-existentes não
      relacionadas (paginationStore ×3, SchoolRankingPage ×1).
- [x] Validação visual **aprovada** pelo usuário em
      `/municipio/compare?codigo_ibge=3551702`.
- [x] Submodule `analytics` (gitlab.com/marcoarthur/edumaps) **removido** da
      árvore — deprecado, substituído por `analysis/edumapsr`. Commit local
      `3de80d0` descartado; repo remoto no GitLab deixado intacto.

## Endpoints implementados
`/api/network/:codigo_ibge/{summary,schools,performance,markers}` (regex `\d{7}`):
- summary — rede por tipo de administração (federal/estadual/municipal/privada),
  agora com `total_etapas` e `media_etapas`
- schools — escolas do município + somas de matrículas
- performance — série IDEB/SAEB
- markers — GeoJSON FeatureCollection

## Correções feitas durante o ciclo (importantes)
1. `Geo.pm` (markers):
   - `not_null('me.geometry')` — `geometry` puro ficava ambíguo nos JOINs.
   - Propriedades do GeoJSON **qualificadas** (`me.municipio`, etc.) para evitar
     ambigüidade com o join de `municipio`.
   - Retorno com `encode('UTF-8', ...)` — necessário, pois `decode_json` do Mojo
     falha em strings utf8-flagged vindas do Postgres via `pg_enable_utf8`.
2. `Analytic.pm`: ResultSet não tem `each`; iterar com
   `->as_hash->get_all->each(sub { $_->{col} })`.
3. `Profile.pm` (schools):
   - `columns` com `-as` explícito nos SUMs (senão o alias não é gerado).
   - `limit` no lugar de `rows` (helper existente em SearchHelpers).
   - filtro `matricula.nu_ano_censo` no WHERE (não em `search_related`).
4. `Controller/SchoolNetwork.pm` (markers): usar
   `render(text => $result, format => 'json')` e não `render(json => ...)`
   (o retorno já é string GeoJSON; `render(json)` duplicava encoding —
   padrão seguido: `City` controller).
5. Testes: `maybe()` **não existe** no `Test2::Tools::Compare` (verificado).
   Substituído por asserts mais simples (`exists`). `number_gt` existe.

## Informações fornecidas pelo usuário (IMPORTANTE)
- **Rodar testes**: usar `prove -l` (equivale a `-I lib`) a partir de
  `backend/`, ou `yath` (runner mais moderno, preferido).
  Ex.: `prove -rl t/05-tasks` (o `-r` é recursivo).
  Sem `-l`, testes como `event_logger.t` falham com
  "Can't find application class EduMaps in @INC" — **não** é falha real.
- **Falhas restantes da suíte são previstas / pré-existentes** — os testes são
  complexos e dependem de serviços externos (R scripts, Siope scraping,
  schema `staging`, jobs gower/similarity). **Não modificar agora.**
  Há um ciclo futuro previsto de **cleanup da suíte** (não iniciar sem pedido).
- **Workflow do projeto** (registrado no AGENTS.md):
  plano → execução → aprovação → validação visual → PR + merge via `gh`
  (`gh pr create --base main` ... `gh pr merge <n> --merge --delete-branch`).
- **Autorização concedida de executar qualquer comando** neste ambiente de
  teste, inclusive via SSH da máquina local para os containers LXC
  (`backend.edumaps`, `database.edumaps`, `analytic.edumaps` — hosts de rede
  `Backend`, `Database`, `Analytic`).
- **Deploy**: Rex em `backend/script/deploy/Rexfile`, "as-is" (rsync do working
  tree). 3 containers: Backend (Perl + Minion + nginx/frontend estático),
  Database (PostgreSQL/PostGIS/Sqitch em `Database`), Analytic (R `edumapsr`,
  Plumber na porta 8000 via `EDUMAPS_R_PORT`). Frontend atual: `frontend/edumaps`
  (Svelte 5/Vite), não mais `frontend/map_app`.

## Comportamento / convenções do repo (descobertas)
- Idioma: PT-BR (comentários, docs e mensagens).
- Commit: `<type>(<scope>): <subject>` (máx. 50 chars, PT-BR). Scopes:
  `backend`, `frontend`, `data_pipeline`, `analytics` (= schema Postgres
  `analytics.mv_*`), `analysis`, `db`.
- Validações de formato de `codigo_ibge` invalid (`abc`, `123`, 8 dígitos)
  retornam **404** (convenção do `City`), não 400. 400 é só p/ params de query
  inválidos.
- `EduMaps::Schema::ResultSet::Base` compõe
  `EduMaps::Roles::DB::{PrettyPrint Formats SearchHelpers Scaling Stats Geo
  Joins Derived SQLUtils Aggregates ProcessedJob Pageable}`.
- ResultSet tem `as_hash`/`get_all` (Mojo::Collection), **não** tem `each` direto.
- `clean.ideb_notas_escolas.rede` e `clean.escolas.dependencia_administrativa`
  usam valores capitalizados: `Estadual/Federal/Municipal/Privada`.
  `clean.ideb_notas_escolas.etapa` ∈ `fundamental_i`, `fundamental_ii`,
  `ensino_medio`.
- Credenciais (dev): `PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel
  -d edumaps_dev`. Sqitch target: `dev_super`. Check "Workers Builds: edumaps"
  (deploy Cloudflare) falha em PRs — infran, não bloqueia merge (UNSTABLE).
- Frontend: `frontend/edumaps` (Svelte 5, Vite, Carbon, Leaflet, MSW, Vitest).
  Rotas em `src/app/routes.js`; `App.svelte` faz `matchRoute(router.path.split("?")[0])`.

## Pendências / fora do escopo desta sessão
- Falhas de teste PRÉ-EXISTENTES (não são regressões): `municipio.t` #8 (OSM
  features sem dado) e `school/clustering.t` (mensagem "Não encontrado").
- Mudanças NÃO commitadas da sessão atual:
- **Hook post-commit quebrado**: `.git/hooks/post-commit` linha 32
  `GIT_DIR: unbound variable` (assinatura de shell com `set -u` sem exportar
  GIT_DIR). O commit funciona; o hook erra depois. Não consertado (não pedido).
- Mudanças pré-existentes NÃO commitadas (mantidas fora de commits/PRs):
  - `backend/lib/EduMaps/EventBus/Middleware/SiopeTask.pm` (log info → error)
  - untrackeds (fontes reais, commitar em ciclo próprio):
    `backend/script/tasks/siope.pl`,
    `backend/templates/osm/query/school.opq.ep`,
    `frontend/map_app/src/lib/js/city.js`.
  - Obs.: `analysis/edumapsr/man/*.Rd`, `backend/cover_db/` e
    `data_pipeline/config/local.ini` agora são GITIGNORADOS; `docs/*` foi
    versionado na reorganização (ciclo de limpeza).
- Próximo ciclo: cleanup da suíte de testes (quando o usuário pedir).

## Comandos úteis para retomar
```bash
cd /home/itaipu/Code/Data/leaflet/backend
prove -vl t/02-models/SchoolNetwork.t        # modelo
prove -vl t/04-api/network/                  # API
prove -rl t/05-tasks                         # (falhas previstas p/ análises R/Siope)

cd /home/itaipu/Code/Data/leaflet/frontend/edumaps
npm run test:run                             # vitest (18 testes da feature inclusos)
npm run build                                # build vite

# PR + merge
git push -u origin <branch>
gh pr create --base main --head <branch> --title "<título em PT-BR>" --body "<entregas, testes, validação>"
gh pr merge <n> --merge --delete-branch
```