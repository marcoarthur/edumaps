# Especificação de Requisitos — Envio por e-mail para listas com QR (Fase 3)

**Data:** 2026-10-12
**Autor:** Tech Lead / Product Engineer (agente) com o developer
**Versão:** 1.0
**Issue relacionado:** #216
**Depende de:** listas com QR (#208, PR #209), confirmação de posse (#212,
PR #213) e e-mail + LGPD (#214, PR #215)
**Specs anteriores:** [Fase 0](./2026-10-11-listas-qr-autoinscricao-contatos.md) ·
[Fase 1](./2026-10-11-confirmacao-posse-listas-qr.md) ·
[Fase 2](./2026-10-12-email-lgpd-listas-qr.md). Esta spec **estende** os
contratos delas sem quebrá-los.

---

# ENTREGÁVEL 1 — ISSUE

## Título

**Envio por e-mail para listas com QR: envio em massa com opt-out, listas dinâmicas e funil de conversão (Fase 3)**

## Contexto

As listas com QR já coletam telefone e/ou e-mail com consentimento versionado
(Fase 2), confirmam a posse (Fases 1 e 2) e respeitam exclusão e retenção
(LGPD). O núcleo de Canais envia **uma** mensagem por vez
(`Channel::Base->send_message`), grava cada envio em `clean.canal_mensagens` e
já tem SMTP configurável (`canais.email.*`). Falta o motivo de existir das
listas: **a escola falar com quem se inscreveu**. Hoje o gestor não tem como
mandar nada à lista, não sabe quantas pessoas leem o QR e quantas concluem a
inscrição, e não tem como recortar um público (ex.: "confirmados das listas A
e B").

## Problema

1. O gestor coleta contatos mas não consegue usá-los: não há envio para a
   lista.
2. Sem envio controlado (fila, ritmo, cota), um envio grande travaria o
   servidor ou queimaria a reputação do remetente SMTP.
3. Quem recebe não tem como deixar de receber sem apagar os próprios dados
   (a exclusão da Fase 2 é tudo ou nada).
4. O gestor não sabe se o QR funciona: não vê acessos, inscrições e
   confirmações ao longo do tempo, nem o resultado de cada envio.

## Objetivo

- O gestor escreve um e-mail (assunto + corpo em markdown simples + operação),
  vê a prévia, manda um teste para si e **envia para uma lista ou lista
  dinâmica**, na hora ou agendado.
- O envio sai **em fila** (Minion), com **dedupe por endereço**, ritmo por
  minuto e **cota diária por escola** definidos pela administração, que também
  pode **suspender** o envio de uma escola.
- Cada e-mail traz um **link para sair da lista**; quem sai deixa de receber
  daquela lista e o gestor vê quem saiu.
- **Listas dinâmicas**: regra salva sobre os membros das listas da própria
  escola, resolvida na hora do envio, com prévia da contagem.
- **Funil por lista** (acessos ao QR → inscrições → confirmações, por período) e
  **resultado por envio** (destinatários, enviados, falhas, ignorados, saídas),
  **sem** pixel de abertura nem rastreio de clique.

## Escopo (Fase 3)

1. Envio em massa por e-mail para lista ou lista dinâmica (fila, dedupe,
   agendamento, cancelamento, envio de teste).
2. Opt-out por lista via link em cada e-mail (e cabeçalho `List-Unsubscribe`).
3. Limites e controle da administração (ritmo, cota diária, teto por envio,
   suspensão por escola).
4. Listas dinâmicas (regras sobre membros das listas da escola).
5. Funil de conversão por lista e resultado por envio.

## Fora de escopo (Fase 3)

- **WhatsApp e Telegram** no envio em massa (decisão: só e-mail nesta fase).
  WhatsApp exige template aprovado e é cobrado; Telegram fica para depois.
- **Vários QR por lista** e segmentação por origem do QR (não escolhido).
- **Modelos reutilizáveis** e variáveis no texto (ex.: `{nome}`).
- **Rastreio de abertura e clique** (decisão: privacidade).
- Listas dinâmicas sobre a **agenda inteira** (contatos cadastrados à mão, fora
  das listas): só membros de listas, que deram consentimento pelo QR.
- Corpo em HTML: o e-mail sai em `text/plain` (markdown simples é legível).
- Provedores de e-mail por API (SES, SendGrid): segue SMTP.

## Requisitos Funcionais

### RF-301: Compor e enviar um e-mail para lista ou lista dinâmica — Essencial
**Ator:** gestor autenticado.
**Descrição:** O sistema deve permitir que o gestor componha um e-mail
(assunto, corpo em markdown simples, operação) para uma lista ou lista
dinâmica da escola e o envie na hora ou numa data agendada.
**Aceite:**
- [ ] Criar envio como **rascunho** com `alvo` (`lista` ou `segmento` + id),
      `operacao` (de `Channel::Operacoes`, exceto `confirmacao`), `assunto`
      (1..200) e `corpo` (1..20000); editar enquanto rascunho.
- [ ] **Prévia** devolve o texto final (com o rodapé) e a **contagem estimada**
      de destinatários (após dedupe e opt-out).
- [ ] **Teste**: envia uma cópia ao e-mail do próprio gestor (não conta na
      cota, marcado como teste no histórico).
- [ ] **Disparar** agora ou com `agendado_para` (futuro, até 90 dias);
      `409` sem SMTP ativo, escola suspensa, cota insuficiente ou envio fora de
      rascunho.
- [ ] Os destinatários são **fixados no disparo** (fotografia): quem entrar na
      lista depois não recebe esse envio.
- [ ] **Cancelar** enquanto `agendado` ou `enviando`: quem ainda não recebeu
      fica `cancelado`.
- [ ] Recebem os membros **com e-mail**, **confirmados e pendentes** (decisão),
      menos os anonimizados e os que saíram da lista.

### RF-302: Envio em fila com ritmo e dedupe — Essencial
**Ator:** sistema.
**Descrição:** O sistema deve entregar o envio em lotes por um job Minion,
respeitando o ritmo por minuto, sem repetir endereço e sem nunca derrubar a
aplicação por falha de SMTP.
**Aceite:**
- [ ] **Dedupe** por e-mail normalizado dentro do envio (o mesmo endereço em
      duas listas do segmento recebe uma vez; os demais ficam
      `ignorado_duplicado`).
- [ ] Job `canais_envio` processa lotes conforme `ritmo_por_minuto`,
      reagenda-se até terminar, confere cancelamento/suspensão a cada lote e é
      **idempotente** (reprocessar não reenvia `enviado`).
- [ ] Cada e-mail passa por `Channel::Email->send_message` (histórico em
      `canal_mensagens` com `referente_tipo='envio'`); falha vira `falhou` com
      o erro, sem nova tentativa automática nesta fase.
- [ ] Contadores do envio atualizados ao longo do processamento; estado final
      `concluido` (mesmo com falhas parciais).
- [ ] Agendamento sobrevive a restart do worker (o job é enfileirado com
      `delay` e o estado vive no banco).

### RF-303: Opt-out por lista — Essencial
**Ator:** destinatário (não autenticado); gestor.
**Descrição:** Cada e-mail deve trazer um link pessoal para deixar de receber
mensagens **daquela lista**, sem apagar os dados.
**Aceite:**
- [ ] Token de saída por destinatário (128 bits, só hash no banco), no rodapé
      e no cabeçalho `List-Unsubscribe` (+ `List-Unsubscribe-Post`, RFC 8058).
- [ ] `GET /api/canais/sair/:token` → `200 {escola_nome, lista_nome}` (sem
      PII); `POST {confirmar:true}` → `200 {ok:1}`, idempotente; `404`
      genérico. O `POST` de um clique (RFC 8058, corpo
      `List-Unsubscribe=One-Click`) também é aceito.
- [ ] Página pública `/privacidade/sair/:token` com confirmação e link para a
      exclusão completa (Fase 2).
- [ ] O opt-out é guardado **por lista e por hash do e-mail** (sobrevive a
      anonimização, sem PII); envios futuros daquela lista (inclusive via lista
      dinâmica que a inclua) pulam o endereço como `ignorado_optout`.
- [ ] Quem **se reinscreve** na mesma lista pelo QR desfaz o opt-out (novo
      consentimento explícito).
- [ ] O gestor vê, por membro, o selo **"Saiu dos envios"** e a contagem de
      saídas da lista; não pode desfazer o opt-out.

### RF-304: Limites e controle da administração — Essencial
**Ator:** administrador da instalação.
**Descrição:** O sistema deve limitar o volume de envio e permitir suspender
uma escola.
**Aceite:**
- [ ] Config `canais.envio.*`: `enabled` (default `true`; sem SMTP não envia),
      `ritmo_por_minuto` (60), `cota_diaria_escola` (500 e-mails/dia),
      `max_destinatarios` (2000 por envio).
- [ ] Cota diária conta e-mails **efetivamente enviados** pela escola no dia
      (America/Sao_Paulo); disparo acima do saldo → `409` com o saldo; um
      envio que atinge a cota durante o processamento pausa e retoma no dia
      seguinte (`pausado_cota`).
- [ ] Admin vê o volume por escola (hoje, 30 dias), **suspende** (com motivo)
      e reativa uma escola; suspensão pausa os envios em curso e bloqueia novos.
- [ ] Tudo auditado (quem, quando, motivo).

### RF-305: Listas dinâmicas — Importante
**Ator:** gestor.
**Descrição:** O sistema deve permitir salvar uma regra sobre os membros das
listas da escola e usá-la como alvo de envio.
**Aceite:**
- [ ] Regra (`criterios`): `listas` (1..N listas da escola, união), `estado`
      (subconjunto de `pendente`/`parcial`/`confirmado`, vazio = todos),
      `email_confirmado` (opcional), `inscritos_desde`/`inscritos_ate`
      (opcional).
- [ ] CRUD de listas dinâmicas por escola, nome único; listas referidas que
      foram excluídas são ignoradas (prévia avisa).
- [ ] `GET .../segmentos/:id/previa` → contagem e amostra mascarada (até 10
      nomes, e-mail `j***@d***.com`).
- [ ] A regra é **resolvida no disparo** (RF-301).

### RF-306: Funil de conversão por lista — Importante
**Ator:** gestor.
**Descrição:** O sistema deve mostrar, por lista e período, quantos acessaram o
QR, quantos se inscreveram e quantos confirmaram, e quantos saíram dos envios.
**Aceite:**
- [ ] Acessos contados por dia e por QR quando a página pública carrega a
      lista (`GET /api/canais/inscricao/:token` válido), **sem PII** (só
      contagem diária; nada de IP, user-agent ou cookie).
- [ ] `GET .../listas/:id/funil?de&ate` (padrão: 30 dias) → série diária e
      totais: `acessos`, `inscricoes`, `confirmados` (geral `confirmado`),
      `optouts`; taxas acesso→inscrição e inscrição→confirmação.
- [ ] Painel na ListasPage (cartões + gráfico simples por dia).

### RF-307: Resultado por envio — Importante
**Ator:** gestor.
**Descrição:** O sistema deve listar os envios da escola com o resultado de cada
um.
**Aceite:**
- [ ] Lista de envios (alvo, assunto, operação, estado, agendado/iniciado/
      concluído, autor) e contadores: `destinatarios`, `enviados`, `falhas`,
      `ignorados` (duplicado, opt-out, anonimizado), `optouts` (saídas geradas
      por aquele envio).
- [ ] Detalhe com destinatários **mascarados** e estado de cada um;
      atualização ao vivo enquanto `enviando` (polling).
- [ ] Sem métrica de abertura/clique (decisão).

## Requisitos Não Funcionais

- **RNF-301 (Entregabilidade):** ritmo e cota configuráveis; cabeçalhos
  `List-Unsubscribe` + `List-Unsubscribe-Post`; `Precedence: bulk`; remetente
  da config; nunca anexos.
- **RNF-302 (LGPD):** envio só para quem consentiu pela lista; opt-out sem PII
  (hash); a anonimização da Fase 2 passa a cobrir as tabelas novas
  (destinatários de envio); acessos agregados sem dado pessoal; sem rastreio.
- **RNF-303 (Robustez):** falha de SMTP nunca derruba o job nem a API;
  reprocessamento idempotente; um envio grande não bloqueia o worker para os
  demais jobs (lotes curtos + reagendamento).
- **RNF-304 (Segurança):** token de saída de 128 bits, só hash, sem enumeração;
  rate limit nos endpoints públicos novos; gestor só vê e envia para listas da
  própria escola (`403/404`).
- **RNF-305 (Compatibilidade):** contratos das Fases 0–2 preservados (campos só
  acrescentados); migrations novas, nenhuma change deployada editada.

## Critérios de Aceite (visão do usuário)

- [ ] O gestor escreve "Reunião de pais na sexta", vê a prévia com o rodapé,
      recebe o teste no próprio e-mail e envia para "Responsáveis 8º".
- [ ] O envio aparece como **Enviando** e depois **Concluído** com
      "42 enviados · 1 falha · 3 ignorados".
- [ ] Uma mãe clica em "Não quero mais receber desta lista"; no próximo envio
      ela é pulada, e o gestor vê o selo "Saiu dos envios".
- [ ] O gestor cria a lista dinâmica "Confirmados 8º e 9º" (duas listas, só
      confirmados), vê "37 destinatários" na prévia e agenda o envio para
      amanhã 8h.
- [ ] O admin suspende a escola; o envio agendado não sai e o gestor vê o
      motivo.
- [ ] O gestor abre o funil de "Responsáveis 8º": 120 acessos → 48 inscrições →
      40 confirmados nos últimos 30 dias.

## Riscos

| # | Risco | Impacto | Mitigação |
|---|-------|---------|-----------|
| R1 | Envio para e-mail pendente (não confirmado) de outra pessoa | Médio | decisão do developer; link de saída e de exclusão em todo e-mail; filtro "só confirmados" na lista dinâmica |
| R2 | Reputação do remetente (spam, bloqueio do SMTP) | Alto | ritmo + cota + teto; `List-Unsubscribe` one-click; suspensão pelo admin |
| R3 | Envio duplicado por reprocessamento do job | Médio | estado por destinatário + `UNIQUE (envio_id, email_hash)`; só `pendente` é processado |
| R4 | Envio grande trava o worker | Médio | lotes curtos e reagendamento; ritmo por minuto |
| R5 | PII nas tabelas novas escapa da anonimização | Alto | inventário de PII atualizado; teste de varredura da Fase 2 estendido |
| R6 | SMTP de dev indisponível | Baixo | transporte SMTP injetável nos testes; e2e com transporte simulado |
| R7 | Opt-out perdido quando a pessoa é anonimizada | Médio | opt-out por hash do e-mail, independente do contato |

## Dependências

- Fases 0–2 (`canal_*`, `Canal::Listas/Confirmacao/Exclusao`, consentimento).
- `Channel::Email` (SMTP, transporte injetável), `Channel::History`,
  `Channel::Operacoes`.
- Minion (padrão autorreagendável de `telegram_polling` e `canais_retencao`).
- Painel de Configuração/Admin (limites, volume, suspensão).

## Métricas de sucesso

- Nº de envios por escola/semana; % entregues ao SMTP sem falha.
- Taxa de opt-out por envio (alerta acima de 2%).
- Taxas acesso→inscrição e inscrição→confirmação por lista.
- Zero envio duplicado por destinatário (teste + consulta).

## Decisões já tomadas (com o developer, 2026-10-12)

1. **Escopo**: envio em massa + opt-out, analytics de conversão, listas
   dinâmicas. **Fora**: vários QR por lista.
2. **Destinatários**: membros **confirmados e pendentes**.
3. **Canal**: **só e-mail**.
4. **Controle**: envio direto pelo gestor, **com limites** da administração
   (ritmo, cota diária, suspensão).
5. **Opt-out**: **por lista**, por link em cada e-mail; exclusão LGPD segue
   separada.
6. **Lista dinâmica**: **filtro sobre membros** das listas da escola, resolvido
   no envio, com prévia.
7. **Conteúdo**: texto (markdown simples) + operação, prévia, teste para o
   gestor, envio imediato ou **agendado**, cancelável.
8. **Analytics**: funil por lista + resultado por envio, **sem rastreio** de
   abertura/clique.

## Perguntas em aberto

1. Reinscrição desfaz o opt-out (proposto: sim, é novo consentimento) — ok?
2. Falhas de SMTP: nova tentativa automática (com backoff) fica para depois?
   Proposto: nesta fase, só `falhou` + reenvio manual das falhas (botão
   "Reenviar falhas") se o tempo permitir.
3. Os textos de envio devem passar a ser citados no consentimento ("a escola
   pode enviar avisos por e-mail")? Proposto: sugerir ao developer uma
   versão 1.2 do texto, sem bloquear a fase.

---

# ENTREGÁVEL 2 — PLANO DE IMPLEMENTAÇÃO

## Inventário de PII (extensão do da Fase 2)

| Tabela | Colunas com PII | Na exclusão (RF-206) |
|---|---|---|
| `clean.canal_envio_destinatarios` | `email` (normalizado, para o job) | `email` → `NULL`; `contato_id` → `NULL`; pendentes → `ignorado_anonimizado` |
| `clean.canal_optouts` | — (só `email_hash`) | mantém (é a vontade da pessoa, sem PII) |
| `clean.canal_qr_acessos` | — (contagem diária) | — |
| `clean.canal_envios` | — (texto da escola, não do titular) | — |

O `email` cru no destinatário existe só enquanto o envio não terminou: ao
concluir/cancelar, o job zera `email` dos destinatários finalizados (fica o
hash). Assim a retenção não precisa de regra nova.

## Modelo de dados

Change nova `canal_envios [canal_email_lgpd]`, anexada ao fim do plano.

```sql
CREATE TABLE clean.canal_segmentos (           -- listas dinâmicas
  id         bigserial PRIMARY KEY,
  cod_inep   bigint NOT NULL,
  gestor_id  bigint NOT NULL REFERENCES clean.gestores (id) ON DELETE CASCADE,
  nome       text   NOT NULL,
  criterios  jsonb  NOT NULL,     -- {listas:[ids], estado:[...], email_confirmado, inscritos_desde, inscritos_ate}
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (cod_inep, nome)
);

CREATE TABLE clean.canal_envios (
  id            bigserial PRIMARY KEY,
  cod_inep      bigint NOT NULL,
  gestor_id     bigint REFERENCES clean.gestores (id) ON DELETE SET NULL,
  alvo_tipo     text   NOT NULL CHECK (alvo_tipo IN ('lista','segmento')),
  alvo_id       bigint NOT NULL,
  alvo_nome     text   NOT NULL,           -- fotografia do nome no disparo
  canal         text   NOT NULL DEFAULT 'email' CHECK (canal IN ('email')),
  operacao      text   NOT NULL CHECK (operacao IN ('aviso','informacao','pedido','convite','lembrete','alerta')),
  assunto       text   NOT NULL,
  corpo         text   NOT NULL,
  status        text   NOT NULL DEFAULT 'rascunho'
    CHECK (status IN ('rascunho','agendado','enviando','pausado_cota','suspenso','concluido','cancelado')),
  agendado_para timestamptz,
  iniciado_em   timestamptz,
  concluido_em  timestamptz,
  cancelado_em  timestamptz,
  destinatarios integer NOT NULL DEFAULT 0,
  enviados      integer NOT NULL DEFAULT 0,
  falhas        integer NOT NULL DEFAULT 0,
  ignorados     integer NOT NULL DEFAULT 0,
  minion_job_id bigint,
  created_at    timestamptz NOT NULL DEFAULT NOW(),
  updated_at    timestamptz NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_canal_envios_escola ON clean.canal_envios (cod_inep, created_at DESC);

CREATE TABLE clean.canal_envio_destinatarios (
  id           bigserial PRIMARY KEY,
  envio_id     bigint NOT NULL REFERENCES clean.canal_envios (id) ON DELETE CASCADE,
  contato_id   bigint REFERENCES clean.contatos (id) ON DELETE SET NULL,
  lista_id     bigint REFERENCES clean.canal_listas (id) ON DELETE SET NULL, -- lista de origem (opt-out)
  email        text,                       -- cru só enquanto pendente
  email_hash   text   NOT NULL,            -- sha256(email_norm)
  saida_hash   text   UNIQUE,              -- sha256 do token de saída
  status       text   NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('pendente','enviado','falhou','cancelado',
                      'ignorado_duplicado','ignorado_optout','ignorado_anonimizado')),
  erro         text,
  mensagem_id  bigint REFERENCES clean.canal_mensagens (id) ON DELETE SET NULL,
  processado_em timestamptz,
  UNIQUE (envio_id, email_hash)
);
CREATE INDEX idx_canal_envio_dest_pend ON clean.canal_envio_destinatarios (envio_id) WHERE status = 'pendente';

CREATE TABLE clean.canal_optouts (             -- sem PII
  id          bigserial PRIMARY KEY,
  lista_id    bigint NOT NULL REFERENCES clean.canal_listas (id) ON DELETE CASCADE,
  canal       text   NOT NULL DEFAULT 'email' CHECK (canal IN ('email')),
  email_hash  text   NOT NULL,
  envio_id    bigint REFERENCES clean.canal_envios (id) ON DELETE SET NULL,  -- envio que gerou a saída
  created_at  timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (lista_id, canal, email_hash)
);

CREATE TABLE clean.canal_qr_acessos (          -- funil, agregado diário, sem PII
  qrcode_id bigint NOT NULL REFERENCES clean.canal_qrcodes (id) ON DELETE CASCADE,
  dia       date   NOT NULL,
  acessos   integer NOT NULL DEFAULT 0,
  PRIMARY KEY (qrcode_id, dia)
);

CREATE TABLE clean.canal_envio_suspensoes (    -- controle da administração
  id          bigserial PRIMARY KEY,
  cod_inep    bigint NOT NULL,
  motivo      text   NOT NULL,
  suspenso_por bigint REFERENCES clean.gestores (id) ON DELETE SET NULL,
  suspenso_em timestamptz NOT NULL DEFAULT NOW(),
  reativado_por bigint REFERENCES clean.gestores (id) ON DELETE SET NULL,
  reativado_em timestamptz
);
CREATE UNIQUE INDEX uq_canal_envio_suspensao_ativa
  ON clean.canal_envio_suspensoes (cod_inep) WHERE reativado_em IS NULL;
```

Hash de e-mail: `sha256(email_norm)` hex calculado no banco (pgcrypto, como o
`consentimento_hash`). `canal_mensagens.referente_tipo='envio'`,
`referente_id=envio_id`. Cota diária: `count(*)` de destinatários `enviado`
da escola com `processado_em` no dia local (índice em `processado_em`).

## Endpoints da API

**Gestão** (prefixo `/api/gestor/:cod_inep/canais`)

| Método | Rota | Função |
|---|---|---|
| GET/POST | `/envios` | listar (paginado) / criar rascunho |
| GET/PATCH/DELETE | `/envios/:id` | detalhe + contadores / editar rascunho / apagar rascunho |
| POST | `/envios/:id/previa` | texto final + contagem estimada |
| POST | `/envios/:id/teste` | e-mail de teste ao gestor (`202`) |
| POST | `/envios/:id/disparar` | `{agendado_para?}` → `202 {status}`; `409 {motivo, saldo?}` |
| POST | `/envios/:id/cancelar` | `200` |
| GET | `/envios/:id/destinatarios` | paginado, mascarado |
| GET | `/envios/limites` | ritmo, cota, saldo do dia, suspensão `{motivo}` |
| GET/POST | `/segmentos` | listar / criar |
| GET/PUT/DELETE | `/segmentos/:id` | detalhe / editar / apagar |
| POST | `/segmentos/previa` | prévia de critérios ainda não salvos |
| GET | `/segmentos/:id/previa` | contagem + amostra mascarada |
| GET | `/listas/:id/funil` | `?de&ate` → série diária + totais + taxas |
| GET | `/listas/:id/inscricoes` | + `optout` por membro; `GET /listas` + `n_optouts` |

**Público**

| Método | Rota | Função |
|---|---|---|
| GET | `/api/canais/inscricao/:token` | passa a contar o acesso (agregado diário) |
| POST | `/api/canais/inscricao/:token` | reinscrição desfaz o opt-out daquela lista |
| GET | `/api/canais/sair/:token` | `200 {escola_nome, lista_nome}` · `404` |
| POST | `/api/canais/sair/:token` | `{confirmar:true}` ou `List-Unsubscribe=One-Click` → `200 {ok:1}` |

**Admin**

| Método | Rota | Função |
|---|---|---|
| GET | `/api/admin/canais/envios` | volume por escola (hoje / 30 dias), suspensões ativas |
| POST | `/api/admin/canais/envios/suspensoes` | `{cod_inep, motivo}` → suspende |
| POST | `/api/admin/canais/envios/suspensoes/:cod_inep/reativar` | reativa |

## Fluxos

**Disparo:** valida rascunho, SMTP, suspensão → resolve o alvo (lista ou
regra) → membros com e-mail, não anonimizados → descarta opt-outs da lista de
origem → dedupe por `email_hash` → checa teto e saldo da cota → insere
destinatários (`pendente`, token de saída gerado, só o hash gravado) numa
transação → `status=agendado` (com `agendado_para`) ou `enviando` → enfileira
`canais_envio [envio_id]` com `delay`.

**Job `canais_envio`:** lock por envio (`minion->guard`) → relê status (sai se
cancelado/suspenso) → lote de até `ritmo_por_minuto` pendentes → para cada um:
monta rodapé (escola, motivo, link `/privacidade/sair/<token>`, link
`/privacidade`) → `send_message` com cabeçalhos → `enviado`/`falhou` → atualiza
contadores → se a cota do dia esgotou: `pausado_cota` + reagenda para 00:05 do
dia seguinte; se sobraram pendentes: reagenda em 60 s; senão `concluido` +
zera `email` dos finalizados. O token em claro do rodapé é derivado no lote
(HMAC do id do destinatário com segredo do app), então não precisa ser
guardado em claro; o banco guarda só o hash.

**Opt-out:** `/privacidade/sair/:token` → hash → destinatário → lista de origem
→ `INSERT canal_optouts ON CONFLICT DO NOTHING`.

**Funil:** `GET /inscricao/:token` válido → `INSERT … ON CONFLICT (qrcode_id,
dia) DO UPDATE SET acessos = acessos + 1`; o funil junta acessos (por QR da
lista), inscrições (`canal_inscricoes.created_at`), confirmados (estado geral
pelo `confirmado_em` mais recente) e opt-outs, por dia.

## Telas/UX mínimas

- **ListasPage:** ação "Enviar e-mail" por lista; selo "Saiu dos envios" e
  contador de saídas; aba **Funil** (cartões + barras por dia, filtro de
  período).
- **EnviosPage (`/gestor/envios`):** lista de envios com estado e contadores;
  botão "Novo envio".
- **Editor de envio:** alvo (lista ou lista dinâmica), operação, assunto,
  corpo (markdown simples, prévia com `TextoMarkdown`), "Enviar teste para
  mim", "Enviar agora" / "Agendar", saldo da cota e aviso de suspensão;
  confirmação com a contagem de destinatários.
- **Detalhe do envio:** contadores ao vivo, destinatários mascarados, cancelar.
- **Listas dinâmicas (`/gestor/segmentos`):** CRUD com seletor de listas,
  estados, filtros de data e prévia (contagem + amostra).
- **SairPage (`/privacidade/sair/:token`):** escola e lista, confirmar, link
  para remover todos os dados.
- **Admin:** limites em `canais.envio.*` no `/config`; painel de volume por
  escola com suspender/reativar.

## Testes

- `t/02-models/canal_envio.t`: resolução de alvo (lista e segmento), dedupe,
  opt-out, anonimizados, teto, cota (incl. virada de dia), fotografia no
  disparo, cancelamento, idempotência do job (rodar duas vezes não reenvia),
  pausa por cota e retomada, suspensão, limpeza do `email` ao concluir.
- `t/02-models/canal_segmentos.t`: critérios, listas excluídas, prévia
  mascarada, isolamento por escola.
- `t/02-models/canal_optout.t` e extensão de `canal_exclusao.t`: opt-out por
  hash, reinscrição desfaz, varredura de PII cobrindo as tabelas novas.
- `t/02-models/canal_funil.t`: contagem de acessos, séries por dia, taxas.
- `t/04-api/canais/`: sair (GET/POST/One-Click/404/idempotente), contagem de
  acesso na inscrição; `t/04-api/gestor`: envios (CRUD, prévia, teste, disparo
  409s, cancelar, destinatários mascarados), segmentos, funil, isolamento
  `403/404`; `t/04-api/admin`: volume, suspender/reativar.
- Frontend (`vitest`): editor (validação, prévia, teste, agendar), lista e
  detalhe de envios (polling), segmentos com prévia, funil, `SairPage`,
  painel admin.
- E2E (CDP): lista com 3 inscritos (1 duplicado em outra lista, 1 opt-out) →
  segmento → envio com transporte SMTP simulado no dev → contadores → link de
  saída no navegador → próximo envio pula → funil mostra acessos/inscrições.

## Estratégia de rollout

1. Migration só cria tabelas: nada muda para listas e inscrições existentes.
2. `canais.envio.enabled=true`, mas sem SMTP ativo o disparo responde `409`;
   em dev, usar SMTP de captura (ex.: Mailpit no compose) ou o transporte
   simulado para o e2e — a definir na onda 3.
3. Deploy: `deploy_db_dev` → `deploy_backend_dev` + `deploy_minion_dev` →
   `deploy_frontend_dev` (com `EDUMAPS_CONFIG_MASTER_KEY` exportada); imagens
   locais `sqitch`, `backend`, `minion`, `frontend`.
4. Rollback: `canais.envio.enabled=false` (bloqueia disparo e pausa o job);
   suspensão por escola como freio fino.

## Execução sugerida (ondas)

| Onda | Trilha | Itens |
|---|---|---|
| 1 | db/backend | migration; segmentos (CRUD + prévia); envios (rascunho, prévia, teste, disparo, cancelar); job `canais_envio` com dedupe, ritmo, cota |
| 1 | frontend | EnviosPage + editor + detalhe; ação "Enviar e-mail" na ListasPage; segmentos |
| 2 | backend | opt-out (token, página pública, One-Click, reinscrição); funil (acessos + endpoint); admin (limites, volume, suspensão); extensão da anonimização |
| 2 | frontend | `SairPage`; selo e contador de saídas; aba Funil; painel admin de envios |
| 3 | coord. | integração, e2e, docs funcionais, deploy, PR |

O registro mutável fica em `2026-10-12-envio-email-listas-qr.execucao.md`,
criado no início da execução.
