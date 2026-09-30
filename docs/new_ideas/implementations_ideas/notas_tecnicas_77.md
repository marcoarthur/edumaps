# Nota Técnica 77 — Fase 1: Contexto Municipal e Sub-Municipal IBGE (#125)

**Data**: 2026-09-30  
**PR**: #142 (merge commit `c10600b`)  
**Branch**: `feat/data/fase1-ibge-contexto` → `main`  
**Commit**: `d30a4bc`

---

## Contexto

Issue #125 (prioridade `[alta]`) — **maior retorno do plano inteiro**: tira o IVET do valor municipal uniforme. Hoje o IVET repassa o mesmo valor municipal a todas as escolas do município — uma escola rural e uma urbana recebem o mesmo contexto.

---

## Entregas

| Migration | Tabela | Linhas/Status | Descrição |
|-----------|--------|---------------|-----------|
| `malha_municipio` | `clean.malha_municipio` | 5.573 municípios | Derivada de `clean.municipios_sp` (raw_municipios_sp), geometrias MULTIPOLYGON SRID 4674 validadas |
| `malha_setor_censitario` | `clean.malha_setor_censitario` | **Vazia** (estrutura para 316.574 setores) | FK para `malha_municipio`, índices GIST, população posterior via `geobr`/`ogr_fdw` |
| `ibge_agregados` | `clean.ibge_agregados` | Vazia (formato longo SIDRA) | PK composta, view `v_ibge_municipio_ano` (PIB, População, IDHM, PIB per capita) |
| `censo2022_setor` | `clean.censo2022_setor` | Vazia (~3.000 variáveis) | Coluna `supressao_celula_pequena` boolean (vazio ≠ zero) |

---

## Decisões de Design

### 1. `malha_municipio` derivada de `clean.municipios_sp`

O `raw_municipios_sp` já baixava o shapefile municipal via OGR_FDW e criava `clean.municipios_sp` com 5.573 municípios e geometrias validadas. Reutilizei essa tabela em vez de baixar novamente o GPKG do Geoftp (que falhava no container por rede).

```sql
CREATE TABLE clean.malha_municipio AS
SELECT ... FROM clean.municipios_sp;
```

### 2. `malha_setor_censitario` **vazia** — população posterior

O GPKG de setor censitário 2022 tem **~748 MB**. Baixar durante `sqitch deploy` no container falha (timeout/rede). A tabela foi criada com estrutura completa (PK, FK, índices GIST, FK para `malha_municipio`) mas **zero linhas**.

**População posterior**: via R package `geobr::read_census_tract()` ou script `ogr_fdw` separado.

### 3. `ibge_agregados` — formato longo SIDRA

A tabela `clean.dados_ibge` já existia no formato *wide* (PIB municipal com colunas `pib_total`, `industria`, `agro`, `governo`). `ibge_agregados` estende para **qualquer agregado SIDRA** no formato longo:

```sql
codigo_ibge | ano | tabela_id | variavel | classificacao | valor
```

Inclui view `v_ibge_municipio_ano` com pivot dos principais indicadores:
- PIB total + setores (tabela 1393)
- População (tabela 6579)
- IDHM (tabela 1093)
- PIB per capita (tabela 5938)

### 4. `censo2022_setor` — **vazio ≠ zero**

A regra mais crítica: **supressão de célula pequena é estado distinto, não zero**. A tabela inclui coluna explícita:

```sql
supressao_celula_pequena BOOLEAN DEFAULT FALSE
```

Quando `TRUE`, os campos numéricos são `NULL` por sigilo estatístico — **não são zero**. Isso evita o erro que mais distorce indicadores territoriais.

---

## Allowlist Atualizada

Adicionadas à `data_pipeline/allowlist.yaml`:

| Fonte | Host | Recursos |
|-------|------|----------|
| IBGE SIDRA v3 | `servicodados.ibge.gov.br` | `/sidra/v3/values/t/{1393,6579,1093,5938}/...` (sem Cloudflare) |
| IBGE Geoftp | `geoftp.ibge.gov.br` | Malhas municipal e setor censitário GPKG |

---

## Deploy Sqitch

```
Changes: 66 (4 novos)
+ malha_municipio ......... ok (5.573 municípios)
+ malha_setor_censitario .. ok (tabela vazia, estrutura completa)
+ ibge_agregados .......... ok (view v_ibge_municipio_ano)
+ censo2022_setor ......... ok (supressao_celula_pequena)

Verify: 4 novos **OK**
(Falha em `rede_escolas_etapas` — divisão por zero pré-existente)
```

---

## Próximos Passos (Desbloqueados)

| Issue | Fase | Fonte | Status |
|-------|------|-------|--------|
| #126 | 2 | CNES + DATASUS (agregados via e-SIC) | ✅ Desbloqueada |
| #127 | 3 | MapBiomas + INMET | ✅ Desbloqueada |
| #128 | 4 | SICONFI + Transparência | ✅ Desbloqueada |
| #129 | 5 | BrazilCrime (segurança) | ✅ Desbloqueada |
| #130 | 6 | ANTT (agregado) + Transportes RENAVAM | ✅ Desbloqueada |
| #131 | — | Overpass/OSM viés de cobertura | ✅ Desbloqueada |
| #132 | — | e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Lições Aprendidas

1. **Reutilize o que já existe**: `malha_municipio` veio de graça do `raw_municipios_sp`.
2. **Arquivos grandes ≠ deploy**: 748 MB não baixam no container durante deploy. Crie estrutura vazia, popule em job separado.
3. **Vazio ≠ zero** precisa ser **explícito no schema** (coluna boolean), não na documentação.
4. **SIDRA v3 em servicodados** evita Cloudflare do `apisidra.ibge.gov.br` — descoberta empiricamente, não documentada pelo IBGE.