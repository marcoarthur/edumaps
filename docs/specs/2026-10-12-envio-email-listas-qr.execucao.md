# Execução — Envio por e-mail para listas com QR (#216, Fase 3)

> **Documento de execução** (contratos por onda, WBS, log), companheiro da spec
> [`2026-10-12-envio-email-listas-qr.md`](./2026-10-12-envio-email-listas-qr.md).

- **Issue:** [#216](https://github.com/marcoarthur/edumaps/issues/216)
- **Branch:** `feat/canais-envio-email`
- **Princípios:** duas trilhas com diretórios disjuntos (T-A `data_pipeline/` +
  `backend/`, T-B `frontend/`); subagentes só código/teste; git, deploy e
  verificação independente no coordenador; migrations por `ci_db.sh` (porta
  5433, verify gate); nenhuma change deployada é editada; deploy com
  `EDUMAPS_CONFIG_MASTER_KEY` exportada (Rexfile aborta sem ela).

## Contrato da onda 1 (congelado)

### Migration

Change única `canal_envios [canal_email_lgpd]` com **toda** a modelagem da spec
(segmentos, envios, destinatários, opt-outs, acessos ao QR, suspensões), como
na Fase 2. Ajuste à spec: o CHECK de `canal_envio_destinatarios.status` **não**
tem `ignorado_duplicado` — duplicados não viram linha (o `UNIQUE (envio_id,
email_hash)` impede), só entram no contador `ignorados` do envio. Valores:
`pendente`, `enviado`, `falhou`, `cancelado`, `ignorado_optout`,
`ignorado_anonimizado`.

### Config (AppConfig, grupo "Envios" na categoria Canais)

`canais.envio.enabled` (boolean, default `true`), `canais.envio.ritmo_por_minuto`
(int, 60, 1..600), `canais.envio.cota_diaria_escola` (int, 500, ≥ 1),
`canais.envio.max_destinatarios` (int, 2000, ≥ 1).

### Regras de negócio

- **Destinatários de uma lista**: membros da lista cujo contato tem e-mail
  (`clean.contatos.email` não nulo), normalizado `lower(trim())`; todos os
  estados (`pendente`, `parcial`, `confirmado`, `nao_exigida`).
- **Destinatários de um segmento**: união dos membros das `criterios.listas`
  (ids da escola que ainda existem), filtrada por `estado` (estado geral do
  membro naquela lista, mesma regra de `estado_contatos`; vazio = todos),
  `email_confirmado` (`true` → `email_confirmado_em` não nulo; `false` → nulo;
  ausente/`null` → indiferente), `inscritos_desde`/`inscritos_ate` (datas
  `YYYY-MM-DD`, inclusivas, sobre `canal_lista_membros.created_at` em
  America/Sao_Paulo).
- **Opt-out**: um endereço é `ignorado_optout` se `canal_optouts` tem
  `(lista_id, 'email', email_hash)` para **alguma** lista do alvo em que ele é
  membro. `email_hash` = `encode(digest(email_norm, 'sha256'), 'hex')`.
- **Dedupe**: um destinatário por `email_hash`; a lista de origem é a de menor
  id entre as listas do alvo em que ele é membro (e não saiu). Duplicados
  contam em `ignorados`.
- **Token de saída**: `hmac_sha256_hex(app secret, "saida:<destinatario_id>")`,
  primeiros 32 hex; `saida_hash` = sha256 hex do token, gravado no disparo. O
  job deriva o token de novo para o rodapé. Link:
  `<canais.inscricao.public_base_url>/privacidade/sair/<token>` (a página e a
  API pública chegam na onda 2).
- **Rodapé** (anexado ao corpo, `text/plain`):
  ```
  --
  Você recebe este e-mail porque se inscreveu na lista "<lista>" da escola <escola>.
  Motivo: <Operação>.
  Não quer mais receber mensagens desta lista? <link de saída>
  Privacidade e remoção dos seus dados: <base>/privacidade
  ```
  Na prévia e no teste, o link de saída é `<base>/privacidade/sair/EXEMPLO`.
- **Cabeçalhos**: `List-Unsubscribe: <link de saída>`,
  `List-Unsubscribe-Post: List-Unsubscribe=One-Click`, `Precedence: bulk`
  (`Channel::Email` passa a aceitar `headers` extras na mensagem).
- **Histórico**: cada e-mail via `Channel::Email->send_message` com
  `referente => {tipo=>'envio', id=>envio_id}`, `contato_id`, `cod_inep`; o
  teste usa `tipo=>'envio_teste'`.
- **Cota**: enviados hoje = destinatários `enviado` da escola com
  `processado_em` no dia corrente em America/Sao_Paulo. Disparo imediato exige
  `destinatarios ≤ saldo_hoje`; agendado exige `destinatarios ≤ cota_diaria`.
- **Suspensão**: escola com linha ativa em `canal_envio_suspensoes`
  (`reativado_em IS NULL`). As telas de admin chegam na onda 2; na onda 1 só a
  leitura (disparo `409` e job para).

### Ciclo do envio

`rascunho` → `agendado` (com `agendado_para`) ou `enviando` → `concluido`.
Desvios: `pausado_cota` (cota do dia esgotou; retoma 00:05 do dia seguinte),
`suspenso` (escola suspensa; retomada na onda 2), `cancelado`.

Job Minion `canais_envio [{envio_id}]`:
- lock `minion->guard("canais_envio:<id>")`; sem lock → sai;
- relê o envio: `cancelado`/`concluido`/`rascunho` → sai; escola suspensa →
  `suspenso` e sai; `canais.envio.enabled=0` ou SMTP indisponível → reagenda em
  300 s sem mudar o estado;
- `agendado` → `enviando` + `iniciado_em`;
- lote de até `ritmo_por_minuto` pendentes (ordem de id), parando se o saldo
  da cota acabar; destinatário sem `email` (anonimizado no meio) →
  `ignorado_anonimizado`; envia → `enviado` | `falhou` (`erro`); grava
  `mensagem_id`, `processado_em`; atualiza contadores;
- sem saldo e com pendentes → `pausado_cota` e reagenda para 00:05 do dia
  seguinte (America/Sao_Paulo); com pendentes → reagenda em 60 s; senão
  `concluido` + `concluido_em` + `email = NULL` em todos os destinatários.
- O disparo enfileira com `delay` = `agendado_para - now` (ou 0) e guarda o
  `minion_job_id`. Reprocessar nunca reenvia `enviado`.

### Gestão (Bearer + posse; prefixo `/api/gestor/:cod_inep/canais`)

**Envio (JSON)**:
```json
{ "id": 1, "cod_inep": 35038751,
  "alvo": { "tipo": "lista", "id": 7, "nome": "Responsáveis 8º" },
  "canal": "email", "operacao": "aviso", "assunto": "...", "corpo": "...",
  "status": "rascunho", "agendado_para": null, "iniciado_em": null,
  "concluido_em": null, "cancelado_em": null,
  "contadores": { "destinatarios": 0, "enviados": 0, "falhas": 0,
                  "ignorados": 0, "pendentes": 0, "cancelados": 0, "optouts": 0 },
  "autor": { "id": 2, "nome": "..." }, "created_at": "...", "updated_at": "..." }
```
Datas ISO 8601 UTC (`Z`). `alvo.nome`: nome atual no rascunho, fotografia
após o disparo; alvo excluído → `nome: null`. Na listagem, sem `corpo`.

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/envios` | `?status&page&per_page` (20, máx. 100) | `200 {items, total, page, per_page}` (mais recentes primeiro) |
| POST | `/envios` | `{alvo_tipo, alvo_id, operacao, assunto, corpo}` | `201` envio · `400` · `404` (alvo fora da escola) |
| GET | `/envios/limites` | — | `200 {enabled, smtp_disponivel, ritmo_por_minuto, cota_diaria, max_destinatarios, enviados_hoje, saldo_hoje, suspensao: null \| {motivo, suspenso_em}}` |
| GET | `/envios/:id` | — | `200` envio · `404` |
| PATCH | `/envios/:id` | qualquer campo do POST | `200` · `400` · `404` · `409` (não é rascunho) |
| DELETE | `/envios/:id` | — | `200 {ok:1}` · `409` (não é rascunho) |
| POST | `/envios/:id/previa` | — | `200 {assunto, texto, estimativa: {destinatarios, ignorados_optout, ignorados_duplicado}}` |
| POST | `/envios/:id/teste` | — | `202 {enviado:1, para}` (e-mail do gestor mascarado) · `409 {motivo}` · `429` (5 por envio) · `502` |
| POST | `/envios/:id/disparar` | `{agendado_para?}` | `202` envio · `400` (data passada ou > 90 dias) · `409 {error, motivo, saldo?, teto?}` |
| POST | `/envios/:id/cancelar` | — | `200` envio · `409` (não está agendado/enviando/pausado_cota/suspenso) |
| GET | `/envios/:id/destinatarios` | `?status&page&per_page` | `200 {items: [{id, nome, email, lista_id, status, erro, processado_em}], total, page, per_page}` — `email` **mascarado** (`j***@d***.com`); `nome` do contato (pode ser `[removido]`/null) |

`operacao` ∈ `aviso`, `informacao`, `pedido`, `convite`, `lembrete`, `alerta`.
`assunto` 1..200, `corpo` 1..20000. `motivo` do `409`: `status`,
`smtp_indisponivel`, `envio_desligado`, `escola_suspensa`, `alvo_inexistente`,
`sem_destinatarios`, `acima_do_teto` (+ `teto`), `cota_insuficiente`
(+ `saldo`). O teste usa `smtp_indisponivel` e `sem_email_gestor`.

**Segmento (JSON)**:
```json
{ "id": 3, "nome": "Confirmados 8º e 9º",
  "criterios": { "listas": [7, 9], "estado": ["confirmado"],
                 "email_confirmado": null, "inscritos_desde": null, "inscritos_ate": null },
  "listas": [ { "id": 7, "nome": "Responsáveis 8º", "existe": true },
              { "id": 9, "nome": null, "existe": false } ],
  "created_at": "...", "updated_at": "..." }
```

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/segmentos` | — | `200 [segmento]` (por nome) |
| POST | `/segmentos` | `{nome, criterios}` | `201` · `400` · `409` (nome repetido) |
| GET/PUT/DELETE | `/segmentos/:id` | PUT `{nome, criterios}` | `200` · `400` · `404` · `409` |
| POST | `/segmentos/previa` | `{criterios}` | `200 {destinatarios, amostra: [{nome, email}], listas_ignoradas: [ids]}` |
| GET | `/segmentos/:id/previa` | — | idem |

Critérios válidos: `listas` 1..50 inteiros (listas de **outra** escola → `400`;
listas excluídas depois → ignoradas, aparecem em `listas_ignoradas`); `estado`
⊆ {`pendente`,`parcial`,`confirmado`,`nao_exigida`}; datas `YYYY-MM-DD` com
`desde ≤ ate`. Amostra: até 10, e-mail mascarado.

### Frontend (onda 1)

- **API** (`gestorCanaisApi.js` ou um `gestorEnviosApi.js`) cobrindo as rotas
  acima; MSW/fixtures no padrão de `canaisFixtures.js`.
- **`/gestor/envios`** (`EnviosPage`): limites (saldo do dia, suspensão),
  lista de envios (estado com selo, alvo, assunto, contadores, datas), "Novo
  envio".
- **Editor** (criar/editar rascunho): alvo (lista ou lista dinâmica),
  operação, assunto, corpo com prévia (`TextoMarkdown`) e "Pré-visualizar"
  (`/previa`, mostra o texto final e a estimativa), "Enviar teste para mim",
  "Enviar agora" / "Agendar" (data/hora) com `ConfirmDialog` mostrando a
  contagem; mensagens para cada `motivo` do `409`.
- **Detalhe**: contadores, estado, destinatários mascarados com filtro por
  estado, "Cancelar"; polling a cada 5 s enquanto `agendado`/`enviando`.
- **`/gestor/segmentos`** (`SegmentosPage`): listar, criar/editar (seletor de
  listas da escola, estados, e-mail confirmado sim/não/indiferente, datas),
  prévia ao vivo (contagem + amostra), apagar.
- **ListasPage**: ação "Enviar e-mail" por lista → editor com o alvo
  preenchido; links de navegação para Envios e Listas dinâmicas.
- `configFixtures.js` com as folhas `canais.envio.*`.

## WBS

| ID | Trilha | Escopo | Status |
|----|--------|--------|--------|
| M1 | T-A | Migration `canal_envios` (toda a modelagem) | 🟢 |
| M2 | T-A | Config `canais.envio.*` + cabeçalhos extras no `Channel::Email` | 🟢 |
| M3 | T-A | Segmentos (CRUD, critérios, prévia) | 🟢 |
| M4 | T-A | Envios (rascunho, prévia, teste, disparo, cancelar, destinatários, limites) | 🟢 |
| M5 | T-A | Job `canais_envio` (lotes, ritmo, cota, suspensão, idempotência) | 🟢 |
| F1 | T-B | API + fixtures | 🟢 |
| F2 | T-B | EnviosPage + editor + detalhe | 🟢 |
| F3 | T-B | SegmentosPage + ação na ListasPage | 🟢 |
| T1 | coord. | verificação, commits, deploy | 🟢 |
| M6 | T-A | Opt-out público (GET/POST, One-Click, reinscrição desfaz) | ⚪ |
| M7 | T-A | Funil (acessos ao QR + endpoint) + `n_optouts`/`optout` | ⚪ |
| M8 | T-A | Admin (volume, suspender, reativar + retomada) | ⚪ |
| M9 | T-A | Anonimização cobre os destinatários de envio | ⚪ |
| F4 | T-B | `SairPage` | ⚪ |
| F5 | T-B | ListasPage: selo, contador, Funil; Saídas no detalhe | ⚪ |
| F6 | T-B | Painel admin de envios no `/config` | ⚪ |

Onda 2: opt-out público (página, One-Click, reinscrição desfaz), funil
(acessos + endpoint + aba), admin (volume, suspender/reativar e retomada dos
envios), anonimização cobrindo as tabelas novas, selo "Saiu dos envios".

## Onda 2 — contrato (congelado)

### Público (independente de `canais.inscricao.enabled` — direito do titular)

| Método | Rota | Entrada | Saída |
|---|---|---|---|
| GET | `/api/canais/sair/:token` | — | `200 {escola_nome, lista_nome, ja_saiu}` · `404` genérico |
| POST | `/api/canais/sair/:token` | JSON `{confirmar:true}` **ou** form `List-Unsubscribe=One-Click` (RFC 8058) | `200 {ok:1, ja_saiu}` (idempotente) · `400` (sem nenhum dos dois) · `404` · `429` |

- Token: 32 hex; procura `canal_envio_destinatarios.saida_hash = sha256(token)`.
  Formato inválido ou não encontrado → `404` genérico. Rate limit por IP no
  mesmo padrão da exclusão (Fase 2).
- Saída: `INSERT INTO canal_optouts (lista_id, 'email', email_hash, envio_id)
  ON CONFLICT DO NOTHING` com a lista de origem do destinatário.
  `ja_saiu` = o opt-out já existia. Lista de origem apagada → `404`.
- `lista_nome` = nome atual da lista de origem; `escola_nome` como na exclusão.

**Mudanças em rotas existentes:**
- `GET /api/canais/inscricao/:token` com resposta `200` → soma 1 em
  `canal_qr_acessos (qrcode_id, dia)` (dia em America/Sao_Paulo; upsert). Não
  conta `404`/`410`. Contrato da resposta inalterado.
- `POST /api/canais/inscricao/:token` real (não honeypot) com e-mail →
  `DELETE FROM canal_optouts WHERE lista_id = <lista> AND canal='email' AND
  email_hash = sha256(email_norm)` (reinscrição = novo consentimento).
  Resposta inalterada.

### Gestão (Bearer + posse)

- `GET /listas`, `GET /listas/:id`: + `n_optouts` (int).
- `GET /listas/:id/inscricoes`: cada membro + `optout` (booleano: o e-mail
  atual do contato tem opt-out nesta lista).
- `GET /listas/:id/funil?de=YYYY-MM-DD&ate=YYYY-MM-DD` (padrão: `ate` = hoje,
  `de` = `ate` − 29 dias; intervalo máx. 366 dias; `400` se inválido) →
  ```json
  { "de": "2026-09-13", "ate": "2026-10-12", "exige_confirmacao": true,
    "totais": { "acessos": 120, "inscricoes": 48, "confirmados": 40, "optouts": 2 },
    "taxas":  { "acesso_inscricao": 0.4, "inscricao_confirmacao": 0.8333 },
    "serie":  [ { "dia": "2026-09-13", "acessos": 0, "inscricoes": 0, "confirmados": 0, "optouts": 0 } ] }
  ```
  `serie` tem **todos** os dias do intervalo (zeros incluídos). Dias em
  America/Sao_Paulo. `acessos` = soma de `canal_qr_acessos` dos QRs da lista;
  `inscricoes` = linhas de `canal_inscricoes` da lista criadas no dia;
  `confirmados` = membros atuais com estado geral `confirmado`, no dia do
  `GREATEST(confirmado_em, email_confirmado_em)` — **`null`** (totais e série)
  se a lista não exige confirmação; `optouts` = `canal_optouts.created_at`.
  Taxas com 4 casas, `null` quando o denominador é 0 ou `confirmados` é `null`.
- `GET /envios/:id`: `contadores.optouts` = opt-outs com `envio_id` = este envio
  (já no contrato da onda 1, agora preenchido de fato).

### Admin (Bearer admin)

| Método | Rota | Saída |
|---|---|---|
| GET | `/api/admin/canais/envios` | `200 {limites: {enabled, ritmo_por_minuto, cota_diaria, max_destinatarios, smtp_disponivel}, escolas: [ {cod_inep, escola_nome, enviados_hoje, enviados_30d, falhas_30d, optouts_30d, envios_em_curso, suspensao: null \| {id, motivo, suspenso_em, suspenso_por}} ]}` |
| POST | `/api/admin/canais/envios/suspensoes` | `{cod_inep, motivo}` (motivo 1..500) → `201 {suspensao}` · `400` · `409` (já suspensa) |
| POST | `/api/admin/canais/envios/suspensoes/:cod_inep/reativar` | `200 {ok:1, envios_retomados}` · `404` (sem suspensão ativa) |

- `escolas`: as que têm envio nos últimos 30 dias **ou** suspensão ativa,
  ordenadas por `enviados_30d` desc. `envios_em_curso` = envios em
  `agendado`/`enviando`/`pausado_cota`/`suspenso`.
- **Suspender**: grava a suspensão (`suspenso_por` = id do admin) e passa na
  hora os envios `agendado`/`enviando`/`pausado_cota` da escola para
  `suspenso` (o job, ao rodar, já sai).
- **Reativar**: fecha a suspensão (`reativado_em/por`); cada envio `suspenso`
  volta a `agendado` se nunca começou (`iniciado_em IS NULL`) ou a `enviando`
  se já começou, e é reenfileirado (`canais_envio_enfileirar`) com o `delay`
  até `agendado_para` (ou 0). `envios_retomados` = quantos.
- **Job**: um envio `suspenso` sem suspensão ativa continua sendo retomado
  (onda 1), mas o caminho normal agora é a reativação.

### Anonimização (extensão do `anonimizar_contato`, RF-206)

Na mesma transação, para o contato: `canal_envio_destinatarios` com
`email = NULL`, `contato_id = NULL`; os `pendente` viram
`ignorado_anonimizado` (+1 em `ignorados` do envio, `processado_em = NOW()`).
`canal_optouts` fica (só hash). O teste de varredura de PII da Fase 2 passa a
cobrir `canal_envio_destinatarios`.

### Frontend (onda 2)

- **`SairPage`** pública em `/privacidade/sair/:token` (fora do guard, como a
  `ExclusaoPage`): escola e lista, o que acontece ("você deixa de receber
  e-mails desta lista; seus dados continuam com a escola"), botão
  "Não quero mais receber", estados concluído / já tinha saído / link inválido,
  e orientação para a remoção completa (link pessoal da inscrição ou pedido à
  escola) + link para `/privacidade`.
- **ListasPage**: selo "Saiu dos envios" por membro (`optout`), contador
  `n_optouts` por lista, e seção/aba **Funil** por lista: cartões (acessos,
  inscrições, confirmados, saídas, taxas) + barras por dia (SVG/CSS, sem lib
  nova), filtro de período (7/30/90 dias); confirmados "—" quando `null`.
- **EnvioDetalhe**: mostrar "Saídas" (`contadores.optouts`).
- **Admin**: painel **Envios** no `/config` ao selecionar uma folha
  `canais.envio.*` (mesmo padrão do `RetencaoStatus`): limites, tabela de
  escolas (volume hoje/30 dias, falhas, saídas, em curso, suspensão) e ações
  Suspender (`ConfirmDialog` com motivo obrigatório) / Reativar.

## Log de decisões

- **2026-10-12 — Início da onda 1** aprovado pelo developer.
- **2026-10-12 — Perguntas em aberto da spec:** reinscrição desfaz o opt-out
  (proposto, onda 2); sem nova tentativa automática de falhas; consentimento
  1.2 só sugerido.
- **2026-10-12 — Duplicados sem linha:** `ignorado_duplicado` sai do CHECK;
  duplicados só no contador `ignorados` (o `UNIQUE (envio_id, email_hash)` não
  permite a linha).
- **2026-10-12 — Token de saída derivado por HMAC** do id do destinatário:
  nada em claro no banco, e o job reconstrói o link a cada lote.
- **2026-10-12 — Desvios da T-A aceitos (onda 1):** `send_message` devolve
  também `mensagem_id` (id do histórico); `Canal::Listas` expõe
  `_sql_estado_membro` para as roles novas; índice extra
  `idx_canal_envio_dest_processado` (cota diária); assunto do teste com
  prefixo `[Teste] `. Interpretações: lista **inativa** conta como alvo
  inexistente (`existe:false`, `listas_ignoradas`); `destinatarios` inclui as
  linhas `ignorado_optout`; `409 cota_insuficiente` de envio agendado traz
  `saldo` = cota diária; destinatários mascaram `COALESCE(d.email,
  contato.email)`; job rodado antes de `agendado_para` reagenda pelo tempo que
  falta; `suspenso` com escola reativada é retomado quando o job roda (o
  reenfileiramento na reativação é da onda 2).
- **2026-10-12 — Desvios da T-B aceitos (onda 1):** `EnviosPage` também abre
  `?id=N` (editor se rascunho, senão detalhe); o editor salva o rascunho antes
  de prévia/teste/disparo e pede `/previa` para a contagem do `ConfirmDialog`;
  ao salvar uma lista dinâmica, ids de listas excluídas saem dos critérios;
  botões de envio desabilitados com escola suspensa, envio desligado ou SMTP
  indisponível; "Enviar e-mail" também por lista dinâmica.

## Verificação independente (coordenador, onda 1)

- Banco de CI recriado do zero (`ci_db.sh up` na 5433) + `verify` →
  `canal_envios .. ok`.
- Backend `prove -l -r t/01-app t/02-models/ t/04-api/canais/ t/04-api/admin/
  t/04-api/gestor/ t/03-plugins/ t/05-tasks/{canais_envio,canais_retencao,telegram_polling}.t`
  → 78 arquivos / 489 testes; só os 6 pré-falhos conhecidos.
- Frontend 92 arquivos / 682 testes; `vite build` OK. Rotas e JSON
  conferidos lado a lado (envio, contadores, limites, prévia, segmentos).
- **2026-10-12 — Onda 2 aprovada.** Reativação devolve o envio a `agendado` quando ele nunca começou, para não antecipar um agendamento; funil com `confirmados = null` em listas sem exigência de confirmação.
