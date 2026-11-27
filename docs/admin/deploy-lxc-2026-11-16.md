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
| `escolas_scores_diversidade_esp` | #459 (recria `clean.mv_escolas_scores`; ver §6, passo 3) |
| `escolas_scores_versao` | #462 (só o COMMENT da `clean.mv_escolas_scores`, com `VERSÃO indices-v2`; sem recálculo) |
| `escolas_scores_sem_registro` | #467 (recria `clean.mv_escolas_scores`: índice `NULL` sem registro de matrículas/docentes/gestores, `VERSÃO indices-v3`; ver §6, passo 3) |
| `escolas_scores_cor_declarada` | #471 (recria `clean.mv_escolas_scores`: parte racial da diversidade sobre as matrículas com cor declarada, `VERSÃO indices-v4`; ver §6, passo 3) |
| `escolas_scores_turnos` | #473 (recria `clean.mv_escolas_scores`: alunos por sala e por turno na capacidade de atendimento, `VERSÃO indices-v5`; ver §6, passo 3) |
| `escolas_scores_gestora` | #475 (recria `clean.mv_escolas_scores`: capacidade gestora com partes vazias sem matrícula e nas privadas, `VERSÃO indices-v6`; ver §6, passo 3) |
| `rede_escolas_ativas` | #479 (recria `analytics.mv_rede_escolas` só com as escolas em funcionamento; a comparação de redes soma ~180,5 mil escolas no Brasil) |
| `school_embedding_l2` | #487 (troca o índice HNSW de `analytics.school_embedding` do cosseno para `vector_l2_ops`; leva alguns minutos com ~178 mil vetores; os vetores não mudam) |
| `ranking_escola_empates` | #506 (colunas `empate_municipio/estado/nacional` em `analytics.ranking_escola`; vazias até o `ranking.pl` do §6) |
| `rede_escolas_creche_pre` | #516 (recria `analytics.mv_rede_escolas` com `matriculas_creche` e `matriculas_pre`; a coluna da infantil fica) |
| `rede_escolas_conveniadas` | #518 (recria `analytics.mv_rede_escolas` com `escolas_conveniadas`, `matriculas_creche_conveniada` e `matriculas_pre_conveniada`) |
| `docentes_formacao_continuada_rotulos` | #522 (só comentários: as 19 colunas `qt_doc_bas_espec_*` como formação continuada, não especialização; sem recálculo) |
| `escolas_scores_vinculo` | #524 (recria `clean.mv_escolas_scores`: capacitação docente com os concursados vazios nas privadas, peso redistribuído, `VERSÃO indices-v7`; comentários curtos em `school_indicators`; ver §6, passo 3. No Postgres do Docker local precisou de `PGOPTIONS="-c max_parallel_workers_per_gather=0"`: a consulta paralela estourou o `/dev/shm` de 64 MB) |
| `populacao_idade_censo2022` | #533 (visão `clean.populacao_idade` sobre `clean.ibge_agregados`, vazia até a carga `IBGEPopulacaoIdade` do §6; comentário de origem nas `faixa_*` de `clean.populacao_municipal`) |
| `remuneracao_nomes_utf8` | #536 (repara os nomes da folha do SIOPE codificados duas vezes na fonte: decodifica, recupera a letra perdida pelo CPF e marca o resto com "?"; sem revert de dado) |
| `rede_escolas_df` | #545 (recria `analytics.mv_rede_escolas`: no DF, as privadas conveniadas com o governo distrital, esfera estadual, contam como conveniadas. No Docker local precisou de `PGOPTIONS="-c max_parallel_workers_per_gather=0"`) |

```bash
rex -H database.edumaps deploy_db_dev
ssh root@database.edumaps "sudo -u postgres psql edumaps_dev -Atc \
  \"SELECT change FROM sqitch.changes ORDER BY committed_at DESC LIMIT 5\""
```

