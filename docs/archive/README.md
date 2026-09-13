# docs/archive

Notas técnicas históricas e registros de decisão. Foram arquivadas no ciclo de
limpeza (2026-09-13) por descreverem trabalho já incorporado ao código ou
estados/arquiteturas que não correspondem mais ao projeto atual. Ideias ainda
ativas e direções novas vivem em `../new_ideas/`.

Consulta por palavra-chave via `rg` antes de descartar algo — registros como
ADRs (decisões, migrações, refatorações) continuam úteis como contexto.

## dev/

| Arquivo | Assunto (1 linha) |
|---|---|
| `notas_tecnicas.md` | Dimensões do schema `clean`; imputação do IDEB via Random Forest |
| `notas_tecnicas_01.md` | Endpoints Plumber p/ modelos salvos; lazy loading com workflow |
| `notas_tecnicas_02.md` | Sqitch deploy/revert/verify do INSE 2023; health_check; pipeline YAML |
| `notas_tecnicas_03.md` | Integração frontend→Plumber por `id_escola`; bugfixes no endpoint |
| `notas_tecnicas_04.md` | Modelagem de domínio: enums, domains, PostGIS, particionamento |
| `notas_tecnicas_05.md` | EDA tamanho da escola vs IDEB; efeito funil, ANOVA, Tukey (Ubatuba) |
| `notas_tecnicas_06.md` | EDA variabilidade IDEB/infraestrutura por etapas (SP/RJ); CV e Levene |
| `notas_tecnicas_07.md` | Modelo bayesiano multinível p/ série histórica do IDEB |
| `notas_tecnicas_08.md` | Proposta e SQL dos cinco scores 0–10 de escola; view materializada |
| `notas_tecnicas_09.md` | Correção de scores fora da escala 0–10; plano de testes Vitest/Playwright |
| `notas_tecnicas_10.md` | Testes Vitest/Svelte do modal de scores; correções de a11y |
| `notas_tecnicas_11.md` | Cruzamento SIOPE × censo docentes; resíduos; binomial negativa |
| `notas_tecnicas_12.md` | Similaridade entre municípios em espaço 3D; correção z-score |
| `notas_tecnicas_13.md` | Refatoração do EduMaps.pm: cache de models, concorrência Minion/DBIC |
| `notas_tecnicas_14.md` | Correção do preview SQL (desempacotar binds, valores escalares) |
| `notas_tecnicas_15.md` | Models semânticos de domínio (EduMaps::Model::Domain) |
| `notas_tecnicas_16.md` | Revisão da task Minion de clusterização R; aplicação ao Rio |
| `notas_tecnicas_19.md` | Tutorial Log::Any; validação dos indicadores IFS/IPS/IGE/IAI vs IDEB |
| `notas_tecnicas_21.md` | Dump integral do frontend legado `map_app` + plano de reescrita (ADR) |
| `notas_tecnicas_22.md` | Plano de reescrita do frontend Svelte 5 por features |
| `notas_tecnicas_23.md` | Configs (vite, Tailwind v4); mapa unificado por feature (LeafletMap) |
| `notas_tecnicas_25.md` | Diagnóstico/correção do teste rank.t (rank undef por filtros MV/IDEB) |
| `notas_tecnicas_27.md` | Design do Role Paginable; busca paginada full-stack Svelte+RxJS |
| `notas_tecnicas_28.md` | Eventos tipados com constantes e dispatcher; depuração de memória |
| `notas_tecnicas_30.md` | EventEmitter do OSM Query (design atual); autocomplete reativo (dir.) |
| `notas_tecnicas_31.md` | Explicação do pipeline RxJS de busca/autocomplete |
| `notas_tecnicas_33.md` | EventBus backend Mojolicious: singleton, listeners, fila com Minion |
| `notas_tecnicas_35.md` | Estrutura do pacote R edumapsr (R6, controllers, serializers) |
| `notas_tecnicas_36.md` | Migração do Gower p/ MVC analítico R (modelo, datasource, repository) |
| `notas_tecnicas_37.md` | Migração mínima do Gower em três peças (código R) |
| `notas_tecnicas_38.md` | Testes Perl do contrato Perl→R/MVC→persistência na similaridade |
| `refactor.md` | Refatorar ResultSet::Base em roles (SearchHelpers, Derived, Stats...) |
| `refactor_ui.md` | Arquitetura frontend por features (DDD) em vez de por tipo |
| `testes.md` | Revisão de teste de health check por capabilities; lições de testes |
| `eda_matinal.md` | EDA proximidade de universidades × desempenho; PSM |
| `regressao_linear.md` | Regressão linear do IDEB 2023 pelos scores |
| `clusterização.md` | Comparativo K-means vs GMM na clusterização de municípios |
| `conceitos.md` | Modelagem conceitual do domínio: ER, ontologia, RDF (base teórica) |
| `system_cloud_administration.md` | Plano antigo de cloud Subutai (Minion/Rex/CMDB) — descartado |
| `deep.md` | Reflexão filosófica sobre matemática/semântica (sem conteúdo operacional) |
| `user_history_1.md` | User story de busca de escolas similares (já implementada) |
| `prompt/claude/clusterization.md` | Prompt enviado p/ padronizar scripts de clusterização |

## IA/
| Arquivo | Assunto |
|---|---|
| `datapipeline.md` | Sqitch da `clean.matriculas`; indicadores e score de vulnerabilidade |
| `clusters.md` | Script R de k-means flexível sobre a view de scores |
| `random_forest.md` | Introdução conceitual a Random Forest (tutorial genérico) |

## analytics/
| Arquivo | Assunto |
|---|---|
| `questions.md` | Proposta de pesquisa sobre desigualdade de infraestrutura entre regiões |
| `eda/formacao_desempenho.Rmd` | EDA formação docente × localização × nota SAEB |

## Raiz
| Arquivo | Assunto |
|---|---|
| `ideas.md` | Catálogo de roles reutilizáveis p/ EduMaps::Model::Base (várias viraram realidade) |
| `notebook-analises-censo-rankings.md` | Debug do operador `!!!` do tidyverse (renomear colunas) |

## Sinalização para `../new_ideas/`
- **`implementations_ideas/`**: `notas_tecnicas_20` (score IQE), `_24` (Painel do
  Diretor), `_26` (gráficos plotly/ggplot2 via Perl), `_29` (EventBus frontend
  sem RxJS), `_32` (Stats::Model em Perl), `_34` (pré-computação especulativa).
- **`concepts/`**: `notas_tecnicas_17` (arquiteturas maduras), `_18` (modelos de
  similaridade por domínio).