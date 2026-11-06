# Cobertura E2E (browser real via CDP)

Fluxos e2e da SPA EduMaps. Para **cada feature**:
1. `browser_navigate` → rota correspondente;
2. carregar e assertar o conteúdo-chave;
3. interagir no fluxo principal (quando houver);
4. registrar `PASS`/`FAIL` (com data e observação).

**Legend**: · ainda não executado · 🟢 PASS · 🔴 FAIL · ⚪ planejado (pré-requisito ausente)

## Rodada 2026-11-06 (aj) (IGE em 0..1 e lote 1 das falhas antigas)

Branch `fix/ige-e-testes-locais`. Backend e testes; sem mudança de tela.

| Verificação | Onde | Resultado |
|---|---|---|
| `ige.t` novo: falha sem a correção, passa com ela | prove | 🟢 |
| `domain/quality.t`, `City.t`, `escola_influencia.t`, `indicators.t`, `admin/telemetry.t` passam no local | prove | 🟢 |
| Banco limpo do CI: `escola_influencia.t`, `ige.t`, `indicators.t`, `telemetry.t` (três rotas conferidas) | prove | 🟢 |
| Imagens backend/minion reconstruídas, md5 do `IGE.pm` bate, minion estável | docker | 🟢 |
| Suíte completa: 18 → 15 falhas (grupos C, D e E); config idêntica | prove + psql | 🟢 |

## Rodada 2026-11-06 (ai) (caminho até o Perfil da Rede)

Branch `fix/frontend-perfil-da-rede`. Docker local (`localhost:8080`).

| Verificação | Onde | Resultado |
|---|---|---|
| Comparação de redes: linha **Ver perfil analítico** com uma rede por botão e **Todas as redes** | navegador (validação do usuário) | 🟢 |
| Link de cada rede abre o Perfil da Rede filtrado; **Todas as redes** sem filtro | navegador (validação do usuário) | 🟢 |
| **← Voltar** do perfil volta à comparação com o município preenchido | navegador (validação do usuário) | 🟢 |
| vitest: 127 arquivos, 1151 testes (4 novos) | Docker | 🟢 |
| Imagem do frontend reconstruída; texto novo no bundle servido | docker | 🟢 |

## Rodada 2026-11-06 (ah) (CI do backend de volta)

Branch `fix/ci-cpanfile-mime-base64`. Só `backend/cpanfile`.

| Verificação | Onde | Resultado |
|---|---|---|
| Inventário de dependências: falhava desde o #339 (`MIME::Base64` não declarado) e pulava a suíte | GitHub Actions | 🟢 |
| Suíte no runner `ubuntu-26.04`: `Test2::V1` (usado por `t/lib/Imports.pm`) ausente no Perl da imagem; declarado nas deps de teste | GitHub Actions | 🟢 |
| `backend-tests` completo: 171 arquivos, 1241 testes, `Result: PASS` | GitHub Actions | 🟢 |

## Rodada 2026-11-06 (ag) (fila própria para os jobs SIOPE dos testes)

Branch `fix/siope-fila-testes`. Backend (fila do job configurável) e testes;
sem mudança de tela.

| Verificação | Onde | Resultado |
|---|---|---|
| `finance_siope.t` três vezes com o minion local de pé, sem job novo | prove + psql | 🟢 |
| `municipio.t` sem job SIOPE (só a falha antiga das feições OSM) | prove + psql | 🟢 |
| `siope.t`: primeiro subteste passa com fila própria; segundo mantém a falha antiga do SSE | prove | 🟢 |
| Banco limpo do CI: `finance_siope.t` passa | prove | 🟢 |
| Imagens backend/minion reconstruídas, md5 do `Siope.pm` bate, minion estável | docker | 🟢 |
| Suíte backend completa: `finance_siope.t` saiu da lista; 1 job SIOPE por suíte (antes ~5); config idêntica | prove + psql | 🟢 |

## Rodada 2026-11-06 (af) (profile.t e event_logger.t independentes)

Branch `test/testes-independentes`. Só testes; sem mudança de tela e sem
deploy.

| Verificação | Onde | Resultado |
|---|---|---|
| `profile.t` com a escola 99999999 no banco (sobra simulada): antiga falha, nova passa | prove + psql | 🟢 |
| Coordenadas: latitude -100 reprovada (antes passava) | perl | 🟢 |
| `event_logger.t` duas vezes: jobs `query_siope` iguais; stub chamado | prove + psql | 🟢 |
| Banco limpo do CI: `profile.t` e `event_logger.t` | prove | 🟢 |
| Suíte backend completa: só as falhas antigas; config idêntica | prove + psql | 🟢 |

Sem a limpeza global, a suíte deixa ~5 jobs `query_siope` de outros testes
no banco local (pendência na nota 175).

## Rodada 2026-11-06 (ae) (testes sem depender do banco local)

Branch `test/higiene-testes-locais`. Só testes e o build local; sem mudança
de tela e sem deploy no LXC.

| Verificação | Onde | Resultado |
|---|---|---|
| Build da imagem do frontend e vitest em paralelo (127 arquivos, 1147 testes) | Docker | 🟢 |
| Contexto do build do frontend sem `node_modules` (~73 kB) | Docker | 🟢 |
| Banco limpo do CI: `telemetry.t` sem bloco pulado, `osm_query.t`, `session.t`, `leitor_grants.t` | prove | 🟢 |
| Cinco testes de telemetria duas vezes com tráfego real: telemetria igual antes e depois | prove + psql | 🟢 |
| Suíte backend completa: sem `admin/telemetry.t` e `osm_query.t` na lista; telemetria preservada; config idêntica | prove + psql | 🟢 |
| Frontend recriado com a imagem nova; minion estável | docker | 🟢 |

## Rodada 2026-11-05 (ad) (permissões explícitas do papel de leitura)

Branch `fix/db-leitor-grants-explicitos`. Só banco e teste; sem mudança de
tela. LXC fora do ar, validação no Docker local e no banco do CI.

| Verificação | Onde | Resultado |
|---|---|---|
| Change `leitor_grants_explicitos`: deploy e verify no Docker local | sqitch | 🟢 |
| Tabela nova em `clean` nasce sem leitura do papel; em `analytics`, com leitura | psql | 🟢 |
| `leitor_grants.t` falha antes da change e com uma tabela esquecida; passa depois | prove | 🟢 |
| Banco limpo do CI: deploy, verify, teste, revert `--to`, deploy e verify de novo | sqitch + prove | 🟢 |
| Gate `ci_db.sh verify` | CI local | 🟢 |
| Suíte backend completa: config idêntica; só as falhas antigas | prove + psql | 🟢 |

`t/osm_query.t` falhou por depender dos dados locais (espera 0 feições OSM no
município de teste; o banco local tem 618). Não usa o papel de leitura.

## Rodada 2026-11-05 (ac) (revisão do proxy do frontend no Docker local)

Branch `fix/infra-proxy-local`. Stack recriada com a rede nova
(`172.30.0.0/24`, frontend em `172.30.0.10`); Mailpit religado à rede.

| Verificação | Onde | Resultado |
|---|---|---|
| nginx do frontend só com as rotas em uso (SPA e `/api/`) | curl | 🟢 |
| Backend → motor R pela rede interna | docker exec | 🟢 |
| Lista de proxies confiáveis do backend com o IP do frontend | docker exec | 🟢 |
| IP registrado na sessão: 3010, 8080 e pela LAN, conforme esperado | curl + psql | 🟢 |
| "Esqueci minha senha" → e-mail no Mailpit pela rede nova | curl + Mailpit | 🟢 |
| Login, `/me`, logout pela 8080 (conta de teste local) | curl | 🟢 |
| `session.t`: subteste novo passa com a correção e falha sem ela | prove | 🟢 |
| vitest: 127 arquivos, 1147 testes | Docker | 🟢 |
| Suíte backend completa: config idêntica, sem jobs `teste_*`; só as falhas antigas | prove + psql | 🟢 |
| Imagens frontend/backend/minion reconstruídas, md5 de `Session.pm` bate, minion sem reinícios | docker | 🟢 |

Sessões e token de redefinição criados na validação foram apagados.

## Rodada 2026-11-05 (ab) (limitador do bot do Telegram no banco)

Branch `fix/telegram-limite-banco`. Só backend e banco; LXC fora do ar,
validação no Docker local.

| Verificação | Onde | Resultado |
|---|---|---|
| Change `auth_falhas_telegram`: deploy + verify no banco local | sqitch | 🟢 |
| Banco limpo (CI): deploy, verify, `revert --to leitor_sem_tabelas_sensiveis`, deploy de novo | `ci_db.sh` + sqitch | 🟢 |
| Dois processos Perl separados, mesma conversa: 10 + 11 mensagens → só a 21ª recusada | script + banco local | 🟢 |
| Registros do limitador: 20 linhas, chave HMAC, nenhuma com o chat_id legível; limpos depois | psql | 🟢 |
| `telegram_updates.t` (contagem comum a dois tratadores, tratador novo segue bloqueado, sem segredo não bloqueia), `telegram_webhook.t`, `telegram_polling.t` | prove | 🟢 |
| `telegram_polling.t` em fila própria: não falha mais com o minion local de pé | prove (suíte) | 🟢 (antes instável) |
| Suíte completa com o minion de pé: config idêntica antes/depois, nenhum job `teste_*` nem registro `telegram` sobrando | prove + psql | 🟢 |
| Imagens backend/minion reconstruídas, md5 de `Updates.pm` e `TelegramPolling.pm` bate, minion estável 7 min, 0 reinícios | docker | 🟢 |

Restantes na suíte: as mesmas antigas da rodada (z). `school/profile.t`
falhou uma vez na suíte e passou 3× isolado (intermitente, fora desta mudança).
`admin/telemetry.t` falhou isolado por uma sessão anônima real da SPA local
nas últimas 24h (depende dos dados).

## Rodada 2026-11-05 (z) (portas no loopback, config restaurada, fila própria nos testes)

Branch `fix/infra-testes-isolados`. Só infraestrutura local e testes; LXC não
envolvido. Banco local com a config do Mailpit recolocada (8 chaves).

| Verificação | Onde | Resultado |
|---|---|---|
| `docker compose port`: backend `127.0.0.1:3010`, analytic `127.0.0.1:8000` | compose | 🟢 |
| Pelo IP da LAN: 3010 e 8000 recusam; 8080 responde 200 | curl | 🟢 |
| Pelo loopback: 3010 e 8000 respondem | curl | 🟢 |
| SPA pelo nginx: `/api/gestor/senha/disponivel` → `disponivel: 1` | curl | 🟢 |
| `ConfigSnapshot`: processo filho apaga/altera/cria; pai vê as linhas de volta, segredo bytea íntegro (falha com a restauração desligada) | prove `config_snapshot.t` | 🟢 |
| Suíte completa 2× seguidas com o minion local de pé: `app_config.items` idêntica antes/depois (md5 de valor+segredo e metadados) | prove + psql | 🟢 |
| Sem falhas de disputa: `canais/envios.t`, `admin/envios.t`, `admin/retencao.t`, `05-tasks/canais_envio.t`, `05-tasks/canais_retencao.t` | prove | 🟢 (antes falhavam na suíte) |
| Nenhum job sobra em filas `teste_*` | psql | 🟢 |
| Imagens backend/minion reconstruídas, md5 bate, minion estável > 40 s | docker | 🟢 |

Restantes na suíte (antigas, dados/serviços externos): `City.t`, `quality` (3),
`03-plugins/analytics.t`, `finance_siope.t`, `municipio.t`, `network/schools.t`,
`05-tasks` de analytics/OSM/SIOPE, `analysis/rpipe.t`, `dbic/inject*`,
`escola_influencia.t`. `telegram_polling.t` instável (falhou 1 de 2).

## Rodada 2026-11-04 (y) (sessão do gestor com hash; leitura do Assistente só no curado)

Branch `fix/backend-sessao-hash`. LXC fora do ar até 2026-11-09: validação no
Docker local (`localhost:8080`). Conta de gestor descartável criada pela API e
apagada no fim; token injetado no `localStorage` (sem digitar credenciais).

| Verificação | Onde | Resultado |
|---|---|---|
| Login pelo nginx devolve token de 64 hex; banco tem só o SHA-256 (busca pelo token em claro → 0) | API (curl) + psql | 🟢 |
| Com o token: "Você já está logado", Painel do Gestor e Reuniões (rota com sessão) carregam | SPA | 🟢 |
| "Sair" → `POST /api/gestor/logout` 204, sessão removida do banco, tela volta ao login | SPA + psql | 🟢 |
| Sessão anterior à migration (uuid convertido em hash) segue válida na SPA | SPA | 🟢 |
| `edumaps_leitor`: `permission denied` em `clean.sessoes`; segue lendo `clean.censo_escolas` | psql (`SET ROLE`) | 🟢 |
| Validador do Assistente no container `analytic`: recusa `clean.sessoes`, aceita `clean.censo_escolas` (nenhuma pergunta enviada ao Assistente) | Rscript | 🟢 |
| Banco de CI do zero: deploy, verify, revert `--to auth_falhas_canais` (devolve o grant) e redeploy convertendo uma sessão uuid | `ci_db.sh` + sqitch | 🟢 |
| `sessao_hash.t` + gestor/pesquisa/admin/canais; suíte R (2113, 0 falhas) | prove / testthat | 🟢 só as falhas antigas |

## Rodada 2026-11-04 (x) (limitador das inscrições por QR com IP real)

Branch `fix/canais-limite-ip-real`. **LXC fora do ar** (SSH em timeout desde
2026-11-03): validação no Docker local; deploy no LXC quando voltar. Lista e
QR descartáveis criados no banco local, config `canais.inscricao.*` salva e
restaurada no fim.

