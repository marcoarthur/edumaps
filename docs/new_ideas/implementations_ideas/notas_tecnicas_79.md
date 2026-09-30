# Nota Técnica 79 — Fase 3: Eventos e Exposição a Risco MapBiomas + INMET (#127)

**Data**: 2026-09-30  
**PR**: #144 (merge commit `bcf5d6d`)  
**Branch**: `feat/data/fase3-mapbiomas-inmet` → `main`  
**Commit**: `fb200dd`

---

## Contexto

Issue #127 (prioridade `[média]`) — **Fecha a lacuna 6 (meio ambiente e clima)** — a de melhor cobertura do catálogo: evento, série histórica e exposição a risco.

---

## Entregas

| Migration | Tabela | Status | Descrição |
|-----------|--------|--------|-----------|
| `mapbiomas_cobertura` | `clean.mapbiomas_cobertura` | ✅ Vazia (estrutura) | Cobertura/uso do solo por município/ano/classe. Coleção FIXA (`collection9`), granularidade 30m. |
| `inmet_alerta` | `clean.inmet_alerta` | ✅ Vazia (estrutura) | Alerta-AS (CAP 1.2) — eventos meteorológicos que interrompem aula. Código IBGE no payload. |
| `inmet_bdmep` | `clean.inmet_bdmep` | ✅ Vazia (estrutura) | BDMEP série diária 26 anos. API sem autenticação. Base para normalização climática. |

---

## Decisões de Design

### 1. **MapBiomas: Fixar a COLEÇÃO, não o ano**

O gotcha crítico do catálogo: a URL por ano morre (ex.: `collection11/2023` → 404). A URL da **coleção** é estável:
```
https://mapbiomas.org/download/collection/collection9/municipios
```

**Regra arquitetural**: ETL que interpola `%d` (ano) na URL **quebra silenciosamente** quando a coleção muda. Fixar `collection9` (ou a coleção vigente) e deixar o ano como dado na tabela.

### 2. **Granularidade 30m → arealizar, não centróide**

MapBiomas é raster 30m. **Nunca** usar o centróide da escola para amostrar. O pipeline deve:
1. Gerar buffer/área de influência da escola (ex.: 500m–1km)
2. Interseccionar com o raster MapBiomas (via `rasterstats` ou `gdal`)
3. Calcular proporção de cada classe na área de influência

Isso evita o erro de classificar uma escola rural como "urbana" só porque o centróide cai num pixel urbano.

### 3. **Alerta-AS mede EVENTO, não EXPOSIÇÃO**

Duas métricas distintas:
- **Evento (Alerta-AS)**: "houve alerta de chuva extrema no município X no dia Y" → binário ou contagem
- **Exposição (MapBiomas Fogo + BDMEP)**: "área queimada nos últimos 5 anos no entorno da escola" → proporção contínua

**Não somar como se fosse a mesma métrica**. A view analítica futura deve ter colunas separadas:
- `iv_risco_evento_meteorologico` (baseado em `inmet_alerta`)
- `iv_exposicao_fogo` (baseado em `mapbiomas_cobertura` classe 6 + `inmet_bdmep` precipitação/temp)

### 4. **INPE Queimadas = redundante com MapBiomas Fogo**

MapBiomas Fogo (classe 6) já cobre o mesmo dado com melhor granularidade (30m vs 1km) e metodologia documentada. **Não ingerir INPE Queimadas**.

### 5. **INMET BDMEP = normalização climática**

26 anos de série diária por estação. Base para calcular:
- Normais climatológicas (média 1991-2020)
- Anomalias de temperatura/precipitação
- Índices de seca (SPI, SPEI)
- Dias de calor extremo / frio extremo

---

## Allowlist Atualizada (Fase 3)

| Fonte | Endpoints Permitidos |
|-------|---------------------|
| **MapBiomas** | `/download/collection/{colecao}/municipios`, `/download/collection/{colecao}/fogo` |
| **INMET** | `/alertas/cap12` (Alerta-AS), `/bdmep/estacao` (BDMEP), `/dados/{tipo}/{ano}/{mes}` |

---

## Deploy Sqitch

```
Deploying changes to db:pg://devel@db/edumaps_dev
  + mapbiomas_cobertura ............ ok
  + inmet_alerta ................... ok
  + inmet_bdmep .................... ok

Verifying db:pg://devel@db/edumaps_dev
  * mapbiomas_cobertura ................ ok
  * inmet_alerta ....................... ok
  * inmet_bdmep ........................ ok
```

---

## Dependências Desbloqueadas

| Issue | Fase | Status |
|-------|------|--------|
| **#128** | 4 — SICONFI/Transparência | ✅ Desbloqueada |
| **#129** | 5 — BrazilCrime segurança | ✅ Desbloqueada |
| **#130** | 6 — ANTT/Transportes | ✅ Desbloqueada |
| **#131** | — Overpass/OSM viés | ✅ Desbloqueada |
| **#132** | — e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Próximos Passos

1. **Jobs de ingestão** (R/Perl) para popular as 3 tabelas via allowlist.
2. **#128 (Fase 4)**: SICONFI (finanças municipais) + Portal da Transparência.
3. **View analítica de risco ambiental**: cruzar `mapbiomas_cobertura` (exposição a fogo/inundação) + `inmet_alerta` (eventos) + `inmet_bdmep` (anomalias climáticas) → `analytics.risco_ambiental_escola`.

---

## Lições Aprendidas

1. **Fixar a coleção MapBiomas**: o erro de interpolar ano na URL custaria re-ingestão completa a cada nova coleção.
2. **Arealização ≠ centróide**: a granularidade 30m do MapBiomas exige arealização sobre buffer da escola, não point-in-polygon do centróide.
3. **Evento ≠ exposição**: separar as métricas evita viés de interpretação (um alerta de chuva não significa que a escola foi alagada).
4. **Redundância controlada**: não ingerir INPE Queimadas quando MapBiomas Fogo já cobre com melhor metodologia.