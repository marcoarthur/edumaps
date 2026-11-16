# Roteiro do deploy do LXC — segunda, 2026-11-16

O LXC está fora do ar desde 2026-11-03. Tudo o que entrou no `main` desde então
foi validado só no Docker local e vai ao LXC de uma vez. Este roteiro junta a
fila espalhada pelo `memory.md` e pelas notas técnicas 165–198, na ordem em que
deve correr.

Rodar sempre a partir de `backend/script/deploy`, com o working tree em `main`
limpo e atualizado (o deploy é rsync do working tree).

## 0. Antes de começar

```bash
cd ~/Code/Data/leaflet
git checkout main && git fetch origin && git merge --ff-only origin/main
git status --short                       # vazio: nada local entra no rsync
gh run list --branch main --limit 3      # CI do SHA mais novo verde
export EDUMAPS_CONFIG_MASTER_KEY="$(cat ~/.config/edumaps/dev_master_key)"
cd backend/script/deploy
```

- [ ] Os três hosts respondem (são aliases do `~/.ssh/config`, sem DNS; conferências de HTTP vão por `ssh`): `ssh root@backend.edumaps true`,
      `ssh root@database.edumaps true`, `ssh root@analytic.edumaps true`.
- [ ] **Banco certo:** o backend fala com `172.19.198.3` (`database.edumaps`),
      não com o `database.dev`:
      `ssh root@backend.edumaps 'ss -tnp | grep :5432'`.
- [ ] Disco do banco: a recarga de ES/MG (passo 6) ocupa ~1 GB.
      `ssh root@database.edumaps 'df -h /var/lib/postgresql'`.
- [ ] Estado do serviço R, em `failed` desde 31/10 na última vez que foi
      visto: `ssh root@analytic.edumaps 'systemctl status edumaps-analytic --no-pager'`.
      O `deploy_analytics_dev` do passo 5 o reinstala; anotar o estado antes.

## 1. Sincronizar

```bash
rex prepare
```

## 2. Banco — `deploy_db_dev`

Ver o que falta antes de aplicar:

```bash
ssh root@database.edumaps "sudo -u postgres psql edumaps_dev -Atc \
  \"SELECT change FROM sqitch.changes ORDER BY committed_at DESC LIMIT 5\""
```

⚠️ Não usar `sqitch status` sem alvo: o target padrão do `sqitch.conf` é
`dev_super` (`ubatexu.lan:5432`, o `database.dev`), **outra base**. O registry
consultado acima é o do banco que o backend usa.

Changes esperadas como pendentes (as do plano desde 2026-11-02; o
`gestores_email_unico_sem_caixa` já foi aplicado no LXC, e outras do dia 02 podem
já estar lá — o registry é quem diz):

| Change | Origem |
|---|---|
| `gestores_senha_argon2id`, `auth_falhas`, `gestor_senha_redefinicao` | #334–#336 (login) |
| `auth_falhas_canais`, `sessoes_token_hash`, `leitor_sem_tabelas_sensiveis` | PR #340/#341 |
| `auth_falhas_telegram`, `leitor_grants_explicitos` | PR #343/#345 |
| `staging_schema` | PR #353 |
| `antt_acidente_geolocalizacao`, `antt_sem_fonte` | #168 (ANTT) |
| `planos_gestao`, `planos_indicadores`, `planos_alertas`, `planos_evidencias`, `planos_base_oficial` | épico #368 |
| `rede_acesso`, `planos_custo_executado` | #375 (visão da rede) |
| `inep_rendimento_distorcao` | #376 |
| `idempotencia` | #416 |
| `analytics_cluster_execucoes` | #427 |

```bash
rex -H database.edumaps deploy_db_dev
ssh root@database.edumaps "sudo -u postgres psql edumaps_dev -Atc \
  \"SELECT change FROM sqitch.changes ORDER BY committed_at DESC LIMIT 5\""
```

