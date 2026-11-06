# Nota técnica 176: fila própria para os jobs SIOPE dos testes

PR #PR_NUM (2026-11-06). Pendência da nota 175: cada suíte deixava ~5 jobs
`query_siope` na fila `default` do banco local, e o minion local os executava
contra a rede.

## De onde vinham

- **`gestor/finance_siope.t`** (município fictício 777777): enfileirava na
  `default` e removia o job logo depois. Quando o minion local pegava o job
  antes, o `remove_job` falhava: o teste caía e o job ficava, terminando em
  erro. **Era a causa de o teste estar entre as "falhas antigas"**: uma
  corrida com o minion, não dependência de dados.
- **`municipio.t`** (2302701, 1100015): pedir os detalhes da cidade aciona o
  middleware `SiopeTask`, que enfileira um SIOPE de verdade.
- **`05-tasks/siope.t`** (110001): baixa o SIOPE de propósito (precisa de
  rede; é pulado no CI). O primeiro subteste executava o job no próprio teste,
  mas na fila `default`, e disputava com o minion local.

## O que mudou

1. `EduMaps::Task::Siope`: o `get_siope` enfileira em
   `minion_fila($app, 'query_siope')`, mesmo padrão do polling do Telegram
   (nota 171). Sem `minion_filas` no config segue a `default`: nada muda no
   LXC nem em produção.
2. `finance_siope.t`: `minion_filas.query_siope = teste_$$`. O minion nunca
   pega o job, o `remove_job` sempre funciona, e o `END` apaga os jobs dessa
   fila.
3. `municipio.t`: `get_siope` vira stub (o teste é dos detalhes da cidade),
   como no `event_logger.t` (nota 175).
4. `siope.t`: o primeiro subteste usa fila própria e
   `perform_jobs({ queues => [fila] })`; o segundo, que acompanha o progresso
   pela API, continua dependendo do minion local. No fim, remove os jobs que
   criou e que não estejam rodando.

## Validação

- `finance_siope.t` três vezes seguidas com o minion local de pé: passa (antes
  falhava na suíte); nenhum job novo.
- `municipio.t`: nenhum job; só a falha antiga das feições OSM.
- `siope.t`: o primeiro subteste passa (antes falhava); o segundo mantém a
  falha antiga da conexão de progresso (SSE). O job dele, em execução no
  minion quando o teste termina, fica no banco.
- Imagens backend/minion reconstruídas; md5 do `Siope.pm` bate nos dois
  contêineres; minion estável.
- Banco limpo do CI: `finance_siope.t` passa; `municipio.t` e `siope.t` são
  pulados (rede).
- Suíte completa: `finance_siope.t` saiu da lista de falhas; a suíte deixa um
  único job `query_siope` (o do segundo subteste do `siope.t`, concluído pelo
  minion), contra ~5 antes; config idêntica.

## Deploy

`deploy_backend_dev` e `deploy_minion_dev` na fila do LXC de 2026-11-09 (o
comportamento não muda lá).
