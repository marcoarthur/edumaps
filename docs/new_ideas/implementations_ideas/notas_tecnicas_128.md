# Nota técnica 128 — #131 (entregável 2 + fechamento): completude da malha, espaçamento e decisão Python/R

Fecha a **#131** (`priority:high`), item do backlog de conformidade do OSM. O
entregável 1 já tinha ido na nota 126 (PR #246). Aqui ficam o **entregável 2**
(PR #252, que não tinha nota própria) e o **fechamento dos critérios de aceite**
(PR #253), depois de uma verificação no código que mostrou **3 lacunas**.

## Entregável 2 — publicar o viés de cobertura (PR #252, merge `617bda6`)

O indicador é **`iv_mobilidade_completude_malha`**: **densidade de metros de via
por km²** no buffer de 500 m da escola. Não é cobertura percentual nem contagem
de *ways* — é densidade, comparável entre municípios.

A regra da #154 vale integralmente: **`NULL` = sem extração; `0` = extração feita
sem via no buffer; `> 0` = densidade**. Ausência nunca vira zero.

Decisões:

- **Extração sob demanda, por escola**, com o perfil `malha_viaria` (não entra no
  agregador `equipamentos_publicos` — incluí-lo poluiria o resumo de POIs com
  vias e inflaria a consulta).
- **Guarda no `Model::OSM`**, não no SQL: o indicador só calcula quando a
  seleção incluiu `malha_viaria`; a função SQL fica simples.
- Entrega: change `osm_mobilidade_completude` (deploy/revert/verify) +
  `clean.iv_mobilidade_completude_malha`, `Model::OSM`, job `query_osm_school`
  (campo `completude_malha`) e `osm_pois_status`.

## Fechamento dos critérios (PR #253, merge `b3e97d6`)

Verificação no código, critério a critério, mostrou que o #246 e o #252 **não**
fechavam tudo:

| Critério | Estado antes | O que foi feito |
|---|---|---|
| Sem paralelismo + fila espaçada | `min_interval` implementado mas **desligado** (`0`, nunca configurado) | default **1 s** em `Model::OSM` e `Task::OSM::Service`; override por `osm_min_interval` |
| Bruto persistido + teste de não-reconsulta | bruto no **banco**; teste **não contava** invocações | `t/osm_model_offline.t` conta invocações: MISS(1) → HIT(0) |
| User-Agent EduMaps | OK no Overpass; tiles com atribuição (UA do browser) | — (já satisfeito) |
| `iv_mobilidade_completude_malha` | OK (#252) | — |
| Decisão Python/R | **não registrada** | registrada em `docs/analises/fontes/mobilidade.md` |

### A decisão Python/R (critério 5)

Pergunta em aberto na issue: OSMnx é Python, o IVET é R — manter fronteira ou
reimplementar? **Resposta: nem um nem outro.** A extração é feita
**inteiramente no cliente Perl** (`EduMaps::Services::OSM`, falando Overpass QL);
o pipeline R apenas **lê** as feições já materializadas em `clean.osm_feature` /
`clean.osm_query`. **Não há fronteira entre linguagens na extração** — logo não
há OSMnx nem `sf`+`httr2` a considerar.

### A decisão do cache (critério 2)

A #131 pede persistência do bruto **em disco**; a própria issue condicionava o
destino à **#153** (fechada). A decisão registrada é **manter no banco**
(`clean.osm_query.raw_results`, com TTL de `osm_cache_ttl_days`): já é
reproduzível, chaveado pelo digest e provê proveniência/FK. O que faltava não
era o mecanismo, era a **prova**: um teste que conte invocações ao serviço e
demonstre que a segunda execução do mesmo objeto **não** reconsulta o Overpass.

### O `min_interval`

Estava implementado desde o #246 (estampilho em `lock_dir`, lido por
`_respeitar_intervalo`), mas com default `0` e sem nenhum ponto que o
configurasse — na prática, só o `flock` serializava. O caminho de produção
(`Model::OSM`, e o legado `Task::OSM::Service`) passa a ligar o espaçamento com
default de 1 s; o cliente de baixo nível (`Services::OSM`) mantém `0` (opt-in).

## #168 (ANTT) — reavaliada e mantida fora

A pedido, o host `dados.antt.gov.br` foi reconferido: **está de volta** (HTTP
200, CKAN ok). Mas a investigação dos 4 pacotes mostrou que **os DDLs das tabelas
não batem com as fontes reais** — fonte por concessionária/mês, `concessionaria`
ausente do CSV, `km` com vírgula decimal, `sat` é metadado de equipamento (sem
colunas de volume), `trecho-concedido` sem código de trecho/município/geometria.
É **redesign de DDL + ETL + stack geospatial**, não "escrever 2 scripts R". A
decisão foi **manter a ANTT fora do objetivo** (como em 2026-10-13) e seguir o
backlog.

## Testes

- `t/osm_*.t` + `t/04-api/gestor/osm_pois.t`: **10 ficheiros, 45 testes, PASS**
  (`osm_service_online.t` é *skip* por design, rede).
- Novos: 2 subtestes de espaçamento em `t/osm_overpass_conformidade.t` (com
  `min_interval>0` há espera; com `=0` não se grava estampilho) e as asserções de
  contagem de invocações em `t/osm_model_offline.t`.

## Entrega e deploy

- **PR #253**, merge **`b3e97d6`**; commit **`9c217e4`**. A #131 foi
  **auto-fechada** (`Closes #131`).
- Deploy: `rex prepare` + `deploy_backend_dev` + `deploy_minion_dev`
  (`backend.edumaps`); imagens locais `backend`/`minion` reconstruídas; `md5sum`
  de `Model/OSM.pm` idêntico em local ↔ host ↔ contentor.
- Sem alteração em `docs/funcionalidades/`: não mudou capacidade de negócio —
  é conformidade, robustez e teste.

## Pendências

- **`.gitignore` não cobre `pgdata.bak-*/`** — o `rex prepare` filtra por ele e o
  rsync abortou (código 23) por causa de
  `pgdata.bak-corrompido-20261014-193013/` (`dnsmasq:root`, 700). Contornado com
  linha temporária e restauro; **falta a correção durável**.
- Troca dos tiles da OSMF por fornecedor dedicado/self-host (produção a escala) —
  item próprio, herdado da nota 126.
