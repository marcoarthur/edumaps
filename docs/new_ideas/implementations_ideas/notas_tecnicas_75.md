# Nota Técnica 75 — Dicionário de Dados Canônico do Censo Escolar (#134)

**Data**: 2026-09-30  
**PR**: #140 (merge commit `54afa9f`)  
**Branch**: `feat/data/censo-dictionary` → `main`  
**Commits**: `eaaf66d` (feat), `267cefd` (test fixes)

---

## Contexto

Issue #134 (prioridade `[alta]`, Zotero Z:9892) solicitava um dicionário de dados **versionado no repositório** para as tabelas do Censo Escolar ingeridas (`clean.censo_escolas`, `clean.censo_matriculas`, `clean.censo_docentes`, `clean.censo_gestor`), resolvendo a ausência de:

- Domínio de valores (enums) para colunas `tp_*` e `in_*`
- Histórico de mudança de código entre edições do Censo
- Chaves primárias/estrangeiras explícitas
- Proveniência (source_url, licença, data de download)
- Validação automática: coluna/código novo **quebra o build**, não vira `NULL` silencioso

---

## Decisões de Design

### 1. Tabela Canônica (`clean.censo_data_dictionary`)

**PK composta**: `(table_name, column_name, year_introduced)` — permite versionar a mesma coluna across edições do Censo (ex.: `tp_dependencia` em 2025 vs 2026).

**Campos-chave**:

| Campo | Tipo | Propósito |
|-------|------|-----------|
| `value_domain` | JSONB | `{codigo: "label"}` para enums; `NULL` para contínuas |
| `year_introduced` | SMALLINT | Primeira edição em que a coluna existe |
| `year_changed` | SMALLINT | Edição em que significado do código mudou |
| `year_deprecated` | SMALLINT | Edição em que coluna foi removida/substituída |
| `is_pk`, `is_fk` | BOOLEAN | Metadados de chave |
| `source_url`, `source_license`, `retrieved_at` | TEXT/TIMESTAMPTZ | Proveniência (Fase 0 #124) |

**Por que não usar `information_schema` direto no R?**  
Performance (catálogo é lento) + versionamento (precisa saber o que mudou entre 2025 e 2026) + proveniência (Fase 0).

### 2. População Automática (Migration Sqitch)

A migration `censo_data_dictionary.sql` faz `INSERT ... SELECT` a partir de:
- `information_schema.columns` + `col_description()` → metadados básicos + PK/FK
- `clean.import_metadata` → `source_file` (CSV de origem)
- **YAML curado** (`analysis/edumapsr/inst/chat/dicionario.yml` seção `codificacoes`) → `value_domain` para 19 enums conhecidos
- **DO block dinâmico** → popula `source_url/license/retrieved_at` **só se colunas Fase 0 existirem** (evita erro se #124 ainda não rodou)

Resultado: **764 linhas** (306 + 237 + 156 + 65) para as 4 tabelas censo.

### 3. Interface R (`censo_dictionary()`)

```r
censo_dictionary(con, tables = NULL, year = NULL,
                 include_domain = TRUE, include_provenance = FALSE)
```

- Filtro por `year`: retorna versão vigente naquela edição (`year_introduced <= year < year_deprecated`)
- `censo_dict_validate(con)`: **quebra se** coluna real não está no dicionário OU `tp_*/in_*` sem `value_domain`
- Helpers: `censo_dict_filter()`, `censo_dict_domain()`, `summary()`

### 4. Integração no Chat (`chat-dictionary.R`)

- **Antes**: catálogo do banco filtrado por whitelist YAML
- **Agora**: `censo_dictionary()` como **fonte primária** para tabelas censo (todas as colunas, tipos, domínios)
- **YAML vira curadoria**: termos educacionais, conexões, `ocultar` (PII)
- Prompt inclui `[enum: 1=Federal, 2=Estadual...]` inline para colunas com domínio

---

## Testes

| Suite | Testes | Status |
|-------|--------|--------|
| Perl `t/02-models/censo_dictionary.t` | 6 subtests | ✅ PASS |
| R `tests/testthat/test-censo-dictionary.R` | 34 testes | ✅ PASS |

Cobertura: estrutura, cobertura 4 tabelas, `tp_dependencia` domain, PK/FK corretas (`linha_id` em `censo_escolas`, composta nas demais), `year_introduced >= 2025`, validação, helpers, filtro por ano.

---

## Dependências Registradas

| Ordem | Issue | Razão |
|-------|-------|-------|
| 1 | **#124 (Fase 0)** | DO block popula proveniência quando colunas existirem |
| 2 | **#134 antes de #137** | Treinar modelo sobre tabela sem dicionário/proveniência → coeficiente inauditável |
| 3 | **#135 depois de #124** | Versionar (DVC) sem proveniência registra erro com data — pior que não versionar |

---

## Arquivos Alterados

| Arquivo | Tipo | Linhas |
|---------|------|--------|
| `data_pipeline/deploy/censo_data_dictionary.sql` | Nova migration | +320 |
| `data_pipeline/revert/censo_data_dictionary.sql` | Revert | +12 |
| `data_pipeline/verify/censo_data_dictionary.sql` | Verify | +66 |
| `backend/lib/EduMaps/Schema/Result/CensoDataDictionary.pm` | Result class | +199 |
| `backend/t/02-models/censo_dictionary.t` | Teste Perl | +106 |
| `analysis/edumapsr/R/censo-dictionary.R` | Interface R | +254 |
| `analysis/edumapsr/tests/testthat/test-censo-dictionary.R` | Teste R | +187 |
| `analysis/edumapsr/R/chat-dictionary.R` | Integração chat | +145/-37 |

**Total**: +1.252 linhas, 8 arquivos (5 novos)

---

## Próximos Passos

1. **#124 (Fase 0)**: Adicionar `source_url`, `source_license`, `retrieved_at` em `clean.import_metadata` → DO block popula automaticamente.
2. **#137**: Usar `censo_dictionary()` + `censo_dict_validate()` no pipeline de treino do RandomForest.
3. **#132 (e-SIC INEP)**: Licença verificada → futuras ingestões já saem com proveniência completa no dicionário.
4. **Edições futuras do Censo**: Quando houver 2026+, rodar migration novamente → novas linhas com `year_introduced = 2026`; comparar `value_domain` para detectar `year_changed`.