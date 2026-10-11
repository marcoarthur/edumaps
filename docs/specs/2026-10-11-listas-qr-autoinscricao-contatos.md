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
criando o contato em `clean.contatos` (vinculado ao grupo correspondente) e
registrando a proveniência.
**Aceite:**
- [ ] `POST /api/canais/inscricao/:token` com `{ nome, telefone, consentimento:true }` → `201 { ok:1 }`.
- [ ] `nome` e `telefone` obrigatórios; sem eles → `400`.
- [ ] Contato aparece na agenda e na visão da lista do gestor.
- [ ] `consentimento` deve ser verdadeiro no MVP → senão `400`.

### RF-005: Duplicidade — Essencial
**Ator:** sistema.
**Descrição:** O sistema deve evitar duplicar contatos por telefone dentro da
mesma escola.
**Aceite:**
- [ ] Mesmo telefone já inscrito na mesma lista → resposta **idempotente** (`200`/`201` sem duplicar).
- [ ] Telefone existente em outra lista/grupo → associação à nova lista sem criar contato duplicado.
- [ ] Normalização de telefone aplicada antes da comparação.

### RF-006: Visualizar contatos da lista — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve listar os contatos inscritos por QR numa lista.
**Aceite:**
- [ ] `GET /api/gestor/:cod_inep/canais/listas/:id/inscricoes` retorna contatos (nome, telefone, quando), só da escola do gestor.
- [ ] Contagem de inscrições aparece no detalhe da lista.
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
- **RNF-006 (Compatibilidade):** reusa `clean.contatos`/`contato_grupos` sem
  quebrar a agenda existente; migrations Sqitch com `verify` no estilo gate.

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
| R4 | Telefones duplicados/compartilhados | Médio | normalização + dedupe por escola (decidir política de telefones compartilhados) |
| R5 | QR vazado/circula além do público | Médio | revogação, expiração opcional, `max_usos` |
| R6 | Rota pública no SPA (crawlers/deep-link) | Baixo | rota fora do guard de auth; noindex |
| R7 | Dependência nova de geração de QR | Baixo | lib client-side leve; fallback backend SVG |
| R8 | Enumeração de listas/escolas por token | Médio | token aleatório 128-bit; mensagens de erro genéricas |

## Dependências

- Núcleo de Canais (`EduMaps::Channel`, PR #207) — para as fases de confirmação.
- Agenda existente: `clean.contatos`, `clean.contato_grupos` (migration `gestor_reunioes`).
- Auth do gestor (`gestor#_require_gestor`) e checagem de posse do `cod_inep`.
- Precedente de link público: `Pesquisa#publica_form`/`publica_resposta`.
- Frontend Svelte 5 + roteador; lib de QR (nova).

## Métricas de sucesso

- Nº de listas criadas e nº de QRs ativos.
- Nº de inscrições via QR por semana e **taxa de conclusão** do formulário.
- Tempo médio para o gestor captar N contatos (antes/depois).
- % de duplicatas bloqueadas (qualidade dos dados).
- Taxa de abuso (inscrições recusadas por rate limit/honeypot).

## Perguntas em aberto (decidir antes/durante o MVP)

1. **Lista = grupo existente?** Reutilizar `clean.contato_grupos` como "lista
   nomeada" ou criar `clean.canal_listas` própria (com vínculo opcional a grupo)?
2. **Normalização de telefone:** regra (só dígitos? DDD obrigatório? `+55`?) e se
   telefone sem DDD é aceito.
3. **Telefones compartilhados:** como deduplicar quando um número representa mais
   de uma pessoa (ex.: telefone da família)?
4. **Expiração default:** sem expiração, TTL fixo (ex.: 30 dias) ou configurável?
   Limite de usos por QR?
5. **Consentimento/LGPD:** texto do consentimento, versão, e o que fazer com quem
   não consente (bloquear? registrar anonimamente?).
6. **IP/User-Agent:** guardar anonimizado para antiabuso, com que retenção?
7. **Domínio/base URL** pública (HTTPS) e formato da URL do QR.
8. **Múltiplos QR por lista / rotação** — um ativo por vez ou histórico?
9. **Cascata:** ao excluir a lista, os contatos inscritos são apagados (dado que
   estão em `clean.contatos`) ou desvinculados?
10. **Rate limit:** limites concretos (por token, por IP, por janela) e se há
    CAPTCHA simplificado no MVP.

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
│    resolve token · rate limit · dedupe · cria contato              │
│  EduMaps::Channel (núcleo existente)  ← confirmação (fases futuras)│
└───────────────┬────────────────────────────────────────────────────┘
                ▼
        PostgreSQL (schema clean.*)
```

Reuso: o par público espelha `Pesquisa#publica_form`/`publica_resposta` (mesma
ideia de token em rota `under` sem auth, com `_valid_public_token`).

