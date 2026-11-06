# Nota técnica 174: testes sem depender do banco local

PR #346 (2026-11-06). Higiene de testes e do build local, sem mudança de
funcionalidade e sem deploy no LXC.

## Problemas

- **Build do frontend.** `frontend/` não tinha `.dockerignore`, então o
  contexto do build levava `edumaps/node_modules`. Um `npm ci` rodando ao
  mesmo tempo (vitest no container) mudava esse diretório no meio da leitura
  e quebrava o build, levando junto o build de backend/minion.
- **Telemetria apagada.** Quatro testes apagavam `event_store` e
  `session_tracking` inteiras no início e no fim: `session.t`, `event_logger.t`,
  `event_logger_buffer.t` e `session/events.t`. No Docker local isso zerava a
  telemetria a cada suíte.
- **Testes dependentes de dados.**
  - `admin/telemetry.t` conferia contagens absolutas; qualquer acesso real nas
    últimas 24h quebrava o teste.
  - `osm_query.t` esperava 0 feições OSM no município 3555406, mas o
    `t/05-tasks/osm.t`, quando roda com rede, grava as feições desse mesmo
    município.

## O que mudou

1. `frontend/.dockerignore`: fora do contexto `edumaps/node_modules`,
   `edumaps/dist`, `edumaps/coverage`, `edumaps/.vite` e `map_app` (legado, o
   Dockerfile não usa). O contexto caiu para ~73 kB.
2. Os testes de telemetria checam se as tabelas existem com `SELECT ... LIMIT 0`
   e apagam só o que criaram:
   - `session.t` e `session/events.t`: pelos `session_id` gerados no teste;
   - `event_logger.t`: pelas fontes e sessões fixas do teste. O evento de
     cidade leva um user agent com o PID, para não confundir com acessos
     reais a São Paulo;
   - `event_logger_buffer.t`: pelo tipo exclusivo `test.bulk.buffer`.
3. `admin/telemetry.t` lê o painel antes de semear e confere as contagens como
   diferença. Ordem do ranking, percentuais e taxas dos tours só são
   conferidos quando a janela estava vazia, como no CI, onde a cobertura
   continua completa. Os ids de gestor semeados não mudaram.
4. `osm_query.t` compara as feições que `from_db` devolve com as linhas
   salvas para a consulta (mesmo `digest`), em vez de exigir zero.

## Armadilha encontrada

No `telemetry.t`, a função de diferença lia `$base{$id}{$k}`. O Perl cria
`$base{$id}` ao ler (autovivificação), e o `%base` vazio passava a parecer
preenchido; no CI os blocos de tours eram pulados sem motivo. A leitura agora
usa `($base{$id} // {})->{$k}` e a decisão de pular é tomada antes.

## Validação

- Build da imagem do frontend e vitest em paralelo: os dois passaram
  (127 arquivos, 1147 testes).
- Banco limpo do CI (`EDUMAPS_CONF=./t/ci/edu_maps.conf`): telemetry.t sem
  nenhum bloco pulado, osm_query.t com 0 salvas, session.t, leitor_grants.t.
- Docker local com tráfego real: os cinco testes de telemetria duas vezes
  seguidas, com a telemetria do banco igual antes e depois.
- Suíte completa: `admin/telemetry.t` e `osm_query.t` saíram da lista de
  falhas; telemetria local preservada; config idêntica.

## Fica para depois

- `school/profile.t` intermitente (causa ainda não investigada).
- `event_logger.t` apaga todos os jobs `query_siope` no fim; não mexe na
  telemetria, mas também é limpeza global.
