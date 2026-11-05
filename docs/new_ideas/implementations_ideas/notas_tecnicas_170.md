# Nota técnica 170: portas no loopback e testes isolados do ambiente local

PR #342 (merge `1e071f2`, 2026-11-05). Ciclo de infra e testes do backlog
pós-#341.

## O problema

1. **Portas internas publicadas em todas as interfaces.** O compose expunha
   `3010` (backend) e `8000` (analytic) na rede local, além da porta de uso.
2. **A suíte apagava a config do ambiente local.** Testes de canais limpam
   faixas de `app_config.items` (`canais.%` etc.) e rodam contra o mesmo banco
   da stack. Cada rodada apagava o SMTP do Mailpit, e o "esqueci minha senha"
   sumia da tela de login até reconfigurar à mão.
3. **Testes de jobs disputavam a fila com o minion local.** Enfileiravam em
   `default`; o minion de pé pegava o job antes do `perform_jobs` do teste
   (`canais_envio.t`, `canais_retencao.t` e outros falhavam ao acaso).

## Decisões

### Portas

- `127.0.0.1:3010:3000` e `127.0.0.1:8000:8000`. O frontend (8080) continua
  aberto: é a porta de uso.
- Validado pelo IP da LAN (recusa em 3010/8000, 200 em 8080) e pelo loopback.

### `ConfigSnapshot` (t/lib)

- `guardar($dbh, @padroes)` fotografa as linhas (todas as colunas, `secret`
  como bytea) antes da primeira escrita; o `END` do módulo apaga as faixas e
  reinsere as linhas.
- **Ordem dos END:** o módulo é compilado antes do corpo do teste, então o
  `END` dele roda depois dos `END` do teste, ou seja, depois das limpezas
  próprias do teste.
- `bind_param(..., { pg_type => PG_BYTEA })` no `secret`: sem o tipo, bytes
  fora de UTF-8 são corrompidos. O teste `t/01-app/config_snapshot.t` muda as
  linhas num processo filho e confere a restauração com 256 bytes crus; falha
  se a restauração for desligada.
- Aplicado nos 27 testes que tocam a config (padrão `%`). Os snapshots
  manuais de `senha_redefinicao.t` e `limite_ip_real.t` saíram.
- Testes que dependiam de config vazia passaram a limpar o que precisam
  (`channel/config.t`, subteste de padrões).

### Fila Minion por task (`EduMaps::Util::MinionFila`)

- `minion_fila($app, $task)` lê `config->{minion_filas}{$task}`; sem
  configuração, `default` — produção e LXC não mudam.
- `gestor_senha_fila` (#339) segue como alias de `gestor_senha_email`.
- Reagendamentos de envio e retenção usam `$job->info->{queue}`: o job fica
  na fila onde nasceu.
- `CanaisRetencao::agendado` filtra pela fila da task; antes um job de teste
  em outra fila contava como "agendado".
- Os 5 testes de jobs usam `teste_$$` e apagam só os jobs dessa fila.

## Validação

- Suíte completa 2× seguidas com o minion local de pé: config idêntica antes
  e depois, nenhuma falha de canais/corrida, nenhum job `teste_*` sobrando.
- Falhas restantes são as conhecidas (dados e serviços externos).
- Imagens backend/minion reconstruídas, md5 confere, minion estável.

## Pendências fora do escopo

- Revisão do proxy do frontend e da lista de proxies confiáveis no ambiente
  Docker local (ciclo próprio).
- `t/05-tasks/telegram_polling.t` é instável (1 falha em 2 rodadas).
- `ALTER DEFAULT PRIVILEGES` do `edumaps_leitor` (nota 169) continua.
- LXC: o compose e `t/` não vão para lá; `backend/lib` mudou, então
  `deploy_backend_dev` + `deploy_minion_dev` entram na fila de domingo.