| Verificação | Onde | Resultado |
|---|---|---|
| Pelo nginx local, `rate_max=2`: inscrições 1 e 2 → 201, a 3ª → 429 | API (curl) | 🟢 |
| Pelo nginx com `X-Real-IP` forjado → 429 `Retry-After: 60` (o nginx sobrescreve o cabeçalho) | API (curl) | 🟢 |
| `ip_anon` preenchido e igual para o mesmo visitante (antes: igual para todos) | psql | 🟢 |
| Visitantes diferentes atrás do proxy têm contagens separadas; forjado de par não confiável ignorado; contagem vale para outro processo; `ip_anon` diferente por IP | prove `limite_ip_real.t` | 🟢 (falha sem o fix) |
| Lote canais + modelos + gestor, duas rodadas seguidas | prove (38 arquivos) | 🟢 só as falhas antigas (`canais/envios.t`, `finance_siope.t`) |

Achado: com a contagem no banco, testes com **token fixo** (`'f' x 32`) herdavam
a contagem da execução anterior (janela de 60 s); e o `rand` do Test2 tem
semente fixa pela data. Tokens agora de PID + relógio.

## Rodada 2026-11-02 (w) (esqueci minha senha do gestor, #336)

Branch `feat/gestor-esqueci-senha`. LXC: banco, backend, minion e frontend
(sem SMTP configurado → link escondido, `disponivel: 0`). Fluxo completo no
**Docker local** com um **Mailpit** (`axllent/mailpit:v1.20.0`, UI em
`127.0.0.1:8025`) e `canais.email.*` + URL pública só no banco local. Conta
de teste descartável criada pela API e apagada no fim.

| Verificação | Onde | Resultado |
|---|---|---|
| “Esqueci minha senha” aparece no login com e-mail configurado; escondido sem | Chrome / LXC | 🟢 |
| Pedido → mensagem genérica (“Se houver uma conta…”) | Chrome | 🟢 |
| 1ª tentativa: job falhou com “Wide character in syswrite” — **e-mail com acento não saía por SMTP real** (defeito do canal, também na confirmação por código) | Mailpit | 🔴→🟢 envelope em bytes UTF-8 |
| E-mail recebido com acentos, link e validade; histórico com o token mascarado | Mailpit + psql | 🟢 |
| Link abre a página e o token sai da barra de endereço | Chrome | 🟢 |
| Senha nova salva → “Senha alterada.” | Chrome | 🟢 |
| Senha antiga 401, nova 200, link reutilizado 400 “não vale mais”, token não está em claro no banco | API + psql | 🟢 |
| Resposta igual com/sem conta, job sem token, hash só, pedido novo invalida, vencido, sessões encerradas, limites | prove `senha_redefinicao.t` | 🟢 (fila própria: o minion local de pé pegava os jobs) |
| Net::SMTP recebe bytes (acentos e símbolo) | prove `email_smtp_utf8.t` | 🟢 (falha sem o fix) |
| Páginas e link | vitest | 🟢 127 arquivos / 1147 testes |

Achado lateral: `t/05-tasks/canais_envio.t` falha quando o minion local está de
pé (disputa a mesma fila); com o minion parado, passa. Já existia.

## Rodada 2026-11-02 (v) (limite de tentativas de login, #335)

Branch `fix/login-limite-tentativas`, banco e backend em `ubatexu.lan`. Só API
(sem mudança de tela). As linhas de `clean.auth_falhas` criadas pela checagem
foram apagadas no fim (120).

| Verificação | Onde | Resultado |
|---|---|---|
| Pelo nginx: 10 falhas com e-mail inexistente, a 11ª | API | 🟢 429, `Retry-After: 896`, “Tente de novo em 15 minutos.” |
| Direto na 3000 (dentro do LXC), `X-Real-IP` forjado e diferente a cada pedido: 50 falhas, a 51ª | API | 🟢 429 — o IP forjado não escapa |
| Config do LXC com `proxies_confiaveis => ['127.0.0.1/32', '::1']` | edu_maps.conf | 🟢 |
| Coluna `chave` só com HMAC | psql | 🟢 0 em claro |
| E-mail inexistente × senha errada (mediana de 15) | Test::Mojo local | 🟢 76 ms × 76 ms |
| Bloqueio por e-mail (inclusive com a senha certa), janela, acerto zera, soma por IP, e-mail sem conta, cadastro por IP, proxies do config | prove `login_limite.t` | 🟢 (falha sem o fix) |
| IP do cliente (redes, cabeçalho forjado/malformado) | prove `t/01-app/client_ip.t` | 🟢 |
| 429 na tela de acesso | vitest `GestorAcessoPage.test.js` | 🟢 5/5 |
| Arquivos que usam cadastro/login | prove (28 arquivos) | 🟢 só as 5 falhas antigas |

## Rodada 2026-11-02 (u) (senha do gestor em Argon2id, #334)

Branch `fix/senha-gestor-argon2`, banco e backend em `ubatexu.lan`. Conta de
teste descartável criada pela API e removida no fim. Só API (sem mudança de
tela).

| Verificação | Onde | Resultado |
|---|---|---|
| Custo por hash no `backend.edumaps`: 19 MiB/t=2 = 22 ms; 64 MiB/t=3 = 128 ms (escolhido) | carton exec | 🟢 |
| Cadastro grava `$argon2id$v=19$m=65536,t=3,p=1` | API + psql | 🟢 |
| Conta no formato antigo (HMAC) entra e é regravada em Argon2id no 1º login | API + psql | 🟢 |
| Senha errada | API | 🟢 401 |
| Tempo do login completo | API | 🟢 0,16–0,25 s |
| Comentário da coluna (change `gestores_senha_argon2id`) | psql | 🟢 |
| Novo formato, conversão, senha errada não converte, custo baixo é regravado, formato desconhecido recusado | prove `t/04-api/pesquisa.t` | 🟢 15/15 (falha sem o fix) |
| Arquivos que usam cadastro/login | prove (27 arquivos) | 🟢 só as 5 falhas antigas (iguais sem a mudança) |

## Rodada 2026-11-02 (t) (cadastro do gestor e pesquisas com sessão)

Branch `fix/gestor-cadastro-e-pesquisas`, banco, backend e frontend em
`ubatexu.lan`. Conta de teste descartável criada pela API e removida no fim;
no navegador, só leitura (o assistente não recebeu texto, para o autosave não
criar rascunho).

| Verificação | Onde | Resultado |
|---|---|---|
| Sem sessão: listar, criar e excluir pesquisa | API (curl) | 🟢 401 |
| Recadastro do mesmo e-mail, em outra caixa e com outra senha | API (curl) | 🟢 409, senha original segue valendo, a nova não |
| Índice `uq_gestores_email_lower` em `database.edumaps` | psql | 🟢 |
| Lista de pesquisas logado, sem `?inep`: escola da sessão | Chrome | 🟢 |
| “+ Nova pesquisa” abre em “Dados da pesquisa”, sem “Seus dados” | Chrome | 🟢 |
| Cadastro só cria; admin intacto; escopo por escola (401/403/404) | prove `t/04-api/pesquisa.t` | 🟢 14/14 (falha sem o fix) |
| Arquivos que criam gestor pelo cadastro | prove (25 arquivos) | 🟢 sem regressão (só falhas antigas) |
| Suíte frontend | vitest | 🟢 126 arquivos / 1136 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (s) (exportar respeita a busca)

Branch `feat/historico-exportar-busca`, backend e frontend em `ubatexu.lan`.
Download suprimido na página (fetch interceptado, `<a download>` desligado):
nenhum arquivo baixado.

| Verificação | Onde | Resultado |
|---|---|---|
| Busca “escolas”: botão “Exportar as da busca (.md)”, `q=escolas`, arquivo com as 5 conversas mostradas | Chrome | 🟢 |
| Busca “Tancredo”: tela mostra 3, arquivo traz exatamente as mesmas 3 | Chrome | 🟢 |
| Nome `conversas-busca-2026-11-02.md` às 22:47 de 01/11 (data do relógio UTC do servidor) | Chrome | 🔴→🟢 `conversas-busca-2026-11-01.md` |
| Export por `q` (falha sem o fix), sem `q` = tudo, busca vazia = arquivo vazio, `q` > 200 = 400, data do nome no `tz` | prove `t/04-api/chat/conversas.t` | 🟢 17/17 |
| Rótulo e termo (aparado) no pedido | vitest `ChatHistoricoPage.test.js` | 🟢 |
| Suíte frontend | vitest | 🟢 125 arquivos / 1134 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (r) (exportar respeita o dia escolhido)

Branch `feat/historico-exportar-dia`, backend e frontend em `ubatexu.lan`. O
download foi **suprimido na página** (clique do `<a download>` desligado por
script): só o pedido à API e a resposta foram lidos, nenhum arquivo baixado.

| Verificação | Onde | Resultado |
|---|---|---|
| Dia 26/09: botão vira “Exportar as do dia (.md)”; `all=1&from=to=2026-09-26&tz`; arquivo `conversas-2026-09-26.md` com as 3 conversas do dia | Chrome | 🟢 |
| Dia 25/09: a conversa das 23:03 vinha com “Data: 2026-09-26 02:03:39.129883+00” (UTC cru) dentro do arquivo do dia 25 | Chrome | 🔴→🟢 “Data: 25/09/2026 23:03” |
| Export por dia (fuso local), arquivo com o dia, datas legíveis no fuso, sem tz = UTC marcado, 400 em data/fuso inválidos (falha sem o fix) | prove `t/04-api/chat/conversas.t` | 🟢 16/16 |
| Rótulo do botão, dia e fuso no pedido; fuso também no export de uma conversa | vitest `ChatHistoricoPage.test.js` | 🟢 |
| Suíte frontend | vitest | 🟢 125 arquivos / 1133 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (q) (trecho e contagem na busca do histórico)

Branch `fix/historico-busca-trecho`, backend e frontend em `ubatexu.lan`. Só
leitura (buscar não grava nada).

| Verificação | Onde | Resultado |
|---|---|---|
| Busca “escolas”: 5 resultados, um por conversa; termo em `<mark>` (3, 2, 2, 1, 2 destaques); nenhum `<b>`/`**` cru | Chrome | 🟢 |
| Contagem nos resultados (“6 mensagens”, “2 mensagens”…), antes vazia | Chrome | 🟢 |
| Uma linha por conversa, `msg_count`, trecho sem marcação, partes com destaque (falha sem o fix) | prove `t/04-api/chat/conversas.t` | 🔴→🟢 15/15 |
| Destaque com `<mark>`; `<b>` do conteúdo fica texto, nunca HTML | vitest `ChatHistoricoPage.test.js` | 🟢 |
| Suíte frontend | vitest | 🟢 125 arquivos / 1130 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (p) (busca única no histórico)

Branch `fix/frontend-historico-busca-unica`, em `ubatexu.lan`. Só leitura.

| Verificação | Onde | Resultado |
|---|---|---|
| Um só campo de busca (o da página); a barra da lista só seleciona e exporta | Chrome | 🟢 |
| Busca “escolas” traz as conversas com trecho; “burro” (só no título) não traz nada | Chrome | 🟢 (busca é no texto das mensagens; documentado) |
| Trecho do resultado com `<b>…</b>` e `**…**` crus; contagem de mensagens vazia | Chrome | 🔴 pré-existente, documentado |
| Um campo; busca filtra pelo servidor; paginação some com busca ativa | vitest `ChatHistoricoPage.test.js` | 🟢 8/8 |
| Suíte frontend | vitest | 🟢 125 arquivos / 1129 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (o) (filtro por dia no histórico do Assistente)

Branch `feat/frontend-historico-filtro-dia`, backend e frontend em
`ubatexu.lan`, sessão de gestor já aberta. Só leitura (filtrar não grava nada).

| Verificação | Onde | Resultado |
|---|---|---|
| Calendário conta o dia no fuso do navegador: conversa de 25/09 23:03 (local) marcada no 25, não no 26 (UTC) | Chrome | 🟢 |
| Clicar no 25: só “noturno” (25/09 23:03); aviso “Mostrando… 25/09/2026”; dia com `aria-pressed` | Chrome | 🟢 |
| Clicar no 26: as 3 conversas que o número indica, todas “Criada em 26/09” | Chrome | 🟢 |
| Clicar de novo no 26: volta às 5, sem aviso | Chrome | 🟢 |
| Antes: `to=<dia>` cortava o próprio dia (lista vazia no dia marcado) | prove `t/04-api/chat/conversas.t` (falha sem o fix) | 🔴→🟢 |
| `tz` no calendário e na lista; fuso inválido → 400; sem `tz` = UTC | prove | 🟢 14/14 |
| Ver todas, dia vazio, busca × dia (se excluem), fuso enviado | vitest `ChatHistoricoPage.test.js` | 🟢 6/6 |
| Suíte frontend | vitest | 🟢 125 arquivos / 1127 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (n) (telas secundárias — lote B)

Branch `feat/frontend-tour-secundarias-b`, em `ubatexu.lan`, com a sessão de
gestor já aberta (escola 35070212, sem perfil admin). Só leitura: tours abertos
por `?tour=` e pelo “?”, nada salvo ou excluído.

| Verificação | Onde | Resultado |
|---|---|---|
| Meus relatórios (`/gestor/relatorios/salvos`, 1 salvo): 2/2 alvos | Chrome | 🟢 |
| Relatório salvo (`/salvos/12`, pelo “?”): fotografia, gerar de novo, imprimir/baixar — 3/3 | Chrome | 🟢 |
| Histórico do Assistente (`/chat/historico`, 5 conversas): 3/3 alvos | Chrome | 🟢 |
| Rodapé do calendário dizia “Clique para filtrar” (clicar só destaca o dia) | Chrome | 🔴→🟢 (texto corrigido) |
| Versões do consentimento: admin com alvos; “restrita” e sem sessão não abrem | vitest `features/config/pages/tourAlvos.test.js` | 🟢 |
| Lista vazia/com itens, detalhe, inexistente e sem sessão; histórico sem sessão e com 401 | vitest | 🟢 |
| Suíte frontend | vitest | 🟢 123 arquivos / 1118 testes |

