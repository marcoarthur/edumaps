# Nota técnica 126 — #131 (entregável 1): Overpass conforme a política da OSMF

Ciclo curto, em paralelo à reexecução da CGU 2025 no produto (nota 125). O
trabalho veio do item **`priority:high`** do backlog: **#131 — conformidade do
Overpass com a política de uso e publicação do viés de cobertura do OSM**.
Aqui ficou só o **entregável 1** (extração conforme e auditável). O entregável 2
(viés de cobertura) depende da #154 e não foi tocado.

## O problema

A #131 afirmava que a extração do OSM "não foi desenhada para escalar". Ao
abrir o código, o diagnóstico era pior do que "não escala": **a proteção
existia só no papel**.

O cliente `EduMaps::Services::OSM` tinha um `_request_with_rate_limit` com
cache em disco, semáforo de concorrência e retry — **que nunca era chamado**. O
`run` chamava `_request` cru. Pior: aquele método referenciava
`$self->cache_dir` e `$self->query->no_cache`, **atributos que não existiam** em
lugar nenhum (o semáforo, idem). Código morto que teria rebentado no primeiro
uso.

Consequências reais:

- **User-Agent anónimo** (o default `Mojolicious (Perl)`). A OSMF exige que o
  cliente se identifique — é o único rasto para contactar quem abusa; a ausência
  é motivo de bloqueio.
- **Sem retry**: um 429 ou 504 transitório do Overpass derrubava a consulta
  (e, por tabela, o job), sem segunda tentativa.
- **Sem serialização**: consultas podiam disparar em paralelo; o Overpass
  limita a 2 slots simultâneos e bloqueia quem dispara em massa.

O que **já estava bem** e foi mantido: o cache do resultado bruto vive no
`EduMaps::Model::OSM` (`clean.osm_query.raw_results`, indexado pelo digest da
query, com TTL de 30 dias). Não havia, de facto, cache em disco a criar — o
`Model` é quem persiste e decide.

## A decisão: consertar a proteção, não reescrever o cache

O escopo foi **deliberadamente estreito**: resolver o que é inequívoco e não
depende de decisões em aberto.

- **`user_agent` que nomeia a aplicação** (`EduMaps/1.0 (+…; plataforma de
  mapeamento escolar brasileiro)`), aplicado no transactor do
  `Mojo::UserAgent`. Sobrescrevível pelo atributo.
- **Retry com backoff exponencial só para falhas transitórias**: `429`, `504`,
  `5xx` e falha de rede (código 0). Um **4xx (excepto 429) propaga de
  imediato** — repetir uma query malformada não a melhora e só gasta o slot de
  outro. O código da última falha é guardado em `_http_code` pelo `_request`.
- **Repetição espaçada, sem paralelismo**: um `flock` exclusivo num ficheiro
  (`/tmp/edumaps-osm/overpass.lock`) serializa entre processos do mesmo host; o
  lock é libertado ao fechar o descritor — inclusive se a consulta morrer.
  `min_interval` (segundos) espaço chamadas consecutivas, se configurado.

### O que ficou fora, e por quê

- **Persistência do bruto em disco** — hoje é no DB (`clean.osm_query`), que já
  é reproduzível e chaveado pelo digest. A #131 fala em "disco", mas um
  comentário da própria issue condiciona a localização do cache à **#153**.
  Criar uma segunda camada de cache sem essa decisão seria adivinhar.
- **Entregável 2** (publicar o viés de cobertura) — o critério de aceite depende
  da **#154** ("ausência ≠ zero"): cobertura baixa é dado fraco, não zero.

## O que o mundo real mostrou (verificação da política de tiles)

A #131 também manda **verificar** se o frontend usa tiles do OSM. Usa:

`frontend/edumaps/src/features/map/components/LeafletMap.svelte:17`
→ `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`, **com atribuição**
(`&copy; OpenStreetMap contributors`).

A atribuição — exigência da política — está cumprida. O ponto de atenção é
outro: a CDN de tiles da OSMF **não é licenciada para uso de produção
intenso**. Publicar o EduMaps a escala implica trocar para um fornecedor de
tiles dedicado (ou self-host). Fica registado como item próprio; não é dívida
deste PR.

## Testes

Novo `t/osm_overpass_conformidade.t`:

- o UA do cliente é o `user_agent` configurado e nomeia a aplicação;
- `429` → retenta → conclui; `504` → retenta → conclui;
- `400` **não** retenta (uma só chamada);
- falha transitória persistente morre exatamente no limite de tentativas;
- um sucesso limpa o rasto de HTTP.

`t/osm_service_errors.t` foi ajustado para injetar retry rápido
(`max_tentativas => 1`, `jitter => 0`), preservando a intenção original
(propagar o erro) sem esperar o backoff. Todos **PASS**. `t/osm_model_offline.t`
falha por depender de DB (`clean.municipios_sp`) — falha igualmente em `main`.

## Bônus do ciclo: #167 fechada

A **#167** (`loader CGU transferências — bloqueado por chave de API 401`)
estava obsoleta: a `clean.transferencia_educ` passou a ser alimentada pelo
loader `CGU.pm` a partir do **ZIP público** (`download-de-dados/transferencias`),
**sem chave**. O stub `ingest_cgu_transferencias` já não existe. Os cinco
critérios de aceite da issue foram revistos contra o loader real e cumpridos; a
issue foi fechada como resolvida por outra via.

## Entrega

- PR **#246**, merge **`5edcfe3`**; commit **`954d676`**.
- Deploy: `rex prepare` + `deploy_backend_dev` (md5 `b3c21141…` confere);
  imagens Docker locais `backend`/`minion` reconstruídas.
- Sem alteração em `docs/funcionalidades/`: a capacidade de negócio (usar o OSM
  para os equipamentos do entorno) não mudou — o que mudou é conformidade e
  robustez da extração.
