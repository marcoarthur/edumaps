# Nota técnica — Reuniões e atas do gestor (agenda, contatos e anexos)

> Data: 2026-09-20 · Ciclo: backend (Mojolicious) + frontend (Svelte 5) + Sqitch

## 1. Contexto

Depois das pesquisas, o painel do gestor ganha a **agenda da escola**: uma lista
de contatos (PII) organizada em grupos, reuniões agendadas por um wizard de 4
passos (quando · quem · aviso · pauta) e o registro da ata/anexos. O EduMaps não
recria ferramentas de videoconferência: guarda o **agendamento** e o **método de
aviso**; o convite é copiável (`wa.me` / e-mail) e gerado no frontend.

Como o gestor é um usuário por escola, entrou junto o conceito de **gestor
responsável pela agenda** (criador da 1ª reunião) e o **auto-cadastro
governado**: uma vez que a escola tem agenda, um e-mail novo não se registra
sozinho (409) — precisa do e-mail já cadastrado ou de uma transferência.

## 2. Problema / decisões de desenho

- **Schema** (migrações `gestor_reunioes` e `gestor_reunioes_grupos_folha`):
  `clean.contato_grupos` (UNIQUE `cod_inep, nome`; `origem` manual/folha;
  `gestor_id` opcional), `clean.contatos` (UNIQUE parcial `lower(email)` por
  escola), `clean.reunioes` (status `agendada|realizada|cancelada`), 
  `reunioes_participantes` (snapshot do convite, com `via_grupo_id`) e
  `reuniao_anexos` (um `pauta` e um `ata` por reunião; arquivo físico em
  `upload_dir`, fora do banco).
- **Responsável pela agenda**: derivado de `reunioes.gestor_id` da **1ª reunião**
  (`ORDER BY id LIMIT 1`) — sem coluna extra de estado. Transferir reescreve
  `gestor_id` de reuniões/contatos/grupos manuais; grupos `folha` ficam sem dono.
- **Grupos pré-listados pela folha**: categorias de `clean.remuneracao_municipal`
  mapeadas para `Professores`/`Administrativos`/`Outros` (`_grupo_para_categoria`),
  criadas de forma **idempotente** por escola (task `GruposFolha` + lazy no
  `GET /grupos`). `gestor_id` NULL porque a folha não tem gestor.
- **Anexos**: validação de extensão → MIME (`%EXT_MIME`), limite de 10 MB,
  gravação em `<upload_dir>/<cod_inep>/<reuniao_id>/<uuid>.<ext>` e download
  com `Content-Disposition` (frontend baixa via `apiClient.download`).
- **Transições**: `agendada → realizada` (libera/habilita ata) e
  `agendada → cancelada`; reunião `realizada` não pode ser excluída.
- **Auto-cadastro governado (Plano A)**: em `Controller/Pesquisa#perfil`, se o
  e-mail é novo **e** a escola já tem agenda → 409; a escola também precisa
  existir (`clean.escolas` ou censo).

## 3. Solução

| Camada | Arquivo | Papel |
|--------|---------|-------|
| Migrações | `data_pipeline/{deploy,revert,verify}/gestor_reunioes*.sql` | tabelas da agenda + grupos folha |
| Backend | `Roles/Business/Gestor/Reunioes.pm` (novo) | contatos, grupos, reuniões, atas, anexos, `perfil_escola`/`transferir_agenda` |
| Backend | `Roles/Business/Pesquisa/Gestores.pm` | `escola_existe`, `gestor_email_existe`, `escola_tem_agenda` |
| Backend | `Controller/Gestor.pm` | ações do módulo + validação + guarda de erros de banco |
| Backend | `Controller/Pesquisa.pm` | 409 no `perfil` (escola existente + agenda) |
| Backend | `Task/GruposFolha.pm` + `script/tasks/grupos_folha.pl` | seed idempotente dos grupos folha |
| Frontend | `features/gestor/api/gestorReunioesApi.js` (novo) | cliente do módulo (inclui multipart/download) |
| Frontend | `features/gestor/pages/{Contatos,Reunioes,ReunioesWizard,ReuniaoDetail}Page.svelte` | agenda, lista, wizard, detalhe |
| Frontend | `features/gestor/utils/{reuniaoDraft,contatoParser,convite,gestorAuth}.js` | rascunho do wizard, parser de importação, convite, sessão |
| Frontend | `shared/api/client.js` | `upload` (FormData) e `download` (blob + filename) |

## 4. Armadilhas encontradas (importante)

- **Constraint de rota: hashref vira *defaults***. A rota nova foi escrita como
  `$auth->get('/:cod_inep' => { cod_inep => qr/\d{8}/ })`: o Mojolicious tratou o
  hashref como *defaults*, não como *constraint*, e `GET /:cod_inep` passou a
  casar com `GET /api/gestor/pesquisas` → caía no `under` de auth → **401**.
  Fix: **arrayref** `[ cod_inep => qr/\d{8}/ ]` (sintaxe já usada em
  `painel`/`similares`). Ver convenção durável no `memory.md`.
- **`$v->error($campo)->[0]` não é mensagem**: é o **nome do check**
  (`like`, `size`, `required`). O botão "Agendar" mostrava literalmente "❌ like".
  Fix: mapear para mensagem PT-BR em `_render_validation` (Gestor **e** Pesquisa).
- **Formato de data divergente**: `QUANDO_RE` exigia `T`
  (`2026-10-10T14:30`), mas o `buildReuniaoPayload` do frontend envia **espaço**
  (`2026-10-10 14:30`, contrato coberto por teste). Fix: aceitar `[ T]`.
- **`datetime-local` na edição**: preencher com espaço é inválido (input exige
  `T`), então o campo aparecia vazio. Fix: `replace(" ", "T")`.
- **Higiene de testes na base compartilhada**: e-mails criados no subteste de
  409 (`intrusa.*`) não estavam no `END` e poluíam `clean.gestores` entre
  execuções, quebrando a contagem de gestores da escola. Fix: rastrear e limpar.
- **`Role::Tiny` "last wins"**: helpers `_rows/_row/_txn` repetidos entre roles —
  manter as cópias idênticas ao compor `Model/Gestor.pm`.

## 5. Validação

- Backend: `prove -rl t/04-api/pesquisa.t t/04-api/gestor/` — **46/46 PASS**
  (`agenda_responsavel`, `contatos`, `reunioes`, `painel`, `similares`,
  `pesquisa`). Novos subtestes cobrem o formato de data do wizard e a mensagem
  de validação amigável.
- Frontend (container `backend.edumaps`): `npx vitest run src/features/gestor` —
  **94/94 PASS**. Suite completa 266/270 (as 4 falhas são pré-existentes:
  `paginationStore` e `SchoolRankingPage` esperando `/busca`).
- Smoke no serviço real (nginx, `-H "Host: ubatexu.lan"`): perfil → login →
  `POST /api/gestor/:inep/reunioes` com `"2026-10-15 14:30"` → **201**; dados
  removidos em seguida.
- Deploy: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev` (build OK) → **PR #77** (merge commit `fde99b2`).

## 6. Próximos passos

- **Acessibilidade**: drag-and-drop prometido nos comentários do schema ainda é
  seleção por `select`/checkbox — implementar DnD ou ajustar a documentação.
- **Notificações reais**: hoje só o convite copiável; avaliar e-mail/WhatsApp
  (respeitando LGPD e consentimento).
- **Ata colaborativa**: edição concorrente e versionamento da ata.
- **Reuso**: extrair `ConviteBox` e o parser de contatos para `shared/` se outros
  módulos reutilizarem.
