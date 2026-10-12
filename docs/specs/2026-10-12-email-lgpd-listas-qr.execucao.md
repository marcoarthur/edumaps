# Execução — E-mail e LGPD nas listas com QR (#214, Fase 2)

> **Documento de execução** (contratos por onda, WBS, log), companheiro da spec
> [`2026-10-12-email-lgpd-listas-qr.md`](./2026-10-12-email-lgpd-listas-qr.md).

- **Issue:** [#214](https://github.com/marcoarthur/edumaps/issues/214)
- **Branch:** `feat/canais-email-lgpd`
- **Princípios:** duas trilhas com diretórios disjuntos (T-A `data_pipeline/` +
  `backend/`, T-B `frontend/`); subagentes só código/teste; git, deploy e
  verificação independente no coordenador; migrations por `ci_db.sh` (porta
  5433, verify gate); nenhuma change deployada é editada; deploy com
  `EDUMAPS_CONFIG_MASTER_KEY` exportada (Rexfile aborta sem ela).

## Contrato da onda 1 (congelado)

### Público

**`GET /api/canais/inscricao/:token`** — acrescenta:
```json
{ "campos": ["nome","telefone","email"], "obrigatorios": ["nome","telefone"],
  "consentimento": { "versao": "1.0", "texto": "<markdown simples>" } }
```
`campos`/`obrigatorios` por `coleta`: `telefone` → `[nome,telefone]`/`[nome,telefone]`;
`email` → `[nome,email]`/`[nome,email]`; `ambos` → `[nome,telefone,email]`/igual;
`qualquer` → `[nome,telefone,email]`/`[nome]` (+ regra: pelo menos um contato).

**`POST /api/canais/inscricao/:token`** — entrada `{nome, telefone?, email?,
consentimento:true, consentimento_versao?, _hp?}`:
- obrigatório ausente, e-mail inválido, ou `qualquer` sem nenhum contato → `400`;
- `consentimento_versao` presente e ≠ vigente → `409 {error, consentimento:{versao,texto}}`;
  ausente → grava a vigente (compatibilidade);
- inscrição grava `consentimento_versao` + `consentimento_hash` (sha256 do texto);
- resposta (201) acrescenta `exclusao_url` = `<public_base_url>/privacidade/exclusao/<token32hex>`
  em **toda** inscrição real (não no honeypot). Endpoints de exclusão são da onda 2.
- `confirmacao.canais` (lista que exige): `telegram`/`whatsapp` só se a inscrição
  tem telefone; `{canal:"email"}` só se tem e-mail **e** o e-mail está
  disponível (`canais.email.enabled` + `smtp_host` + `from`).

**`GET /api/canais/confirmacao/:ref`** — `estado` ∈ `pendente`|`parcial`|`confirmado`;
acrescenta `contatos`, só com os contatos presentes na inscrição:
```json
{ "estado": "parcial", "canais": [...], "expira_em": "...",
  "contatos": { "telefone": {"estado":"confirmado","via":"telegram"},
                "email":    {"estado":"pendente","via":null} } }
```
A ref só é marcada usada quando o estado geral fica `confirmado`.

**`POST /api/canais/confirmacao/:ref/email`** → `202 {enviado:1, expira_em}` ·
`404` (ref inválida/usada) · `409` (e-mail indisponível, inscrição sem e-mail ou
e-mail já confirmado) · `429` (3 por ref; 3 por e-mail/h) · `502` (SMTP falhou).
**`POST /api/canais/confirmacao/:ref/email/verificar {codigo}`** →
`200 {estado, contatos}` (estado geral, pode ser `parcial`) · `400` · `410`.

**`GET /api/canais/consentimento`** → `200 {versao, texto, publicada_em}` (vigente).

### Gestão (Bearer + posse)

- `POST /listas`, `PATCH /listas/:id`: + `coleta` (default `telefone`; `400` se inválido).
- `GET /listas`, `/listas/:id`: + `coleta`. `membros_confirmados` = estado geral
  `confirmado`; `membros_pendentes` = `pendente` + `parcial` (só se exige).
- `GET /listas/:id/inscricoes`: cada membro + `email`, `telefone_estado`,
  `email_estado` (`confirmado`|`pendente`|`nao_exigida`|`null` se não coletado/ausente),
  `email_confirmado_em`; `estado` geral ganha `parcial`.
- `POST /listas/:id/qrcode {expira_em?, max_usos?}`: `expira_em` ISO 8601 futura,
  `max_usos` inteiro > 0, senão `400`. Detalhe do QR já traz `usos`,
  `max_usos`, `expira_em`, `status`.

### Admin (Bearer admin)

| Método | Rota | Saída |
|---|---|---|
| GET | `/api/admin/consentimento/versoes` | `200 [ {id, versao, texto, texto_hash, status, publicada_em, created_at} ]` |
| POST | `/api/admin/consentimento/versoes` | `{versao, texto}` → `201` rascunho · `400` · `409` (versão repetida) |
| PUT | `/api/admin/consentimento/versoes/:id` | `{versao?, texto?}` → `200` · `409` (não é rascunho) · `404` |
| POST | `/api/admin/consentimento/versoes/:id/publicar` | `200` (vira vigente; anterior arquivada) · `409` (não é rascunho) |

## WBS

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| M1 | T-A | Migration `canal_email_lgpd` (toda a modelagem da spec, inclusive exclusões; seed 1.0) | 🟢 |
| M2 | T-A | Consentimento versionado (modelo + público + admin) | 🟢 |
| M3 | T-A | `coleta` + e-mail na inscrição (dedupe, conflito) + `exclusao_url` | 🟢 |
| M4 | T-A | Confirmação por contato + canal e-mail | 🟢 |
| M5 | T-A | QR: validação de `expira_em`/`max_usos` | 🟢 |
| F1 | T-B | ListasPage: `coleta`, e-mail, estado por contato, `parcial` | 🟢 |
| F2 | T-B | Página pública: campos por `coleta`, consentimento vigente/409, confirmação por e-mail, `parcial`, link de exclusão | 🟢 |
| F3 | T-B | QRModal: validade e limite; estados expirado/esgotado | 🟢 |
| T1 | coord. | verificação, commits, deploy | ⚪ |

Onda 2: exclusão (titular + gestor + histórico), retenção (job + admin),
`ExclusaoPage`, admin de consentimento/retenção na UI, `/privacidade`.

## Log de decisões

- **2026-10-12 — Perguntas em aberto da spec:** acesso/portabilidade fica fora
  da Fase 2; textos provisórios (revisão jurídica depois); exclusão anonimiza o
  contato (cobre reuniões/relações sem apagá-las).
- **2026-10-12 — Migration única** na onda 1 com toda a modelagem (inclusive
  `canal_exclusoes` e `exclusao_hash`), para não abrir duas changes no ciclo.
- **2026-10-12 — `consentimento_versao` opcional no POST** (ausente → vigente),
  para compatibilidade; presente e desatualizada → `409` com o texto vigente.
- **2026-10-12 — `exclusao_url` já na onda 1** (o token nasce com a inscrição);
  as rotas que o consomem chegam na onda 2.
- **2026-10-12 — Desvios da T-A aceitos (onda 1):** `canal_listas.desativada_em`
  (o `updated_at` muda em PATCH de lista inativa; não serve de data de
  desativação); `canal_confirmacao_refs.envios_email`; `contatos` também no
  `confirmacao` do POST; `canais` só lista contatos ainda pendentes; os dois
  `/verificar` devolvem `{estado, contatos}`; dedupe preenche o contato
  reaproveitado sem sobrescrever; campos fora da `coleta` são ignorados;
  `validado=true` só com o estado geral confirmado; código mascarado no
  histórico (`******`), inclusive no WhatsApp em modo texto; SMTP injetável
  (`canais_smtp`) para testes; `GET /api/canais/consentimento` não depende da
  flag de autoinscrição; validação de `expira_em` aceita data ou data+hora.
- **2026-10-12 — E-mail de código sem `exclusao_url`:** só o hash do token é
  guardado; o e-mail orienta a usar o link mostrado na conclusão ou pedir à
  escola. Aceito.
- **2026-10-12 — Consentimento 1.0 = texto atual (só telefone).** É o texto que
  as inscrições antigas aceitaram; publicar 1.1 citando e-mail (pela tela de
  admin da onda 2) antes de usar listas `email`/`ambos`/`qualquer`.
- **2026-10-12 — T-B:** `ApiError.data` guarda o corpo do erro (409 do
  consentimento); `ConfirmacaoTelefone` virou `ConfirmacaoContatos`; markdown do
  consentimento renderizado sem `{@html}`; formulários com `novalidate` e
  validação própria.

## Verificação independente (coordenador, onda 1)

- `ci_db.sh verify` → `canal_email_lgpd .. ok`.
- Backend `prove -l -r t/02-models/ t/04-api/canais/ t/04-api/admin/
  t/04-api/gestor/ t/03-plugins/ t/05-tasks/{telegram_polling,bot_telegram,bot_notifier}.t`
  → 69 arquivos / 449 testes; só os 6 pré-falhos conhecidos. `check_dependencies` OK.
- Frontend 85 arquivos / 564 testes; `vite build` OK. Campos do contrato
  conferidos lado a lado.
