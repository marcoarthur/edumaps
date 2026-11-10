# Nota técnica 183: motor analítico no Docker local e testes no contrato http

PRs #358 e #359 (2026-11-10). Corrige o diagnóstico da nota 178 e revisa
a metodologia dos indicadores de condição da escola.

## O que se descobriu

Ao instalar o pacote R do projeto no host (nome real `edumapsAnalytics`;
`edumapsr` é só a pasta), apareceram três problemas encadeados:

1. **Docker local nunca rodou clustering, similaridade nem análise de cidade
   pelo minion.** O `docker-entrypoint.sh` gerava o `edu_maps.conf` sem
   `analytics_engine`, e o padrão é o motor legado `pipe`, que chama o
   `Rscript` dentro do contêiner — onde não há R. Havia 209 jobs falhos com
   "Rscript not found" (341 de clustering, 134 de similaridade e 55 de cidade
   falharam no total). No LXC a config usa `http`, então lá não acontecia.
2. **O `skip_r_host` (nota 178) checava a coisa errada.** Procurava um pacote
   `edumapsr` que nunca existe, então pularia os cinco testes para sempre. E o
   `edu_maps.conf` do host já usa o motor `http`: esses testes chamam o
   serviço R do Docker, não o R do host. Com o skip removido, falhavam porque
   esperavam o contrato do `pipe` (`r_meta.status`, `run_id`, `timestamp`…).
3. **Código de produção lia campos que só o `pipe` devolve.**
   `inject_similarity_relation_from_job` lia `r_meta.id_column` (no `http` é
   `metadata.entity_id`) e caía com "id_column nao informado". A política
   `last_matching_features` do `ProcessedJob` lia `params.features` e, além
   disso, procurava o resultado em `$info->{similarity_info}` em vez de
   `$info->{result}{similarity_info}` — nunca encontrava job nenhum.

## O que mudou

- `docker-entrypoint.sh` grava `analytics_engine => 'http'` e
  `analytics_url => 'http://analytic:8000'` (sobrescrevíveis por
  `ANALYTICS_ENGINE`/`ANALYTICS_URL`). Validado: um kmeans enfileirado na fila
  `default` foi pego pelo minion do contêiner e terminou (3.555 escolas).
- `CI->skip_r_host` virou `CI->skip_analytics($app, $motivo)`: no CI, mesma
  razão do `skip_r`; fora dele, pula se o motor não for `http` ou se o
  `/health` do serviço não responder, e a mensagem diz qual dos dois.
- Os cinco testes (`clustering*.t`, `similarity.t`, `dbic/inject*.t`) seguem o
  contrato do motor `http`, como o `city_analyticis.t` já fazia (#355). As
  métricas de similaridade não portadas (`euclidean_zscore`, `mahalanobis`,
  `aitchison`, `dtw`) passam a esperar a falha "nao suportada no motor http".
- Os helpers `run_clustering_job`/`run_similarity_job` mandam o job para uma
  fila própria (senão o minion do Docker o pega antes do `perform_jobs`) e
  desligam o cache do cliente durante o job (senão o R não regrava a tabela
  que o teste confere).
- Os dois consumidores aceitam os dois formatos (`id_column` ou
  `metadata.entity_id`; `params.features` ou `metadata.features`).

## Decisão

O motor `pipe` deixa de ser testado. Testá-lo no host exigiria os pacotes
dos scripts de `templates/rscripts` no R do host (o `tidyverse` foi instalado,
mas não basta) e um serviço `edumaps_local` com senha no
`~/.pg_service.conf`. Nenhum ambiente o usa.

## Deploy

`deploy_backend_dev` + `deploy_minion_dev` na fila do LXC (2026-11-12). Docker
local: imagens `backend` e `minion` reconstruídas.

## Metodologia dos indicadores IFS, IPS, IGE e IAI (PR #359)

O `indicators_quality.t` exigia que os quatro previssem o IDEB numa só cidade
(Brasília), pegando "o último IDEB" de cada escola. Os ρ ficavam entre −0,11
e −0,02, o que parecia dizer que os indicadores não medem nada.

Medidos em 22.698 escolas de DF, SP, BA, PA e RS, com o IDEB 2023 por etapa:

- a correlação bruta é moderada (até 0,41 no fundamental I);
- quase toda ela vem do nível socioeconômico (ρ dos indicadores com o INSE
  entre 0,19 e 0,48);
- descontados INSE, UF e rede, o efeito próprio fica entre −0,02 e 0,05
  desvio-padrão em todas as etapas.

O resultado de Brasília era artefato: um município só achata a variação, e as
etapas do IDEB têm escalas diferentes (médias 5,8, 5,0 e 4,5).

**Decisão:** os indicadores medem condições e direitos, não resultado, e o
uso real deles é descrever escolas para a similaridade. O teste passa a exigir
variação e cobertura (dp ≥ 0,05, no máximo metade das escolas no teto ou no
zero, no máximo 10% com campo ausente). A relação com o IDEB vira diagnóstico,
por etapa, bruta e ajustada. Detalhe e limites de uso em
`docs/analises/ivet.md` §2.3.1. Nada muda no produto.

**Pendente:** o `t/02-models/indicators/quality.t` (IQD, São José dos Campos)
usa a mesma lógica de prever o IDEB numa cidade só; só reprova se o R falhar.
