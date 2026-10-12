# Nota técnica 110 — Confirmação de posse do telefone nas listas com QR (PR #213)

## Resumo

Fase 1 do roadmap das listas com QR (#212). A Fase 0 (#208) aceitava o
telefone sem validação; agora o gestor pode **exigir confirmação** numa lista,
e quem se inscreve prova, no próprio celular, que o número é seu:

- **Telegram** (caminho principal): deep link `t.me/<bot>?start=<ref>` → o bot
  pede "Compartilhar meu número" → o Telegram entrega o número da conta, já
  verificado por ele. Prova de posse **sem código**.
- **WhatsApp**: código de 6 dígitos por template de autenticação da Cloud API.

Entrega em 3 ondas (contratos congelados por onda no arquivo de execução), duas
trilhas paralelas (backend/db e frontend) e verificação independente do
coordenador a cada onda. PR #213, merge `8d5c502`.

## Decisões de design

- **Ref pública como capability.** 128 bits aleatórios (`gen_random_bytes(16)`),
  uso único, TTL 24h; no banco só `sha256(ref)`. Reinscrição de pendente
  invalida a ref anterior. A API pública nunca expõe ids internos.
- **Estado derivado, não coluna.** `confirmado` se `confirmado_em` não nulo;
  `pendente` se a lista exige; senão `nao_exigida`. Ligar a exigência numa
  lista com membros não reescreve nada.
- **Não destrutivo, como na Fase 0.** Número divergente vira `conflito` na
  inscrição; o membro continua pendente; nada é apagado. `concluir` é
  idempotente (preserva o primeiro `confirmado_em/via`).
- **Prova do Telegram:** `contact.user_id == from.id` (o contato é da própria
  conta) + número normalizado igual (tolerância ao `55`). O vínculo
  `chat ↔ ref` entre o `/start` e o contato é persistido
  (`telegram_chat_pendente`), sobrevivendo a reinício do worker.
- **Um tratador, dois transportes.** `Updates->handle($update)` é chamado pelo
  webhook (produção, `secret_token` comparado em tempo constante) e pela task
  Minion `telegram_polling` (dev, sem URL pública): `getUpdates` com long
  polling, offset persistido por update (nunca retrocede), lock por bot,
  reagendamento com backoff. São modos exclusivos; iniciar polling chama
  `deleteWebhook`.
- **Bot público dedicado** (`canais.telegram.*`), separado do bot de
  notificações internas — o público nunca alcança o canal de operação.
- **Polling da página com bucket próprio de rate limit** (60/min) — o limite do
  POST (10/min) quebraria a consulta a cada 3s; o cliente trata 429 como
  transitório.
- **Contrato público só acrescenta campos**: listas sem exigência recebem a
  resposta idêntica à Fase 0.

## Achado de infra

O Rexfile renderiza `EDUMAPS_CONFIG_MASTER_KEY` nas units a partir do ambiente
de quem faz o deploy (`$ENV{...} || ''`). Deploys sem a variável zeraram a
chave no servidor de dev e tornaram ilegíveis todos os segredos do AppConfig —
sem erro algum, só canais "indisponíveis". O defeito apareceu no e2e, quando o
canal Telegram não era oferecido. Correção: as tasks que renderizam units
abortam com a variável vazia; dev usa chave própria fora do repositório e as
chaves reais ficam só no deploy de nuvem.

## Validação

Backend 65 arquivos / 428 testes (6 pré-falhos idênticos no `main`), frontend
83 / 511, `sqitch verify` + revert/deploy, e2e CDP em dev com Telegram
simulado pelo webhook. Pendente: teste com o app real do Telegram e com o
WhatsApp Cloud (credenciais externas).
