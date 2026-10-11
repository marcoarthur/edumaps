# Nota técnica 107 — Listas com QR para autoinscrição de contatos (PR #209)

## Resumo

O ciclo anterior (nota 106 / PR #207) entregou o **núcleo** dos canais de
comunicação — classes para validar endereço, confirmar posse e registrar
histórico. Faltava a primeira **capacidade de negócio** em cima disso: deixar o
gestor criar **listas nomeadas** e receber inscrições por **QR/link público**,
sem depender de importação manual.

Este ciclo entrega a **Fase 0 (MVP telefone)**: o gestor cria uma lista, gera um
QR, e qualquer pessoa que escaneie chega numa **página pública** e se inscreve
informando **nome + telefone + consentimento**. O telefone é gravado de forma
**sensível e não destrutiva** (bruto + normalizado, com marcações), e o sistema
faz **dedupe** sem descartar dados.

Entrega: 5 commits na branch `feat/canais-listas-qr` → **PR #209**
(merge `4b2828f`).

Escopo deliberadamente restrito ao **telefone**, **sem** validação de posse
(não envia código de confirmação nesta fase) e sem envio em massa.

## Decisões (com o developer no planejamento)

1. **Lista própria (`canal_listas`)** — **não** reusa `clean.contato_grupos`,
   que será deprecado. O pertencimento vive em `canal_lista_membros`.
2. **Telefone é sensível e não destrutivo**: guarda o valor **bruto** e o
   **normalizado**; marca cada inscrição (`validado`, `duplicado_de`,
   `conflito`); **nunca descarta**. Dedupe é informativo, não uma exclusão.
3. **Sem validação de posse na Fase 0** — MVP telefone. O código de confirmação
   (do núcleo) é uma fase futura.
4. **API unificada** `GET/POST /api/canais/inscricao/:token` — uma rota pública
   só, servindo leitura (metadados da lista para o formulário) e escrita
   (a inscrição).
5. **Página pública fora do guard** de autenticação da SPA.
6. **Registro de execução em arquivo companheiro versionado** (WBS + DAG + log),
   separado da spec congelada.
7. **Duas trilhas paralelas** (backend/db e frontend), **git centralizado** no
   coordenador — subagentes não tocam git nem deploy.

## Processo de execução

A spec (`docs/specs/2026-10-11-listas-qr-autoinscricao-contatos.md`) é o
**contrato congelado**; o companheiro `…execucao.md` é **mutável** e registra
WBS/DAG/log. Duas trilhas em diretórios disjuntos:

```
Onda 1 (paralela)
  T-A:  M1 ──► M2 ──► A1 ──► A2      (data_pipeline/ + backend/)
  T-B:  F1 ───────────► F2           (frontend/, contra o contrato)

Onda 2 (coordenador)
  T1:  integração · e2e · verify · branch/PR · deploy · memory/nota técnica
```

O contrato público/gestão foi **congelado antes** de as trilhas começarem, para
que backend e frontend pudessem evoluir sem se esperar. A verificação
independente foi feita pelo coordenador (segunda opinião), não pelos
subagentes.

## Arquitetura

### Migrations (`data_pipeline/`)

Quatro tabelas novas, todas **anexadas ao fim** do `sqitch.plan` (nunca
reordenar/editar change já deployada — quebra o `change_id` e o registry):

- `canal_listas` — a lista nomeada, dona é a escola (`cod_inep`); **soft-delete**
  via `ativo=false`.
- `canal_qrcodes` — QR/link de uma lista; `token` único.
- `canal_lista_membros` — pertencimento lista ↔ contato (o contato pode estar em
  várias listas sem duplicação).
- `canal_inscricoes` — o registro bruto da inscrição (nome, telefone bruto +
  normalizado, marcações, `ip_anon`, `consentimento`); `qrcode_id` **nullable**
  com `ON DELETE SET NULL`.

Os `verify/*.sql` seguem o estilo **gate** da issue #160
(`DO $$ … RAISE EXCEPTION '…' $$;`): no Sqitch 1.6.1 um `SELECT` que devolve `f`
conta como sucesso; só **erro** reprova.

### Backend (`Roles::Business::Canal::Listas`)

O núcleo de negócio concentra:

- **Normalização de telefone** tolerante (aceita máscara/DDI),sempre preservando
  o bruto ao lado do normalizado.
- **Dedupe não destrutivo**: se o telefone normalizado já existe na lista,
  registra nova inscrição marcada (`duplicado_de`) e **não** cria contato/membro
  duplicado.
- **Token** do QR via `gen_random_uuid()::text`.
- **Rate limit** em memória, por processo (o model é singleton no backend).
- **Honeypot** (`_hp`) — campo escondido no formulário; se preenchido, responde
  `201` **sem gravar**.
- **IP anonimizado** (`ip_anon`) via HMAC-SHA256 com **salt diário** — não guarda
  o IP cru (LGPD).

### Face pública (`Controller::Canais` + `Plugin::API::Canais`)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/canais/inscricao/:token` | — | `200 {lista_nome, escola_nome, canal, campos, expira_em}` · `404/410` |
| POST | `/api/canais/inscricao/:token` | `{nome, telefone, consentimento:true, _hp?}` | `201 {ok:1, duplicado?}` · `400` · `410` · `429` |

Sem autenticação. GET de token esgotado → **410**; POST de token esgotado →
**429**. A resposta pública é **mínima**: nunca devolve contatos de terceiros.

### API de gestão (`Controller::Gestor` + `Plugin::API::Gestor`)

Base `/api/gestor/:cod_inep/canais/listas` — **Bearer + posse do `cod_inep`**.
CRUD de listas, geração de QR e listagem de inscrições. `excluir_lista` é
**soft-delete** (`ativo=false`) e a lista pode ser **reativada**.
Gestor sem sessão → **401**.

### Frontend (Svelte 5 + Leaflet)

- `features/gestor/pages/ListasPage.svelte` + `components/canais/QRModal.svelte`
  — criar lista, ver QR/link, ver membros. Dep leve `qrcode@^1.5.4`; o QR é
  gerado **no cliente**.
- `features/inscricao/pages/InscricaoPublicaPage.svelte` — rota pública
  `/inscricao/:token`, **fora do guard**. Normalização tolerante das respostas
  (o backend devolve array cru — comportamento inócuo).
- Link da política via prop `politicaUrl` (default `/privacidade`).

### Configuração

`Roles::Business::Config::AppConfig` ganha `inscricao_config` e o catálogo
`canais.inscricao.*`. Em dev, `app_config.items` recebeu
`canais.inscricao.enabled=true` e `public_base_url=http://ubatexu.lan:8080`.

## Segurança e LGPD

- Telefone é PII; a resposta pública **nunca** expõe contatos de terceiros.
- IP é **anonimizado** (HMAC + salt diário), não armazenado cru.
- **Consentimento** obrigatório: sem `consentimento:true`, a inscrição é
  rejeitada com **400**. O formulário linka para a política de privacidade.
- **Honeypot** contra bots (responde `201` sem gravar).
- **Rate limit** por token/IP.

## Defeito corrigido pelo coordenador: `/privacidade` não existia

O consentimento do formulário público apontava para `/privacidade`, **rota
inexistente** — um link quebrado num ponto sensível (base informada do
consentimento). Criada página pública mínima `/privacidade` + rota + teste. O
texto definitivo fica com a escola / revisão jurídica.

## Validação

Host `ubaxala` (backend no perlbrew, Postgres de CI em `127.0.0.1:5433`,
`env -u PERL5LIB`):

- `prove -l t/02-models/canal_listas.t t/04-api/canais/`
  → **3 arquivos / 30 testes PASS**.
- Migrations via `db/fixtures/ci_db.sh` (banco descartável + `sqitch deploy` +
  `sqitch verify` como gate) → **verde**.
- Frontend `vitest run` (suíte completa) → **82 arquivos / 463 testes PASS**.

### E2E (CDP, `http://ubatexu.lan:8080`)

Tudo verde: GET 200; token inválido 404; POST 201; duplicado 201
`{duplicado:1}` (resultando em 1 contato, 2 inscrições, 1 membro); honeypot 201
sem gravar; sem consentimento 400; telefone curto 400; rate limit 429; gestor sem
sessão 401; SPA `/inscricao/:token` → "Inscrição confirmada!"; `/privacidade`
OK. Rodada registrada em `docs/e2e/cobertura.md`.

## Deploy

- `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` + `deploy_frontend_dev`.
- Migração confirmada em `edumaps_dev` (`database.edumaps`); flag
  `canais.inscricao.enabled=true` e `public_base_url` em `app_config.items`.
- **Imagens Docker locais** `sqitch`/`backend`/`minion`/`frontend` reconstruídas;
  `docker compose up -d`; md5 do código no container confere com o `main`.

### Armadilha: disco cheio no rebuild local

O `docker compose build` falhou com `no space left on device`
(`/var/lib/containerd`, `/` em **100%**). O build cache acumulado tinha **5,8 GB
recuperáveis**; `docker builder prune -f` liberou o espaço e o build passou.
**Follow-up pedido pelo developer**: mover o **data-root do Docker para a
partição de `/home`**, para não repetir o problema (onde precisar `sudo`, o
developer fornece a senha na hora).

## Documentação funcional

`docs/funcionalidades/gestor/listas-autoinscricao.md` (capacidade de negócio,
alto nível) + índice em `docs/funcionalidades/README.md`.

## Pendências (fora da Fase 0)

- Banner/aviso da `ConfigPage.svelte` sobre canais.
- Reverts ausentes de `canal_confirmacoes`/`canal_mensagens` (lacuna herdada do
  PR #207).
- Atualizar `docs/funcionalidades/plataforma/canais-de-comunicacao.md`.
- Validação de posse do telefone (código de confirmação).
- Envio em massa (`Channel::List::*` com fila, dedupe, opt-out).
- Limpar dados de teste em dev (lista `E2E Coord 208`, gestor id 2,
  `cod_inep 35038751`).