## Modelo de dados

Novas tabelas em `clean` (migrations Sqitch, **anexadas ao fim** do plano,
`verify` no estilo gate). A decisão "lista própria vs. reusar grupo" é a
pergunta #1; o desenho abaixo usa **lista própria com vínculo opcional a grupo**
(recomendação), porque QR/listas têm ciclo de vida (revogar, expirar, múltiplos
canais) que não pertence ao grupo.

```sql
clean.canal_listas
  id          bigserial PK
  cod_inep    bigint NOT NULL
  gestor_id   bigint NOT NULL REFERENCES clean.gestores(id) ON DELETE CASCADE
  nome        text NOT NULL
  canal       text NOT NULL DEFAULT 'telefone' CHECK (canal IN ('telefone'))  -- expandir depois
  grupo_id    bigint REFERENCES clean.contato_grupos(id) ON DELETE SET NULL   -- exibição/agenda
  ativo       boolean NOT NULL DEFAULT true
  created_at  timestamptz NOT NULL DEFAULT NOW()
  updated_at  timestamptz NOT NULL DEFAULT NOW()
  UNIQUE (cod_inep, nome)

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

clean.canal_inscricoes
  id          bigserial PK
  qrcode_id   bigint NOT NULL REFERENCES clean.canal_qrcodes(id) ON DELETE CASCADE
  lista_id    bigint NOT NULL REFERENCES clean.canal_listas(id) ON DELETE CASCADE
  contato_id  bigint REFERENCES clean.contatos(id) ON DELETE SET NULL
  nome        text NOT NULL
  telefone    text NOT NULL
  telefone_norm text NOT NULL               -- só dígitos, para dedupe
  ip_anon     text                          -- HMAC/sal, nunca IP puro
  user_agent  text
  consentimento_em timestamptz NOT NULL
  consentimento_versao text NOT NULL
  created_at  timestamptz NOT NULL DEFAULT NOW()
  UNIQUE (lista_id, telefone_norm)          -- idempotência por lista
  INDEX (lista_id), INDEX (telefone_norm)
```

Dedupe por escola usa `clean.contatos` + `telefone_norm`; o `UNIQUE(lista_id,
telefone_norm)` garante idempotência por lista mesmo sob concorrência.

> Questão: `clean.contatos` **não** tem hoje índice único por telefone. O plano
> prevê dedupe **na camada de modelo**; um índice parcial
> `UNIQUE (cod_inep, telefone_norm)` seria a opção robusta — decidir na pergunta
> #2/#3 (telefones compartilhados podem inviabilizar o índice global).

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
| POST | `/api/canais/inscricao/:token` | `{nome, telefone, consentimento:true, _hp?}` | `201 {ok:1}` · `400` · `409/200` (dedupe) · `410` · `429` |

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
   telefone → dedupe → cria/atualiza `clean.contatos` (com `grupo_id` da lista) →
   grava `canal_inscricoes` → incrementa `usos` → `201`.
6. Gestor recarrega a lista → vê o contato (nome, telefone, data).

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
  - `t/02-models/`: modelo de lista/QR (token gen/rotaciona/revoga, expiração,
    `max_usos`, normalização, dedupe idempotente).
  - `t/04-api/canais/`: auth+posse (401/403), CRUD de lista, geração/revogação de
    QR, `GET`/`POST` públicos (200/201/400/404/410/429), dedupe (409/200),
    consentimento, resposta sem PII.
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
- Migrations `canal_listas`/`canal_qrcodes`/`canal_inscricoes`.
- Model/roles + endpoints de gestão e públicos (unificados).
- Dedupe + normalização + consentimento + rate limit básico + honeypot.
- `InscricaoPublicaPage` + `QRModal` + visão de inscrições.
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

## Decisões recomendadas (a confirmar)

- **API unificada** `/api/canais/inscricao/:token` (canal como atributo) — atende
  a preferência do requisito e evita duplicação.
- **Lista própria** (`canal_listas`) com vínculo opcional a `contato_grupo`.
- **Contato materializado** em `clean.contatos` (+ proveniência em
  `canal_inscricoes`) — o gestor vê na agenda existente.
- **Token UUID v4**, revogável; expiração **desligada por default** no MVP, mas
  coluna pronta.
- **Dedupe** por telefone normalizado por escola, idempotente por lista.
- **Consentimento obrigatório**, IP anonimizado, resposta pública mínima.
