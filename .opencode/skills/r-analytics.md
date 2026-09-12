# Skill: r-analytics

## Purpose
Auxiliar no desenvolvimento de scripts R de análise educacional do projeto EduMaps.

## Pacote: edumapsr
```r
library(edumapsr)
# Localização: analysis/edumapsr/
# Conexão DB: EduMaps::AnalyticsConfig (via config/database.yml ou RPostgres)
```

## Dados de entrada
- `clean.mv_escolas_scores` — scores consolidados (infraestrutura, docentes, gestão, etc.)
- `clean.censo_escolas` — dados brutos do Censo (2025)
- `clean.ideb_notas_escolas` — notas IDEB/SAEB
- `clean.escolas` — geocodificação + nomes das escolas

## Scripts de análise (analysis/)

### Ranking de escolas
- Indicadores compostos: capacidade_atendimento, capacidade_gestora,
  capacitacao_docente, diversidade_discente, infraestrutura, sustentabilidade
- Geração de ranking por município (tabela `analytics.ranking_escolas`)

### Similaridade (Gower)
- Distância Gower entre escolas usando múltiplas variáveis numéricas e categóricas
- Resultado: pares de escolas com distância < threshold (ex: 0.2)
- Armazenado em `analytics.similarity_*`

### Clusterização (K-means)
- Função: `clusterizar_escolas()` em docs/IA/clusters.md
- Método: elbow/silhouette para seleção automática de k
- Análise por grupo: composição por dependência administrativa, infra vs docentes

### SIOPE (Scraper)
- Scripts R de scraping via Event-Bus (backend script/tasks)
- Variáveis: despesas, categorias orçamentárias, contratos

## Visualização
- Mapas: Leaflet.js (frontend/ Lua)
- Gráficos: `ggplot2` / `plotly` em notebooks R

## Convenções R
- Conexão: `DBI::dbConnect(RPostgres::Postgres(), dbname="edumaps_dev", host="ubatexu.lan", user="devel", password="senhaboa123")`
- Escrita: `DBI::dbWriteTable(con, c("analytics","tabela"), df, append=TRUE)`
- Scripts rodam como jobs no Event-Bus via `EduMaps::Task::RJob`
