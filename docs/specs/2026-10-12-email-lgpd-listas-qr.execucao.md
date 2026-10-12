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

## Onda 2 — contrato (congelado)

### Público (independente de `canais.inscricao.enabled` — direito do titular)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/canais/exclusao/:token` | — | `200 {escola_nome, lista_nome, ja_excluido}` · `404` genérico |
| POST | `/api/canais/exclusao/:token` | `{confirmar:true}` | `200 {ok:1, ja_excluido}` (idempotente) · `400` (sem `confirmar`) · `404` · `429` |
| GET | `/api/canais/consentimento` | — | (onda 1) + `retencao {metadados_dias, pendentes_dias, listas_inativas_meses, enabled}` |

`ja_excluido` = a inscrição do token já foi anonimizada. O token é o da
`exclusao_url` (32 hex; só o sha256 em `canal_inscricoes.exclusao_hash`).

### Gestão (Bearer + posse)

| Método | Rota | Saída |
|---|---|---|
| DELETE | `/api/gestor/:cod_inep/canais/listas/:id/membros/:membro_id` | corpo opcional `{motivo}` → `200 {ok:1, contatos, inscricoes, membros}` · `403` · `404` |
| GET | `/api/gestor/:cod_inep/canais/exclusoes` | `200 [ {id, origem, regra, motivo, gestor_id, contatos, inscricoes, membros, created_at} ]` (mais recentes primeiro, até 200) |

### Admin (Bearer admin)

| Método | Rota | Saída |
|---|---|---|
| GET | `/api/admin/canais/retencao` | `200 {enabled, metadados_dias, pendentes_dias, listas_inativas_meses, ultima_execucao: {em, metadados, pendentes, listas_inativas} \| null, agendado}` |
| POST | `/api/admin/canais/retencao/executar` | `202 {ok:1, job_id}` (execução avulsa, não reagenda) |

As versões de consentimento (onda 1) ganham tela de admin nesta onda.

### Anonimização (`anonimizar_contato`, RF-206)

Conforme o inventário de PII da spec, numa transação: contato da escola
(`nome='[removido]'`, telefone/e-mail `NULL`); todas as inscrições do contato
(nome `[removido]`, telefone/telefone_norm/email/email_norm/ip_anon/user_agent
`NULL`, `anonimizado_em`); membros do contato removidos de **todas** as listas da
escola; refs invalidadas (`invalidada_em`, `telegram_chat_pendente NULL`);
`canal_confirmacoes` pendentes do endereço expiradas e `endereco` trocado por
hash; `canal_mensagens` do contato com destinatário e corpo apagados; registro
em `canal_exclusoes` sem PII. Idempotente.

### Retenção

- Folhas `canais.retencao.enabled` (boolean, default true),
  `metadados_dias` (90), `pendentes_dias` (180), `listas_inativas_meses` (12) no
  AppConfig, grupo "Retenção (LGPD)" na categoria Canais.
- Task Minion `canais_retencao`: diária, autorreagendável, lock único, início no
  boot do worker (mesmo padrão da `telegram_polling`); `{manual:1}` executa uma
  vez sem reagendar. Três regras (spec RF-207), cada uma registra uma linha em
  `canal_exclusoes` (`origem='retencao'`, `regra`) **mesmo com contagem zero**,
  para a última execução ser visível. Contato em outra lista ativa não é
  anonimizado pela regra de lista inativa.

### Frontend (onda 2)

- `ExclusaoPage` pública em `/privacidade/exclusao/:token` (fora do guard):
  escola/lista, o que será removido, confirmar, estados concluído/já excluído/
  inválido.
- `ListasPage`: ação "Remover inscrito" (diálogo de confirmação + motivo) e
  seção "Exclusões" (histórico da escola: data, origem, regra/motivo, contagens).
- `PrivacidadePage`: texto vigente do consentimento (markdown seguro já
  existente), prazos de retenção e como excluir.
- Admin: tela de **versões de consentimento** (listar, criar rascunho, editar,
  publicar com confirmação) em rota admin própria, linkada do `/config`; painel
  de **retenção** (prazos, última execução, "Executar agora") ao selecionar uma
  folha `canais.retencao.*` no `/config` (mesmo padrão do painel do bot).

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| E1 | T-A | `anonimizar_contato` + varredura de PII em teste | 🟢 |
| E2 | T-A | Exclusão pública + pelo gestor + histórico | 🟢 |
| E3 | T-A | Retenção: config, task, endpoints admin | 🟢 |
| G1 | T-B | `ExclusaoPage` + `PrivacidadePage` | 🟢 |
| G2 | T-B | ListasPage: remover inscrito + histórico | 🟢 |
| G3 | T-B | Admin: versões de consentimento + painel de retenção | 🟢 |

### Log de decisões — onda 2

- **Retenção só anonimiza contatos criados pela autoinscrição** (primeira
  inscrição sem `duplicado_de`): contato que já existia na agenda do gestor
  nunca é apagado por prazo. Restringe o RF-207 a favor da agenda; aceito.
- **Pendente preservado** se confirmou algum contato em qualquer lista, se é
  membro de lista ativa sem exigência, ou se tem inscrição mais nova que o prazo.
- **Linhas de retenção:** resumo da instalação com `cod_inep = 0` (sempre, mesmo
  zero; é o que `ultima_execucao` lê) + uma linha por escola afetada (histórico
  do gestor).
- **Anonimização além do inventário:** apaga também `canal_mensagens.erro` (o erro
  SMTP pode conter o e-mail) e o telefone/e-mail do titular em inscrições de
  outros contatos (caso de conflito); mensagens localizadas por contato,
  endereços e refs; repetição devolve zeros sem novo registro.
- **`{manual:1}` executa mesmo com `enabled=false`** (ação explícita do admin);
  boot agenda a primeira diária para +1h; sem lock reagenda +10min; erro +1h;
  prazo < 1 usa o default.
- **Exclusão pública:** formato do token validado no controller (404
  genérico); rate limit só no POST. Booleanos JSON em `ja_excluido`,
  `agendado`, `retencao.enabled`.
- **T-B:** `apiClient.delete(path, body?)`; `ConfirmDialog` acessível em
  `shared/ui`; versões de consentimento em `/config/consentimento` (mesma guarda
  do `/config`), sem mexer no menu; 429 da exclusão como aviso.

## Verificação independente (coordenador, onda 2)

- Backend 74 arquivos / 476 testes; só os 6 pré-falhos. `check_dependencies` OK.
- Frontend 88 arquivos / 611 testes; `vite build` OK.
- Alinhamento conferido: `regra` = `metadados`|`pendentes`|`lista_inativa`
  (o front aceita as duas grafias); contagens numéricas; DELETE sem corpo aceito.
