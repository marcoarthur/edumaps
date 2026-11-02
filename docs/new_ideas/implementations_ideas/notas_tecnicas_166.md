# Nota técnica 166 — limite de tentativas de login e cadastro do gestor (#335)

PR #338 (merge `b2fd020`, 2026-11-02). Terceira etapa da série de
autenticação (notas 164 e 165); falta a #336 (esqueci minha senha).

## Achados que mudaram o desenho

1. **O limitador existente não servia.** As inscrições por QR têm um
   `rate_limit_check` em memória do processo, por `tx->remote_address` — que
   atrás do nginx é o IP do nginx: todos os visitantes dividem a contagem.
2. **A API escuta direto** (`0.0.0.0:3000` no LXC; 3010 no Docker local),
   além de via nginx. `X-Real-IP` é forjável por quem conecta direto.
3. **Morbo com 2 processos no LXC** (e reinícios a cada deploy): contagem em
   memória não vale.

## Decisões

- **Contagem no Postgres**, janela deslizante: `clean.auth_falhas` (uma linha
  por tentativa que conta; escopos `email`, `ip`, `cadastro_ip`). Bloqueado
  com `max` linhas na janela; `Retry-After` = quando a mais antiga dessas `max`
  sai. Linhas com mais de 24 h são apagadas a cada registro.
- **Sem dado pessoal legível**: a chave é HMAC-SHA256 (segredo da aplicação)
  do e-mail em minúsculas ou do IP.
- **Bloqueio antes da senha**: a senha certa durante o bloqueio também recebe
  429 — senão o bloqueio só atrasaria quem acerta.
- **Limites** (config `auth_limite`): login 10/e-mail e 50/IP em 15 min
  (IP folgado: escola com vários gestores atrás de um IP); cadastro 20/IP por
  hora (o 409 revela e-mail existente).
- **Tempo constante**: conta inexistente verifica contra um hash Argon2id
  fictício (calculado uma vez por processo). Medido: mediana 76 ms × 76 ms
  (senha errada). Fecha a enumeração por tempo anotada na nota 165.
- **IP do cliente** (`EduMaps::Util::ClientIP`): `X-Real-IP` só quando o par
  é proxy confiável. Padrão: loopback + redes privadas; configurável em
  `auth_limite.proxies_confiaveis`. No LXC, só loopback — a primeira versão
  confiava nas redes privadas, e de dentro da rede do LXC ainda dava para
  forjar o IP; a checagem ao vivo foi feita depois da correção.
- **Suíte de testes**: `t/lib/Imports.pm` liga `EDUMAPS_AUTH_LIMITE_OFF`
  (dezenas de cadastros saem de 127.0.0.1); `login_limite.t` o remove e testa
  os limites com valores pequenos. Nunca usar a variável fora dos testes.

## Verificação ao vivo (LXC)

- Pelo nginx: 10 × 401 e 429 na 11ª, `Retry-After: 896`.
- Direto na 3000, `X-Real-IP` diferente a cada pedido: 50 × 401 e 429 — o IP
  forjado não escapa.

## Pendências

- Limitador das inscrições por QR (`rate_limit_check`): passar a usar
  `client_ip` e contagem fora da memória.
- Docker local: a porta 3010 publicada aceita `X-Real-IP` forjado vindo da
  rede do Docker (só ambiente de desenvolvimento).
- #336 — esqueci minha senha (usa este limite nos pedidos).
