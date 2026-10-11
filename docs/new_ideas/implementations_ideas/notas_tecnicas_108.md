# Nota técnica 108 — Dívidas do ciclo de listas com QR (PR #210)

## Resumo

Ciclo curto de **fechamento de dívidas** herdadas do ciclo de listas com QR
(#208 / nota 107). Não há capacidade nova: o objetivo é eliminar as pontas
soltas apontadas no fecho anterior, todas elas de baixo risco e alto retorno de
consistência.

Quatro dívidas, das quais três são artefatos versionados:

1. **Reverts faltantes** de `canal_confirmacoes` e `canal_mensagens`. Os
   `deploy/` e `verify/` existiam desde o PR #207, mas os `revert/` não — o que
   faria `sqitch revert` quebrar nessas duas changes (lacuna herdada).
2. **Banner do Painel de Configuração** desatualizado: dizia que só o Assistente
   do Censo era configurável, quando Integrações (Bot Telegram) e Canais já
   estavam ativos.
3. **Fixture de config** do frontend desalinhada do backend: a categoria
   **Canais de comunicação** não existia no mock (nem no teste).
4. **Doc funcional** `plataforma/canais-de-comunicacao.md` inexistente — os
   canais só apareciam indiretamente pela doc de listas.

Além disso, **limpeza dos dados de teste em dev** deixados pela rodada E2E do
#208.

Entrega: 3 commits na branch `fix/canais-dividas-208` → **PR #210**
(merge `b009495`).

## Decisões

1. **Reverts são seguros de adicionar a changes já deployadas.** O `change_id`
   do Sqitch é o hash dos *metadados* (nome, `requires`/`conflicts` e o
   `change_id` do pai) — **não** do conteúdo dos scripts. Adicionar um
   `revert/*.sql` não mexe no id, ao contrário de editar `requires` ou reordenar
   o plano (as armadilhas documentadas no `AGENTS.md`).
2. **Alinhar o mock à realidade**, não só trocar o texto do banner. Se o banner
   anuncia Canais como configurável, o fixture que os testes usam deveria
   representá-los. Optou-se por inserir a categoria no índice correto (após
   Integrações), espelhando `AppConfig`, sem quebrar os acessos por índice
   (`categories[1]` = Integrações).
3. **Ajuste de asserção no teste**, não do banner. O banner legitimamente nomeia
   as categorias; como agora contém os rótulos exatos ("Integrações", "Canais de
   comunicação"), `getByText` passou a achar dois nós. Trocou-se por
   `getAllByText(...).length > 0`.
4. **Limpeza cirúrgica e transacional** dos dados de teste, precedida de
   verificação de referências (FKs) para garantir que não se apagava nada real.

## Arquitetura

Sem mudança de arquitetura. Os reverts seguem o padrão existente
(`DROP TABLE IF EXISTS`, ordem inversa de dependência, `IF EXISTS` para
reverter banco parcialmente aplicado):

- `data_pipeline/revert/canal_confirmacoes.sql`
- `data_pipeline/revert/canal_mensagens.sql`

No frontend:

- `ConfigPage.svelte`: banner.
- `configFixtures.js`: nova categoria `canais` com os três grupos (E-mail SMTP,
  WhatsApp, Autoinscrição por QR) e suas folhas, espelhando `AppConfig.pm`.
- `ConfigPage.test.js`: rótulo novo no loop + asserção tolerante a duplicatas.

## Validação

- **Migrations (CI db descartável, `EDUMAPS_CI_PORT=5433`)**:
  `sqitch revert --to event_store_add_session` → reverteu
  `canal_listas_autoinscricao`, `canal_mensagens`, `canal_confirmacoes`
  (os dois novos scripts) `.. ok`; `to_regclass` das três tabelas = `NULL`;
  `sqitch deploy` → `+ canal_confirmacoes/mensagens/listas .. ok`;
  `ci_db.sh verify` → **Verify successful**.
- **Backend**: `prove -l t/02-models/canal_listas.t t/04-api/canais/` →
  **3 arquivos / 30 testes PASS**.
- **Frontend**: `vitest run` → **82 arquivos / 463 testes PASS** (feature config
  8/8).

## Deploy

`rex prepare` + `rex -H database.edumaps deploy_db_dev` +
`rex -H backend.edumaps deploy_frontend_dev` — todos OK. ⚠️ `deploy_db_dev`
**reinicia o `postgresql`** (comportamento do task). Conferido: reverts presentes
em `/opt/edumaps/data_pipeline/revert/`; app responde 200 (frontend) e 404
(token inválido). Imagens Docker locais `sqitch` + `frontend` reconstruídas
(regra do `AGENTS.md`).

## Limpeza dos dados de teste em dev

No `edumaps_dev` (host `database.edumaps`), em transação e com contagem
antes/depois, removidos da rodada E2E do #208: lista `id 1` ("E2E Coord 208"),
2 QR codes, 2 membros, 3 inscrições e os contatos `173`/`174`. As chaves
`canais.inscricao.*` em `app_config.items` **foram mantidas** (mantêm a
autoinscrição ativa em dev). Antes de apagar, confirmou-se via
`pg_constraint`/contagens que os contatos só eram referenciados pelos próprios
dados de teste.

## Documentação funcional

- Nova capacidade `docs/funcionalidades/plataforma/canais-de-comunicacao.md`
  (🟡 parcial) + linha no índice.
- `painel-configuracao.md` e `listas-autoinscricao.md` atualizados (categorias e
  ligações cruzadas).

## Pendências (roadmap de canais, fora deste ciclo)

- **Validação de posse do telefone** (código de confirmação, reusando
  `EduMaps::Channel::Confirmation`).
- **Envio em massa / campanhas** (`Channel::List::*` com fila, dedupe, opt-out).
- **Opt-out/consentimento granular** e ciclo de vida LGPD (retenção/expurgo).
- **Múltiplos QR por lista** e analytics de conversão (fase 2).
- **Dívida menor**: no `AppConfig`, as folhas de `canais.inscricao.*` estão com
  `enabled => 0` (aparecem como "Em breve" no Painel), embora a autoinscrição
  esteja ativa via `app_config.items`. Alinhar os defaults do tree com o estado
  real.
