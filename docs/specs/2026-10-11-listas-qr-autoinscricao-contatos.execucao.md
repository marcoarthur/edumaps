# Execução — Listas nomeadas com QR para autoinscrição (#208)

> **Documento de execução** (WBS + DAG + log de decisões), companheiro da spec
> [`2026-10-11-listas-qr-autoinscricao-contatos.md`](./2026-10-11-listas-qr-autoinscricao-contatos.md).
> A spec é o **contrato congelado**; este arquivo é **mutável** e registra o
> andamento da Fase 0, no mesmo espírito do `memory.md` (que continua sendo o
> registro do projeto inteiro).

- **Issue:** [#208](https://github.com/marcoarthur/edumaps/issues/208)
- **Spec (contrato):** `docs/specs/2026-10-11-listas-qr-autoinscricao-contatos.md`
- **Branch:** `feat/canais-listas-qr` (a criar pelo coordenador)
- **Fase:** Fase 0 — MVP telefone (sem validação)

## Princípios de execução

- **Duas trilhas em paralelo, diretórios disjuntos:**
  - **T-A (backend/db):** `data_pipeline/` + `backend/`
  - **T-B (frontend):** `frontend/`
- **Git centralizado:** subagente **só escreve código e roda teste**. Ninguém
  commita, dá push ou faz deploy exceto o coordenador. Nada de push direto em
  `main` (regra do repo: `feat`/`fix` via branch → PR).
- **Migrations validadas por banco limpo:** `db/fixtures/ci_db.sh` (Postgres
  descartável + `sqitch deploy` + `sqitch verify` como gate). Porta dedicada
  (`EDUMAPS_CI_PORT=5433`) para não colidir com o `docker compose db`.
- **Contrato entre as trilhas:** o par público congelado abaixo. Qualquer
  mudança nele exige aviso do coordenador às duas trilhas.

### Contrato público (congelado)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/canais/inscricao/:token` | — | `200 {lista_nome, escola_nome, canal, campos, expira_em}` · `404/410` |
| POST | `/api/canais/inscricao/:token` | `{nome, telefone, consentimento:true, _hp?}` | `201 {ok:1, duplicado?}` · `400` · `410` · `429` |

### Contrato de gestão (congelado)

Base: `/api/gestor/:cod_inep/canais/listas` (Bearer + posse do `cod_inep`).

| Método | Rota | Função |
|---|---|---|
| GET | `/listas` | listar listas |
| POST | `/listas` | criar lista nomeada |
| GET | `/listas/:id` | detalhe + contagem |
| DELETE | `/listas/:id` | excluir/desativar lista |
| POST | `/listas/:id/qrcode` | gerar/rotacionar QR → `{token,url,expira_em}` |
| DELETE | `/listas/:id/qrcode` | revogar QR |
| GET | `/listas/:id/inscricoes` | membros (nome, telefone, quando, validado, conflito) |

## WBS (Fase 0)

| ID | Trilha | Escopo | Depende de | Status | Evidência |
|----|--------|--------|------------|--------|-----------|
| M1 | T-A | Migrations `canal_listas`/`canal_qrcodes`/`canal_lista_membros`/`canal_inscricoes` (+`revert`/`verify`) | — | 🟢 | `ci_db.sh` (deploy+verify) verde |
| M2 | T-A | `Schema::Result::Canal*` + role de negócio (normalização, dedupe não destrutivo, token) | M1 | 🟢 | `t/02-models/canal_listas.t` verde |
| A1 | T-A | API de gestão (CRUD listas, QR, inscrições; auth+posse) | M2 | 🟢 | `t/04-api/canais/gestao.t` verde |
| A2 | T-A | API pública `GET/POST /api/canais/inscricao/:token` (sem auth; rate limit, honeypot, consentimento) | M2 | 🟢 | `t/04-api/canais/publico.t` verde |
| F1 | T-B | UI gestão (criar lista, `QRModal`, membros) | — (contrato) | 🟢 | `vitest` (ListasPage/QRModal/api) verde |
| F2 | T-B | Página pública `/inscricao/:token` (`InscricaoPublicaPage`) fora do guard | — (contrato) | 🟢 | `vitest` (InscricaoPublicaPage) verde |
| T1 | coord. | Testes de integração + e2e + `sqitch verify`; fecho | M1..F2 | 🟢 | e2e verde; deploy OK; PR #209 mergeado |

Legenda de status: ⚪ pendente · 🟡 em andamento · 🟢 concluído · 🔴 bloqueado.

## DAG / ondas

```
Onda 1 (paralela)
  T-A:  M1 ──► M2 ──► A1 ──► A2
  T-B:  F1 ───────────► F2          (contra o contrato congelado)

Onda 2 (coordenador, após Onda 1)
  T1:  integração · e2e · verify · branch/PR · deploy · memory/nota técnica
```

## Log de decisões

- **2026-10-11 — Lista própria.** `canal_listas` é a entidade canônica; **não**
  depende de `clean.contato_grupos` (será deprecado). Pertencimento via
  `canal_lista_membros`. *(Confirmado pelo developer.)*
- **2026-10-11 — Telefone sensível e não destrutivo.** Guarda bruto + normalizado;
  marca (`validado`, `duplicado_de`, `conflito`); **nunca descarta**.
  *(Confirmado pelo developer.)*
- **2026-10-11 — Registro de execução.** WBS + DAG + log em arquivo companheiro
  versionado (não dentro da spec congelada, não só na issue).
- **2026-10-11 — Duas trilhas paralelas** (backend/db + frontend), **git
  centralizado** no coordenador; subagentes não tocam git/deploy.
- **2026-10-11 — Migrations via `ci_db.sh`** (banco descartável + verify gate),
  porta `5433`. Backend roda com `env -u PERL5LIB` (perlbrew do host).
- **2026-10-11 — Telefone é PII; resposta pública mínima.** O endpoint público
  nunca devolve contatos de terceiros; IP é anonimizado (HMAC + salt diário).
- **2026-10-11 — Página `/privacidade` criada (coordenador).** O consentimento
  do formulário público apontava para `/privacidade`, que não existia (link
  quebrado). Criada página pública mínima e factual para dar base informada ao
  consentimento (LGPD). Texto definitivo fica com a escola/revisão jurídica.

## Verificação independente (coordenador, 2026-10-11)

Executada pelo coordenador, **não** pelos subagentes (segunda opinião):

- **Backend:** `env -u PERL5LIB … prove -l t/02-models/canal_listas.t t/04-api/canais/`
  → **3 arquivos / 30 testes PASS** (contra o Postgres de CI em `127.0.0.1:5433`).
- **Migrations:** `ci_db.sh` com `sqitch verify` como gate → verde.
- **Frontend:** `vitest run` (suíte completa) → **82 arquivos / 463 testes PASS**.
- **Contrato:** conferido lado a lado; o backend devolve **array cru** para listas
  e membros e o cliente aceita array (a normalização tolerante do T-B é inócua).
  Público e gestão casam com o contrato congelado.

## Fecho (coordenador, 2026-10-11)

- **Deploy (LXC):** `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_frontend_dev` → OK. Migração confirmada em `edumaps_dev`
  (`database.edumaps`); flag `canais.inscricao.enabled=true` e
  `public_base_url=http://ubatexu.lan:8080` em `app_config.items`.
- **E2E (CDP, `http://ubatexu.lan:8080`):** tudo verde — GET 200; token
  inválido 404; POST 201; duplicado 201 `{duplicado:1}` (1 contato, 2
  inscrições, 1 membro); honeypot 201 sem gravar; sem consentimento 400;
  telefone curto 400; rate limit 429; gestor sem sessão 401; SPA
  `/inscricao/:token` → "Inscrição confirmada!"; `/privacidade` OK. Rodada
  registrada em `docs/e2e/cobertura.md`.
- **PR:** [#209](https://github.com/marcoarthur/edumaps/pull/209) mergeado
  (`4b2828f`); branch remoto deletado; `main` local sincronizado.
- **Imagens Docker locais:** `sqitch`/`backend`/`minion`/`frontend`
  reconstruídas e containers recriados (`docker compose up -d`); md5sum do
  código no container confere com o `main`. (O build inicial falhou por disco
  cheio; resolvido com `docker builder prune`, que liberou ~5,8 GB.)

## Riscos de execução

| Risco | Mitigação |
|-------|-----------|
| Duas trilhas mexendo no mesmo worktree | Diretórios disjuntos; nenhum subagente roda `git` |
| Colisão de porta Postgres (compose usa 5432) | `EDUMAPS_CI_PORT=5433` |
| `sqitch` obsoleto na imagem local (AGENTS) | Subir por `ci_db.sh`, que monta `data_pipeline/` no container `sqitch/sqitch` |
| Frontend sem lib de QR | Adicionar dep leve (`qrcode`) via `npm install` no container node |
| Divergência de contrato entre trilhas | Contrato público/gestão congelado neste arquivo |

## Pendências herdadas (fora da Fase 0)

- `docs/funcionalidades/plataforma/canais-de-comunicacao.md` (documentação
  funcional da capacidade) — atualizar no fecho.
- Banner/aviso da `ConfigPage.svelte` sobre canais.
- Reverts ausentes de `canal_confirmacoes`/`canal_mensagens` (lacuna herdada).
