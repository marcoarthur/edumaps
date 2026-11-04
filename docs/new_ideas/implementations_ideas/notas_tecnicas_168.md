# Nota técnica 168 — limitador das inscrições por QR com IP real

PR #340 (merge `738f2c8`, 2026-11-04). Pendência das notas 166 e 167.

## O problema

As oito rotas públicas das listas com QR (inscrição, consulta da confirmação,
código por WhatsApp e e-mail, exclusão, saída) usavam `rate_limit_check`:
contagem **em memória, por processo**, chaveada por `tx->remote_address` — que
atrás do nginx é o IP do nginx. Consequências:

- todos os visitantes dividiam a contagem: num evento com o QR no cartaz, 10
  inscrições por minuto bloqueavam todo mundo; um abusador não era separado;
- a contagem não valia entre os 2 workers Morbo do LXC e zerava a cada deploy;
- o `ip_anon` (HMAC do IP, auditoria LGPD) era o mesmo para todas as
  inscrições do dia.

## Decisões

- **IP real pelo mesmo utilitário do login** (`client_ip_app`, extraído do
  controller de pesquisas para `EduMaps::Util::ClientIP`): `X-Real-IP` só de
  proxy confiável, lista em `auth_limite.proxies_confiaveis`.
- **Contagem no Postgres** reaproveitando `clean.auth_falhas` (escopo novo
  `canais`, change `auth_falhas_canais`) e o papel `AuthLimite` (composto no
  modelo Canal). Chave = HMAC(segredo do app, `token|IP`). Janela deslizante
  com os mesmos `rate_max`/`rate_window_seconds` da config.
- `rate_limit_check` manteve a assinatura (+ `secret`, + `retry_after` na
  resposta); o controller ganhou `_rate_canais`, e `_render_too_many` envia
  `Retry-After`.

## Efeito nos testes

Com a contagem no banco, ela passa a atravessar execuções: testes com token
fixo (`'f' x 32`) recebiam 429 no primeiro pedido se o arquivo tinha rodado no
último minuto. E `rand` não resolve: o Test2 semeia pela data, então o
"aleatório" é igual o dia inteiro. Tokens agora de PID + relógio. O teste novo
restaura a config `canais.inscricao.*` que altera (deixá-la ligada quebrava o
`canal_listas.t`, que espera os padrões).

## Incidentes do ciclo

- `git stash` sem nada a guardar + `git stash pop` aplicou uma entrada antiga
  (`stash@{0}`, artefatos IBGE de outro branch). Limpo a pedido do developer;
  a entrada continua guardada. Lição: para comparar com o estado anterior,
  usar `git worktree`/`git show`, não stash, quando a árvore está limpa.
- A stack local caiu duas vezes por fora (parada externa e reboot do host);
  subida de novo e conferida (md5, minion estável, Mailpit).

## Pendências

- **Deploy no LXC** (fora do ar desde 2026-11-03): `rex prepare`,
  `deploy_db_dev` (changes `gestor_senha_redefinicao` já foi; agora
  `auth_falhas_canais`), `deploy_backend_dev`, `deploy_minion_dev`.
- Limitador do bot do Telegram (em memória, por chat) — fora deste escopo.
