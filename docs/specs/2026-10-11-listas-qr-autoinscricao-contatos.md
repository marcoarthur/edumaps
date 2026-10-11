# Especificação de Requisitos — Listas nomeadas com QR code para autoinscrição de contatos

**Data:** 2026-10-11
**Autor:** Tech Lead / Product Engineer (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #208
**Depende de:** núcleo de Canais (`EduMaps::Channel`, PR #207)

---

# ENTREGÁVEL 1 — ISSUE

## Título

**Listas nomeadas com QR code para autoinscrição de contatos (canal telefone — MVP)**

## Contexto

O EduMaps já tem a agenda de contatos da escola (`clean.contatos`) organizada em
grupos (`clean.contato_grupos`) e acaba de ganhar o **núcleo de Canais**
(`EduMaps::Channel`, PR #207) para validação, confirmação de posse e histórico de
mensagens. Hoje, inscrever contatos numa lista depende de digitação/importação
manual pelo gestor.

## Problema

O gestor não tem uma forma **frictionless** de coletar contatos no local (sala de
professores, reunião de pais, evento): distribuir um link ou pedir o telefone e
digitar depois é lento e propenso a erro. Falta um **canal de entrada
auto-serviço**: um QR code que o interessado escaneia e preenche sozinho.

## Objetivo

Permitir que o gestor **crie uma lista nomeada** (ex.: "Alunos 6ºA",
"Responsáveis") e **gere um QR code** associado. Qualquer dispositivo móvel que
escaneie o QR acessa um formulário público e registra **nome + telefone** na
lista correta. O gestor **vê os contatos** na lista.

Métrica de valor: reduzir o esforço de captura de contatos de minutos de digitação
para segundos de escaneamento, aumentando a cobertura da agenda da escola.

## Escopo (MVP)

1. Gestor autenticado cria uma **lista nomeada** e gera um **QR code** para ela.
2. QR aponta para uma **URL pública** que abre um formulário mobile.
3. Formulário coleta **nome** e **telefone** (canal `telefone`, **sem validação**).
4. API registra o contato na lista (cria em `clean.contatos` + proveniência).
5. Gestor visualiza os contatos inscritos na lista.
6. Controles mínimos de abuso, duplicidade, revogação e (opcionalmente) expiração.

## Fora de escopo (MVP)

- Canais **WhatsApp** e **e-mail** (confirmação de posse, envio). Ficam para as
  fases seguintes, reusando `EduMaps::Channel::*`.
- **Validação** do telefone (formato/sintaxe/posse) — o MVP aceita "telefone
  simples, sem validação" por decisão de produto.
- Envio em massa para a lista (campanhas) e listas dinâmicas por critério.
- Opt-out/consentimento granular, ciclo de vida LGPD completo (retenção/expurgo
  automático) — apenas o **gancho** de consentimento entra no MVP.
- Importação por CSV/link além do QR; edição em tempo real pelos inscritos.
- Analytics de conversão, A/B de formulário, múltiplos QR por lista (fase 2).
- Página pública com marca/personalização da escola.

## Requisitos Funcionais

### RF-001: Criar lista nomeada — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve permitir criar uma lista nomeada vinculada à escola
(`cod_inep`) do gestor, com nome único por escola.
**Aceite:**
- [ ] `POST /api/gestor/:cod_inep/canais/listas` cria a lista; retorna `201` + `id`.
- [ ] Nome duplicado na mesma escola retorna `409`.
- [ ] Gestor só cria listas para o seu próprio `cod_inep` (`403` caso contrário).

### RF-002: Gerar/rotacionar QR code para a lista — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve gerar um token público (UUID) e devolver a URL de
inscrição para a lista; deve permitir **rotacionar** (revogar o anterior).
**Aceite:**
- [ ] `POST /api/gestor/:cod_inep/canais/listas/:id/qrcode` retorna `{ token, url, expira_em }`.
- [ ] Rotacionar invalida o token anterior (`410` ao usá-lo).
- [ ] `DELETE .../qrcode` revoga o token ativo.

### RF-003: Página pública de inscrição — Essencial
**Ator:** qualquer pessoa com o QR (não autenticada).
**Descrição:** O sistema deve expor `GET /api/canais/inscricao/:token` devolvendo
apenas o mínimo para renderizar o formulário: nome de exibição da lista, nome da
escola, canal, campos exigidos e validade. **Nunca** expor a lista de contatos.
**Aceite:**
- [ ] Token válido → `200 { lista_nome, escola_nome, canal:"telefone", campos:["nome","telefone"], expira_em }`.
- [ ] Token inválido/revogado/expirado → `404` ou `410` (sem distinguir existência).
- [ ] Resposta não contém PII de terceiros.

### RF-004: Registrar contato (telefone, sem validação) — Essencial
**Ator:** inscrito (não autenticado).
**Descrição:** O sistema deve registrar `nome` + `telefone` na lista do token,
criando/reusando o contato em `clean.contatos` e vinculando-o à **lista**
(`canal_lista_membros`), com proveniência em `canal_inscricoes`.
**Aceite:**
- [ ] `POST /api/canais/inscricao/:token` com `{ nome, telefone, consentimento:true }` → `201 { ok:1 }`.
- [ ] `nome` e `telefone` obrigatórios; sem eles → `400`.
- [ ] Contato aparece na visão da lista do gestor (membro vinculado).
- [ ] `consentimento` deve ser verdadeiro no MVP → senão `400`.

### RF-005: Duplicidade — modelo sensível e não destrutivo — Essencial
**Ator:** sistema.
**Descrição:** O sistema deve evitar duplicar **contato** e **pertencimento** por
telefone dentro da mesma lista/escola adotando um **modelo sensível e não
destrutivo**: guarda o telefone **bruto e normalizado**, **marca** o dado
pré-existente/não validado e **nunca descarta** registros.
**Aceite:**
- [ ] Normalização aplicada antes da comparação (guarda `telefone` bruto + `telefone_norm`).
- [ ] Mesmo telefone já na lista → **sem novo contato e sem novo membro** (idempotente); a submissão ainda é registrada como histórico com `duplicado_de`.
- [ ] Telefone já existente na escola (outra lista) → vincula à nova lista **sem** criar contato duplicado.
- [ ] Divergência de nome/telefone **não sobrescreve** o existente: marca `conflito=true`.
- [ ] Entradas do MVP ficam marcadas `validado=false` (telefone não validado); **nada é apagado**.

### RF-006: Visualizar contatos da lista — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve listar os **membros** (contatos vinculados) de uma
lista, distinguindo origem e status de validação.
**Aceite:**
- [ ] `GET /api/gestor/:cod_inep/canais/listas/:id/inscricoes` retorna os membros (nome, telefone, quando, `validado`, `conflito`), só da escola do gestor.
- [ ] Contagem de membros aparece no detalhe da lista.
- [ ] Somente o gestor dono da escola acessa (`403` caso contrário).

### RF-007: Revogação/expiração — Importante
**Ator:** gestor / sistema.
**Descrição:** O sistema deve permitir revogar o QR e respeitar expiração
(`expira_em`) e limite de usos (`max_usos`) quando configurados.
**Aceite:**
- [ ] Após revogar/expirar/atingir `max_usos`, o `GET`/`POST` públicos recusam (`410`/`429`).
- [ ] Valores são configuráveis por lista (default: sem expiração no MVP, `expira_em` nulo).

## Requisitos Não Funcionais

- **RNF-001 (Segurança):** token de 128 bits (UUID v4); sem enumeração; o
  endpoint público retorna o mínimo e não lista contatos; autorização de gestão
  exige Bearer + posse do `cod_inep`.
- **RNF-002 (LGPD/Privacidade):** dados pessoais (nome, telefone) coletados com
  **consentimento** explícito e finalidade declarada; armazenados na agenda PII
  restrita ao gestor da escola; IP/UA, se guardados, **anonimizados** (HMAC) e
  com retenção definida.
- **RNF-003 (Antiabuso):** rate limit por token e por origem; honeypot/validação
  mínima; `max_usos`; revogação imediata. Degradação graciosa (nunca `500` por abuso).
- **RNF-004 (Mobile-first):** formulário responsivo, carrega rápido em 4G;
  funciona sem login.
- **RNF-005 (Observabilidade):** cada inscrição registra proveniência
  (QR/lista) para auditoria; eventos de abuso logados.
- **RNF-006 (Compatibilidade):** reusa `clean.contatos` sem quebrar a agenda
  existente e **não depende de `clean.contato_grupos`** (grupos serão deprecados;
  o pertencimento passa a ser da **lista**); migrations Sqitch com `verify` no
  estilo gate.

## Critérios de Aceite (visão do usuário)

- [ ] Gestor cria "Responsáveis", clica em "Gerar QR", vê o QR e copia o link.
- [ ] Escaneando (ou abrindo o link no celular), o formulário abre em < 3s.
- [ ] Preenchendo nome+telefone, a confirmação aparece e o contato entra na lista.
- [ ] O gestor vê o contato na lista com data/hora.
- [ ] Um segundo cadastro com o mesmo telefone não cria duplicata.
- [ ] Revogar o QR faz o link parar de funcionar imediatamente.
- [ ] Link não expõe contatos de terceiros nem dados da escola além do nome.

## Riscos

| # | Risco | Impacto | Mitigação |
|---|-------|---------|-----------|
| R1 | Spam/abuso no endpoint público | Alto | rate limit, honeypot, `max_usos`, revogação, monitoramento |
| R2 | Vazamento de PII | Alto | resposta mínima, PII só na agenda do gestor, token forte, sem listagem pública |
| R3 | LGPD (consentimento/retenção) | Alto | consentimento explícito, anonimização de IP, retenção definida (decidir) |
| R4 | Telefones duplicados/compartilhados | Médio | modelo sensível não destrutivo: normaliza, reusa contato, marca `duplicado_de`/`conflito`, sem descarte |
| R5 | QR vazado/circula além do público | Médio | revogação, expiração opcional, `max_usos` |
| R6 | Rota pública no SPA (crawlers/deep-link) | Baixo | rota fora do guard de auth; noindex |
| R7 | Dependência nova de geração de QR | Baixo | lib client-side leve; fallback backend SVG |
| R8 | Enumeração de listas/escolas por token | Médio | token aleatório 128-bit; mensagens de erro genéricas |

## Dependências

- Núcleo de Canais (`EduMaps::Channel`, PR #207) — para as fases de confirmação.
- Agenda existente: `clean.contatos` (migration `gestor_reunioes`). **Não**
  depende de `clean.contato_grupos` (será deprecado).
- Auth do gestor (`gestor#_require_gestor`) e checagem de posse do `cod_inep`.
- Precedente de link público: `Pesquisa#publica_form`/`publica_resposta`.
- Frontend Svelte 5 + roteador; lib de QR (nova).

## Métricas de sucesso

- Nº de listas criadas e nº de QRs ativos.
- Nº de inscrições via QR por semana e **taxa de conclusão** do formulário.
- Tempo médio para o gestor captar N contatos (antes/depois).
- % de duplicatas bloqueadas (qualidade dos dados).
- Taxa de abuso (inscrições recusadas por rate limit/honeypot).

## Decisões já tomadas

1. **Lista própria** (`clean.canal_listas`) — **não** reutiliza
   `clean.contato_grupos` (que será **deprecado**). O pertencimento passa a ser
   da **lista**, via tabela de membros própria, independente de grupo.
2. **Modelo de telefone sensível e não destrutivo:** guarda o telefone **bruto +
   normalizado**, **marca** o dado (não validado / conflito) e **não descarta**.
   Telefones compartilhados convivem como registros históricos/membros distintos.

## Perguntas em aberto (demais)

3. **Expiração default:** sem expiração, TTL fixo (ex.: 30 dias) ou configurável?
   Limite de usos por QR?
4. **Consentimento/LGPD:** texto do consentimento, versão, e o que fazer com quem
   não consente (bloquear? registrar anonimamente?).
5. **IP/User-Agent:** guardar anonimizado para antiabuso, com que retenção?
6. **Domínio/base URL** pública (HTTPS) e formato da URL do QR.
7. **Múltiplos QR por lista / rotação** — um ativo por vez ou histórico?
8. **Cascata:** ao excluir a lista, os membros são desvinculados (padrão, sem
   descarte do contato) — confirmar; e os contatos órfãos em `clean.contatos`?
9. **Rate limit:** limites concretos (por token, por IP, por janela) e se há
   CAPTCHA simplificado no MVP.
10. **`clean.contatos.telefone_norm`:** adicionar coluna normalizada (nullable,
    backfill **marcado**, sem descarte) para dedupe indexável na escola?

---

# ENTREGÁVEL 2 — PLANO DE IMPLEMENTAÇÃO

## Arquitetura proposta

**Decisão: API unificada.** Um único par de endpoints públicos
(`/api/canais/inscricao/:token`) serve **qualquer** canal. O canal é um
**atributo de dados** da lista/QR (`canal = 'telefone'` no MVP), não um prefixo de
rota. Justificativa: o fluxo público é idêntico entre canais (resolver token →
validar → coletar campos → registrar); o que muda é o **conjunto de campos** e,
em fases futuras, a **confirmação de posse** (que já vive em `Channel::Confirmation`).
Uma API por canal duplicaria roteamento, rate limit e dedupe sem ganho.

```
┌─ Frontend Svelte (SPA) ────────────────────────────────────────────┐
│  ContatosPage / ListasPage (autenticado)                           │
│    └─ cria lista · gera QR · exibe inscrições                      │
│  InscricaoPublicaPage (PÚBLICA, mobile)  ← QR aponta p/ cá         │
│    └─ form nome+telefone+consentimento                             │
└───────────────┬───────────────────────────────┬────────────────────┘
                │ Bearer                        │ (sem auth)
                ▼                               ▼
┌─ Backend Perl (Mojolicious) ───────────────────────────────────────┐
│  Plugin::API::Gestor  (under _require_gestor)                      │
│    gestor#canais_lista_*  ── cria lista / gera QR / lista inscrições│
│  Plugin::API::Canais  (PÚBLICO, novo)                              │
│    canais#inscricao_form (GET) · canais#inscricao_create (POST)    │
│  Model::Canal / Roles::Business::Canal                             │
│    resolve token · rate limit · dedupe · contato/membro           │
│  EduMaps::Channel (núcleo existente)  ← confirmação (fases futuras)│
└───────────────┬────────────────────────────────────────────────────┘
                ▼
        PostgreSQL (schema clean.*)
```

Reuso: o par público espelha `Pesquisa#publica_form`/`publica_resposta` (mesma
ideia de token em rota `under` sem auth, com `_valid_public_token`).

## Modelo de dados

Novas tabelas em `clean` (migrations Sqitch, **anexadas ao fim** do plano,
`verify` no estilo gate). **A lista é entidade própria** (`canal_listas`), sem
dependência de `contato_grupos` (deprecado); o pertencimento é da lista, via
tabela de membros. O modelo de telefone é **sensível e não destrutivo** (bruto +
normalizado, marcado, sem descarte).

```sql
clean.canal_listas                     -- a "lista nomeada" (entidade canônica)
  id          bigserial PK
  cod_inep    bigint NOT NULL
  gestor_id   bigint NOT NULL REFERENCES clean.gestores(id) ON DELETE CASCADE
  nome        text NOT NULL
  canal       text NOT NULL DEFAULT 'telefone' CHECK (canal IN ('telefone'))  -- expandir depois
  descricao   text
  ativo       boolean NOT NULL DEFAULT true
  created_at  timestamptz NOT NULL DEFAULT NOW()
  updated_at  timestamptz NOT NULL DEFAULT NOW()
  UNIQUE (cod_inep, nome)
  -- sem grupo_id: contato_grupo será deprecado; o pertencimento é da lista.

clean.canal_qrcodes
  id          bigserial PK
  lista_id    bigint NOT NULL REFERENCES clean.canal_listas(id) ON DELETE CASCADE
  token       uuid NOT NULL UNIQUE          -- 128 bits; segredo público
  status      text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','revogado','expirado'))
  expira_em   timestamptz                    -- NULL = sem expiração
  max_usos    integer                        -- NULL = ilimitado
  usos        integer NOT NULL DEFAULT 0
  criado_por  bigint NOT NULL REFERENCES clean.gestores(id) ON DELETE CASCADE
  created_at  timestamptz NOT NULL DEFAULT NOW()
  revogado_em timestamptz

clean.canal_lista_membros              -- pertencimento (desacoplado de grupos)
  id          bigserial PK
  lista_id    bigint NOT NULL REFERENCES clean.canal_listas(id) ON DELETE CASCADE
  contato_id  bigint NOT NULL REFERENCES clean.contatos(id) ON DELETE CASCADE
  origem      text NOT NULL DEFAULT 'qrcode' CHECK (origem IN ('qrcode','manual','import'))
  validado    boolean NOT NULL DEFAULT false -- MVP: telefone não validado
  created_at  timestamptz NOT NULL DEFAULT NOW()
  UNIQUE (lista_id, contato_id)              -- um contato por lista, idempotente
  INDEX (contato_id)

clean.canal_inscricoes                 -- proveniência/auditoria (append-only, sem descarte)
  id          bigserial PK
  qrcode_id   bigint NOT NULL REFERENCES clean.canal_qrcodes(id) ON DELETE CASCADE
  lista_id    bigint NOT NULL REFERENCES clean.canal_listas(id) ON DELETE CASCADE
  contato_id  bigint REFERENCES clean.contatos(id) ON DELETE SET NULL
  nome        text NOT NULL
  telefone    text NOT NULL                    -- como digitado (bruto)
  telefone_norm text NOT NULL                  -- só dígitos; chave de comparação
  validado    boolean NOT NULL DEFAULT false   -- MVP: telefone não validado
  duplicado_de bigint REFERENCES clean.contatos(id) ON DELETE SET NULL -- contato pré-existente
  conflito    boolean NOT NULL DEFAULT false   -- nome/telefone divergem do existente
  ip_anon     text                             -- HMAC/sal, nunca IP puro
  user_agent  text
  consentimento_em timestamptz NOT NULL
  consentimento_versao text NOT NULL
  created_at  timestamptz NOT NULL DEFAULT NOW()
  INDEX (lista_id), INDEX (telefone_norm), INDEX (contato_id)
```

**Dedupe não destrutivo (MVP):**

1. Normaliza o telefone (só dígitos; **sem** validação de formato).
2. Procura um contato existente na escola por `telefone_norm`.
   - **Existe:** não sobrescreve. Insere o membro (`ON CONFLICT DO NOTHING`) e
     registra a inscrição com `duplicado_de = contato_id` e `conflito = (nome difere)`.
   - **Não existe:** cria o contato (`validado=false`), insere o membro e a inscrição.
3. **Nunca apaga**; o dado antigo/não validado permanece apenas **marcado**.

`UNIQUE (lista_id, contato_id)` garante idempotência do pertencimento mesmo sob
concorrência; `canal_inscricoes` é histórico append-only (o mesmo telefone pode
ter várias submissões registradas — é a "marca", não um erro).

> `clean.contatos` **não** tem today coluna normalizada de telefone. Para dedupe
> indexável na escola, o caminho sensível é adicionar `telefone_norm` (nullable,
> backfill **marcado**, sem descarte) — pergunta em aberto nº 10. No MVP, o dedupe
> pode ser feito na camada de modelo.

## Endpoints da API

**Gestão (Bearer, `gestor#_require_gestor` + posse do `cod_inep`):**

| Método | Rota | Função |
|---|---|---|
| GET | `/api/gestor/:cod_inep/canais/listas` | listar listas |
| POST | `/api/gestor/:cod_inep/canais/listas` | criar lista nomeada |
| GET | `/api/gestor/:cod_inep/canais/listas/:id` | detalhe + contagem |
| DELETE | `/api/gestor/:cod_inep/canais/listas/:id` | excluir/desativar lista |
| POST | `/api/gestor/:cod_inep/canais/listas/:id/qrcode` | gerar/rotacionar QR → `{token,url,expira_em}` |
| DELETE | `/api/gestor/:cod_inep/canais/listas/:id/qrcode` | revogar QR |
| GET | `/api/gestor/:cod_inep/canais/listas/:id/inscricoes` | contatos inscritos |

**Público (sem auth, `Plugin::API::Canais`):**

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/canais/inscricao/:token` | — | `200 {lista_nome, escola_nome, canal, campos, expira_em}` · `404/410` |
| POST | `/api/canais/inscricao/:token` | `{nome, telefone, consentimento:true, _hp?}` | `201 {ok:1, duplicado?}` · `400` · `410` · `429` |

Erros **genéricos** para token inválido/expirado (não revelar existência).

## Fluxo do QR code

1. Gestor: `POST .../listas/:id/qrcode` → backend cria `canal_qrcodes` (UUID) e
   devolve `url = $PUBLIC_BASE_URL/inscricao/<token>`.
2. Frontend autenticado **gera a imagem do QR no navegador** (lib leve) a partir
   da `url`; exibe "copiar link", estado (ativo/revogado), usos e expiração.
3. Inscrito escaneia → abre a rota pública do SPA `/inscricao/<token>`.
4. SPA faz `GET /api/canais/inscricao/:token` → renderiza form (nome, telefone,
   consentimento).
5. `POST` → backend: valida token, rate limit, campos, consentimento → normaliza
   telefone → dedupe **não destrutivo** (cria contato **ou** reusa o existente,
   `ON CONFLICT DO NOTHING` no membro, marca `duplicado_de`/`conflito`) → grava
   `canal_inscricoes` → incrementa `usos` → `201`.
6. Gestor recarrega a lista → vê o **membro** (nome, telefone, quando,
   `validado`/`conflito`).

## Telas/UX mínimas

- **Gestão (Svelte):** na `ContatosPage` (ou seção "Listas e QR"), por lista:
  botão **Gerar QR** → `QRModal.svelte` (QR renderizado, link copiável, revogar,
  usos, expiração) e uma tabela **Inscrições** (nome, telefone, quando). Mobile
  também funciona para o gestor.
- **Pública `InscricaoPublicaPage.svelte`:** formulário mobile-first com nome,
  telefone (teclado numérico), checkbox de consentimento com texto e link da
  política; estados: carregando, sucesso, **já cadastrado**, **expirado/indisponível**,
  erro de rede. `noindex`.
- **Roteamento:** rota pública `/inscricao/:token` **fora** do guard de auth, em
  `routes.js`.

## Validações

- **Backend (autoridade):** token (formato UUID + existência + status + expiração
  + `max_usos`); `nome` (1..120, trim); `telefone` (mínimo de dígitos para ser
  útil, **sem validação de formato** no MVP); `consentimento` obrigatório;
  normalização de telefone; rate limit.
- **Frontend:** espelha o backend (obrigatórios, máscara opcional), mas nunca é a
  única barreira.
- Mensagens de erro claras para o usuário; erros de token genéricos.

## Autenticação / Autorização

- **Gestão:** Bearer token do gestor (`_require_gestor`) + verificação de que o
  `cod_inep` da rota é o do gestor (`_gestor_inep_ok`). Sem isso → `401/403`.
- **Público:** autorização **por token** (o token é a capability). Sem sessão.
  O token concede apenas: ler metadados de exibição e **inserir** contato — nunca
  listar contatos.
- **Rate limit** e **revogação** como controles centrais do endpoint público.

## Testes

- **Backend (`yath -l`):**
  - `t/02-models/`: modelo de lista/QR/membros (token gen/rotaciona/revoga,
    expiração, `max_usos`, normalização bruto+norm, dedupe **não destrutivo**,
    marcação `validado`/`conflito`).
  - `t/04-api/canais/`: auth+posse (401/403), CRUD de lista, geração/revogação de
    QR, `GET`/`POST` públicos (200/201/400/404/410/429), dedupe **não destrutivo**
    (sem novo contato/membro; `duplicado_de`/`conflito`), consentimento, resposta sem PII.
  - Migrations: `verify` gate obrigatório.
- **Frontend (`vitest`):** `InscricaoPublicaPage` (estados), `QRModal`
  (renderiza/usos/revoga), fluxo de criação de lista.
- **e2e (Chrome/CDP):** criar lista → gerar QR → abrir URL pública em nova aba →
  preencher → verificar contato na lista (scan de câmera é manual/fora do e2e;
  testa-se pelo link).
- **Carga/abuso:** teste de rate limit e de `max_usos`.

## Estratégia de rollout

1. **Feature flag** por config (`canais.inscricao.enabled`) — desligada por
   default; rota pública responde `404` se desligada.
2. Deploy: migrations (`deploy_db_dev`) → backend (`deploy_backend_dev`) →
   frontend (`deploy_frontend_dev`); reconstruir imagens locais `sqitch`,
   `backend`, `minion`, `frontend`.
3. Habilitar primeiro em **um** `cod_inep` piloto (lista interna), medir abuso e
   conversão; depois abrir.
4. Observabilidade: contadores de inscrição/recusa por token; alerta de pico de
   abuso.
5. Rollback: desligar a flag + revogar tokens (sem migration reversa necessária).

## Backlog em fases

**Fase 0 — MVP (telefone, sem validação)** *(esta issue)*
- Migrations `canal_listas`/`canal_qrcodes`/`canal_lista_membros`/`canal_inscricoes`.
- Model/roles + endpoints de gestão e públicos (unificados).
- Dedupe não destrutivo + normalização + consentimento + rate limit básico + honeypot.
- `InscricaoPublicaPage` + `QRModal` + visão de membros.
- Testes API/vitest/e2e + migration verify.

**Fase 1 — Confirmação de posse (WhatsApp/Telegram)**
- Canal configurável na lista; reusa `Channel::Confirmation` (código já
  hash+salt, TTL).
- UX de confirmação no formulário; estado "pendente/confirmado".

**Fase 2 — E-mail + políticas & LGPD**
- Canal e-mail (reusa `Channel::Email`).
- Expiração/`max_usos` configuráveis na UI; retenção/expurgo; exclusão a pedido;
  texto de consentimento versionado e auditável.

**Fase 3 — Listas em massa e escala**
- `Channel::List::*` (envio em fila para a lista, dedupe, opt-out).
- Múltiplos QR/segmentação; analytics de conversão; listas dinâmicas.

## Decisões tomadas (confirmadas com o developer)

- **API unificada** `/api/canais/inscricao/:token` (canal como atributo) — atende
  à preferência do requisito e evita duplicação.
- **Lista própria** (`clean.canal_listas`) — **sem** vínculo a `contato_grupo`
  (será deprecado). O pertencimento é da lista (`canal_lista_membros`).
- **Contato materializado** em `clean.contatos` + **membro** na lista +
  proveniência em `canal_inscricoes` — o gestor vê na visão da lista.
- **Token UUID v4**, revogável; expiração **desligada por default** no MVP, mas
  coluna pronta.
- **Dedupe não destrutivo** (modelo sensível): bruto+normalizado, reusa contato,
  marca `duplicado_de`/`conflito`/`validado`, **sem descarte**.
- **Consentimento obrigatório**, IP anonimizado, resposta pública mínima.
