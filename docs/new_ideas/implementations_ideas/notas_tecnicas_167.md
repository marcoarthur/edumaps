# Nota técnica 167 — esqueci minha senha do gestor (#336)

PR #339 (merge `72f3101`, 2026-11-02). Fecha a série de autenticação aberta
depois do PR #333: notas 164 (cadastro só cria conta), 165 (Argon2id), 166
(limite de tentativas) e esta.

## Fluxo

1. `GET /api/gestor/senha/disponivel` — e-mail habilitado + SMTP + remetente
   + `canais.email.public_base_url`. Sem isso o link fica escondido.
2. `POST /api/gestor/senha/esqueci {email}` — 202 sempre, mesma mensagem;
   limites `reset_email` (3/h) e `reset_ip` (10/h) em `clean.auth_falhas`;
   se a conta existe, enfileira `gestor_senha_email [{gestor_id}]`.
3. Job: gera o token (32 bytes, base64url), invalida os pedidos anteriores,
   grava só o SHA-256 em `clean.senha_redefinicoes` (30 min), envia o link
   `<URL pública>/gestor/redefinir-senha#<token>`; o histórico do canal grava o
   corpo com o token mascarado.
4. `POST /api/gestor/senha/redefinir {token, senha}` — marca usado, grava
   Argon2id, apaga todas as sessões do gestor, zera as falhas de login do
   e-mail. Inválido, vencido e usado: mesma resposta (400); conta no
   `reset_ip`.

## Decisões

- **Job em vez de envio na requisição**: o tempo de resposta não revela se a
  conta existe, e o SMTP lento não prende a API.
- **Token nasce no job**: os argumentos ficam em `minion_jobs`; o token em
  claro não pode ir para lá.
- **Token no fragmento (`#`)**: não chega ao servidor no carregamento, não vai
  para logs nem para o Referer; a página o apaga da barra ao abrir.
- **URL pública por configuração**, nunca do cabeçalho `Host` (um atacante
  forjaria o Host e o e-mail apontaria para o site dele).
- **Encerrar todas as sessões** ao trocar: quem pediu porque perdeu o controle
  da conta tira o intruso junto.

## Achados

- 🔴→🟢 **E-mail com acento não saía por SMTP real.** `Channel::Email` mandava o
  envelope ao `Net::SMTP->datasend` como caracteres; com acento, "Wide
  character in syswrite". Atingia também a confirmação por código das
  inscrições ("confirmação"). Os testes usam transporte injetado e nunca
  passaram pelo Net::SMTP. Só apareceu com um SMTP de verdade (Mailpit). Agora
  em bytes UTF-8; teste novo pelo caminho real.
- **Testes de job × minion local**: com o minion do Docker de pé, ele pega os
  jobs que o teste enfileira (mesma fila, mesmo banco). O teste novo usa fila
  própria (`gestor_senha_fila`); `t/05-tasks/canais_envio.t` tem a mesma
  fragilidade (passa com o minion parado).
- `t/03-plugins/channel/config.t` apaga `canais.%` de `app_config.items` ao
  terminar — leva junto qualquer configuração de e-mail do banco local.
- `docker compose run sqitch` reinicia o `db`, e o minion local cai (mesma
  armadilha da memória `conferir-minion-apos-rebuild`).

## Ambiente de desenvolvimento

Mailpit local fora do compose: `docker run -d --name edumaps-mailpit --network
leaflet_default -p 127.0.0.1:8025:8025 axllent/mailpit:v1.20.0`; banco local
com `canais.email.smtp_host=edumaps-mailpit`, porta 1025, sem TLS, URL pública
`http://localhost:8080`. Mensagens na API `http://127.0.0.1:8025/api/v1/messages`.

## Pendências

- LXC: preencher SMTP e URL pública no Painel de Configuração para ativar.
- `canais_envio.t`: fila própria no teste, como aqui.
- `config.t`: restaurar o que havia em vez de apagar `canais.%`.
- ~~Limitador das inscrições por QR~~ — PR #340 (nota 168).
