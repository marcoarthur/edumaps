# Nota técnica 112 — Listas com QR: ciclo completo (Fases 0–3)

## Resumo

Esta nota fecha o ciclo da feature **listas com QR**, que começou em 2026-10-11
sobre o núcleo de canais (nota 106, PR #207) e terminou em 2026-10-12 com o
envio por e-mail (Fase 3, #216). As notas 107 a 111 registraram cada passo; esta
consolida o conjunto: o que existe agora, como as peças se ligam e por que
foram desenhadas assim.

Em uma frase: o gestor cria uma lista, publica um QR, a comunidade se inscreve
com telefone e/ou e-mail sob um termo de consentimento versionado, confirma a
posse dos contatos (Telegram, WhatsApp ou código por e-mail), pode sair dos
envios ou apagar os próprios dados a qualquer momento, e a escola **envia
e-mails** para a lista ou para recortes dela, em fila, com limites da
administração e um funil que mostra quanto o QR converte.

O processo foi o mesmo em todas as fases: spec congelada + arquivo de execução
mutável (contratos por onda, WBS, log de decisões), duas trilhas paralelas em
diretórios disjuntos (T-A `data_pipeline/` + `backend/`, T-B `frontend/`),
subagentes só com código e teste, e git, deploy e verificação independente no
coordenador.

## Linha do tempo

| Fase | Issue · PR · merge | Nota | Entrega |
|---|---|---|---|
| Núcleo (antecedente) | PR #207 · `e0a16b6` | 106 | `Channel::*` (e-mail, WhatsApp, Telegram), confirmação por código, histórico de mensagens; sem API nem UI |
| **0** — MVP telefone | #208 · PR #209 · `4b2828f` | 107 | Listas nomeadas, QR/link, página pública de inscrição (nome + telefone + consentimento), dedupe não destrutivo, honeypot, rate limit, IP anonimizado, página `/privacidade` |
| Dívidas | PR #210 · `b009495` | 108 | Reverts faltantes de `canal_confirmacoes`/`canal_mensagens`, banner e fixture do `/config`, doc funcional de canais, limpeza do dev |
| Config | PR #211 · `c424ae4` | 109 | Folhas `canais.inscricao.*` habilitadas no painel (`enabled` da folha é só apresentação) |
| **1** — Posse do telefone | #212 · PR #213 · `8d5c502` | 110 | Exigência por lista, refs públicas, bot público do Telegram (webhook e polling), código por WhatsApp, estado por membro; trava da master key no Rexfile |
| **2** — E-mail + LGPD | #214 · PR #215 · `a09f3b5` | 111 | Coleta por lista, confirmação por código de e-mail e estado `parcial`, consentimento versionado, exclusão pelo titular e pelo gestor, retenção automática |
| **3** — Envio por e-mail | #216 · PR #217 · `0960418` | 112 | Envio em massa para lista ou lista dinâmica (fila, ritmo, cota, agendamento, cancelamento, teste), opt-out por lista com One-Click, limites e suspensão pela administração, funil de conversão, resultado por envio |

A Fase 3 foi entregue em duas ondas na branch `feat/canais-envio-email`: onda 1
(`58ac51a` migration, `67ff61e` backend, `cd4b8ec` frontend) e onda 2
(`30318c5` backend, `e25222c` frontend), mais a correção dos achados do e2e
(`2babb37`), cada onda com contrato congelado e
registro de execução (`0cca9f0`, `05f8e80`, `69176a1`, `6096d7f`, `45321d9`).

## Arquitetura consolidada

### Backend

**Núcleo de canais (`EduMaps::Channel::*`)** — biblioteca sem conhecimento de
listas:

- `Channel::Base` — template method `send_message` sobre `Mojo::EventEmitter`
  (eventos `message.*` e `confirm.*`); na Fase 3 passou a devolver também o
  `mensagem_id` do histórico.
- `Channel::Email` (SMTP nativo; transporte injetável nos testes desde a Fase 2;
  cabeçalhos extras desde a Fase 3), `Channel::WhatsApp` (provedores `link` e
  `cloud`), `Channel::Telegram` + `Channel::Telegram::Updates` (tratador único
  de updates do bot público, chamado pelo webhook e pelo polling).
- `Channel::Confirmation` (código com hash + salt, TTL e tentativas),
  `Channel::History` (histórico em `canal_mensagens`), `Channel::Operacoes`
  (lista canônica de motivos, espelhada no CHECK).

**Regras de negócio (`Roles::Business::Canal::*`)**, compostas no
`EduMaps::Model::Canal`:

| Role | Fase | Responsabilidade |
|---|---|---|
| `Canal::Listas` | 0 (+1, 2, 3) | Listas, QR, inscrição pública, normalização, dedupe, rate limit, honeypot, estado do membro (`_sql_estado_membro` exposto às roles da Fase 3) |
| `Canal::Confirmacao` | 1 (+2) | Refs públicas, estado por contato, conclusão via Telegram/WhatsApp/e-mail, conflito |
| `Canal::Consentimento` | 2 | Versões do termo (rascunho → vigente → arquivada), hash do texto aceito |
| `Canal::Exclusao` | 2 (+3) | Anonimização pelo inventário de PII, exclusão pública e pelo gestor, retenção; na Fase 3 cobre os destinatários de envio |
| `Canal::Segmentos` | 3 | Listas dinâmicas: CRUD, validação de critérios, prévia mascarada |
| `Canal::Envios` | 3 | Rascunho, prévia, teste, disparo (fotografia dos destinatários), cancelamento, cota, suspensão, processamento em lotes |
| `Canal::Optout` | 3 | Saída por lista via token, One-Click, reinscrição desfaz |
| `Canal::Funil` | 3 | Contagem diária de acessos ao QR e série acessos → inscrições → confirmações → saídas |

A configuração vive no `Roles::Business::Config::AppConfig`, categoria
**Canais**: `canais.email.*`, `canais.whatsapp.*`, `canais.inscricao.*`,
`canais.telegram.*` (bot público), `canais.retencao.*` e `canais.envio.*`.

### Tasks Minion

Três tasks autorreagendáveis com lock (`minion->guard`), no mesmo padrão:

| Task | Fase | Função |
|---|---|---|
| `telegram_polling` | 1 | `getUpdates` com long polling, offset persistido por update, backoff; início no `wait` do worker; exclusiva com o webhook |
| `canais_retencao` | 2 | Expurgo diário (metadados, pendentes, listas inativas); `{manual:1}` executa uma vez sem reagendar |
| `canais_envio` | 3 | Um job por envio: lote de até `ritmo_por_minuto` pendentes, reagenda em 60 s, pausa por cota até 00:05 do dia seguinte, sai em cancelado/suspenso, reagenda em 300 s sem SMTP ou com envios desligados; enfileirada pelo helper `canais_envio_enfileirar` com `delay` |

### Rotas

**Públicas** (sem autenticação, `Controller::Canais`), todas com resposta
mínima e `404` genérico para token/ref inválidos:

| Rota | Fase |
|---|---|
| `GET/POST /api/canais/inscricao/:token` | 0 (+ `confirmacao` na 1; `campos`, consentimento e `exclusao_url` na 2; contagem de acesso e reinscrição que desfaz opt-out na 3) |
| `GET /api/canais/confirmacao/:ref` e `POST …/whatsapp`, `…/whatsapp/verificar` | 1 |
| `POST /api/canais/telegram/webhook` | 1 |
| `POST /api/canais/confirmacao/:ref/email`, `…/email/verificar` | 2 |
| `GET /api/canais/consentimento` | 2 |
| `GET/POST /api/canais/exclusao/:token` | 2 |
| `GET/POST /api/canais/sair/:token` (JSON `{confirmar:true}` ou form `List-Unsubscribe=One-Click`) | 3 |

As rotas de exclusão e de saída **não dependem** de
`canais.inscricao.enabled`: são direito do titular.

**Gestão** (Bearer + posse do `cod_inep`, prefixo
`/api/gestor/:cod_inep/canais`): `/listas` (CRUD, `PATCH`, QR com validade e
limite, inscrições com estado por contato, `DELETE …/membros/:membro_id`,
`…/funil`), `/exclusoes`, `/envios` (CRUD de rascunho, `previa`, `teste`,
`disparar`, `cancelar`, `destinatarios`, `limites`) e `/segmentos` (CRUD,
`previa` de critérios salvos ou não).

**Admin** (Bearer admin): `/api/admin/canais/telegram/*` (status, webhook,
polling — Fase 1), `/api/admin/consentimento/versoes*` e
`/api/admin/canais/retencao*` (Fase 2), `/api/admin/canais/envios` e
`…/envios/suspensoes*` (volume, suspender, reativar — Fase 3).

### Telas

| Tela | Fase | Conteúdo |
|---|---|---|
| `InscricaoPublicaPage` (`/inscricao/:token`, fora do guard) | 0 (+1, 2) | Formulário por `coleta`, `TermoConsentimento`, passo de confirmação (`ConfirmacaoContatos`, polling 3 s / 5 min), `LinkExclusao` |
| `ListasPage` + `QRModal`, `MembrosTable`, `ExclusoesHistorico`, `FunilLista` | 0 (+1, 2, 3) | Listas, QR, membros com selos de estado e "Saiu dos envios", remoção de inscrito, histórico de exclusões, aba Funil, "Enviar e-mail" |
| `EnviosPage` + `EnvioEditor`, `EnvioDetalhe`, `EnvioSelo`, `LimitesPainel` | 3 | Lista de envios, editor com prévia/teste/agendar, detalhe com polling de 5 s e destinatários mascarados, saldo e suspensão |
| `SegmentosPage` + `SegmentoForm` | 3 | Listas dinâmicas com prévia ao vivo |
| `PrivacidadePage`, `ExclusaoPage`, `SairPage` (`/privacidade/*`, fora do guard, sem menu) | 0, 2, 3 | Política e termo vigente, exclusão pelo link pessoal, saída da lista (`noindex`) |
| `ConfigPage` + `TelegramPublicoStatus`, `RetencaoStatus`, `EnviosAdmin`; `ConsentimentoVersoesPage` | 1, 2, 3 | Painéis contextuais por grupo de folhas; versões do termo em `/config/consentimento` |

## Modelo de dados consolidado

Seis changes Sqitch, todas anexadas ao fim do plano, cada uma dependendo da
anterior; nenhuma change deployada foi editada:

| Change | Fase | Tabelas |
|---|---|---|
| `canal_confirmacoes [gestor_reunioes]` | núcleo (#207) | `canal_confirmacoes` (código de posse, hash + salt) |
| `canal_mensagens [canal_confirmacoes]` | núcleo (#207) | `canal_mensagens` (histórico: canal, operação, destinatário, corpo, status, `referente_tipo/id`) |
| `canal_listas_autoinscricao [canal_mensagens]` | 0 | `canal_listas` (soft-delete `ativo`), `canal_qrcodes` (token, validade, `usos`/`max_usos`), `canal_lista_membros`, `canal_inscricoes` (registro append-only: bruto + normalizado, `validado`, `duplicado_de`, `conflito`, `ip_anon`, consentimento) |
| `canal_confirmacao_listas [canal_listas_autoinscricao]` | 1 | `canal_listas.exige_confirmacao`; `canal_lista_membros.confirmado_em/via`, `telegram_chat_id`; `canal_confirmacao_refs` (só o sha256 da ref, TTL, `telegram_chat_pendente`); `canal_telegram_estado` (offset do polling) |
| `canal_email_lgpd [canal_confirmacao_listas]` | 2 | `canal_listas.coleta`, `desativada_em`; `canal_inscricoes.email/email_norm`, `consentimento_hash`, `exclusao_hash`, `anonimizado_em` (telefone vira opcional); `canal_lista_membros.email_confirmado_em/via`; `canal_confirmacao_refs.envios_email`; `consentimento_versoes` (seed 1.0, índice único parcial da vigente); `canal_exclusoes` (auditoria sem PII) |
| `canal_envios [canal_email_lgpd]` | 3 | `canal_segmentos` (critérios em `jsonb`, nome único por escola); `canal_envios` (alvo, fotografia do nome, operação, assunto, corpo, estado, datas, contadores, `minion_job_id`); `canal_envio_destinatarios` (`email` cru só enquanto pendente, `email_hash`, `saida_hash`, estado, erro, `mensagem_id`; `UNIQUE (envio_id, email_hash)`); `canal_optouts` (lista + canal + `email_hash`, sem PII); `canal_qr_acessos` (QR × dia × contagem); `canal_envio_suspensoes` (índice único parcial da suspensão ativa) |

Ciclo de vida do envio: `rascunho` → `agendado` ou `enviando` → `concluido`,
com desvios `pausado_cota`, `suspenso` e `cancelado`. Estado do destinatário:
`pendente`, `enviado`, `falhou`, `cancelado`, `ignorado_optout`,
`ignorado_anonimizado`.

Os `verify/*.sql` de todas as changes seguem o estilo gate da #160
(`DO $$ … RAISE EXCEPTION $$`), e cada fase foi exercitada com revert → deploy
num banco descartável.

## Fluxos ponta a ponta

1. **Inscrição.** O gestor cria a lista (escolhe `coleta` e se exige
   confirmação) e gera o QR. A página pública lê a lista (conta 1 acesso no dia,
   Fase 3), mostra os campos e o termo vigente. O POST valida contra a `coleta`
   e a versão do termo (`409` se desatualizada), faz dedupe por telefone e por
   e-mail sem descartar (nova inscrição marcada, contato reaproveitado), cria o
   membro, grava versão + hash do termo e devolve o `exclusao_url`. Se a pessoa
   tinha saído dos envios daquela lista, a reinscrição apaga o opt-out.
2. **Confirmação.** Lista que exige confirmação devolve uma ref de 128 bits
   (TTL 24 h) e os canais disponíveis: Telegram (deep link → compartilhar
   contato → confere `user_id == from.id` e o número), WhatsApp (código por
   template) e e-mail (código por SMTP). O estado geral é `pendente`,
   `parcial` ou `confirmado`; a página acompanha por polling.
3. **Envio.** O gestor compõe o rascunho, pede a prévia (texto final com rodapé
   + estimativa), manda um teste para si e dispara (agora ou agendado). O
   disparo resolve o alvo, descarta anonimizados e opt-outs, deduplica por
   `email_hash`, confere teto e cota, grava os destinatários com o `saida_hash`
   numa transação e enfileira `canais_envio`. O job envia em lotes por
   `Channel::Email->send_message` com `List-Unsubscribe`,
   `List-Unsubscribe-Post` e `Precedence: bulk`, atualiza contadores e, ao
   concluir, apaga o `email` cru de todos os destinatários.
4. **Saída.** O link do rodapé (ou o One-Click do cliente de e-mail) leva à
   `SairPage`; o POST grava `(lista, 'email', email_hash)` em `canal_optouts`
   de forma idempotente. Envios seguintes da lista, inclusive por lista
   dinâmica que a contenha, marcam o endereço como `ignorado_optout`.
5. **Exclusão.** Pelo link pessoal ou pelo gestor, `anonimizar_contato` aplica
   o inventário de PII numa transação, registra em `canal_exclusoes` e, desde a
   Fase 3, limpa `email`/`contato_id` dos destinatários de envio e passa os
   pendentes a `ignorado_anonimizado`. A retenção faz o mesmo por prazo.

## Decisões de design (com o porquê)

### Fases 0–2

- **Lista própria (`canal_listas`)**, sem reaproveitar `contato_grupos`, que
  será deprecado.
- **Não destrutivo**: bruto + normalizado, dedupe e conflito marcam, nunca
  apagam. Exclusão a pedido e retenção são as **únicas** vias que removem PII,
  sempre auditadas sem dado pessoal.
- **Capabilities de 128 bits, só o hash no banco** (ref de confirmação, token
  de exclusão e, na Fase 3, token de saída). A API pública nunca expõe ids.
- **Estado derivado**, não coluna: ligar a exigência numa lista com membros não
  reescreve nada.
- **Um tratador, dois transportes** para o bot (webhook em produção, polling em
  dev), bot público separado do bot interno.
- **Anonimizar, não apagar**: o contato vira `[removido]` e reuniões/relações
  que apontam para ele não quebram; teste de varredura de PII como guarda.
- **Consentimento imutável e auditável** (versão + sha256 do texto na
  inscrição; `409` com o texto novo quando a página está desatualizada).
- **Retenção conservadora**: só anonimiza contatos criados pela autoinscrição;
  prazo inválido usa o default.
- **Contratos só acrescentam campos** em todas as fases.

### Fase 3

- **Destinatários = confirmados e pendentes** (decisão do developer). Quem quer
  só confirmados usa uma lista dinâmica com esse filtro; todo e-mail leva os
  links de saída e de exclusão, o que mitiga o risco de escrever para um
  endereço digitado errado.
- **Só e-mail**: WhatsApp exige template aprovado e é cobrado; Telegram fica
  para depois. O campo `canal` já existe nas tabelas, preso a `email` por CHECK.
- **Opt-out por lista, por hash do e-mail**: a vontade da pessoa sobrevive à
  anonimização do contato e não guarda PII; a exclusão LGPD continua separada
  (sair ≠ apagar).
- **Token de saída por HMAC** do id do destinatário com o segredo do app
  (32 hex): nada em claro no banco, e o job reconstrói o link a cada lote sem
  precisar guardá-lo.
- **Duplicados sem linha**: o `UNIQUE (envio_id, email_hash)` impede a linha,
  então `ignorado_duplicado` saiu do CHECK e os duplicados só contam em
  `ignorados`. A lista de origem de um endereço é a de menor id do alvo.
- **Fotografia no disparo**: destinatários e nome do alvo são fixados quando o
  envio é disparado; quem entra depois não recebe, e o histórico continua
  legível mesmo se a lista mudar de nome.
- **Cota no fuso de São Paulo**: conta destinatários `enviado` com
  `processado_em` no dia local (índice próprio). Disparo imediato exige saldo
  do dia; agendado exige caber na cota diária. Quem atinge a cota no meio pausa
  e retoma às 00:05 do dia seguinte.
- **Reativação devolve a `agendado`** o envio que nunca começou (não antecipa
  um agendamento) e a `enviando` o que já tinha começado.
- **Reativação remove o job antigo ainda na fila** antes de reenfileirar, para
  não haver duas cadeias de lotes do mesmo envio (o lock já impediria envio
  duplicado, mas a fila ficaria com trabalho fantasma).
- **Funil sem PII e sem rastreio**: acessos são só um contador por QR e por
  dia (nada de IP, user-agent ou cookie); não há pixel de abertura nem
  redirecionamento de clique. `confirmados` é `null` em lista sem exigência.
- **Lista inativa conta como alvo inexistente** (`existe:false`,
  `listas_ignoradas`, `409 alvo_inexistente`) — mas a página de saída ainda
  aceita lista de origem desativada; só a apagada dá `404`.
- **Sem nova tentativa automática de falhas** nesta fase: falha vira `falhou`
  com o erro, e o envio termina `concluido` mesmo com falhas parciais.
- **Corpo em `text/plain`** com markdown simples, sem anexos.

## Segurança e LGPD consolidadas

### Inventário de PII

| Tabela | PII | Tratamento na exclusão/retenção |
|---|---|---|
| `clean.contatos` | `nome`, `telefone`, `email` | `[removido]`, `NULL`, `NULL` |
| `canal_inscricoes` | `nome`, `telefone`, `telefone_norm`, `email`, `email_norm`, `ip_anon`, `user_agent` | apagadas + `anonimizado_em` (esqueleto: data, lista, versão do termo) |
| `canal_lista_membros` | vínculo, `telegram_chat_id` | linhas do contato removidas de todas as listas da escola |
| `canal_confirmacao_refs` | `telegram_chat_pendente` | invalidadas, chat apagado |
| `canal_confirmacoes` | `endereco` | pendentes expiradas, endereço trocado por hash |
| `canal_mensagens` | destinatário, corpo, `erro` | apagados para as mensagens do contato |
| `canal_envio_destinatarios` | `email` (cru, só enquanto pendente), `contato_id` | `NULL`; pendentes → `ignorado_anonimizado`; ao concluir o envio o `email` já é apagado para todos |
| `canal_optouts` | — (só `email_hash`) | mantido: é a vontade da pessoa, sem PII |
| `canal_qr_acessos`, `canal_exclusoes`, `canal_envios`, `canal_segmentos`, `canal_envio_suspensoes` | — | — |

### Controles

- Resposta pública mínima; `404` genérico para tokens e refs; rate limit nos
  POST públicos (e bucket próprio para o polling da confirmação); honeypot;
  IP anonimizado por HMAC com salt diário.
- Gestão sempre por Bearer + posse do `cod_inep` (`403/404`); destinatários e
  amostras de lista dinâmica com e-mail mascarado (`j***@d***.com`).
- Códigos de confirmação mascarados no histórico (`******`); segredos do
  AppConfig cifrados com a master key.
- Webhook do Telegram com `secret_token` comparado em tempo constante.
- Envio: teste limitado a 5 por envio; teto por envio, ritmo e cota; suspensão
  por escola auditada (quem, quando, motivo).

## Testes e validação

| Fase | Backend | Frontend | Outras verificações |
|---|---|---|---|
| 0 (#209) | 3 arquivos / 30 testes | 82 / 463 | `ci_db.sh` deploy + verify; e2e CDP (404, 201, duplicado, honeypot, 400, 429, 401, página pública) |
| Dívidas (#210) | 3 / 30 | 82 / 463 | revert → deploy dos reverts novos |
| Config (#211) | 5 / 33 | 82 / 463 | validação visual do `/config` |
| 1 (#213) | 65 / 428 (6 pré-falhos) | 83 / 511 | e2e com bot fictício e Telegram simulado pelo webhook |
| 2 (#215) | 74 / 476 (6 pré-falhos) | 88 / 611 | e2e com exclusão no navegador, remoção pelo gestor e varredura de PII; retenção avulsa |
| 3 (#216) | 81 / 508 (6 pré-falhos) | 96 / 718+ | ver abaixo |

Os 6 pré-falhos são os mesmos desde a Fase 1 e idênticos no `main` limpo:
`City.t`, `domain/quality.t`, `indicators/quality.t`, `indicators_quality.t`,
`03-plugins/analytics.t` e `middlewares/session.t`.

**Fase 3** — banco de CI recriado do zero (`ci_db.sh up` na 5433) + `verify`
(`canal_envios .. ok`); backend 78 / 489 na onda 1 e 81 / 508 na onda 2;
frontend 92 / 682 na onda 1 e 96 / 718 na onda 2, mais os testes das correções
do e2e; `vite build` OK.

**E2E em dev** (CDP, `http://ubatexu.lan:8080`, rodada registrada em
`docs/e2e/cobertura.md`) com envio **real por SMTP** para um **Mailpit de
captura** temporário no `ubaxala` (só `127.0.0.1`), alcançado pelo backend por
um **túnel SSH reverso**; `canais.email.*` de dev apontou para ele só durante a
rodada. Listas `E2E 216 A` e `B`, quatro inscritos (um nas duas listas). Foram
41 verificações — prévia da lista dinâmica com dedupe, rascunho → prévia →
teste, disparo concluído (3 enviados, 0 falhas), rodapé e cabeçalhos
`List-Unsubscribe`/`List-Unsubscribe-Post`/`Precedence` em cada e-mail, saída
pelo link no navegador e por One-Click, envio seguinte pulando opt-outs e
duplicado, reinscrição desfazendo o opt-out, funil, suspensão e reativação
pelo admin (o agendado volta a `agendado`), cancelamento — mais a **remoção de
um inscrito pelo gestor seguida de varredura de PII** no banco (0
ocorrências), o **`409 cota_insuficiente`** com a cota da escola em 1 e o
**painel de administração** de envios no `/config`.

**Achados do e2e da Fase 3:**

- Faltava um espaço na página de saída entre o nome da lista e "da escola"
  ("E2E 216 Ada escola") — **corrigido**.
- Concordância no contador de saídas: "1 saíram dos envios" — **corrigido**
  para "1 saiu".
- A taxa acesso → inscrição **pode passar de 100%**: inscrições feitas pela API
  sem abrir a página não somam acesso, e várias inscrições podem sair de um
  mesmo acesso. Documentado como comportamento, não defeito.

## Infraestrutura e lições

- **Guard da master key no Rexfile** (Fase 1): deploys sem
  `EDUMAPS_CONFIG_MASTER_KEY` gravavam a chave vazia nas units e deixavam todos
  os segredos ilegíveis, sem erro. Agora `deploy_backend_dev`,
  `deploy_minion_dev` e `deploy_analytics_worker_dev` abortam; dev usa uma
  chave só de teste fora do repositório.
- **Imagens Docker locais fazem parte do deploy**: `docker compose up` não
  reconstrói; `sqitch` obsoleto culpa o banco com `Cannot find change`, e
  `backend`/`minion` obsoletos servem código antigo em silêncio. Cada fase
  reconstruiu as imagens afetadas e conferiu por `md5sum`.
- **Dois bancos em `ubatexu.lan`**: `database.edumaps` (o do backend, alvo do
  `deploy_db_dev`) e `database.dev` (target `dev_super`). As medições de dados
  do ciclo foram feitas em `database.edumaps`.
- **`ci_db.sh` com `EDUMAPS_CI_PORT=5433`**: banco descartável + `sqitch verify`
  como gate, sem colidir com o Postgres do compose; testes no host exigem
  também `EDUMAPS_CONF=./t/ci/edu_maps.conf` e `env -u PERL5LIB`.
- **Disco do host** (Fase 0): o root do containerd foi movido para `/home`,
  porque o Docker 29 guarda imagens e build cache em `/var/lib/containerd`.
- **`deploy_db_dev` reinicia o PostgreSQL** — esperado, mas convém saber.
- **Dev sem SMTP real**: as Fases 2 e 3 dependem de e-mail; o código e o envio
  foram exercitados com transporte injetável nos testes e com Mailpit no e2e
  da Fase 3.

## Pendências e próximos passos

- **Envio por WhatsApp e Telegram** (template aprovado e custo no WhatsApp).
- **Vários QR por lista** e segmentação por origem do QR.
- **Modelos reutilizáveis** de mensagem e variáveis no texto (ex.: `{nome}`).
- **Nova tentativa automática** de falhas (com backoff) ou botão "Reenviar
  falhas".
- **E-mail em HTML** (hoje `text/plain`).
- **Consentimento 1.2** citando que a escola pode enviar avisos por e-mail
  (sugerido, não bloqueou a fase).
- **Direito de acesso e portabilidade** do titular.
- **Textos jurídicos** definitivos da política e do termo.
- **Teste com serviços reais**: provedor SMTP real (o e2e usou só captura),
  app real do Telegram e WhatsApp Cloud (credenciais externas).
- Listas dinâmicas sobre a agenda inteira (fora das listas) ficaram fora por
  decisão: só quem consentiu pelo QR.