- [ ] A última change do registry é `rede_escolas_df` (#545; antes `remuneracao_nomes_utf8`, #536) e o `deploy_db_dev` não
      reportou erro. `psql edumaps_dev -f verify/rede_escolas_df.sql` (falha se as conveniadas do DF na MV não baterem com o Censo). `psql edumaps_dev -f verify/remuneracao_nomes_utf8.sql` (falha se algum nome da folha ainda tiver "Ã"/"Â" seguido de byte de continuação ou "ÿ"). `psql edumaps_dev -f verify/populacao_idade_censo2022.sql` (falha sem a visão `clean.populacao_idade`, sem o GRANT ao `edumaps_leitor` ou sem o comentário de origem nas `faixa_*`). Conferir as seis últimas pelos verifies:
      `psql edumaps_dev -f verify/escolas_scores_diversidade_esp.sql` (falha se a MV ainda somar os turnos) e
      `psql edumaps_dev -f verify/escolas_scores_versao.sql` (falha se o COMMENT da MV não trouxer `indices-vN`) e
      `psql edumaps_dev -f verify/escolas_scores_sem_registro.sql` (falha se houver 0 onde falta o registro ou sem `indices-v3` ou posterior) e
      `psql edumaps_dev -f verify/escolas_scores_cor_declarada.sql` (falha se a diversidade não bater com a fórmula da `indices-v4`) e
      `psql edumaps_dev -f verify/escolas_scores_turnos.sql` (falha se o atendimento não bater com a fórmula da `indices-v5`) e
      `psql edumaps_dev -f verify/escolas_scores_gestora.sql` (falha se a capacidade gestora não bater com a fórmula da `indices-v6`) e
      `psql edumaps_dev -f verify/rede_escolas_ativas.sql` (falha se a comparação de redes contar escola fora de funcionamento) e
      `psql edumaps_dev -f verify/school_embedding_l2.sql` (falha se o índice das escolas semelhantes não for `vector_l2_ops`) e
      `psql edumaps_dev -f verify/ranking_escola_empates.sql` (falha se faltar alguma das três colunas de empate) e
      `psql edumaps_dev -f verify/rede_escolas_creche_pre.sql` (falha se faltar creche ou pré-escola, ou se as duas não somarem a infantil) e
      `psql edumaps_dev -f verify/rede_escolas_conveniadas.sql` (falha se faltar coluna, se uma rede pública tiver conveniadas ou se as conveniadas passarem dos totais) e
      `psql edumaps_dev -f verify/docentes_formacao_continuada_rotulos.sql` (falha se um comentário de `qt_doc_bas_espec_*` ainda disser especialização) e
      `psql edumaps_dev -f verify/escolas_scores_vinculo.sql` (falha se a capacitação docente não bater com a fórmula da `indices-v7` ou faltar comentário da #524).
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
O IVET com o motivo de ficar sem número (`blocos_faltando`) e a versão
citável em `/fontes` (#489).
A folha contada pela pessoa e um ano por vez no painel financeiro, e o bloco
de remuneração da base de análise (#491).

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
- [ ] A mesma resposta traz `blocos_faltando` (lista vazia se a escola tem C,
      D e E), #489.
- [ ] Folha (#491): `curl -s http://127.0.0.1:3000/api/school/51037343/finance?ano=2025`
      traz `ano`, `anos` e `periodo` (12 meses, se o LXC tiver a folha de
      Cuiabá), e `/api/base-analise/csv?uf=MT&codigo_ibge=5103403&blocos=remuneracao`
      sai como `…-siope<ano>.csv`, com `prof_magisterio` … `meses_folha`.

## 4. Frontend

```bash
rex -H backend.edumaps deploy_frontend_dev
```

Leva o template novo do nginx (só a SPA e `/api/`, PR #344), as travas de
envio (#415/#416), planos, visão da rede e documento da rede, os totais das
roscas e o "menor é melhor" (#421) e a ausência no financeiro e na folha
(#422), os menus dos gráficos em PT-BR e a página de Análises sem jargão
(#431), a página `/fontes` e o selo de fonte (#428) e a página `/ranking` (#430, com o salto atípico, o mínimo e a ordem da #437, o porte do município da #439 e a região da #445; conferir que `/api/ranking/redes?indicador=ideb_anos_iniciais&regiao=NE` responde 200; o CSV baixado traz `recorte`, #448; e `&destaque=3205309` traz o bloco `destaque`, #449; o CSV de redes traz `posicao_valor` e `posicao_variacao`, #453; `/api/ranking/escolas?codigo_ibge=2204402&indicador=infraestrutura_basica` traz `faltam` e `indicador.metodo`, #457; com `indicador=diversidade_discente`, `indicador.versao = indices-v7` (#524); `GET /api/cluster/presets` traz `etapa_filter` e `etapas` no `desempenho`, e `POST /api/task/cluster` com `preset=desempenho` sem `etapa` responde 400, #481; `/api/school/<inep>/profile` traz `metadata.regra_sinais = 4`, `ideb_comparacao = mesma_etapa` e a tabela `ideb_por_etapa`, e `/api/network/<ibge>/profile` traz `ideb_anos_iniciais` … `nota_ensino_medio` no lugar de `ideb_observado`, #483; `/api/school/<inep>/evolution` traz o SAEB com `etapa` e `variacao` nula nas séries de uma edição, #485, `/api/school/29445906/panel/info` traz em `similar_schools` a `distancia` em pontos e as seis `notas` de cada vizinha, com a 29398037 em primeiro (a 1,56 ponto), #487, e `/api/fontes` termina nas entradas `indices_edumaps` (#462 e #467) e `ivet_edumaps`, com `versao = ivet-v1.9` e dez versões no histórico (#489, #524); no painel de uma escola sem isócrona (Sul, Centro-Oeste ou Norte) o IVET diz "ainda não pode ser calculado: faltam os blocos C (acesso)…" e mostra os blocos medidos, e os rótulos de D a G são Saúde, Segurança, Meio ambiente e Recursos, #489; `/api/ranking/escolas?codigo_ibge=2927408&indicador=capacitacao_docente` sem escola com valor 0 vinda de centro de atendimento, cerca de 1.410 escolas, #467) e a página `/base-analise` (#439, com os avisos da #444; conferir que `/api/base-analise/csv?uf=AC&blocos=porte` responde 200 com `base-analise-AC-censo<ano>.csv` e a coluna `regiao` depois de `uf`, #448; com `blocos=infraestrutura`, as colunas `in_*_inexistente` e, na identificação, `latitude`/`longitude`, #452; com `blocos=etapas`, as colunas `oferece_*`, #461; com `blocos=indices`, o arquivo `base-analise-AC-censo<ano>-indices-v3.csv` com as seis colunas `indice_*` e `versao_indice`, #465; agora `-indices-v7.csv` (#524), com célula vazia na escola sem registro, #467, e as partes da diversidade (`diversidade_racial` … `prop_eja`) no fim do bloco, #471, seguidas das do atendimento (`alunos_sala_turno` … `alimentacao`), #473, e das da capacidade gestora (`gestores_formacao` … `prop_acesso_cargo_selecao`, vazia nas privadas), #475, e das da infraestrutura e da sustentabilidade (`infra_basico` … `educacao_ambiental`), #477; com `blocos=docencia`, as colunas `prop_superior`, `prop_pos_graduacao` e `prop_formacao_continuada` no fim do bloco, vazias nas escolas sem docentes, #469). O `frontend/nginx.conf` do #423 é só da stack Docker; o LXC usa o
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
(`regra_sinais` diferente; agora 9, com os concursados sem comparação e com o motivo na privada, #527; a 8 trouxe os concursados vazios nas privadas, #524; a 7 trouxe "sem formação continuada" no lugar de "sem especialização", #522; a 6 trouxe o grupo de referência pelo contexto, as
30 escolas do município mais parecidas, e o INSE sem sinal, #493; as escolas
similares pelo mesmo contexto, no município inteiro, #495).
O agrupamento passa a guardar cada execução (#427): o motor grava em
`analytics.cluster_atribuicoes` com o mesmo usuário do banco que já grava
`analytics.clustering_metadata`; conferir com um agrupamento de teste na tela
(caixa **Universo** e **Baixar CSV**; o arquivo sai como
`agrupamento-censo<ano>-ideb<ano>-<run_id>.csv`, com as colunas `ano_censo` e
`ano_ideb`, #438).

- [ ] `ssh root@analytic.edumaps 'systemctl is-active edumaps-analytic'`.
- [ ] Perfil com o grupo pelo contexto (#493): `curl -s http://127.0.0.1:3000/api/school/29445906/profile`
      no backend traz `metadata.regra_sinais = 9` (#527), `cluster_source = contexto_municipio`,
      `cluster_size = 30` e nenhum sinal `inse`.
- [ ] Similares do perfil pelo contexto (#495): no mesmo perfil,
      `metadata.peers_source = contexto_municipio` e até 10 `tables.peers`
      com `similarity` ≥ 0,7.
- [ ] Perfil da rede (#497): `curl -s 'http://127.0.0.1:3000/api/network/2927408/profile?tp_dependencia=3'`
      no backend traz `metadata.referencia_rotulo = "Brasil, redes municipais"`, `n_brasil`
      preenchido e grupos `INSE Nível …`/`Sem INSE` em `tables.clusters` (nenhum
      "Sem cluster"); o cache antigo cai sozinho (chave `versao = 4`).
- [ ] Ranking de redes (#499): `curl -s 'http://127.0.0.1:3000/api/ranking/redes?indicador=ideb_anos_iniciais&uf=PA'`
      traz `variacao_regra = "mesmas_escolas"` e `escolas_variacao` em cada rede;
      São Sebastião da Boa Vista (1507706) com variação perto de +0,03 e sem salto atípico.
- [ ] Lista de escolas pelo IDEB (#503): `curl -s 'http://127.0.0.1:3000/api/ranking/escolas?indicador=ideb_anos_iniciais&codigo_ibge=2927408'`
      traz `cobertura` (oferecem ~794, públicas ~282, privadas ~512) e `indicador.metodo`
      com "não é aleatória"; `total` sem escolas fora de funcionamento (~247).
- [ ] Posição da escola com empate (#506), depois do `ranking.pl` do §6:
      `curl -s 'http://127.0.0.1:3000/api/school/29422620/ranking?indicador=sustentabilidade&national=1'`
      traz `empate` (~52.164 no nacional) e `percentil` 0 nos três escopos; o IDEB anos
      iniciais da 29190231 dá "1º de ~247" no município, sem escolas fora de funcionamento.
- [ ] Ranking de redes só com escolas em funcionamento (#508):
      `curl -s 'http://127.0.0.1:3000/api/ranking/redes?indicador=ideb_anos_iniciais&uf=MG'`
      traz `ano_censo` e `escolas_fora` (~13); Mário Campos (3140159) com média 6,35,
      4 escolas e `escolas_fora` = 1, perto de 68º de 298.
- [ ] Painel público da escola (#510):
      `curl -s 'http://127.0.0.1:3000/api/school/29190231/panel/info'` traz `escola.matriculas`
      = 285, `ano_censo`, `etapas.pre_escola` = 1 e `infraestrutura` como objeto (com `detalhe`);
      a 29211999 (Abaíra) com `esgoto` = 1 e `detalhe.esgoto` = "outra_solucao",
      `quadra_esportes` e `acessibilidade` = 1.
- [ ] Folha da base por UF (#512):
      `curl -s 'http://127.0.0.1:3000/api/base-analise?uf=SP'` traz `folha.padrao` = o último ano
      completo da UF e `folha.municipios` com os anos e os meses; o CSV de uma UF com folha traz
      `prof_magisterio_mes` e `aux_educacional`; `/api/fontes` traz `cobertura` no SIOPE.
- [ ] Aviso de anos na base (#514):
      `curl -s 'http://127.0.0.1:3000/api/base-analise/dicionario?uf=BA&blocos=desempenho,inse'`
      traz em `ano_ideb` "cruzada com o Censo Escolar 2025 (dois anos depois)" e em `ano_inse`
      "a mesma do IDEB".
- [ ] Matrículas na base e creche/pré nas redes (#516):
      o CSV de `curl -s 'http://127.0.0.1:3000/api/base-analise/csv?uf=BA&blocos=matriculas'` traz
      `mat_basica` a `mat_integral`; `curl -s 'http://127.0.0.1:3000/api/network/2927408/summary'`
      traz `matriculas_creche` e `matriculas_pre` na rede municipal de Salvador (~8,3 mil e ~14,3 mil).
- [ ] Conveniadas na base e nas redes (#518):
      `curl -s 'http://127.0.0.1:3000/api/network/3516200/summary'` traz, na rede privada de Franca,
      `escolas_conveniadas` 82 e `matriculas_creche_conveniada` 7758; o dicionário de
      `curl -s 'http://127.0.0.1:3000/api/base-analise/dicionario?uf=SP&blocos=parceria'` traz
      `parceria_poder_publico`, `parceria_esfera` e `categoria_privada`.
- [ ] Teto das conveniadas (#520, sem change nova):
      `curl -s 'http://127.0.0.1:3000/api/base-analise/dicionario?uf=SP&blocos=parceria' | grep -c 'não a vaga'`
      → 1; a nota da comparação de redes de Franca diz "o máximo da oferta pública".
- [ ] Sem formação continuada (#522, change `docentes_formacao_continuada_rotulos`):
      `curl -s 'http://127.0.0.1:3000/api/base-analise/dicionario?uf=SP&blocos=docencia' | grep -c '^prop_sem_formacao_continuada;'`
      → 1 e `grep -c '^prop_sem_especializacao;'` → 0; o perfil da rede de Franca diz
      "Docentes sem formação continuada" (cache do perfil da rede na `versao` 6, #524).
- [ ] Concursados vazios nas privadas (#524, change `escolas_scores_vinculo`):
      `curl -s 'http://127.0.0.1:3000/api/ranking/escolas?codigo_ibge=3516200&indicador=capacitacao_docente'`
      traz `indicador.versao = indices-v7` e, das 136 privadas de Franca, cerca de 108 na metade de baixo
      (eram 116); o CSV de uma execução de agrupamento com o conjunto docência traz
      `prop_sem_formacao_continuada`, e a caixa Universo conta as privadas sem dado de concursados.
      Depois do `ranking.pl`, rodar `school_profile_refresh.sh` (a referência do perfil passa a ter
      `prop_efetivos` vazio na rede 4).
- [ ] Rótulos curtos e privada sem comparação (#526 e #527, sem change nova): no agrupamento, os
      indicadores escolhidos aparecem com o nome curto; `curl -s http://127.0.0.1:3000/api/school/35004827/profile`
      traz, na linha `prop_efetivos`, `brasil` nulo e a `nota` "Não se aplica à rede privada…".
- [ ] Docentes por etapa (#529, sem change nova):
      `curl -s 'http://127.0.0.1:3000/api/base-analise/csv?uf=SP&codigo_ibge=3516200&blocos=docencia' | head -1`
      termina em `qt_docentes_infantil;qt_docentes_ai;qt_docentes_af;qt_docentes_em` (antes das colunas de versão).
- [ ] CEP, bairro e endereço (#531, sem change nova):
      `curl -s 'http://127.0.0.1:3000/api/base-analise/csv?uf=SP&codigo_ibge=3516200&blocos=porte' | head -2`
      traz `longitude;cep;bairro;endereco` (a identificação sai sempre), e o CEP vem como `00000-000` (ex.: `14404-110`).
- [ ] Taxa de atendimento da educação infantil (#533, change `populacao_idade_censo2022`), depois da carga do §6:
      `curl -s http://127.0.0.1:3000/api/network/3516200/summary` traz `populacao_0_3 = 15862`, `populacao_4_5 = 9094` e
      `ano_populacao_idade = 2022` em toda rede; o CSV da base com `blocos=porte` traz `populacao_0_3;populacao_4_5` depois de
      `porte_municipio` e termina em `ano_populacao_idade`; `/api/fontes` traz o cartão `ibge_populacao_idade`.
- [ ] Taxa de atendimento no ranking de redes (#535, sem change nova), depois da carga do §6:
      `curl -s 'http://127.0.0.1:3000/api/ranking/redes?indicador=atendimento_creche&uf=MT&destaque=5103403'` traz
      `tipo = atendimento`, `total = 141`, `meta.abaixo = 116` e o destaque de Cuiabá na posição 101; na tela,
      `/ranking?aba=redes&indicador=atendimento_creche&uf=MT` abre com menor primeiro.
- [ ] Fontes do ranking pelo indicador (#539, sem change nova): nessa tela, o rodapé "Fonte:" cita o Censo Escolar, a
      estimativa da população e a "População por idade (Censo Demográfico) 2022", sem IDEB nem INSE;
      `/api/fontes` traz `ranking_atendimento` em `censo`, `ibge_populacao` e `ibge_populacao_idade`.
- [ ] Posição da escola sem verde fixo (#541, só frontend): no painel de uma escola (ex.: `/escola/panel?inep=51038510`),
      "Acima de X%" sai em cinza, e o empate no 1º lugar aparece como "1º lugar, dividido com N escolas com o mesmo valor".
- [ ] Sinal de atenção com os números (#542, só frontend): no perfil de uma escola com sinal (ex.: `/escola/perfil?inep=51038510`),
      o sinal diz o valor da escola, "metade tem…" das parecidas e se está melhor ou pior que o município e o Brasil, sem "quartil".
- [ ] Rede distrital do DF (#545, change `rede_escolas_df`): `curl -s 'http://127.0.0.1:3000/api/ranking/redes?indicador=atendimento_creche&uf=DF'`
      traz `rede_local = distrital`, `matriculas_municipal = 149`, `matriculas_conveniadas = 24570` e `teto` perto de 0,19
      (com a carga do §6); MT continua com `meta.abaixo = 116`.
- [ ] Vagas que faltam para a meta (#547, sem change nova): `curl -s 'http://127.0.0.1:3000/api/ranking/redes?indicador=atendimento_creche&regiao=NE'`
      traz `meta.vagas_faltam` perto de 405.893; na comparação de redes de Vitória de Santo Antão (2616407), 2.026 vagas de creche e 494 de pré-escola.
- [ ] Taxa bruta de matrícula (#549, sem change nova): o rótulo do indicador em `/api/ranking/redes?indicador=atendimento_creche&uf=PE`
      é "Creche (0 a 3 anos): taxa bruta de matrícula"; a tela diz "abaixo de 50%" e traz o aviso de que não é o indicador oficial.
- [ ] Fontes no CSV do ranking (#550, só frontend): na página `/ranking?aba=redes&uf=PE&indicador=atendimento_creche`,
      o "Baixar CSV" traz as colunas `fontes` (Censo Escolar, estimativa e população por idade, com a data da carga) e `fontes_links`.
- [ ] Folha por fonte de recurso (#553, sem change nova): `curl -s http://127.0.0.1:3000/api/school/35010919/finance | jq .por_fonte`
      (Secretaria de Taubaté, 2026) traz `fundeb_70` perto de 137,5 mi e `fundeb_30` perto de 25,7 mi; o painel
      `/escola/financeiro?inep=35010919` mostra o cartão "Por fonte de recurso" com o aviso do mínimo legal; a base de Ubatuba
      (bloco Remuneração, 2026) traz `gasto_fundeb_70_ano` em reais inteiros, sem notação científica.
- [ ] Fechamento da folha (#554, sem change nova): `curl -s 'http://127.0.0.1:3000/api/base-analise?uf=SP&codigo_ibge=3555406' | jq '.folha.municipios[].anos[].fechamento'`
      traz, em Ubatuba 2026, `total` perto de 67,7 mi, `escolas_base` 55,6 mi, `secretaria` 11,8 mi e a escola 35659605 em `fora`;
      `curl -s http://127.0.0.1:3000/api/city/3555406/payroll/overall` diz "São Paulo".
- [ ] Mês com a folha pela metade (#557, sem change nova): `curl -s 'http://127.0.0.1:3000/api/school/51171805/finance?ano=2025' | jq '[.meses_incompletos[].nome]'`
      dá `["setembro","outubro"]`; `/fontes` mostra "2025 (12 meses (setembro e outubro incompletos), 167 escolas)" em Cuiabá
      (se a folha do LXC for a mesma do local).
- [ ] Meses por escola e da Secretaria (#558, sem change nova): `/fontes` mostra Cuiabá "2026 (por escola só em janeiro e
      fevereiro; de março a agosto, só o total da Secretaria; …)" e o painel `/escola/financeiro?inep=51171805` (2026) avisa
      "De março a agosto de 2026, o município declarou a folha só no total da Secretaria" (se a folha do LXC for a mesma do local).
- [ ] Gasto dos meses completos (#561, sem change nova): o CSV da base de Cuiabá (rede municipal, bloco Remuneração, 2025)
      traz `meses_completos` = 10 e, na escola 51171805, `gasto_pessoal_meses_completos` perto de 4.308.886 (se a folha do LXC
      for a mesma do local).
- [ ] Salário base e piso (#563, sem change nova): o CSV da base de Alta Floresta D'Oeste (RO, rede municipal, Remuneração,
      2024) traz `piso_magisterio_ano` = 4580,57 e a soma de `prof_magisterio_base_abaixo_piso` = 45 (se a folha do LXC for a
      mesma do local).
- [ ] Registro da carga da folha (#564, sem change nova; inclui `deploy_minion_dev`): antes de recarregar, `/fontes`
      diz "carga não registrada" em todos; recarregar um município (ex.: Ubatuba 2026, com permissão) e conferir
      `psql edumaps_dev -Atc "SELECT jsonb_array_length(raw_manifest) FROM clean.import_metadata WHERE table_name = 'clean.remuneracao_municipal'"`
      e "carga em <data>" em `/fontes`.
- [ ] Docentes do Censo ao lado da folha (#567, sem change nova): `curl -s http://127.0.0.1:3000/api/school/35070212/finance | jq .docentes`
      traz `folha_ano` 36, `censo.docentes` 62 e `municipio.avisar` true (se a folha do LXC for a mesma do local); o painel
      `/escola/financeiro?inep=35070212` mostra "Docentes na folha" e o aviso da Secretaria.
- [ ] Meses em vez de competências (#568, só frontend): o painel `/escola/financeiro?inep=35070212` diz "Meses com folha" e
      "No último mês (…)", sem "competência", e a nota da soma das categorias quando passa do total.
- [ ] Salário da rede inteira (#571, sem change nova): `curl -s http://127.0.0.1:3000/api/school/35010919/finance | jq .salario_rede`
      (Secretaria de Taubaté) traz `total` 6975, `base` 2669 e `carga_comum` 18 (se a folha do LXC for a mesma do local).
- [ ] Carga que não parece em horas (#572, sem change nova): `curl -s http://127.0.0.1:3000/api/school/35010919/finance | jq .salario_rede.carga_suspeita`
      dá true (Taubaté, carga 18); o CSV da base de Ubatuba traz `carga_comum_municipio` = 31 e o salário por 40 horas preenchido.
- [ ] Piso na rede inteira (#575, sem change nova): `curl -s 'http://127.0.0.1:3000/api/base-analise?uf=MT&codigo_ibge=5103403' | jq '[.folha.municipios[].anos[].salario_magisterio.abaixo_piso]'`
      dá `[1559, 6]` (2026, 2025; se a folha do LXC for a mesma do local); o mesmo pedido leva poucos segundos, não 30.
- [ ] Aviso do mês incompleto com a carga (#576, sem change nova): sem recarga no LXC, o aviso mantém "pode ser a
      declaração ou a carga"; depois de recarregar Cuiabá 2025 (com permissão), o painel `/escola/financeiro?inep=51171805`
      (2025) diz "A planilha do SIOPE baixada em <data> traz estes meses assim".
- [ ] Fundeb da folha inteira e folha por município (#579, #580, sem change nova): `curl -s 'http://127.0.0.1:3000/api/base-analise/folha-municipios.csv?uf=SP'`
      traz Taubaté e Ubatuba com 26 colunas (Ubatuba: `fundeb_70` 63980190); a tela da base de SP mostra "Pela fonte: 94,5%…" e o link.
- [ ] Aviso de anos com a folha (#583, só frontend): a tela da base de Cuiabá com Desempenho e Remuneração (folha 2025)
      diz "A folha do SIOPE é de 2025, dois anos depois do IDEB (2023)".
- [ ] Folha do total da Secretaria (#585, sem change nova): `curl -s -o /dev/null -w "%{http_code}\n" 'http://127.0.0.1:3000/api/school/51171805/payroll/secretaria?date=04-2026'`
      dá 200 (se a folha do LXC for a mesma do local); a página `/escola/payroll?inep=51171805&date=04-2026&secretaria=1` pagina de 100.
- [ ] Salário da escola ao lado da rede (#589, sem change nova): o painel `/escola/financeiro?inep=35070212` mostra "Nesta escola
      em 2026: … 24% acima da rede no salário total" (se a folha do LXC for a mesma do local).
- [ ] Listagem de redes (#593, sem change nova): o admin abre `/admin/rede` e a lista de contas carrega (sem 404).
- [ ] Salário da rede em matviews (#595, **change nova** `analytics_salario_rede`: `deploy_db_dev`, depois `deploy_backend_dev` e `deploy_minion_dev`):
      `psql edumaps_dev -Atc "SELECT count(*) FROM analytics.mv_salario_rede"` > 0 e a base `/base-analise?uf=MT` responde em menos tempo que antes.
- [ ] Piso por situação (#597, **change nova** `analytics_salario_rede_situacao`: `deploy_db_dev`, depois `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`):
      `psql edumaps_dev -Atc "SELECT situacao, sum(n) FROM analytics.mv_salario_rede_md GROUP BY 1"` lista efetivo/temporario/outros, e o painel da Secretaria de Cuiabá diz "Deles, … temporários e … efetivos".
- [ ] Marca do piso na folha (#598, sem change nova: `deploy_backend_dev` e `deploy_frontend_dev`): a página
      `/escola/payroll?inep=51171805&date=04-2026&secretaria=1` diz quantos ficam abaixo do piso no ano e filtra por situação (se a folha do LXC for a mesma do local).
- [ ] Lista do ano do piso (#601/#602, sem change nova: `deploy_backend_dev` e `deploy_frontend_dev`):
      `curl -s "$API/api/city/5103403/piso?ano=2026" | jq .total` dá o mesmo número do painel da Secretaria de Cuiabá, e `/municipio/piso?ibge=5103403&ano=2026` baixa o CSV.
- [ ] Folha que não se compara (#604, sem change nova: `deploy_backend_dev` e `deploy_frontend_dev`):
      o painel da rede de Cuiabá em 2026 diz "A folha de 2026 não se compara à de 2025" (se o LXC tiver as folhas de 2025 e 2026), e a folha por município de MT tem a coluna `comparavel_ano_anterior`.
- [ ] Nomes da folha (#536): `psql edumaps_dev -Atc "SELECT ano, count(*) FILTER (WHERE nome_profissional LIKE '%?%') FROM clean.remuneracao_municipal WHERE cod_municipio = '510340' GROUP BY 1"`
      dá 93 em 2025 e 0 em 2026, se a folha do LXC for a mesma do local (senão, conferir só que o verify passa).
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
3. **Índices das escolas recalculados (#459, #467, #471, #473, #475 e #524)**, nesta ordem, depois do
   `deploy_db_dev` e do `deploy_backend_dev` (a MV já sai recalculada da change;
   o `ranking.pl` precisa ser o da #467, que remove quem saiu do ranking):
   ```bash
   perl -Ilib bin/ranking.pl                      # ranking pré-calculado, índices e IDEB (#506; ~1 min)
   ./script/edumaps.pl eval 'app->build_controller->refresh_school_embeddings'   # escolas semelhantes
   ```
   Esperado: média do `score_diversidade_discente` perto de 3,7 (era 6,0 antes da #459 e 4,4 na `indices-v3`);
   `score_capacidade_atendimento` das escolas públicas perto de 6,2 nos municípios com menos de 20 mil habitantes e de 5,6 nos com mais de 500 mil (#473);
   `score_capacidade_gestora` com média perto de 4,75 nas privadas e 5,47 nas públicas (#475);
   `score_capacitacao_docente` com média perto de 4,85 nas privadas (era 3,88, teto de 8) e 6,41 nas públicas, máximo 10 nas duas (#524);
   ~2.067 escolas com `score_capacitacao_docente` nulo e ~1.774 com a
   diversidade nula (Censo 2025); `analytics.ranking_escola` sem nenhuma linha
   de escola sem o índice (`capacitacao_docente`/`todas` com ~178,5 mil);
   `refresh_school_embeddings` termina com ~178 mil vetores. O IVET vem no
   §7 (precisa do `deploy_analytics_dev` do §5, com `ivet-v1.9`).

4. **População por idade do Censo 2022 (#533):** depois do `deploy_db_dev`
   (change `populacao_idade_censo2022`) e do `deploy_backend_dev`.
   ```bash
   perl -Ilib ingestion_runner.pl --job=IBGEPopulacaoIdade
   ```
   Esperado: 5 requisições ao `apisidra.ibge.gov.br`, 222.800 registros de
   5.570 municípios em ~30 s; `SELECT sum(populacao_total) FROM clean.populacao_idade`
   dá 203.080.756. O job aborta, sem gravar, se as faixas não somarem o total.

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

- [ ] ES e MG com acesso calculado (não `n/d`), fórmula `ivet-v1.9` (#459 e #471: insumo de diversidade corrigido; #467: índice vazio sem registro; #473: lotação por turno; #475: partes da capacidade gestora; #524: concursados vazios nas privadas).
- [ ] Publicáveis próximos dos 145 mil da última medição nacional.
- [ ] **Medir a régua da versão vigente (#489, RK-02).** As medições
      publicadas (§4.8 de `docs/analises/ivet.md`) são da `ivet-v1.2`, de antes
      da escala log do bloco C, e a ajuda do gestor deixou de citá-las:
      ```bash
      ssh root@analytic.edumaps 'cd /opt/edumaps/analysis/edumapsr && Rscript inst/scripts/medir-ivet-nacional.R'
      ```
      Registrar a distribuição (p25, p50, p75, p90, publicáveis) da `ivet-v1.9`
      no §4.8 e repor a régua na §4.1 da ajuda `docs/ajuda/gestor/ivet.md`
      (commit só de documentação).
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