> **Não coberto no Chrome:** versões do consentimento — a sessão não é admin.

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (m) (telas secundárias — lote A)

Branch `feat/frontend-tour-secundarias`, em `ubatexu.lan`, com a sessão de
gestor já aberta (escola 35070212; sem injeção de credencial). Só leitura:
nenhum clique fora do quadro do tour, nada digitado ou salvo.

| Verificação | Onde | Resultado |
|---|---|---|
| Assistente de reunião (`/gestor/reunioes/nova`): abre sozinho, 3/3 alvos | Chrome | 🟢 |
| Assistente de pesquisa (`/nova?inep=`): abre sozinho na 1ª tela de identidade, 2/2 alvos | Chrome | 🟢 |
| Passo 2 de pesquisa falava só de “Dados da pesquisa” sobre a tela de identidade | Chrome | 🔴→🟢 (texto cobre as duas) |
| Resultados, detalhe de reunião e de relação: alvos × markup | vitest `tourAlvosSecundarias.test.js` | 🟢 |
| Colisão `/reunioes/nova` × `/reunioes/:id`: catálogo escolhe o tour certo (nova, 51, 51/editar) | vitest | 🟢 |
| Suíte frontend | vitest | 🟢 123 arquivos / 1100 testes |

> **Não coberto no Chrome:** detalhe de reunião, detalhe de relação e
> resultados — a escola da sessão não tem reuniões, relações nem pesquisa
> publicada; criar dados seria escrita na conta do developer.

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (l) (tour do Painel de Configuração)

Alvo `http://ubatexu.lan:8080/config` (branch `feat/frontend-tour-config`).

| Verificação | Onde | Resultado |
|---|---|---|
| Sessão de gestor **sem** perfil admin: “restrita”, sem grade, nenhum tour, sem “?”, nada marcado | Chrome (sessão existente) | 🟢 |
| Admin com dados: `prontoQuando` e os 3 alvos existem | vitest `features/config/pages/tourAlvos.test.js` | 🟢 |
| “Restrita” e sem sessão: não abre | vitest | 🟢 2/2 |
| Suíte frontend | vitest | 🟢 122 arquivos / 1076 testes |

> **Não coberto pelo agente:** o tour visível com perfil de administrador (a
> sessão aberta no Chrome não é admin). Validação visual com o developer.

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (k) (tour do Painel de Administração)

Alvo `http://ubatexu.lan:8080/admin` (branch `feat/frontend-tour-admin`).

| Verificação | Onde | Resultado |
|---|---|---|
| Sessão de gestor **sem** perfil admin: tela “restrita”, nenhum tour, sem “?”, nada marcado | Chrome (sessão existente) | 🟢 |
| Admin com dados: `prontoQuando` e os 7 alvos existem | vitest `features/admin/pages/tourAlvos.test.js` | 🟢 |
| 403 (“restrita”) e sem sessão: não abre | vitest | 🟢 2/2 |
| Testes existentes do `AdminTelemetryPage` | vitest | 🟢 5/5 |
| Suíte frontend | vitest | 🟢 121 arquivos / 1072 testes |

> **Não coberto pelo agente: o tour visível com perfil de administrador.** A
> sessão aberta no Chrome não é de administrador, e o agente não digita nem
> injeta credenciais. A validação visual fica com o developer.

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (j) (tour do Assistente do Censo)

Alvo `http://ubatexu.lan:8080/chat/censo` (branch
`feat/frontend-tour-assistente`), com a sessão de gestor já aberta no Chrome
(sem injeção de credencial). **Nenhuma pergunta enviada**: cada pergunta
consome o serviço de IA da instalação.

| Verificação | Resultado |
|---|---|
| Abre sozinho logado; 4/4 alvos certos (escopo, pergunta, conversa, ações), popover na janela | 🟢 |
| Layout do chat intacto (alvo da conversa no contêiner flex; caixa de pergunta envolvida) | 🟢 (screenshot) |
| Contrato `features/chat/pages/tourAlvos.test.js`: logado todos os alvos; sem sessão não abre | 🟢 2/2 |
| Testes existentes do `ChatPage` | 🟢 11/11 |
| Ficha `historico-conversas.md` dizia “salvar automaticamente”; o código só salva pelo botão | 🔴→🟢 (ficha corrigida) |
| Suíte frontend | 🟢 120 arquivos / 1068 testes |

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (i) (tours dos módulos do gestor — lote 2)

Tours: Pesquisas, Reuniões, Inventário, Relações, Documentos (branch
`feat/frontend-tour-gestor-lote2`), em `ubatexu.lan:8080`. Pesquisas não exige
login. Para os outros quatro, o Chrome **já tinha uma sessão de gestor aberta**
(da validação do lote 1). O agente não injetou credencial e só navegou e leu,
sem nenhuma ação de escrita.

| Verificação | Resultado |
|---|---|
| Pesquisas (`?inep=35211576`, estado vazio real): abre sozinho; alvo no `<div>` do vazio; 2 passos | 🟢 |
| Reuniões logado: abre sozinho; 4/4 alvos certos, popover na janela | 🟢 |
| Inventário logado: 3/3 | 🟢 |
| Relações logado: 4/4 | 🟢 |
| Documentos logado: 4/4 (painel “Como funciona” com o texto corrigido) | 🟢 |
| Sair de uma página com tour aberto → abre o tour da página nova | 🔴→🟢 (fix no `aoNavegar`) |
| Envios por `?novo=1` logado (lote 1): editor aberto, **nenhum** tour, sem “?”, nada marcado | 🟢 |
| 1º passo de Pesquisas no estado vazio falava só de “rascunhos, publicadas…” | 🔴→🟢 (texto ajustado) |
| Contrato `tourAlvos.test.js`: 10 páginas com sessão + Pesquisas sem `?inep=` | 🟢 20/20 |
| Suíte frontend | 🟢 118 arquivos / 1058 testes |

> **Bug fora do escopo (corrigido depois, branch `fix/frontend-excluir-pasta`):**
> em Documentos, a confirmação de excluir pasta dizia “Pastas e arquivos
> internos serão preservados”, mas o backend (`DocumentosEscolares.pm`,
> `pasta_nao_vazia`) **recusa** excluir pasta com conteúdo. Corrigido neste ciclo só o texto “Enviar arquivo público”
> do painel “Como funciona”, que o tour destaca.

Profile da automação devolvido a `?tour=off`.

## Rodada 2026-11-01 (h) (tours dos módulos do gestor — lote 1)

Tours: Relatórios, Contatos, Listas, Envios, Listas dinâmicas (branch
`feat/frontend-tour-gestor-lote1`). Todas as páginas exigem login de gestor.

| Verificação | Onde | Resultado |
|---|---|---|
| Sem sessão: tela de login, **nenhum** tour, **sem** “?”, nada marcado como visto (5 páginas, automático ligado) | Chrome, stack Docker local `127.0.0.1:8080` | 🟢 |
| Com sessão (MSW): `prontoQuando` e **todos** os alvos de todos os passos existem no markup real | vitest `features/gestor/pages/tourAlvos.test.js` | 🟢 5/5 |
| Sem sessão (MSW): `prontoQuando` não aparece | vitest | 🟢 5/5 |
| Textos × código: “capítulos são fixos” (Relatórios) e filtro “Estado” (Envios) | leitura do código | 🔴→🟢 (corrigidos antes do deploy) |
| Suíte frontend | vitest | 🟢 118 arquivos / 1042 testes |

> **Não coberto pelo agente: o tour visível logado.** A injeção do token de
> uma conta de teste local na aba foi **bloqueada pela política de
> permissões** (materialização de credencial) — não contornada. A conta de
> teste da stack local existe (credenciais em
> `~/.config/edumaps/e2e_gestor_local`, fora do repositório, modo 600). A
> validação visual logada fica com o developer.

## Rodada 2026-11-01 (g) (`?tour=off` para e2e em profile limpo)

Alvo `http://ubatexu.lan:8080` (deploy do branch `fix/frontend-tour-e2e`).
Profile “limpo” simulado apagando todas as chaves `edumaps.tour.*`.

| Verificação | Resultado |
|---|---|
| `/?tour=off` → marca `edumaps.tour.automatico=off`, nada abre, `?tour` sai da URL | 🟢 |
| Navegações completas a `/`, `/escola/search`, `/gestor/painel?inep=35211576`, `/cluster/geotag`: **nenhum** tour/overlay | 🟢 |
| Nenhuma chave de “visto” gravada (tours seguem pendentes) | 🟢 |
| Botão “?” continua abrindo (análises: “1 de 6”) | 🟢 |
| `/?tour=on` → marca removida, tour de primeiro acesso abre sozinho | 🟢 |
| Testes unitários frontend | 🟢 117 arquivos / 1025 testes (5 novos) |

Profile da automação deixado com `?tour=off` (estado do runbook).

## Rodada 2026-11-01 (f) (“?” na tela de erro do painel)

Alvo `http://ubatexu.lan:8080` (deploy do branch `fix/frontend-ajuda-tela-erro`).

| Verificação | Resultado |
|---|---|
| `/gestor/painel?inep=00000000` (“Escola não encontrada…”): **sem** “?” no menu | 🟢 |
| Painel carregado (`inep=35211576`): “?” presente; nenhuma amostra com “?” sem o alvo | 🟢 |
| “?” abre o tour no passo 1 com destaque em `gestor-escola` | 🟢 |
| Outras páginas com tour (busca) seguem mostrando o “?” | 🟢 |
| Testes unitários frontend | 🟢 117 arquivos / 1020 testes (3 novos: sem alvo, alvo chega/sai, alvo já presente) |

## Rodada 2026-11-01 (e) (telemetria da ajuda guiada)

Alvo `http://ubatexu.lan:8080` (deploy do branch
`feat/frontend-telemetria-tour`: backend + frontend), Chrome real; eventos
conferidos na base real (`database.edumaps`, `172.19.198.3`, confirmado por
`ss` no backend).

| Verificação | Resultado |
|---|---|
| `?tour=` → `start` com `trigger=link`; “?” → `trigger=button` | 🟢 |
| Esc no passo 2 → `dismiss` com `step=2` (número JSON, não string) | 🟢 |
| Conclusão do tour `analises` → `complete` com `step=6` | 🟢 |
| Nenhuma chave fora da allowlist no `event_store` | 🟢 |
| Lote sai no `pagehide` via `sendBeacon` (interceptado no navegador) | 🟢 |
| Agregação `_tours` rodada na base real bate com os eventos | 🟢 |
| **Fechar pelo × durante a animação do passo** (~300 ms) | 🔴→🟢 (ver abaixo) |
| Testes: vitest 117 arquivos / 1017; Perl `t/04-api/session`, `t/04-api/admin`, middleware de sessão: 44 | 🟢 |

**Bug achado (existia desde a fase 1, exposto pela telemetria):** o driver.js
só chama `onDestroyed` se já houver elemento ativo, e esse estado só existe
depois da animação de cada passo (~0,6–1,2 s). Fechar (× ou Esc) nessa janela
destruía o tour **sem avisar** o `TourManager`: nenhum `dismiss`, `ativo`
preso e — consequência pior — nenhum tour automático nem `?tour=` abria de
novo até recarregar a página. Reproduzido fechando pelo × a 300 ms.
Correção: todo encerramento passa por `#finalizar()` (idempotente), acionado
por `onDestroyStarted` (chamado antes da checagem), `encerrar()` e conclusão.
Depois: × a 300 ms → `dismiss@1`, foco devolvido ao “?”, e `?tour=analises`
abre em seguida na mesma sessão.

> **Não coberto**: a tabela no Painel de Administração com login de admin
> (o agente não digita credenciais em `ubatexu.lan`); coberta por vitest
> (fixtures) e pela consulta direta na base. Os eventos destes testes ficaram
> na telemetria do ambiente de dev (10 aberturas de `busca-escola`, várias sem
> fechamento por causa do bug).

## Rodada 2026-11-01 (d) (ajuda guiada — tour `analises`)

Alvo `http://ubatexu.lan:8080/cluster/geotag` (deploy do branch
`feat/frontend-tour-analises`), Chrome real.

| Verificação | Resultado |
|---|---|
| 1ª visita abre o tour sozinho (“Agrupar escolas parecidas”, 1 de 6) | 🟢 |
| 6 passos com o alvo certo (cabeçalho, recorte, indicadores, algoritmo, gerar, resultado) | 🟢 |
| Popover dentro da janela em todos os passos (medido por `getBoundingClientRect`) | 🟢 |
| Ordem lógica (onde → quais → como) rola para cima entre os passos 3 e 4 — legível | 🟢 |
| Concluir → `edumaps.tour.analises.v1 = concluido`; “?” = “Ajuda guiada: Como agrupar escolas” | 🟢 |
| Passo 6 dizia “O mapa mostra…” sobre o espaço ainda vazio | 🔴→🟢 (“Depois de gerar, o mapa mostra…”) |
| Testes unitários frontend | 🟢 117 arquivos / 1006 testes |

> **Não coberto**: mapa de clusters gerado (depende do motor R); o destaque
> sobre mapa Leaflet já foi medido na rodada (c).

### Causa da “primeira carga em branco” após deploy (3ª ocorrência, resolvida)

Não é falha: é **lentidão**. Medido pela Resource Timing API nesta carga:

| Recurso | Transferido | Duração |
|---|---|---|
| `index-*.js` (muda a cada deploy) | 1030 KB | **10,6 s** |
| `vendor-*.js` / `*.css` (cache `immutable`) | 0 KB | < 0,3 s |
| Navegação completa | — | 12,6 s |

