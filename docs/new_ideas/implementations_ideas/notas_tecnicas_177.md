# Nota técnica 177: IGE limitado a 0..1 e o lote 1 das falhas antigas

PR #PR_NUM (2026-11-06). Primeiro lote da limpeza das 18 falhas antigas da
suíte local (no CI esses testes são pulados).

## Classificação das 18 falhas

| Grupo | Arquivos | Causa |
|---|---|---|
| A. Bug de código | `domain/quality.t` | IGE passava de 1 |
| B. Bug no teste | `City.t`, `escola_influencia.t` | expectativas desatualizadas ou dependentes dos dados |
| C. Sem schema `staging` | `clustering.t`, `clustering2.t`, `similarity.t`, `dbic/inject.t`, `dbic/inject_sim.t` | nada no repositório cria o schema; `skip_staging` só pula no modo CI |
| D. Motor R local | `indicators/quality.t`, `indicators_quality.t`, `analysis/rpipe.t`, `03-plugins/analytics.t`, `05-tasks/analytics_engine.t`, `city_analyticis.t` | codificação do R no host, servidor R de teste sem `portfile`, argumentos inválidos num job |
| E. Rede ou expectativa conhecida | `municipio.t`, `osm.t`, `siope.t`, `network/schools.t` | Overpass, SSE de progresso, expectativas contraditórias |

Este lote trata A e B. C, D e E ficam para os próximos.

## IGE (Qualidade da Gestão)

`EduMaps::Model::Indicator::calculate` faz `sum(valor*peso)/sum(pesos)`, o que
só fica em 0..1 se cada item estiver em 0..1. O item da proposta pedagógica
devolvia 0/1/2 com peso 2: uma escola com proposta própria chegava a
**1,29**. Agora o item vale 1 (própria), 0,5 (adaptada) ou 0, mantendo o
peso 2 — a gradação fica no valor, a importância no peso. A ordem relativa
entre as escolas não muda.

O IGE é calculado na hora (camada de *features* do
`Domain::SchoolQuality`), não é persistido e não aparece direto na tela; entra
no vetor de similaridade usado no Perfil da Escola quando a escola não tem
pares calculados (cálculo no município).

O `t/02-models/indicators.t` **fixava o valor errado** (esperava 1,1429, com o
comentário "vamos ver se o método permite >1"). Agora espera os valores
corrigidos e o máximo 1. Teste novo `t/02-models/indicators/ige.t` (sem banco)
falha com a versão antiga e passa com a nova.

## Testes corrigidos

- `City.t`: `payroll()` devolve `Mojo::Collection` (o controller faz
  `->to_array`, o `SiopeTask` usa `->size`); o teste esperava o texto JSON de
  uma versão antiga, e os subtestes de decodificação passavam no vazio.
- `escola_influencia.t`: contava todas as linhas da escola; o banco local tem
  também o buffer de 2000 m da carga real. Agora conta só os raios que o teste
  gera (500 e 1000).
- `admin/telemetry.t`: o ranking de rotas tem limite de 10 itens; com tráfego
  real, a rota semeada com 1 acesso podia sair da lista. A rota fora do
  ranking cheio é anotada e não conferida; no CI (janela vazia) as três são
  conferidas.

## Validação

- Os testes do lote passam no Docker local; `ige.t` falha sem a correção.
- Banco limpo do CI: `escola_influencia.t`, `ige.t`, `indicators.t` e
  `telemetry.t` passam (`City.t` e `domain/quality.t` são pulados lá).
- Suíte completa: de 18 para 15 falhas, todas dos grupos C, D e E; config
  idêntica. Imagens backend/minion reconstruídas, md5 do `IGE.pm` bate.

## Deploy

`deploy_backend_dev` e `deploy_minion_dev` na fila do LXC de 2026-11-09.
