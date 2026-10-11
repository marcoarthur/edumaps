# Execução — Confirmação de posse nas listas com QR (#212, Fase 1)

> **Documento de execução** (WBS + DAG + log de decisões), companheiro da spec
> [`2026-10-11-confirmacao-posse-listas-qr.md`](./2026-10-11-confirmacao-posse-listas-qr.md).
> A spec é o **contrato**; este arquivo é **mutável** e registra o andamento.

- **Issue:** [#212](https://github.com/marcoarthur/edumaps/issues/212)
- **Branch:** `feat/canais-confirmacao-posse`
- **Onda atual:** 1 (modelo, estado, gestão e página pública contra o contrato)

## Princípios de execução

- **Duas trilhas em paralelo, diretórios disjuntos:** T-A (`data_pipeline/` +
  `backend/`) e T-B (`frontend/`).
- **Git centralizado:** subagentes só escrevem código e rodam teste; commit,
  push, deploy e PR são do coordenador.
- **Migrations validadas por banco limpo** (`db/fixtures/ci_db.sh`, porta
  `5433`, `sqitch verify` como gate). Nenhuma change já deployada é editada.
- **Contrato da onda congelado abaixo.** Mudança exige aviso às duas trilhas.

## Contrato da onda 1 (congelado)

### Público

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/inscricao/:token` | (Fase 0) | (Fase 0) + `confirmacao` quando a lista exige |
| GET | `/api/canais/confirmacao/:ref` | — | `200 {estado, canais, expira_em}` · `404` genérico · `429` (rate limit; o polling trata como transitório) |

`confirmacao` na resposta do POST (só se `lista.exige_confirmacao`):

```json
// membro pendente (novo, ou reinscrição de pendente → nova ref, a anterior é invalidada)
{ "ref": "<32 hex>", "estado": "pendente", "expira_em": "<ISO8601>",
  "canais": [ { "canal": "telegram", "url": "https://t.me/<bot>?start=<ref>" },
              { "canal": "whatsapp" } ] }
// membro já confirmado (reinscrição)
{ "estado": "confirmado" }
```

- `canais` contém só os canais **disponíveis** (ordem: telegram, whatsapp);
  pode ser `[]`.
  - telegram: `canais.telegram.enabled` verdadeiro **e** `token` **e**
    `bot_username` definidos.
  - whatsapp: `canais.whatsapp.enabled` verdadeiro, `provider=cloud`, `token`,
    `phone_number_id` **e** `template_confirmacao` definidos.
- `GET /api/canais/confirmacao/:ref`: `ref` pendente válida → `estado:"pendente"`
  com `canais` e `expira_em`; `ref` já usada (confirmada) → `200
  {estado:"confirmado", canais:[], expira_em}`; inexistente, expirada sem uso
  ou invalidada → `404 {error:"Confirmação não encontrada."}` (genérico).
  Também `404` com a feature desligada (`canais.inscricao.enabled`). Sem PII.
- Listas sem exigência: resposta do POST **idêntica** à Fase 0 (sem a chave).

### Endpoints da onda 2 (o frontend já implementa contra eles, com mock)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| POST | `/api/canais/confirmacao/:ref/whatsapp` | — | `202 {enviado:1, expira_em}` · `404` · `409` (canal indisponível) · `429` |
| POST | `/api/canais/confirmacao/:ref/whatsapp/verificar` | `{codigo}` | `200 {estado:"confirmado"}` · `400` (código inválido) · `410` (expirado/tentativas) |

### Gestão (Bearer + posse do `cod_inep`)

| Método | Rota | Mudança |
|---|---|---|
| POST | `/listas` | aceita `exige_confirmacao` (boolean, default `false`) |
| PATCH | `/listas/:id` | **novo**: `{nome?, descricao?, exige_confirmacao?}` → `200` detalhe · `400` (nada a alterar / inválido) · `409` (nome duplicado) · `404` |
| GET | `/listas`, `/listas/:id` | + `exige_confirmacao`, `membros_confirmados`, `membros_pendentes` |
| GET | `/listas/:id/inscricoes` | cada membro + `estado` (`nao_exigida`\|`pendente`\|`confirmado`), `confirmado_via`, `confirmado_em` |

Estado derivado do membro: `confirmado` se `confirmado_em` não nulo; senão
`pendente` se a lista exige; senão `nao_exigida`. `membros_pendentes` conta os
pendentes só quando a lista exige (senão `0`).

### Modelo (para a onda 2 consumir)

`Roles::Business::Canal::Confirmacao` (ou métodos no role de listas):
`abrir_ref(membro_id, inscricao_id)` → `{ref, expira_em}`;
`estado_ref(ref)`; `concluir(ref|membro, via => 'telegram'|'whatsapp',
telegram_chat_id?)` → membro `confirmado_em/via`, `validado=true`, ref
`usada_em`; `registrar_conflito(ref)` → `canal_inscricoes.conflito=true`.

## WBS

| ID | Trilha | Escopo | Depende | Status | Evidência |
|----|--------|--------|---------|--------|-----------|
| M1 | T-A | Migration `canal_confirmacao_listas` (deploy/revert/verify gate) | — | 🟢 | `ci_db.sh verify` ok; revert → deploy ok |
| M2 | T-A | Modelo: refs (hash, TTL 24h, invalidação), estado, concluir, conflito | M1 | 🟢 | `t/02-models/canal_confirmacao.t` |
| M3 | T-A | AppConfig: folhas `canais.telegram.*` + `canais.whatsapp.template_*`; disponibilidade de canais | — | 🟢 | `t/02-models/app-config.t` |
| A1 | T-A | POST inscrição com `confirmacao`; GET `confirmacao/:ref` | M2,M3 | 🟢 | `t/04-api/canais/confirmacao.t` |
| A2 | T-A | Gestão: `exige_confirmacao`, PATCH, contadores, estado por membro | M2 | 🟢 | `t/04-api/canais/gestao.t` |
| F1 | T-B | `ListasPage`: toggle, selo, filtro, contadores | contrato | 🟢 | vitest (ListasPage/gestorCanaisApi) |
| F2 | T-B | `InscricaoPublicaPage`: passo 2 (Telegram, WhatsApp, polling) | contrato | 🟢 | vitest (InscricaoPublicaPage/ConfirmacaoTelefone) |
| T1 | coord. | verificação independente, commit, deploy da onda | M1..F2 | ⚪ | |

Onda 2 (depois): `Telegram::Updates`, webhook, task de polling, WhatsApp
template + endpoints de código. Onda 3: integração, e2e, docs, PR.

## Log de decisões

- **2026-10-11 — Perguntas em aberto da spec seguem a proposta:** `ref` válida
  por 24h; página consulta o estado a cada 3s por até 5 min; `chat_id`
  confirmado em `canal_lista_membros.telegram_chat_id` (sem tocar
  `clean.contatos`).
- **2026-10-11 — Config do bot público na onda 1.** As folhas
  `canais.telegram.*` e `canais.whatsapp.template_*` entram já na onda 1 porque
  a disponibilidade dos canais (resposta do POST) depende delas; o uso efetivo
  (envio/recebimento) é da onda 2.
- **2026-10-11 — GET de `ref` usada responde `confirmado`** (não 404), para a
  página pública, que consulta o estado, enxergar a conclusão feita no Telegram.
- **2026-10-11 — 429 no GET de confirmação (aprovado pelo coordenador).** O
  GET tem bucket de rate limit próprio (`rate_max × 6` por janela, 60/min no
  default), separado do POST: o limite do POST (10/min) quebraria o polling de
  3s (20/min). O cliente ignora 429 e tenta no próximo tick.
- **2026-10-11 — Ref de 128 bits completos** (`gen_random_bytes(16)` em hex,
  pgcrypto já presente); só `sha256(lc ref)` é gravado; `expira_em` em ISO 8601
  UTC.
- **2026-10-11 — Ref aberta na mesma transação da inscrição**; a API pública
  não expõe ids internos.
- **2026-10-11 — `concluir` idempotente** (preserva o primeiro
  `confirmado_em/via`); `registrar_conflito` só com ref pendente e não altera
  membro.
- **2026-10-11 — Ligar `exige_confirmacao` numa lista com membros** não abre
  refs para eles: passam a contar como `pendente` e só recebem ref ao se
  reinscrever (confirmação retroativa é fora de escopo, spec).
- **2026-10-11 — UX:** `confirmacao` tem precedência sobre `duplicado` na
  página; ao esgotar 5 min de polling, a página oferece "Verificar
  novamente"; o toggle "Exigir confirmação" fica no detalhe da lista (não havia
  edição de lista na UI).

## Verificação independente (coordenador, onda 1)

- **Migrations:** `ci_db.sh verify` → `canal_confirmacao_listas .. ok`,
  *Verify successful*.
- **Backend:** `prove -l t/02-models/ t/04-api/canais/ t/04-api/admin/
  t/03-plugins/channel/ t/04-api/gestor*` → 37 arquivos / 298 testes; falham só
  `City.t` (#21) e `indicators_quality.t` (#8), **idênticas no `main` limpo**
  (worktree) — pré-existentes.
- **Contrato:** campos conferidos lado a lado (`exige_confirmacao`,
  `membros_confirmados/pendentes`, `estado`, `confirmado_via/em`, `canais[].url`,
  `expira_em`).