O nginx do container (`backend/script/deploy/files/edumaps-frontend-nginx.conf`
/ `/etc/nginx/nginx.conf`) tem `gzip on`, mas **`gzip_types` comentado**: só
`text/html` é comprimido (956 → 467 B); o JS vai cru (`Content-Length:
1054856` mesmo com `Accept-Encoding: gzip`). O build indica ~310 KB com gzip.
Após cada deploy o bundle principal muda de hash e é baixado inteiro; checar a
página antes de ~12 s parece “tela em branco”. Os registros anteriores (“o
navegador não pediu o bundle”) estavam errados: o nginx loga ao **fim** da
requisição. Correção aplicada no branch `fix/infra-gzip-nginx` (`gzip_types` nas duas
configs; sem `gzip_proxied`, para não afetar a API/SSE).

**Depois da correção** (1ª carga pós-deploy, bundle novo fora do cache):

| | Antes | Depois |
|---|---|---|
| `index-*.js` transferido | 1030 KB | 🟢 304 KB |
| download do bundle | 10,6 s | 🟢 1,3 s |
| navegação completa | 12,6 s | 🟢 1,5 s |
| app renderizado na 1ª checagem | 🔴 não | 🟢 sim |

`Content-Encoding: gzip` + `Vary: Accept-Encoding` no LXC e na imagem Docker
local (311 KB contra 1.055 KB). A API já vinha comprimida pelo próprio
Mojolicious (`Server: Mojolicious` responde `gzip` direto na :3000), sem
relação com esta mudança.

## Rodada 2026-11-01 (c) (ajuda guiada — tour `painel-gestor`)

Alvo `http://ubatexu.lan:8080/gestor/painel?inep=35211576` (deploy do branch
`feat/frontend-tour-painel-gestor`), Chrome real, **sem login** (a API do
painel responde 200 sem sessão).

| Verificação | Resultado |
|---|---|
| `?inep=00000000` (erro “Escola não encontrada”): tour **não** abre, chave não gravada | 🟢 |
| INEP válido: abre ~100 ms após o cabeçalho da escola montar (`prontoQuando`) | 🟢 |
| 8 passos com o alvo certo (escola, módulos, resumo, atalhos, matrículas, infraestrutura, similares, influência) | 🟢 |
| Seções altas (matrículas 746 px, infraestrutura 649 px) enquadradas; popover ao lado | 🟢 |
| Concluir → `edumaps.tour.painel-gestor.v1 = concluido` | 🟢 |
| “?” reabre; passo 7 com o mapa Leaflet de similares carregado: mapa visível no destaque | 🟢 |
| z-index medido: overlay 10000 > Leaflet panes 400 / controles 1000 | 🟢 |
| Texto do passo “Matrículas” omitia a faixa etária | 🔴→🟢 (corrigido) |
| Testes unitários frontend | 🟢 117 arquivos / 1004 testes |

> **Não coberto**: estado logado (área de influência com mapa, equipamentos do
> entorno). Sem login essas seções mostram “Entre como gestor desta escola…”;
> o passo 8 destaca a seção nos dois estados. O “?” continuava visível na tela
> de erro do painel (cada passo caía no popover centralizado) — **corrigido no
> branch `fix/frontend-ajuda-tela-erro`**: o “?” de tour com `prontoQuando` só
> aparece quando o alvo existe.

## Rodada 2026-11-01 (b) (ajuda guiada — tour `primeiro-acesso`)

Alvo `http://ubatexu.lan:8080` (deploy do branch
`feat/frontend-tour-primeiro-acesso`), Chrome real via extensão.

| Verificação | Resultado |
|---|---|
| 1ª visita a `/` abre o tour sozinho (“Bem-vindo ao EduMaps”, 1 de 7) | 🟢 |
| Passos 1–2 destacam apresentação e atalhos da home | 🟢 |
| Passos 3–6 destacam Busca Escola, Análises, Assistente do Censo, Gestor no menu escuro | 🟢 |
| Passo 7 destaca o botão “?” (Concluir) | 🟢 |
| Concluir → `edumaps.tour.primeiro-acesso.v1 = concluido` | 🟢 |
| Revisita a `/` não reabre; “?” na home = “Ajuda guiada: Conhecer o EduMaps” | 🟢 |
| Tour da busca continua independente (já visto → não reabre) | 🟢 |
| Testes unitários frontend | 🟢 117 arquivos / 999 testes |

> **Observação de ambiente (2ª ocorrência)**: a primeira carga após o
> `deploy_frontend_dev` ficou em branco. O `edumaps-frontend-access.log` mostra
> o `GET /` (200) às 13:28:28 **sem nenhum GET do bundle** `index-*.js` nessa
> carga — o navegador não chegou a pedir o script; a recarga seguinte
> funcionou. Não é do código do tour (nenhum JS do app rodou). Investigar à
> parte (cache do Chrome de automação × `index.html` `no-cache`).
> Comportamento do driver.js: setas apertadas durante a animação são
> ignoradas (avança um passo por vez).
>
> **⚠️ Diagnóstico corrigido na rodada (d)**: não houve “GET ausente”. O
> nginx registra a requisição **ao terminar**; o GET do bundle às 13:28:38
> (que atribuí ao meu `fetch` manual) era a própria carga, que levou ~10 s.
> Causa real: `index-*.js` de 1 MB servido **sem gzip** (ver rodada (d)).

## Rodada 2026-11-01 (ajuda guiada — tour `busca-escola`)

Alvo `http://ubatexu.lan:8080` (deploy `deploy_frontend_dev` do branch
`feat/frontend-ajuda-guiada`), Chrome real via extensão, perfil sem
`localStorage` prévio.

| Verificação | Resultado |
|---|---|
| 1ª visita a `/escola/search` abre o tour sozinho (“1 de 7”, destaque no cabeçalho) | 🟢 |
| Setas ← → percorrem os 7 passos; textos PT-BR; botões Anterior/Próximo/Concluir | 🟢 |
| Passo 6 → 7 navega para `/municipio/compare` e destaca o seletor de município | 🟢 |
| Recarregar no passo 7 retoma em “7 de 7” (sessionStorage) | 🟢 |
| ← no passo 7 volta para `/escola/search`, passo 6 | 🟢 |
| Concluir: overlay some, `edumaps.tour.busca-escola.v1 = concluido`, sessão limpa | 🟢 |
| Revisita: não abre sozinho; botão “?” no menu (aria-label) abre em “1 de 7” | 🟢 |
| Popover com `role=dialog` + `aria-modal=true`; foco entra no popover | 🟢 |
| Esc fecha e devolve o foco ao botão “?” | 🔴→🟢 (botão `disabled` perdia o foco; corrigido) |
| `/about?tour=busca-escola` navega até a busca e abre o tour | 🟢 |
| Voltar do navegador no meio do tour encerra o tour sem overlay órfão | 🟢 |
| Testes unitários frontend | 🟢 117 arquivos / 997 testes (docker `node:22-slim`) |

> **Nota**: logo após o `deploy_frontend_dev`, uma carga ficou em branco sem
> erro no console; o `error.log` do nginx registra o restart abortando com
> sockets abertos (13:15:21). Não se reproduziu em 5 recargas seguidas.

## Rodada 2026-09-28 (tiles OSM no lugar do CARTO)

**Causa do bug "mapas sem tiles + tarja para definir chave API"**: o tile
layer usava o CDN `basemaps.cartocdn.com` (`light_all`), que exige
chave/API em algumas condições. **Fix: `LeafletMap.svelte` e
`AnalBaseMap.svelte` (legado) passaram a usar
`https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`** (sem chave).

