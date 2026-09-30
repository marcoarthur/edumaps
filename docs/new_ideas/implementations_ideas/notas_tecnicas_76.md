# Nota Técnica 76 — Fase 0: Allowlist de Endpoints + Proveniência com Licença (#124)

**Data**: 2026-09-30  
**PR**: #141 (merge commit `163d1d5`)  
**Branch**: `feat/data/fase0-allowlist-proveniencia` → `main`  
**Commit**: `886b571`

---

## Contexto

Issue #124 (prioridade `[alta]`, bloqueia #125–#130) definia a **fundação** do pipeline de ingestão: nenhuma fonte nova entra antes da Fase 0. Duas peças obrigatórias:

1. **Allowlist de endpoints** — impede download acidental de microdado individual (LGPD)
2. **Proveniência com licença** — estende `clean.import_metadata` para auditoria posterior

---

## Decisões de Design

### 1. Allowlist por **Recurso**, não por Host

O caso-limite que generalizou a regra:

| Fonte | Recurso Permitido | Recurso Negado | Razão |
|-------|-------------------|----------------|-------|
| ANTT MONITRIIP | Serviço Regular (agregado) | **Viagens** (74 recursos) | CC-BY, mas expõe CNPJ, placa, IMEI, lat/long **por viagem** |
| SPTRANS | Créditos agregados (se houver) | **Bilhete Único Usuário** | CCZero, mas **nível individual** (saldo por usuário) |
| Min. Saúde (SUS) | — | **SISVAN, Vacinação, CNES** | Microdado individual (menor de idade, PII) |

**Conclusão**: allowlist por host não basta. Precisa ser por **recurso** (path completo), com `denied` explícito para recursos sensíveis no mesmo host de permitido.

### 2. `clean.import_metadata` Estendido

| Coluna | Tipo | Papel |
|--------|------|-------|
| `source_url` | TEXT | URL canônica exata do recurso baixado |
| `source_license` | TEXT | SPDX ou "Não verificada" |
| `retrieved_at` | TIMESTAMPTZ | Momento do download |

Sem isso, o critério nº 9 do método de priorização **não é auditável** depois da ingestão.

### 3. Validação **Antes** do Request (Fail-Fast)

O módulo `EduMaps::Data::Allowlist` valida a URL **antes** de qualquer HTTP. Se falha:
- Job aborta com erro explícito: `"Allowlist validation failed: Endpoint explicitamente NEGADO: ..."`
- Não há "download e depois descobre" — o dado sensível nunca chega ao banco.

### 4. DO Block Dinâmico na Migration do Dicionário (#134)

A migration `censo_data_dictionary` já tinha um `DO $$ ... $$` que:
- Verifica se colunas Fase 0 existem (`source_url`, `source_license`, `retrieved_at`)
- Se existem → popula `clean.censo_data_dictionary` com proveniência
- Se não → avisa via `RAISE NOTICE` e segue (proveniência fica NULL)

Isso permite rodar o dicionário **antes** da Fase 0, sem erro.

---

## Arquivos Alterados

| Arquivo | Tipo | Descrição |
|---------|------|-----------|
| `data_pipeline/deploy/import_metadata_fase0.sql` | Nova migration | +3 colunas + índice em `clean.import_metadata` |
| `data_pipeline/revert/import_metadata_fase0.sql` | Revert | Remove colunas + índice |
| `data_pipeline/verify/import_metadata_fase0.sql` | Verify | Checa colunas, tipos, índice, comentários |
| `data_pipeline/allowlist.yaml` | Config | 6 fontes permitidas + 5 recursos negados |
| `backend/lib/EduMaps/Data/Allowlist.pm` | Módulo | Validador (carrega YAML, `validate_url`, `get_license_for_url`) |
| `backend/lib/EduMaps/Task/Siope/Scrap/SpreadSheet/Gastos.pm` | Integração | Valida `base` URL antes de `get_p` |
| `data_pipeline/deploy/censo_*.sql` (4) | Atualização | Popula `source_url/license/retrieved_at` |
| `backend/t/02-models/allowlist.t` | Teste | 8 subtests (permitido, negado, host desconhecido, licenças, source_id) |

**Total**: +549 linhas, 11 arquivos (4 novos)

---

## Testes

| Suite | Testes | Status |
|-------|--------|--------|
| Perl `t/02-models/allowlist.t` | 8 subtests | ✅ PASS |
| Perl `t/02-models/censo_dictionary.t` | 6 subtests | ✅ PASS (com Fase 0 rodando) |
| R `test-censo-dictionary.R` | 34 testes | ✅ PASS |

---

## Dependências Desbloqueadas

| Issue | Status | Nota |
|-------|--------|------|
| **#125** (Fase 1 — contexto municipal/IBGE) | ✅ Desbloqueada | Allowlist já tem IBGE SIDRA/servicodados |
| **#126** (Fase 2 — saúde CNES/DATASUS) | ✅ Desbloqueada | Recursos SUS microdado individual **negados**; agregados permitidos via e-SIC |
| **#127** (Fase 3 — MapBiomas/INMET) | ✅ Desbloqueada | Allowlist tem MapBiomas + INMET |
| **#130** (Fase 6 — mobilidade) | ✅ Desbloqueada | ANTT agregado permitido, viagens negado; Transportes RENAVAM permitido |
| **#134** (Dicionário) | ✅ Integrada | DO block popula proveniência automaticamente |

---

## Próximos Passos

1. **#132 (e-SIC INEP)**: Obter licença oficial do Censo Escolar → atualizar `source_license` de "Não verificada" para SPDX real.
2. **#125 (Fase 1)**: Implementar ingestão IBGE (SIDRA PIB, servicodados municípios) usando allowlist.
3. **#126 (Fase 2)**: Ingerir CNES (estabelecimentos) + DATASUS/SISAB (agregados) — ambos via e-SIC, recursos permitidos na allowlist.
4. **Validação em runtime**: Estender allowlist para OSM/Overpass (#131) e demais scrapers quando surgirem.

---

## Lições Aprendidas

- **Licença aberta ≠ livre de LGPD**: SPTRANS CCZero foi o caso-limite que provou que allowlist deve ser por recurso, não por licença.
- **Negar por omissão é frágil**: `denied` explícito força revisão consciente — "este recurso existe, eu sei, e decidi não ingerir".
- **Proveniência no metadado da tabela** (não no dicionário): `import_metadata` é o local canônico; dicionário referencia.
- **Fail-fast salva LGPD**: Validar antes do HTTP evita que dado de menor chegue ao banco de dev.