- [ ] A última change do registry é `analytics_cluster_execucoes` (#427; antes era `idempotencia`) e o `deploy_db_dev` não
      reportou erro.
- [ ] Não rodar `sqitch verify` global: o registry do LXC dá ~45 "Out of
      order" históricos (ver AGENTS.md). Para conferir uma change, rodar o
      `verify/<change>.sql` dela no banco.
- 🔴 Se algo falhar: **nada de `sqitch revert` sem `--to`**. Parar e
  investigar; correção de change deployada é change nova.

## 3. Backend e minion

```bash
rex -H backend.edumaps deploy_backend_dev
rex -H backend.edumaps deploy_minion_dev
```

O que entra: login com Argon2id e limites, sessão com hash, proxy confiável,
planos de gestão, visão da rede, INEP, idempotência (#416), embeddings diários
(#413), as tasks diárias novas, as escolas semelhantes com etapa em comum e a
chave de cache do perfil com a regra dos sinais (#421), e o financeiro com
`ausencia`/`cobertura` sem o vazamento da folha da secretaria (#422).
A busca por município com código IBGE e a ordem das sugestões (#431).

O `cpanfile` não pede mais o PDL (#419). O PDL já instalado no host pode
ficar: nada mais o carrega, e não é preciso desinstalar.

- [ ] md5 de um arquivo característico igual ao local:
      ```bash
      ssh root@backend.edumaps md5sum /opt/edumaps/backend/lib/EduMaps/Plugin/Idempotencia.pm
      md5sum ../../lib/EduMaps/Plugin/Idempotencia.pm
      ```
- [ ] Serviços de pé ~30 s depois (o md5 não pega worker que caiu):
      `ssh root@backend.edumaps 'systemctl is-active edumaps-web edumaps-minion edumaps-minion-analytics'`.
- [ ] As tasks diárias se agendaram sozinhas no boot do worker
      (`planos_alertas`, `planos_oficiais` 06:00, `refresh_school_embeddings`
      05:00): no painel do Minion ou
      ```bash
      ssh root@database.edumaps "sudo -u postgres psql edumaps_dev -c \
        \"SELECT task, state, delayed FROM minion_jobs WHERE task IN \
        ('planos_alertas','planos_oficiais','refresh_school_embeddings') \
        AND state IN ('inactive','active') ORDER BY task\""
      ``` Um job `inactive` por
      task, com `delayed` na próxima janela.
- [ ] API responde: `ssh root@backend.edumaps 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/api/school/11000023/ivet'`
      → 200 (o backend do LXC escuta na **3000**, não na 3010 do Docker).

## 4. Frontend

```bash
rex -H backend.edumaps deploy_frontend_dev
```

Leva o template novo do nginx (só a SPA e `/api/`, PR #344), as travas de
envio (#415/#416), planos, visão da rede e documento da rede, os totais das
roscas e o "menor é melhor" (#421) e a ausência no financeiro e na folha
(#422), os menus dos gráficos em PT-BR e a página de Análises sem jargão
(#431), a página `/fontes` e o selo de fonte (#428) e a página `/ranking` (#430, com o salto atípico, o mínimo e a ordem da #437). O `frontend/nginx.conf` do #423 é só da stack Docker; o LXC usa o
template do Rexfile.

- [ ] O bundle novo está no ar: a chave de envio está nele.
      `ssh root@backend.edumaps 'grep -l Idempotency-Key /var/www/edumaps-frontend/assets/*.js'`.
- [ ] nginx só com as rotas em uso:
      `ssh root@backend.edumaps 'grep -c analytic-api /etc/nginx/sites-available/edumaps-frontend.conf'`
      → 0, e `ssh root@backend.edumaps 'curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1/analytic-api/health'`
      → não 200.
- [ ] Na tela (`http://ubatexu.lan:8080`): login de gestor, um plano, a visão
      da rede. Um duplo clique em "Salvar meta" cria uma meta só.

## 5. Motor analítico — `deploy_analytics_dev`

```bash
rex -H analytic.edumaps deploy_analytics_dev
```

Leva `ivet-v1.3` (acesso em log, #295/PR #362) e a instalação completa das
dependências do `DESCRIPTION` (#363: o deploy falha se faltar alguma; o Rexfile
já instala `libsodium-dev` e `libuv1-dev`), mais os sinais de atenção v2 do
perfil da escola (#421). O cache antigo do perfil é ignorado sozinho
(`regra_sinais` diferente; agora 3, com o rótulo do IDEB com a etapa, #431).
O agrupamento passa a guardar cada execução (#427): o motor grava em
`analytics.cluster_atribuicoes` com o mesmo usuário do banco que já grava
`analytics.clustering_metadata`; conferir com um agrupamento de teste na tela
(caixa **Universo** e **Baixar CSV**; o arquivo sai como
`agrupamento-censo<ano>-ideb<ano>-<run_id>.csv`, com as colunas `ano_censo` e
`ano_ideb`, #438).

- [ ] `ssh root@analytic.edumaps 'systemctl is-active edumaps-analytic'`.
- [ ] O backend alcança o motor pelo `analytics_url` do LXC
      (`http://analytic:8000`, em `files/edumaps_db.conf`):
      `ssh root@backend.edumaps 'curl -s -o /dev/null -w "%{http_code}\n" http://analytic:8000/health'`
      → 200. O `run.R` escuta em `0.0.0.0`.

## 6. Cargas pós-deploy

Rodar no `backend.edumaps`, em `/opt/edumaps/backend`, uma de cada vez
(conferir o minion entre elas):

1. **INEP — rendimento e distorção (#376):**
   ```bash
   perl -Ilib ingestion_runner.pl --job=INEPIndicadores
   ```
   Esperado: ~925 mil (rendimento) e ~933 mil (distorção) linhas para
   2023–2025, como na carga local. O LXC precisa alcançar
   `download.inep.gov.br`; a cadeia TLS vai versionada em
   `lib/EduMaps/Ingestion/certs/`.
2. **ANTT (#168):** antes, ver a memória livre do minion
   (`free -h`): a carga completa teve pico de 1,67 GB local.
   ```bash
   perl -Ilib ingestion_runner.pl --job=ANTT
   ```
   Esperado: ~80% dos acidentes com município. Se faltar memória, rodar com
   `--arg apenas_marcos` depois de uma carga parcial (nota técnica 189).

## 7. Isócrona ES/MG e IVET (#295)

Os CSVs ficam no host local (`~/Code/Data/osm/piloto_es_s2/` e
`~/Code/Data/osm/piloto_mg/`); os scripts falam com o banco por SSH. Da raiz do
repositório:

```bash
bash db/isocrona/cobertura_snapshot.sh            # deve acusar ES e MG fora do vigente
UF=ES CSV=~/Code/Data/osm/piloto_es_s2/isocrona_escolar.csv SNAPSHOT=<vigente> \
  bash db/isocrona/recarregar_csv.sh
UF=MG CSV=~/Code/Data/osm/piloto_mg/isocrona_escolar.csv SNAPSHOT=<vigente> \
  bash db/isocrona/recarregar_csv.sh
bash db/isocrona/cobertura_snapshot.sh            # rc=0: nenhuma UF fora
```

`<vigente>` é o snapshot mais recente que o primeiro `cobertura_snapshot.sh`
mostra (esperado `2026-10-21`). A carga roda destacada no host do banco
(systemd-run); acompanhar pela unit `carga-<UF>`.

Depois, reprocessar o IVET pelo job `refresh_ivet` (fila `analytics`), como na
validação de 2026-10-20, e conferir:

- [ ] ES e MG com acesso calculado (não `n/d`), fórmula `ivet-v1.3`.
- [ ] Publicáveis próximos dos 145 mil da última medição nacional.
- [ ] Fechar a #295 e abrir a issue de Sul, Centro-Oeste e Norte (~47 mil
      escolas), condicionada a ampliar o disco do banco.

## 8. Fechamento

- [ ] Imagens Docker locais já correspondem ao `main` (feito nos merges).
- [ ] `memory.md`: sessão do deploy, com o que rodou, contagens e o que ficou.
- [ ] Remover o "LXC fora" das pendências; a #138 segue para a medição dos
      componentes no LXC (spec `docs/specs/2026-11-13-similaridade-territorial.md`).
- [ ] `tools/notify/notify.sh --event done --title "Deploy do LXC" --msg "..."`.

## Se algo der errado

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `deploy_backend_dev` aborta com "EDUMAPS_CONFIG_MASTER_KEY vazia" | variável não exportada neste shell | passo 0 |
| `Cannot find change ... in sqitch.plan` | rsync incompleto (plano velho no host) | refazer `rex prepare` e conferir `wc -l` do plano no host |
| Minion `failed` logo após o deploy | módulo Perl novo ausente (ex.: `Crypt::Argon2`, `Crypt::URandom`) | `journalctl -u edumaps-minion -n 50`; o `deploy_backend_dev` instala o `cpanfile` (repetir backend e depois minion) |
| Login do gestor recusa senha certa | conta antiga ainda com hash velho | não deveria: o hash antigo é aceito e regravado no primeiro login certo (nota 165); olhar o log |
| `deploy_analytics_dev` falha na verificação | dependência do `DESCRIPTION` sem lib de sistema | a mensagem lista o pacote; instalar a lib `-dev` e repetir |