Validação e2e (Chrome CDP `:9333`, profile `/tmp/edumaps-cdp2`, alvo
`http://ubatexu.lan:8080/gestor/painel?inep=35211576`, fluxo "Buscar
escolas similares"):

| Verificação | Resultado |
|---|---|
| Bundle servido | `index-CWm3qagX.js` — `cartocdn: 0`, única `tileUrl` = OSM |
| Tiles carregados | 🟢 15/15 (hosts `a/b/c.tile.openstreetmap.org`) |
| Status HTTP dos tiles | 🟢 200 `image/png` (frio, 17 respostas, 0 falhas) |
| Tarja/texto de API key no DOM do mapa | 🟢 ausente (`keyTexts: []`, `tileErrorCls: false`) |
| Testes unitários frontend | 🟢 26 arquivos / 138 testes (docker `node:22-slim`) |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` (`backend.edumaps`) |

> **Nota do fix**: o `edumaps` não passa `tileUrl` custom em nenhum caller —
> todos os mapas (escolas similares, escola, rede, cluster) usam o default
> do `LeafletMap`; a troca única corrige todos.

## Ambiente desta rodada (2026-09-28)

`ubatexu.lan` e `backend.edumaps` seguem **fora do ar**, então o alvo
padrão (`http://ubatexu.lan:8080`) não existe. A rodada rodou contra um
alvo montado local:

| Peça | Onde |
|---|---|
| Banco | container `edumaps-db` (já existente), `127.0.0.1:5432` |
| Backend | perlbrew na máquina, `prefork` em `:3000` |
| Build da SPA | `node:22-slim` (`npm ci` + `vite build`) |
| Servidor da SPA | `nginx:alpine`, `/api` com proxy para o backend |
| Dev server (para diagnosticar) | `vite dev` em `:5173` |
| Chrome | CDP em `127.0.0.1:9222`, profile dedicado |

O plugin `opencode-chrome-devtools` **não estava conectado** nesta sessão
(`browser.tabs.list` → *No desktop browser is connected*). O e2e foi feito
dirigindo o **CDP direto** com um cliente WebSocket próprio, dentro de um
container com `--network host` (assim `127.0.0.1:9222` alcança o Chrome sem
expor o CDP na rede). O runbook continua válido: só o *driver* mudou.

Descoberta de infraestrutura, **pré-existente**:

- Rotas com query string (`/escola/ranking?inep=…`) retornam **500 do
  nginx** — o `try_files $uri $uri/ /index.html` não cobre o caminho com
  `?`. Montar as URLs com a query **antes** do `browser_navigate`.

> **Correção de uma leitura anterior deste arquivo.** Numa primeira
> passagem observei `/` e `/gestor` quebrando com
> `TypeError: fn is not a function` no flush do Svelte e atribuí a causa ao
> `manualChunks` do `vite.config.js`. **Atribuição errada**: o erro não
> reproduz em nenhuma configuração testada — mesmo build, mesmo chunk,
> perfil de browser novo, origem nova e primeira visita. É
> **transiente** e a causa não foi identificada. As tabelas abaixo já não
> o tratam como falha Reproduzível.

## Cobertura por rota

| # | Rota | Feature | Status | Obs. |
|---|------|---------|--------|------|
| 1 | `/` | home | 🟢 2026-09-28 | Renderiza os pilares; 0 exceções (ver nota sobre o erro transitício acima) |
| 2 | `/about` | about | 🟢 2026-09-28 | Página institucional |
| 3 | `/municipio/compare` | network-compare | 🔴 2026-09-28 | 500 do nginx (query string) |
| 4 | `/escola/search` | schools | 🟢 2026-09-28 | Formulário e hints renderizam |
| 5 | `/escola/panel?inep=35245239` | schools | 🟢 2026-09-28 | Carrega com 1 chamada `/api` |
| 6 | `/escola/ranking?inep=35011162` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 7 | `/escola/payroll?inep=…&date=…` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 8 | `/escola/financeiro?inep=…` | schools | 🔴 2026-09-28 | 500 do nginx (query string) |
| 9 | `/cluster/geotag` | cluster-geotag | 🔴 2026-09-28 | 500 do nginx (reproduz com URL sem query) |
| 10 | `/gestor` | gestor | 🟢 2026-09-28 | Card de login, 1 chamada `/api`, 0 exceções |
| 11 | `/gestor/painel?inep=35245239` | gestor | 🟢 2026-09-28 | Raio-X com 1 chamada `/api` |
| 12 | `/gestor/pesquisas?inep=…` | gestor | 🟢 2026-09-28 | Carrega |
| 16 | `/chat/censo` | chat | 🟢 2026-09-28 | Página carrega; o NL→SQL depende do serviço de analytics (ausente) |
| 27 | `/config` | config | 🟢 2026-09-28 | Árvore de categorias, 3 chamadas `/api` |

### Rota fora da tabela — descoberta nesta rodada

| # | Rota | Feature | Status | Obs. |
|---|------|---------|--------|------|
| 28 | `/chat/historico` | chat (histórico) | 🔴→🟢 2026-09-28 | **Não estava na cobertura.** Ver achados abaixo |

### Interações em `/chat/historico` (build de produção, com sessão real)

| Interação | Status | Obs. |
|----------|--------|------|
| Listar conversas | 🟢 | 3 conversas, `/api/chat/conversas` 200 |
| Contador no calendário | 🟢 | `aria-label="28 - 3 conversa(s)"`; badge "3" no dia 28 |
| Clicar num dia do calendário | 🟢 | Filtra para as conversas do dia (as 3 são de 28/09) |
| Buscar por texto | 🟢 | Filtra a lista **depois** da correção nº 3 |
| Buscar pelo campo **da lista** | 🟢 | Tinha `bind:value` num prop não-bindável (achado 9) |
| Limpar a busca | 🟢 | Volta à listagem completa |
| Selecionar uma / todas | 🟢 | Checkbox e "selecionar todas" criados nesta rodada |
| Exportar todas (.md) | 🟢 | Baixa `conversas-2026-09-28.md`, 818 B, 3 seções |
| Exportar selecionadas | 🟢 | Idem, com os ids marcados |
| Exportar **uma** conversa | 🟢 | Botão do item |
| Excluir | 🟢 | `confirm()` + `DELETE` 204 + item some da lista |
| "Ver conversa" | ⚪ | **Sem destino** — ver achado 10 |

> **Nota de driver**: o `a.click()` de um `blob:` disparado por script **não**
> concede *user activation*, e o Chrome descarta o download. Só funciona com
> clique de verdade (`Input.dispatchMouseEvent`). O `Page.setDownloadBehavior`
> na sessão de página não redirecionou o download — o arquivo foi para o
> diretório padrão do Chrome. Para `confirm()`, é preciso responder a
> `Page.javascriptDialogOpening` com `Page.handleJavaScriptDialog`.

## Achados em `/chat/historico` (commit `9fd4a0e`)

A página **não funcionava**. Três bugs independentes, todos do mesmo
commit, nenhum pego pelos testes (a rota não tem `*.test.js` nem handler
MSW):

1. **`ChatCalendar.svelte:66` — `$effect(buildCalendar())`**.
   `$effect` espera uma **função**; a chamada passava o **retorno** de
   `buildCalendar()` (`undefined`). Erro: `TypeError: Object.defineProperty
   called on non-object`. Como o erro acontece no flush do Svelte, ele
   **aborta o `onMount` da página** — a lista nunca era buscada e a tela
   mostrava "Nenhuma conversa encontrada" mesmo com conversas no banco.
   *Corrigido: `$effect(() => { buildCalendar(); })`.*

2. **`ChatConversaItem.svelte:33` — `{snippet}` sem prop**.
   O JSDoc declara `conversa.snippet`; o template usava o identificador
   solto. Erro: `ReferenceError: snippet is not defined`, uma vez por
   linha da lista. *Corrigido: `conversa.snippet`.*

3. **`ChatHistoricoPage.svelte` — `searchResults` escrito e nunca lido**.
   A busca preenchia `searchResults`, mas o template passava
   `conversas={conversas}`. O servidor era consultado e o resultado
   descartado: **a busca não filtrava nada na tela**.
   *Corrigido: `conversas={searchQuery.trim() ? searchResults : conversas}`.*

Uma vez a página carregou, apareceram **mais seis defeitos** — nenhum deles
pego por teste, porque a rota não tem cobertura. Os dois primeiros só eram
visíveis depois da correção nº 3.

4. **Handlers stub em `ChatConversaList.svelte`** — "Exportar todas",
   "Exportar selecionadas" e o item inteiro tinham `onclick={() => {}}` /
   `onClick={() => {}}` / `onExport={(id) => {}}` / `onDelete={(id) => {}}`,
   embora a página passasse as funções reais. Exportar e excluir não faziam
   nada. *Corrigido: handlers ligados e `onExportOne`/`onDelete`/`onOpen`
   repassados.*

5. **`exportConversas` ignorava a autenticação.** Era a única função de
   `chatApi.js` que não passava por `apiClient`: usava `fetch` cru com
   `credentials: "include"`, ou seja, só cookie. Mas `_require_gestor` só
   lê `Authorization: Bearer` → **401 nos dois botões de exportar**.
   *Corrigido: passou a usar `apiClient.download`, que monta o header e
   ainda aproveita o `Content-Disposition` para o nome do arquivo.*

6. **`URL.revokeObjectURL` no mesmo tick** do `a.click()` pode cancelar o
   download antes de ele começar; e o `a` solto no DOM é frágil.
   *Corrigido: âncora anexada ao `body` e `revoke` num `setTimeout`.*

7. **Os botões "Excluir" e "Exportar" do item eram inclicáveis.** O botão
   "Ver conversa" é um overlay `absolute inset-0` sobre o card inteiro e,
   por vir depois no DOM, ficava por cima: `document.elementFromPoint` no
   centro do botão de excluir devolvia o overlay, não o botão. O
   `stopPropagation` dos handlers não ajudava, porque o clique nem chegava
   neles. *Corrigido: `relative z-10` no cabeçalho do item.*

8. **`bind:value={searchQuery}` num prop não-bindável.** O campo de busca
   **dentro da lista** escrevia numa cópia local: digitar nele não filtrava
   e não chegava no input do topo. *Corrigido: `$bindable("")` no
   componente e `bind:searchQuery` na página.*

9. **Não havia UI de seleção.** `selectedIds`/`toggleSelect`/`selectAll`
   existiam, mas o item não tinha checkbox — logo "Exportar selecionadas"
   nunca podia ser usado. *Corrigido: checkbox por item e "selecionar
   todas"; o botão só habilita com seleção.*

10. **"Ver conversa" não tem destino.** A `ChatPage` não sabe reabrir uma
    conversa salva: não lê id nem query param, a rota é estática, e
    `getConversa()` em `chatApi.js` não é chamado por código nenhum. Em vez
    de deixar o clique mudo, a página agora avisa que a reabertura não está
    disponível. **Continua sendo lacuna de produto** — implementá-la exige
    rota/param e carga da conversa no chat.

11. **O filtro `ids` do export nunca funcionou — em nenhuma das duas
    formas.** Só apareceu depois de ligar os botões (achado 4):
    - `?ids[]=1` — o `to_hash` do Mojolicious **não** converte a notação
      de colchete: a chave vira literalmente `ids[]` e `to_hash->{ids}`
      volta `undef`. Resultado: `@ids` vazio, filtro ignorado, e o export
      saía com **todas** as conversas do gestor, **em silêncio**.
    - `?ids=1` — aí o filtro era aplicado, mas o `prefetch => mensagens`
      fazia JOIN e `id` existe nas duas tabelas →
      `ERROR: column reference "id" is ambiguous` → **500**.

    *Corrigido nos dois lados:* o controller coleta `ids` e `ids[]` e
    filtra para inteiro, e o `prefetch` foi removido do modelo (ele era
    inclusive **descartado** — o loop já buscava as mensagens com
    `$c->mensagens->search(...)`, ou seja o JOIN só existia para atrapalhar).

12. **O teste do export afirmava o que não testava.** Ele usava
    `?ids[]=$id` — a forma ignorada — e depois conferia que o corpo tinha
    `## Pergunta 1` e `## Resposta 1`. Como o filtro não valia, o corpo
    vinha com *todas* as conversas, então as asserções passavam por uma
    conversa que não era a pedida. *Corrigido: o teste cria a própria
    conversa e passa a contar as seções, checando que a outra não vaza;
    o subteste novo cobre `ids=`, `ids[]`, ids repetidas e `all=1`.*

13. **A chamada usava a chave errada.** O `POST /api/chat/conversas`
    espera `messages` (inglês), não `mensagens` — `mensagens` dá 400
    "messages deve ser um array". E a resposta traz só `{id}`, apesar de o
    comentário prometer `{id, created_at}`.

### Achados abertos (não corrigidos — 14 e 16 são decisão de produto)

Os três são do backend (`Roles/Business/Chat/Conversas.pm::search_conversas`)
e reproduzíveis só depois da correção nº 3 — antes dela a busca nem
filtrava a tela, então ninguém via estes sintomas.

14. **Busca devolve uma linha por mensagem, não por conversa.** O SQL usa
    `SELECT DISTINCT c.id, c.titulo, c.created_at, c.updated_at,
    ts_headline(...) AS snippet`. Como o **`snippet` entra no `DISTINCT`**,
    duas mensagens com trechos diferentes produzem **duas linhas com o
    mesmo `id`**. O `COUNT(DISTINCT c.id)` do total já conta certo, e o
    comentário do método diz "Retorna conversas distintas que têm match",
    ou seja a **intenção é uma linha por conversa** e o `DISTINCT` não
    cumpre por causa do `snippet`. Além disso o item de busca **não traz
    `msg_count`**, então o `ChatConversaItem` renderiza ` msg` sem número.
    *Mitigação no cliente:* a página deduplica os ids em `listaExibida`.
    Sem isso, ids repetidos num `{#each}` com key derrubam a tela com
    `each_key_duplicate` — foi o que aconteceu ao adicionar a key
    durante esta rodada, e o sintoma (busca que "não filtra nada") é
    parecido com o do achado nº 3, o que confunde o diagnóstico.
15. **`snippet` vem com HTML** (`30 escolas têm <b>biblioteca</b>.`, porque
    `ts_headline` marca o match com `<b>`) e é renderizado como **texto** —
    o usuário vê as tags. Duas saídas: `{@html}` no componente (exige
    sanitizar, senão é XSS a partir do conteúdo da conversa) ou passar
    `StartSel=<mark>, StopSel=</mark>`/remover as tags no backend.
16. **Busca é sensível a acento.** `to_tsvector('portuguese', ...)` não
    remove acento, e o `unaccent` não está no SQL:

    | consulta | conversas |
    |----------|-----------|
    | `matriculas` | **0** |
    | `matrículas` | 1 |

    Digitação sem acento é o caso comum; resolver com `unaccent` no
    `to_tsvector` (exige a extensão `unaccent` no banco).

 (não são bugs do app, mas custam tempo)

- **`?ids[]=` e não `?ids=`.** O `export_conversas` lê
  `params->to_hash->{ids}`; sem os colchetes o Mojolicious não monta o
  `arrayref` e a rota estoura em **500**. `?ids[]=1&ids[]=2` → 200.
  Descobri isso porque "corrigi" para `ids` durante esta rodada e quebrei o
  export — o teste e2e pegou, mas o contrato merece ficar escrito no
  cliente.
- **Autenticação é por header, não cookie.** `_require_gestor` só lê
  `Authorization: Bearer`. `credentials: "include"` sozinho dá 401 mesmo
  com sessão válida. Toda chamada nova tem de passar por `apiClient`.
- **O `POST /api/chat/conversas` espera `messages`** (inglês), não
  `mensagens`; e responde só `{id}`.

## Verificação do backend de conversa (commit `9fd4a0e` + PR #100)

Com 3 conversas semeadas via API e uma sessão de gestor real
(`POST /api/gestor/login`), conferido **contra a API, não contra o código**:

- `meta` gravado no banco como **objeto** jsonb (`jsonb_typeof = 'object'`,
  6 mensagens).
- `GET /api/chat/conversas/:id` devolve `meta` como **dict**, com as chaves
  `timestamp`, `sql`, `resultado`, `origem` — e `origem.join(", ")`, que é
  exatamente o que `ChatMessage.svelte` faz. Antes da correção do PR #100
  vinha `str`.
- A página de histórico consome só a **listagem**; `getConversa(id)` existe
  em `chatApi.js` e **não é chamado por nenhum código**. Ou seja: a
  correção do `meta` é verificável pela API, mas **não tem efeito
  visível na SPA** — o que o `frontend` mostra hoje continua igual.

## Pendências de cobertura

- Rotas **13-15, 17-26** não executadas (exigem sessão de gestor com
  escola real ou formulário público).
- Interações ainda não cobertas: busca de escola, paginação do
  histórico, exclusão, exportar `.md`.
- Os 500 do nginx em query string impediram 5 rotas (#3, 6, 7, 8 e 9).
  **Não é bug do app** — é o `try_files` do nginx de e2e. Ainda assim o
  `nginx.conf` do repo tem o mesmo `location /` e merece uma
  `location ~ \.html$` ou checagem de `?`.
- `/chat/historico` não tem `*.test.js` nem handler MSW — foi por isso que
  três bugs sobreviveram até o e2e.

_Atualizar esta tabela a cada rodada; manter rastro de data + achados._

## Rodada 2026-09-28 — Perfil da escola (`/escola/perfil`)

Feature nova (issue #105): painel analítico do gestor com diagnóstico,
posição relativa (município/rede/Brasil/cluster), distribuição no cluster,
sinais de atenção e escolas similares (Gower). Consome
`GET /api/school/:cod_inep/profile` (ponte backend → serviço analítico R).

| Verificação | Resultado |
|---|---|
| Bundle deployado contém a rota/feature | 🟢 `index-DAS1-W4A.js` com `escola/perfil`, "Perfil da Escola", "Posição relativa", `school_profile` |
| `GET /api/school/23165669/profile` (via `ubatexu.lan:8080`) | 🟢 200, payload com `indicadores_comparados`/`cluster_resumo`/`peers`/`flags` |
| `co_entidade` inexistente | 🟢 400 (`Escola não encontrada`, sem vazar caminho/linha) |
| `co_entidade` malformado | 🟢 404 |
| Painel em `http://ubatexu.lan:8080/escola/perfil?inep=23165669` | 🟢 PASS (validação visual do developer, 2026-09-28) |
| Atalho "Perfil analítico" em `/escola/panel` e `/gestor/painel` | 🟢 presente |

Desempenho no host analítico de dev: escola típica (sem cluster persistido)
**~1,7–2,4s**; escola com cluster persistido ~3,4s (percentis sobre 2.821
escolas). A primeira chamada de cada escola é mais lenta (cache do backend
`analytics.analysis_cache` cobre as seguintes por 24h).

## Rodada 2026-09-29 — Perfil da Escola Fase 2 (issue #107)

Read-through do perfil (referências/percentis pré-computados):

| Verificação | Resultado |
|---|---|
| `GET /api/school/23165669/profile` warm | 🟢 200 em ~0,1–0,4s; `cached=true`, `reference_source_municipio=reference` |
| Escola com cluster persistido (`51054531`) | 🟢 `cluster_source=persisted`, `cluster_scope=cluster_profile`, `cluster_run_id` presente |
| `POST /api/task/school_profile` (JSON, limit=2) | 🟢 202; job processou 2 (`analytics.school_profile` 422→424) |
| Timer `edumaps-school-profile-refresh.timer` | 🟢 enabled, próxima execução agendada |
| Painel `/escola/perfil` (linha "Perfil atualizado em") | 🟢 PASS (validação visual do developer, 2026-09-29) |

## Rodada 2026-09-29 — Roadmap do Perfil da Escola (itens A/B/C)

| Verificação | Resultado |
|---|---|
| `/escola/perfil` — seção "Evolução" (IDEB/SAEB por ano) | 🟢 PASS (validação visual do developer, 2026-09-29) |
| `/municipio/perfil?ibge=2307304` — "Rede vs. Brasil" + clusters | 🟢 PASS (validação visual do developer, 2026-09-29) |
| `GET /api/school/:cod/evolution` | 🟢 200 (27 pontos); 99999999 → 400; `abc` → 404 |
| `GET /api/network/:ibge/profile` | 🟢 200 (225 escolas); 9999999 → 400; `abc` → 404 |
| `/ask` "Como está a escola 23165669?" | 🟢 200 consultando `analytics.school_profile_flat` (resposta coerente com o perfil) |

## Rodada 2026-10-07 — Certificação e2e do Bot Telegram (login → `system.bot.info`)

**Objetivo**: certificar ponta a ponta o fluxo da #188 (PR #189) — login na
SPA dispara `system.bot.info` e o bot entrega a mensagem no Telegram. Driver
próprio sobre o CDP do Chrome (mesmo padrão da rodada 2026-09-28), container
`node:22-slim` com `--network host`, alvo `http://ubatexu.lan:8080/gestor`.

**Causa raiz do teste manual do developer (falha ≠ bug)**: no produto
(`database.edumaps`) a `app_config.items` só tinha `allowed_actions` do
`bot_telegram` — faltavam `enabled`, `token` e `chat_id`. E
`EDUMAPS_CONFIG_MASTER_KEY` estava **vazia** no serviço `edumaps-web`, o que
impede o backend de cifrar/decifrar secrets (nem o `assistant_censo.api_key`
era legível). O log do backend registrava a cadeia a funcionar, só faltava
config: `Notifier: bot desativado — system_bot_info ignorada`.

**Preparação** (ambiente dev autorizado): master key gerada e setada em
`edumaps-web` + `edumaps-minion` (systemd, restart); config completa via SQL
na BD do produto (`enabled=1`, `chat_id` do `tools/notify/.env`, `token`
cifrado com `pgp_sym_encrypt` + master key; `allowed_actions` já continha
`system_bot_info`); gestor admin descartável `e2e.bot@edumaps.local` (hash
`salt:hmac_sha256` via `Digest::SHA` — ⚠️ `openssl dgst -mac HMAC` diverge do
Perl, não usar para esse hash).

| Verificação | Resultado |
|---|---|
| Login na SPA (`/gestor`) — Chrome CDP real | 🟢 `POST /api/gestor/login` → **200** |
| Sessão criada | 🟢 navegou para `/gestor/painel` ("Painel do Gestor") |
| `Middleware::Login` → EventBus `system.bot.info` | 🟢 log `Middleware::Bot: system_bot_info entregue` |
| Envio ao Telegram | 🟢 `Notifier: system_bot_info enviada (HTTP 200)` — API aceitou (`ok:true`) |
| Mensagem esperada | 🟢 `Login realizado: e2e.bot@edumaps.local`; no próximo login do developer: `Login realizado: rovai@edumaps.dev` |

> **Notas**: `getUpdates` da API do Telegram **não** é evidência de envio (lista
> só mensagens recebidas pelo bot) — a prova é o HTTP 200 com `ok:true` no log
> do Notifier. A master key agora vive nos units do host (`backend.edumaps`);
> se rotacionar, re-cifrar os secrets (`secret_key_version`).

## Rodada 2026-10-09 — Busca 502: container do backend morto; validado pós-`up -d` (PR #196)

**Contexto**: após o ciclo #172+#157 (PR #196), as imagens `backend`/`minion`
foram reconstruídas e os containers recriados (`docker compose up -d`,
12:53). O developer reportou **"busca retorna 502"** verificando os dockers.

**Causa raiz do 502**: o container `edumaps-backend` **antigo** (criado ~5
dias antes, código velho) estava com o aplicativo **sem escutar em `:3000`**.
O nginx do frontend registrou `connect() failed (111: Connection refused)`
no upstream `172.18.0.5:3000` de **12:07:16 até 12:40:31** — todos os
`/api/*` da SPA (`school/suggestions`, `city/suggestions`,
`school/search/pageable`, `gestor/me`) responderam **502**. A armadilha
conhecida do AGENTS: imagem reconstruída ≠ container recriado. O
`docker compose up -d` (12:53) recriou o backend com a imagem mergeada →
`restart=0`, zero 502 desde então (log do nginx confirma).

| Verificação (alvo `http://localhost:8080`, Chrome CDP `:9222`) | Resultado |
|---|---|
| `/escola/search` carrega (formulário) | 🟢 PASS |
| Autocomplete: digitar "freire" → `GET /api/school/suggestions?q=freire` | 🟢 200 (1359 B) |
| "Buscar Escolas" → `GET /api/school/search/pageable?escola=freire&page=1&per_page=10` | 🟢 200 (1382 B) — lista renderiza (Paulo Freire/RJ etc.) |
| `/` (home) | 🟢 PASS (landing, sem chamadas de API) |
| `/municipio/compare` | 🟢 PASS (mapa após selecionar município) |
| Nenhum 502 no nginx após 12:53 | 🟢 PASS |

**Observações**:
- `search/pageable` para escola **inativa** retorna vazio por design:
  `tp_situacao_funcionamento = 1` (só em funcionamento). Ex.: "mojuca"
  (CENTRO EDUCACIONAL MOJUCA, Porto Velho) tem `tp=2` → corretamente
  excluída; `search`/`suggestions` (sem o filtro) a acham.
- A página de busca é **lista** (mapa é do painel da escola e das páginas de
  comparação/geotag) — `leaflet-container` ausente na rota de busca é
  esperado.
- Nenhuma correção de código foi necessária: era infra/local (container
  recriado). Sem deploy.

## Rodada 2026-10-09 — Certificação de regressão pós #160/#136

**Objetivo**: certificar que os merges recentes — #160 (`sqitch verify` como
gate) e #136 (git hooks) — **não mudaram comportamento** da SPA. Nenhum dos
dois toca `frontend/`/`backend/` de runtime (é infra de banco/CI e de git),
logo o esperado é **regressão zero**.

Driver próprio sobre o CDP do Chrome (`:9222`), container
`node:22-slim --network host`, alvo `http://localhost:8080` (o plugin de
browser do agente **não estava conectado** — mesmo padrão de 2026-09-28).
14 rotas + interação de busca + fluxo de mapa, com captura de console,
exceções e requisições `/api/`.

| Rota | Resultado | API |
|---|---|---|
| `/` home | 🟢 PASS | — |
| `/about` | 🟢 PASS | — |
| `/escola/search` (+ digitar "freire" + Buscar) | 🟢 PASS | `suggestions` 200, `search/pageable` 200; 60 cards, "freire" presente |
| `/escola/panel?inep=35245239` | 🟢 PASS | `panel/info` 200 |
| `/escola/perfil?inep=23165669` | 🟢 PASS | `profile` 200, `evolution` 200 |
| `/escola/ranking?inep=35011162` | 🟢 PASS | `info`/`indicators`/`ranking` 200 |
| `/escola/financeiro?inep=35245239` | 🟢 PASS | `finance` 200; `gestor/me` 401 (anônimo, esperado) |
| `/gestor` | 🟢 PASS | `gestor/me` 401 (card de login, esperado) |
| `/municipio/compare` | 🟢 PASS | — |
| `/municipio/perfil?ibge=2307304` | 🟢 PASS | `network/profile` 200 |
| `/cluster/geotag` | 🟢 PASS | `regions`/`presets`/`columns`/`years` 200 |
| `/chat/censo` | 🟢 PASS | — |
| `/chat/historico` | 🟢 PASS | — ("Sessão não encontrada", esperado anônimo) |
| `/config` | 🟢 PASS | — (card de admin, esperado) |

As 14 rodadas: **0 exceções, 0 erros de console, 0 falhas de rede** (fora as
duas 401 de `gestor/me`, esperadas). As rotas com query string que em rodadas
antigas davam **500 do nginx** (`ranking`, `financeiro`, `municipio/perfil`)
agora **PASS** — o nginx do container atual não reproduz o `try_files` antigo.

### Fluxo de mapa (regressão histórica de tiles)

| Verificação | Resultado |
|---|---|
| `/municipio/compare?codigo_ibge=2307304` — `.leaflet-container` | 🟢 1 |
| Tiles OSM | 🟢 8/8 `complete` e `naturalWidth>0`, 0 `.leaflet-tile-error` |
| Hosts de tile | 🟢 `a/b/c.tile.openstreetmap.org`, HTTP 200 |
| `/escola/panel?inep=35245239` — mapa | 🟢 1 container, 8/8 tiles OK |

### Achado aberto (pré-existente — não é regressão) → **resolvido no PR #201**

Na `/municipio/compare?codigo_ibge=…` (com dados/mapa) o Chrome registrava
**4 rejeições de promise não tratadas** cujo motivo é a **string de um rótulo
de etapa** (`"Infantil"`), **sem stack**. Não derrubava a página: gráficos, mapa
e tiles renderizam; 0 erros de console do app; API 200. Reproduzia em todas as
execuções; **não** aparecia em `/municipio/perfil` nem `/escola/panel`. A origem
é a camada de gráficos (Carbon Charts, `tooltip.customHTML`/rótulos de etapa) —
**não** há `throw`/`reject` em `src/features/network-compare`. **Não
relacionado a #136/#160** (frontend inalterado há 6 dias). Rastreado na
**issue #200**.

**Causa raiz** (medida via CDP `setPauseOnExceptions` + source maps): o Radar
do `@carbon/charts` 1.22.18 anima os rótulos do eixo com
`transition(...).end().finally(...)`; `.end()` **rejeita com o datum** (string,
ex.: "Infantil") quando a transição é interrompida por um novo update, e o
`.finally()` do Carbon **não trata** a rejeição. Interrupções vinham do wrapper
app (`RadarChart.svelte`) que re-renderizava o Carbon com options idênticas
(ResizeObserver + `$effect`).

**Fix (PR #201, merge `9c26dcc`)**: no wrapper — `syncSize`/`$effect` só
re-atribuem `chartOptions` quando o conteúdo muda (fim do churn) + guarda de
`unhandledrejection` para reasons **string** enquanto o radar está montado
(erros `Error` continuam a propagar).

### Rodada 2026-10-09 — validação do fix #200 (PR #201)

Alvo `http://localhost:8080` (imagem local reconstruída + deploys
`frontend`), driver CDP (`node:22-slim --network host`), rota
`/municipio/compare?codigo_ibge=2307304`.

| Verificação | Resultado |
|---|---|
| Rejeições `Runtime.exceptionThrown` no load | 🟢 0 (eram 4× `"Infantil"`) |
| Rejeições após troca de modo do radar (Perfil → Volume) | 🟢 0 |
| Radar renderizado (grupo de modo + `h2` + paths SVG) | 🟢 `246` paths |
| Toggle de modo (Perfil → Volume) | 🟢 `aria-checked` muda |
| Testes unitários (charts + network-compare + shared/ui) | 🟢 41/41 (9 no charts, 3 novos do guard) |
| `vite build` | 🟢 OK |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` + imagem local `frontend` |

### Rodada 2026-10-10 — Busca Escola: toast espúrio "Nenhuma escola encontrada." na carga (fix, PR #203)

**Relato do developer**: "a busca (busca escola) não retorna (vazia)" com a
imagem docker em `localhost:8080`.

**Diagnóstico** (smoke CDP `:9222`, drivers próprios `smoke_busca*.mjs`,
alvo `http://localhost:8080`): a **busca funcionava** (nome e município →
`/api/school/search/pageable` 200, cards renderizados). O "vazio" era um
**toast espúrio na carga** da página: `createPaginationStore` emite um ciclo
loading→pronto na **montagem** (sem filtro o adaptador devolve
`meta.total_entries = 0` **sem chamar a API**), e o `notifySearchOutcome` da
página convertia `total === 0` em toast "Nenhuma escola encontrada." — mesmo
sem o usuário buscar nada. Buscas reais sem correspondência (ex.: "E.M.",
prefixo ausente da base local) retornam vazio **consistentemente** (curl =
browser = `[]`), não é bug.

**Fix (PR #203, merge `2f4e43d`)**: guard `if (!hasSearched) return;` no topo de
`notifySearchOutcome` (`SchoolSearchPageRx.svelte`) — só notifica o resultado
de busca iniciada pelo usuário. Teste de regressão novo em
`SchoolSearchPageRx.test.js` (montagem sem busca → 0 toasts; comprovado que
falha sem o guard).

| Verificação (imagem local `frontend` reconstruída, `localhost:8080`) | Resultado |
|---|---|
| Carga fresca de `/escola/search` — toast espúrio | 🟢 **ausente** (`toasts=[]`); corpo: "Informe um nome de escola ou município para começar" |
| Busca por nome (`CENTRO EDUCACIONAL DE UBATUBA`) | 🟢 `/api/school/search/pageable?escola=…&page=1&per_page=10` 200; toast "Busca concluída: 1 escola encontrada" |
| Busca por município (`Ubatuba`) | 🟢 200, resultados |
| Busca real vazia (`E.M.`) | 🟢 200 vazio; toast legítimo "Nenhuma escola encontrada." (usuário buscou) |
| Autocomplete (`freire`) vs app | 🟢 sinais preservados |
| Testes unitários da feature (schools) | 🟢 21 arquivos / 99 testes (incl. regressão nova) |
| Deploy | 🟢 imagem local `frontend` reconstruída + `rex prepare` + `deploy_frontend_dev` |

### Rodada 2026-10-10 — Telemetria de sessão: tracker no navegador (feat, etapa 2)

**Objetivo**: certificar ponta a ponta a **etapa 2** da telemetria de sessão —
o rastreador no navegador (Svelte/JS) que envia eventos a
`POST /api/session/events` e os persiste em `clean.event_store` pela allowlist
do backend (etapa 1, PR #204). Regra de privacidade: **nunca o texto digitado**.

Driver próprio sobre o CDP do Chrome (`:9222`, `Network.setCacheDisabled`),
alvo `http://ubatexu.lan:8080/escola/search` (deploy via `redeploy` +
`deploy_frontend_dev`).

| Verificação | Resultado |
|---|---|
| App monta com o bundle novo (`index-CKSXScwW.js` contém `api/session/events`) | 🟢 |
| Busca por "Ubatuba" + navegação SPA (`pushState`/`popstate` → `/about`) | 🟢 input/btn/results OK, rota muda |
| Flush no unload (`pagehide` → `sendBeacon`) | 🟢 1 `POST /api/session/events` |
| Corpo do lote | 🟢 3 eventos: `navigate /escola/search`, `schools:search` `{q_len:7,result_count:5}`, `navigate /about` |
| **Texto digitado no lote** | 🟢 **ausente** (nunca "Ubatuba"; allowlist corta no cliente e no servidor) |
| Exceções / erros de console | 🟢 0 |
| Persistência em `clean.event_store` (BD do backend) | 🟢 `source=frontend`, `session_id` único, payload só com as chaves permitidas |
| Sessão do request de API (`Middleware::Session`) | 🟢 `session.request` com o **mesmo** `session_id` dos eventos `frontend` |
| Testes unitários (tracker + mapeamento + gestor + busca) | 🟢 41/41 |
| `vite build` | 🟢 OK |
| Deploy | 🟢 `rex prepare` + `deploy_frontend_dev` + imagem local `frontend` |

> **Nota de driver**: um `#app` vazio na primeira tentativa era **cache de
> service worker** de sessão anterior, não regressão — resolvido com
> `Network.setCacheDisabled: true` e espera pela montagem. Sem isso o probe
> dá falso negativo (nenhuma request `/api/`, nenhuma exceção).

### Rodada 2026-10-11 — Painel de Administração: telemetria de acesso (feat)

**Objetivo**: certificar ponta a ponta o **Painel de Administração** (`/admin`),
que lê a telemetria de sessão (etapas 1+2) e apresenta KPIs agregados do fluxo
de acesso: logins de gestores (6/12/24 h), sessões ativas (logadas/anônimas),
buscas, eventos, série temporal e rotas mais acessadas. Privacidade: **só
agregados** — sem IP, texto de busca ou sessão individual.

Driver próprio sobre o CDP do Chrome (`:9222`, `Network.setCacheDisabled`),
alvo `http://ubatexu.lan:8080/admin` (deploy via `rex prepare` +
`deploy_backend_dev` + `deploy_frontend_dev`). Sessão obtida por
`POST /api/gestor/login` e injetada em `localStorage` antes do carregamento.

| Verificação | Resultado |
|---|---|
| SPA monta e roteia `/admin` ("Painel de Administração", nav "Administração") | 🟢 |
| Guard de admin (`GET /api/gestor/me` antes do overview) | 🟢 200, `access_role=admin` |
| `GET /api/admin/telemetry/overview?window=24h` | 🟢 200 |
| KPIs renderizados (logins 6/12/24 h; sessões ativas/logadas/anônimas; buscas; eventos) | 🟢 `0/1/1`; `11/3/8`; `3`; `49` |
| Série temporal (gráfico Carbon `LineChart`, granularidade por hora) | 🟢 eixo 09:00→09:00, 24 buckets |
| Rotas mais acessadas (com volume e `%`) | 🟢 `/escola/search 44`, `/about 22`, `/escola/panel 11`, … |
| Seletor de janela (24 h → 7 dias recalcula) | 🟢 nova request `window=7d` |
| Atualização manual ("Atualizar agora") / auto-refresh 30 s | 🟢 botão presente; `REFRESH_MS=30000` |
| Requests `/api/` com status ≥ 400 | 🟢 0 |
| `Runtime.exceptionThrown` | 🟢 0 |
| Teste de unidade da página (gsap/Carbon mockados) | 🟢 4/4 |
| Suíte frontend completa | 🟢 72/76 arquivos (4 falhas pré-existentes multipart `gestor*Api`, fora do admin) |
| `vite build` | 🟢 1053 módulos transformados |
| Teste de API do backend (`t/04-api/admin/telemetry.t`) | 🟢 401/403/200, janela inválida 400 |
| Deploy | 🟢 `rex prepare` + `deploy_backend_dev` + `deploy_frontend_dev` |

> **Nota**: a página já existia na janela visível (Chrome x11 `:9223`) para
> validação visual. Nenhuma exceção e nenhuma request falhada em ambas as
> janelas (24 h e 7 d).

### Rodada 2026-10-11 — Listas com autoinscrição por QR (feat, issue #208)

**Objetivo**: certificar ponta a ponta a **Fase 0** das listas nomeadas com QR
para autoinscrição de contatos: migrations (`clean.canal_listas`,
`canal_qrcodes`, `canal_lista_membros`, `canal_inscricoes`), API de gestão
(autenticada) e face pública anônima `GET/POST /api/canais/inscricao/:token`,
mais a SPA (gestão em `/gestor/listas` e página pública `/inscricao/:token`).

Driver próprio sobre o CDP do Chrome (`:9222`), alvo `http://ubatexu.lan:8080`.
Deploy: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
`deploy_frontend_dev`. A face pública exige a flag
`canais.inscricao.enabled` (por omissão **desligada → 404**); habilitada na BD
de dev (`app_config.items`) com `public_base_url=http://ubatexu.lan:8080`.

| Verificação | Resultado |
|---|---|
| Migração aplicada (`database.edumaps`, `edumaps_dev`) | 🟢 4 tabelas + `sqitch.changes` com `canal_listas_autoinscricao` |
| `sqitch verify` (banco limpo via `ci_db.sh`) | 🟢 |
| `GET /api/canais/inscricao/:token` | 🟢 200 `{lista_nome, escola_nome, canal, campos, expira_em}` |
| Token inválido | 🟢 404 |
| `POST` válido | 🟢 201 `{ok:1}` |
| `POST` telefone repetido (normalizado) | 🟢 201 `{duplicado:1}` — **sem** sobrescrever: 1 contato, 2 inscrições (`duplicado_de`, `conflito`), 1 membro, `usos` incrementado |
| Honeypot `_hp` preenchido | 🟢 201 falso, **nada gravado** |
| Consentimento ausente | 🟢 400 |
| Telefone < 8 dígitos | 🟢 400 |
| Rate limit (token+IP, 10/60 s) | 🟢 429 após o limite |
| `GET /api/gestor/:inep/canais/listas` sem sessão | 🟢 401 |
| SPA `/inscricao/:token` (formulário) | 🟢 lista + escola renderizam; preencher + consentir + submeter → "Inscrição confirmada!" |
| SPA `/privacidade` (link do consentimento) | 🟢 "Política de Privacidade" renderiza (página nova desta rodada) |
| Testes de unidade backend (`t/02-models/canal_listas.t` + `t/04-api/canais/`) | 🟢 3 arquivos / 30 testes |
| Suíte frontend completa | 🟢 82 arquivos / 463 testes |

> **Notas**: (1) o driver do plugin `opencode-chrome-devtools` **não estava
> conectado** — usou-se um cliente CDP próprio (mesmo padrão das rodadas
> 2026-09-28 e 2026-10-09). (2) A flag por omissão desligada é intencional
> (endpoint público inexistente até decisão do admin). (3) Dados de teste
> criados em dev: lista `E2E Coord 208` (escola de gestor id 2).

### Rodada 2026-10-11 — Confirmação de posse do telefone nas listas com QR (feat, issue #212)

**Objetivo**: certificar a Fase 1 (confirmação por Telegram) ponta a ponta em
dev (`http://ubatexu.lan:8080`), com a lista `E2E 212` (exige confirmação,
escola 35038751) e um bot público **fictício** em modo webhook (token falso:
as respostas do bot falham, o que é esperado — o fluxo de confirmação não
depende delas). Driver CDP próprio em Perl (`Mojo::UserAgent` websocket),
Chrome `:9222`. As mensagens do Telegram foram simuladas com POST no webhook
público com o `secret_token`.

| Verificação | Resultado |
|---|---|
| Migração `canal_confirmacao_listas` em `database.edumaps` | 🟢 |
| `POST` inscrição em lista que exige | 🟢 201 com `confirmacao {ref, estado:"pendente", canais:[telegram url t.me/<bot>?start=<ref>]}` |
| Webhook sem `X-Telegram-Bot-Api-Secret-Token` | 🟢 401 |
| `/start <ref>` + contato próprio com o número da inscrição | 🟢 `GET /confirmacao/:ref` → `confirmado`; membro `confirmado_via=telegram`, `telegram_chat_id` gravado, `validado=true` |
| Contato de terceiro (`user_id` ≠ `from.id`) | 🟢 recusado; continua `pendente` |
| Contato com número divergente | 🟢 `conflito=true` na inscrição; membro não confirmado; nada apagado |
| Respostas do bot com token fictício | 🟢 registradas como `failed` em `canal_mensagens` (operação `confirmacao`) |
| SPA `/inscricao/:token` → passo 2 "Confirme seu telefone" com link do Telegram | 🟢 |
| Confirmação simulada → página mostra "Telefone confirmado!" **sem recarregar** (polling) | 🟢 |
| Backend (65 arquivos / 428 testes; 6 pré-falhos idênticos no `main`) | 🟢 |
| Frontend completo | 🟢 83 arquivos / 511 testes |

> **Notas**: (1) o caminho com o app real do Telegram (bot criado no
> @BotFather, modo polling) e o WhatsApp Cloud (template aprovado) não foram
> exercitados — dependem de credenciais externas; ficam para a validação do
> developer. (2) Achado de infra corrigido nesta rodada: deploys do Rex sem
> `EDUMAPS_CONFIG_MASTER_KEY` na shell gravavam a chave **vazia** nas units
> (segredos ilegíveis); agora o Rexfile aborta. Dev usa uma chave própria,
> fora do repositório.

### Rodada 2026-10-12 — E-mail e LGPD nas listas com QR (feat, issue #214)

**Objetivo**: certificar a Fase 2 em dev (`http://ubatexu.lan:8080`) com a lista
`E2E 214` (coleta `ambos`, exige confirmação, QR com limite 5 e validade) e a
versão **1.1** do consentimento (cita e-mail) publicada pelo modelo de admin.
Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Migração `canal_email_lgpd` em `database.edumaps`; 1.0 vigente no seed | 🟢 |
| Publicação da 1.1 (rascunho → vigente; 1.0 arquivada) | 🟢 |
| `GET` inscrição: `campos`/`obrigatorios` = nome, telefone, e-mail; consentimento 1.1 | 🟢 |
| `POST` com `consentimento_versao` 1.0 (desatualizada) | 🟢 409 |
| `POST` sem e-mail (coleta `ambos`) / e-mail inválido | 🟢 400 / 400 |
| `POST` válido | 🟢 201 com `exclusao_url` e `contatos` (telefone e e-mail pendentes) |
| SPA: campo e-mail + termo 1.1 visível → inscrição → link "Remover meus dados" | 🟢 |
| SPA `/privacidade/exclusao/:token` → confirmar → "Seus dados foram removidos"; recarregar → já excluído | 🟢 |
| Varredura de PII no banco (contatos, inscrições, membros, refs, confirmações, mensagens) após exclusão pelo titular | 🟢 0 ocorrências |
| Remoção pelo gestor (modelo) com motivo; varredura de PII | 🟢 0 ocorrências; auditoria `gestor` com motivo |
| Auditoria `canal_exclusoes` sem PII (titular, gestor) | 🟢 |
| Retenção avulsa: 3 linhas de resumo (`cod_inep=0`) mesmo com zero | 🟢 |
| Inscrições com `consentimento_hash` e `anonimizado_em` | 🟢 2/2 |
| Backend (74 arquivos / 476 testes; 6 pré-falhos idênticos no `main`) | 🟢 |
| Frontend completo | 🟢 88 arquivos / 611 testes |

> **Notas**: (1) envio real de código por e-mail não exercitado — não há SMTP
> em dev; coberto por testes com SMTP simulado. (2) A versão 1.1 do
> consentimento fica publicada em dev (pré-requisito para listas com e-mail).

### Rodada 2026-10-12 — Envio por e-mail para listas com QR (feat, issue #216)

**Objetivo**: certificar a Fase 3 em dev (`http://ubatexu.lan:8080`) com envio
**real por SMTP**: um Mailpit temporário no `ubaxala` (`axllent/mailpit:v1.21.0`,
só `127.0.0.1`) recebe os e-mails do backend por um túnel SSH reverso
(`backend.edumaps:127.0.0.1:1025` → Mailpit); `canais.email.*` de dev apontou
para ele só durante a rodada. Listas `E2E 216 A` e `B` (coleta e-mail, sem
exigência), 4 inscritos pela API pública (Carla nas duas listas), sessões
temporárias de gestor e admin. Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Migração `canal_envios` em `database.edumaps` | 🟢 |
| Limites: SMTP disponível, saldo 500/500 | 🟢 |
| Lista dinâmica A+B: prévia com 4 destinatários (Carla deduplicada), amostra mascarada | 🟢 |
| Rascunho → prévia (rodapé + estimativa 3) → teste (`[Teste]` no Mailpit) | 🟢 |
| Disparo imediato → job `canais_envio` → **concluído, 3 enviados, 0 falhas** | 🟢 |
| Cada e-mail: rodapé com lista e link pessoal; `List-Unsubscribe` = link, `List-Unsubscribe-Post: One-Click`, `Precedence: bulk` | 🟢 3/3 |
| Destinatários mascarados na API | 🟢 |
| SPA `/privacidade/sair/:token` pelo link do e-mail → "Pronto, você saiu" → recarregar → "já tinha saído" | 🟢 |
| One-Click (RFC 8058, form) | 🟢 200 |
| Selo de opt-out só em quem saiu; contador de saídas do envio = 2 | 🟢 |
| Envio pela lista dinâmica: 2 opt-out + 1 duplicado ignorados; só Carla (uma vez) e Davi receberam | 🟢 |
| Reinscrição pelo QR desfaz o opt-out (`n_optouts` 2 → 1) | 🟢 |
| Funil: acessos, inscrições, saídas, `confirmados` null (lista sem exigência), série diária completa | 🟢 |
| Agendado → admin suspende (201) → envio `suspenso`; disparo com escola suspensa → 409 `escola_suspensa` | 🟢 |
| Reativar → envio volta a `agendado` (não antecipa); cancelar | 🟢 |
| Cota da escola em 1 → disparo → 409 `cota_insuficiente` (saldo 0) | 🟢 |
| Remoção pelo gestor → varredura de PII: destinatários de envio só com hash (sem e-mail/contato), mensagens/contatos/inscrições sem resto | 🟢 0 ocorrências |
| Telas: `EnviosPage`, detalhe, `SegmentosPage`, `ListasPage` (+ aba Funil), painel Envios do admin no `/config` | 🟢 |
| Backend 81 arquivos / 508 testes (6 pré-falhos idênticos no `main`); frontend 96 / 718 | 🟢 |

> **Achados corrigidos na rodada**: (1) faltava espaço entre o nome da lista e
> "da escola" na página de saída; (2) "1 saíram dos envios" → "1 saiu".
> **Comportamento documentado**: a taxa acesso → inscrição pode passar de 100%
> (inscrições sem abrir a página, ou várias a partir de um acesso).
> **Não exercitado**: provedor SMTP real (só captura), WhatsApp/Telegram no
> envio (fora do escopo).

### Rodada 2026-10-12 — Assistente de Relatório (feat, issue #219, Fase 1)

**Objetivo**: certificar a Fase 1 em dev (`http://ubatexu.lan:8080`) de ponta
a ponta: Perl → Minion (fila `analytics`) → R (`/report`, `edumapsAnalytics`)
→ eduBR (`2dc9af9`, persona pesquisadora, role `edumaps_leitor`) → **LLM real
do painel (Gemini)** → tela `/gestor/relatorios`. Sessão temporária do gestor
da escola 35038751 (Ubatuba/SP). Driver CDP próprio em Perl (Chrome `:9222`).

| Verificação | Resultado |
|---|---|
| Sem sessão → 401 | 🟢 |
| Recorte-padrão: escola → Ubatuba (SP, SE) | 🟢 |
| Temas do nível UF = IDEB, redes, professores, gestores | 🟢 |
| Escola de outro gestor → 400; tema fora do nível → 400 | 🟢 |
| `minha_escola` (escola) | 🟢 ~5 s, 6 seções |
| `ideb_territorio` (município, anos iniciais) | 🟢 ~7 s |
| `docentes_territorio` (UF BA) | 🟢 ~5–9 s |
| `gestores_territorio` (região S) | 🟢 ~11–13 s |
| `tendencia_ideb` (região NE, anos finais) | 🟢 ~6–7 s |
| Texto redigido pelo Gemini (`rastreio.llm = ok`) em todos | 🟢 |
| Pedido repetido servido do cache (~1,6 s, `cache_hit`) | 🟢 |
| Sem PII nos relatórios (endereço, telefone, CEP, CNPJ, e-mail) | 🟢 |
| Tela: recorte, temas, opções, "Gerar relatório" → seções + fontes | 🟢 |
| Backend 103 / 676 (só falhas antigas); R 28 arquivos / 1085 asserções; frontend 101 / 779 | 🟢 |

> **Achados corrigidos na rodada**:
> 1. o texto do LLM usava ponto decimal e citava o nome interno da
>    ferramenta: os dados para o LLM passaram a sair arredondados pelo formato
>    e sem nome de ferramenta, e o prompt pede padrão brasileiro;
> 2. faltava espaço nos separadores "·" do cabeçalho e das fontes;
> 3. `censo-dictionary.R` estava fora do `Collate` e quebrou a reinstalação do
>    pacote no deploy.
>
> **Observações**:
> - logo depois de um deploy do `analytic`, os jobs que pegam o reinício do
>   serviço R falham (não há nova tentativa);
> - a chave do cache de relatórios não inclui a versão do prompt nem do
>   pacote, então uma mudança de texto só aparece depois de 24 h ou de limpar
>   o cache;
> - logo após o deploy do frontend, o service worker pode servir o bundle
>   antigo (tela em branco até recarregar).

### Rodada 2026-10-12 — Assistente de Relatório, Fase 2 (feat, issue #219)

**Objetivo:** certificar os temas de aprofundamento em dev
(`http://ubatexu.lan:8080`), com o **Gemini real**, gestor da escola 35038751
(Ubatuba/SP) e sessão temporária. Driver CDP próprio em Perl, um caso por aba.

| Verificação | Resultado |
|---|---|
| Catálogo: `ideb_escolas` (município, profunda); temas da escola (minha escola, histórico, parecidas) | 🟢 |
| `ideb_escolas` Ubatuba (anos finais): 11 escolas com nota, mediana 4,7, **"7ª de 11"**, linha da escola destacada | 🟢 ~6–8 s |
| `infraestrutura_ideb` BA e SP: seção de associações (10 itens urbano/rural), 2 tabelas técnicas recolhidas, aviso "associação" | 🟢 ~6 s |
| `historico_escola`: gráfico de linhas, série, scores | 🟢 ~5 s |
| `escolas_parecidas`: **10 escolas distintas**; "Todas as etapas" por padrão | 🟢 ~11 s |
| Regressão: `ideb_territorio` (Fase 1) segue OK | 🟢 |
| Avisos e fontes sem nome interno de ferramenta; sem PII; texto da regressão fala em associação | 🟢 |
| Tela: tema certo por nível, associações, "Associação não é causa" no topo, `<details>` técnicos, "★ sua escola" | 🟢 11/11 |
| R 29 / 1374 asserções; frontend 101 / 795; Perl dos relatórios 2 / 23 | 🟢 |

> **Achados corrigidos na rodada:**
> 1. **Pilha estourando no Plumber.** O `escolas_similares` estourava a pilha
>    de C do R (8 MB) dentro do Plumber; agora a pilha é de 64 MB, via
>    `LimitSTACK` na unit e `ulimits` no compose. A integração fora do
>    Plumber não reproduzia o erro.
> 2. **Etapa obrigatória sem padrão.** A etapa era sempre obrigatória e
>    enviava "anos iniciais" a uma escola que não os oferece. O catálogo passou
>    a expor `padroes`, e a etapa sem padrão vira "Todas as etapas".
> 3. **Nomes internos na tela.** Os avisos e o rodapé de fontes mostravam
>    nomes internos de ferramenta; foram removidos.
> 4. **Menos escolas parecidas que o pedido.** A ferramenta devolvia 7 escolas
>    distintas para `n = 10`; agora pede 20 linhas e fica com 10 escolas.
> 5. **Cache entre versões.** Uma mudança do pacote R só aparecia depois de
>    24 h de cache. Agora `edumapsAnalytics` 0.2.0 e `analytics_source_version`
>    sobem juntos.
>
> **Nota do driver:** o Mojo limita mensagens de WebSocket a 256 KB e
> derrubava as capturas grandes; use `max_websocket_size`.

### Rodada 2026-10-12 — Assistente de Relatório, Fase 3 (feat, issue #219)

**Objetivo:** certificar a exportação e os relatórios salvos em dev, com o
Gemini real, o gestor da escola 35038751 e uma sessão temporária. O Chrome usa
download real (`Browser.setDownloadBehavior`) e `Page.printToPDF` para a
versão de impressão.

| Verificação | Resultado |
|---|---|
| Salvar job concluído → 201; de novo → 200 com o mesmo id; job em andamento → 409; inexistente → 404 | 🟢 |
| Fotografia = resultado do job (corpo enviado pelo cliente ignorado; sem `cache_hit`) | 🟢 |
| Query `?nivel=uf&codigo=BA&…&gerar=1` preenche o recorte e gera | 🟢 |
| "Salvar relatório" → "Salvo"; "Meus relatórios" lista; "Abrir" mostra "Fotografia de …"; "Gerar de novo" gera com os dados atuais | 🟢 |
| Markdown baixado (`relatorio-docentes-territorio-bahia-2026-10-12.md`): título, tabelas pt-BR, fontes, sem nomes internos | 🟢 |
| `<details>` abertos no `beforeprint`; PDF A4 com 2 páginas, sem navegação nem formulário | 🟢 |
| Exclusão dos salvos do teste; lista vazia | 🟢 |
| Backend 102 / 690 (só falhas antigas); frontend 105 / 864; `relatorios_salvos` verify OK | 🟢 |

> **Achado corrigido:** a tabela de dados dos gráficos (tela, PDF e
> Markdown) ignorava o `formato` da seção e mostrava frações ("0,8") em vez de
> percentuais ("80,3%").
>
> **Pendência visual:** o eixo do gráfico continua de 0 a 1 para séries
> percentuais.

### Rodada 2026-10-12 — Assistente de Relatório, Fase 4 (feat, issue #219)

**Objetivo:** certificar os assistentes declarativos ("Relatório por tema" e
"EDA do município") em dev (`http://ubatexu.lan:8080`), com o **Gemini real**,
o gestor da escola 35038751 (Ubatuba/SP) e uma sessão temporária. Driver CDP
próprio em Perl, um caso por aba; PDF por `Page.printToPDF` e download real
do Markdown.

| Verificação | Resultado |
|---|---|
| Assistentes listados: "Relatório por tema" e "EDA do município" | 🟢 |
| EDA em nível UF → 400; assistente desconhecido → 400 | 🟢 |
| EDA de Ubatuba: 5 capítulos, incluindo "Minha escola no município" | 🟢 ~34 s a frio; 1,6 s do cache |
| Seções gerais `resumo` (primeira) e `leitura` (última), sem capítulo | 🟢 |
| Etapa escolhida sobrepõe a etapa fixa dos capítulos de IDEB | 🟢 |
| EDA salva com o assistente; salvos mostram o selo do assistente | 🟢 |
| "Relatório por tema" intacto (comportamento das Fases 1–3) | 🟢 |
| Tela: seletor de assistente, sumário com âncoras, `h2` por capítulo | 🟢 |
| Markdown com sumário, `##` por capítulo e `###` por seção; PDF da versão de impressão | 🟢 |
| "Gerar de novo" a partir de um salvo refaz a EDA | 🟢 |
| R 30 arquivos / 1591 asserções / 0 falhas; backend 102 / 697 (só falhas antigas); frontend 106 / 899; `relatorios_salvos_assistente` verify OK | 🟢 22/22 |

> **Achados corrigidos na rodada:**
> 1. **Resumo da EDA truncado.** O saneamento de HTML do texto do LLM usava
>    uma regex gananciosa que engolia o trecho entre comparações
>    ("4,5 < 4,7 … > 4"); agora só remove o que parece tag.
>    `edumapsAnalytics` 0.3.1 e `analytics_source_version` 0.3.1.
> 2. **Bundle antigo após o deploy.** O primeiro carregamento depois do
>    deploy do frontend veio do service worker antigo (problema já conhecido;
>    recarregar resolve).
>
> **Pendências:**
> - a EDA leva ~25–34 s por município (fatias de redes e docentes no eduBR);
> - eixo percentual dos gráficos de 0 a 1;
> - paginação de listas grandes;
> - achados para o eduBR: filtro por município nas ferramentas agregadas,
>   filtro em `regressao_escolas` e código do município na saída de
>   perfil/resumo da escola;
> - modelagem do perfil pesquisador (o catálogo já tem profundidade e
>   público).

### Rodada 2026-10-13 — Assistente do Censo com sessão (fix, issue #224) e atualização da SPA (fix, issue #225)

**#224, em dev** (Gemini real; sessões temporárias de dois gestores):

| Verificação | Resultado |
|---|---|
| `ask` e `progress` sem sessão | 🟢 401 |
| Escopo forjado no corpo (Salvador/BA, INEP falso) ignorado; job com o escopo da sessão (Ubatuba/35038751) | 🟢 |
| `progress` do job de outro gestor | 🟢 404 |
| Tela: sem sessão pede login; com sessão mostra o escopo da conta (só leitura) | 🟢 |
| Resposta em markdown (negrito, lista) e gráfico de barras desenhado com a tabela de dados | 🟢 |

**#225:**

| Verificação | Resultado |
|---|---|
| Dev (`http://ubatexu.lan`) não é contexto seguro, então **não há service worker** ali (`isSecureContext=false`) | diagnóstico |
| Sonda durante o `deploy_frontend_dev` atômico: 87 pedidos a `/` + asset principal | 🟢 0 falhas |
| Asset do build anterior servido depois do deploy (abas abertas) | 🟢 200 |
| Stack local (`localhost:8080`), aba aberta, transição do SW antigo: aviso → Atualizar → `edumaps-v2` apagado | 🟢 |
| 2º e 3º builds: aviso → Atualizar → recarga → só o cache do build atual; nome determinístico (`edumaps-17265fae` ↔ `edumaps-0ea1e1e7`) | 🟢 3/3 cada |

> **Pendência menor (#224):** os títulos dos eixos do gráfico usam o nome
> técnico da coluna escolhido pelo LLM (ex.: `total_escolas`).

### Rodada 2026-10-13 — Dicionário do Censo a partir do INEP (feat, issue #134)

Sem mudança de tela. Verificação em dev (`edumaps_dev`, dados reais de 2025) e
no CI (fixtures):

| Verificação | Resultado |
|---|---|
| Change `censo_data_dictionary_inep` aplicada em `database.edumaps`; verify em gate no CI | 🟢 |
| Dicionário: 760 colunas `inep` + 5 `derivada`; **229 com domínio oficial** (antes 15, a maioria errada) | 🟢 |
| `tp_aee` = Não oferece / Não exclusivamente / Exclusivamente | 🟢 |
| `clean.censo_dict_violacoes()` sobre os 214 mil registros reais | 🟢 **0 violações** (~29 s) |
| Gate no CI (fixtures): função vazia; código e coluna plantados são detectados | 🟢 |
| Gerador: 25 testes unittest (xlsx sintético); CSV regenerado byte a byte igual | 🟢 |
| Assistente do Censo: dicionário do prompt com 8 tabelas e rótulos oficiais (antes **vazio** desde `eaaf66d`) | 🟢 |
| R 31 / 1658; backend só falhas antigas | 🟢 |
