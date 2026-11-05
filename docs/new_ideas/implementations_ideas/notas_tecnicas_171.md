# Nota técnica 171: limitador do bot do Telegram no banco

PR #343 (merge `8f6fafa`, 2026-11-05). Item do backlog pós-#342.

## O problema

O bot público do Telegram (confirmação de telefone das listas com QR) limita
cada conversa a 20 mensagens por minuto. A contagem vivia num hash em memória,
por processo:

- os workers do webhook e o minion do polling contavam cada um por si, então
  o limite real era 20 × número de processos;
- a contagem zerava a cada reinício;
- a limpeza só rodava acima de 10 mil conversas.

## Decisões

- **Mesmo mecanismo do login e das listas** (`AuthLimite` sobre
  `clean.auth_falhas`, janela deslizante). A change `auth_falhas_telegram` só
  amplia o CHECK do `escopo`; índice e retenção de 24h já existiam.
- **Chave = HMAC do chat_id com o segredo do app.** Em conversa privada o
  chat_id é o id do usuário no Telegram, um identificador pessoal; a tabela
  não o guarda legível.
- **Limite fixo em 20/60 s no código**, sem opção no painel: ninguém pediu
  para ajustar, e dá para expor depois sem migração.
- **Falha aberta.** Sem modelo, sem segredo ou com erro de banco, o bot
  responde (loga um aviso). Bloquear um usuário legítimo por falha interna é
  pior que deixar passar algumas mensagens a mais.
- O tratador recebe o segredo de quem o cria (controller do webhook e task de
  polling); o zerador `reset_rate_limit` dos testes saiu.

### Fila do `telegram_polling`

A instabilidade do `telegram_polling.t` (nota 170) tinha a mesma causa dos
testes de canais: o minion local pegava o job antes do `perform_jobs` do
teste. A task passou a usar `minion_fila` (padrão `default`); o reagendamento
fica na fila do job anterior e `ativo` filtra pela fila da task. O teste usa
`teste_$$` e apaga só os jobs dela — antes apagava todos os jobs
`telegram_polling` do banco, inclusive uma cadeia real do minion local.

## Validação

- Dois processos Perl separados, mesma conversa: 10 + 11 mensagens → só a
  21ª recusada; 20 linhas na tabela, nenhuma com o chat_id legível.
- Banco limpo: deploy, verify, `revert --to`, deploy de novo.
- Suíte completa com o minion de pé: config idêntica, nada sobrando,
  `telegram_polling.t` passa.

## Pendências

- `school/profile.t` intermitente (1 falha na suíte, 3 passes isolado).
- `admin/telemetry.t` conta sessões reais da janela de 24h: falha quando
  alguém usou a SPA local no dia.
- LXC (2026-11-09): `deploy_db_dev` (+ `auth_falhas_telegram`),
  `deploy_backend_dev`, `deploy_minion_dev`.
