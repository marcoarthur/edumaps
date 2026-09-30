# Nota Técnica 81 — Fase 5: Segurança e Sinistralidade Viária BrazilCrime + ANTT + RENAEST (#129)

**Data**: 2026-09-30  
**PR**: #146 (merge commit `5810881`)  
**Branch**: `feat/data/fase5-brazilcrime-seguranca` → `main`  
**Commit**: `90c6d64`

---

## Contexto

Issue #129 (prioridade `[alta]`) — **Fecha a lacuna 2 (segurança pública)** e é a fase com **maior risco ético** do plano inteiro: lida com dado sensível por natureza (ocorrência policial) e dado de deslocamento individual.

---

## Entregas

| Migration | Tabela | Status | Descrição |
|-----------|--------|--------|-----------|
| `brazilcrime_municipio` | `clean.brazilcrime_municipio` | ✅ Vazia (estrutura) | Criminalidade agregada por município/ano (homicídio doloso, roubo, furto, latrocínio, etc.) com **supressão de célula pequena (count < 5)**. |
| `antt_acidente_trecho` | `clean.antt_acidente_trecho` | ✅ Vazia (estrutura) | Acidentes ANTT por trecho rodoviário. Chave bruta `Concessionaria;Data;Km;Trecho` — **SEM MUNICÍPIO**. |
| `antt_trecho_geodados` | `clean.antt_trecho_geodados` | ✅ Vazia (estrutura) | Geodados ANTT de trechos rodoviários (Concessionaria;Trecho;Km_Inicial;Km_Final;Municipio+codigo_ibge;geometria LineString). Resolve trecho → município. |
| `renaest_sinistro` | `clean.renaest_sinistro` | ✅ Vazia (estrutura) | Sinistros RENAEST agregados por **localidade (não município)**. Requer **de-para localidade → município** versionado. |

---

## Decisões Críticas de LGPD

### 1. **Licença aberta NÃO anula risco LGPD** — princípio arquitetural

| Conjunto | Licença | O que expõe | Decisão |
|----------|---------|-------------|---------|
| ANTT Monitriip Viagens (74 recursos) | CC-BY 4.0 | `cnpj`, `placa`, `numero_imei`, `latitude`, `longitude` **por viagem** | 🔴 **NEGADO** |
| SPTRANS Bilhete Único Usuário | **CCZero** | saldo/crédito **por usuário individual** | 🔴 **NEGADO** |

**Regra arquitetural**: licença aberta **não anula** risco LGPD. O caso SPTRANS é o mais instrutivo: CCZero é o degrau mais alto de liberdade de uso e ainda assim é **nível individual**. Ambos negados explicitamente na allowlist por nome, com teste.

### 2. **ANTT acidentes sem município** → JOIN OBRIGATÓRIO

A chave bruta ANTT acidentes é `Concessionaria;Data;Km;Trecho` — **não tem município**. O pipeline **deve** fazer JOIN com `antt_trecho_geodados` (que tem `municipio` + `codigo_ibge` + geometria LineString) para resolver o município.

### 3. **RENAEST agrega por localidade (não município)**

O RENAEST agrupa por **localidade** (ex.: 'São Paulo', 'Campinas'), cuja cobertura não é idêntica à divisão municipal IBGE. A fonte **não publica** o de-para localidade → município. **Construir e versionar esse de-para é parte do escopo**.

### 4. **BrazilCrime: supressão de célula pequena obrigatória**

Coluna `supressao_celula_pequena` boolean (TRUE = valor suprimido por sigilo estatístico, count < 5). **NUNCA expor por escola** — nem agregada.

### 5. **INPE Queimadas = redundante com MapBiomas Fogo**

MapBiomas Fogo (classe 6) já cobre com melhor granularidade (30m vs 1km) e metodologia documentada. **Não ingerir INPE Queimadas**.

---

## Allowlist Atualizada (Fase 5)

| Fonte | Endpoints Permitidos |
|-------|---------------------|
| **BrazilCrime** | CRAN package `BrazilCrime` (sem HTTP endpoint) |
| **ANTT** | `/dataset/acidentes`, `/dataset/trechos` |
| **Transportes** | `/dataset/renatest-sinistro` |

**Negados explicitamente** (mesmo host de permitido):
- ANTT Monitriip Viagens (CC-BY mas cnpj/placa/imei/lat-long por viagem)
- SPTRANS Bilhete Único Usuário (CCZero mas nível individual)

---

## Deploy Sqitch

```
Deploying changes to db:pg://devel@db/edumaps_dev
  + brazilcrime_municipio .......... ok
  + antt_acidente_trecho .......... ok
  + antt_trecho_geodados .......... ok
  + renaest_sinistro .............. ok

Verifying db:pg://devel@db/edumaps_dev
  * brazilcrime_municipio ................ ok
  * antt_acidente_trecho ............... ok
  * antt_trecho_geodados ............... ok
  * renaest_sinistro ................... ok
```

---

## Dependências Desbloqueadas

| Issue | Fase | Status |
|-------|------|--------|
| **#130** | 6 — ANTT/Transportes frota/renatest | ✅ Desbloqueada |
| **#131** | — Overpass/OSM viés de cobertura | ✅ Desbloqueada |
| **#132** | — e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Próximos Passos

1. **Jobs de ingestão** (R/Perl) para popular as 4 tabelas via allowlist.
2. **#130 (Fase 6)**: ANTT/Transportes — frota agregada por município + RENAEST frota/veículo.
3. **De-para localidade → município RENAEST**: construir e versionar o mapeamento localidade → município IBGE.
5. **View analítica de sinistralidade viária**: cruzar `antt_acidente_trecho` (via trechos geodados) + `renaest_sinistro` (via de-para) + `brazilcrime_municipio` → `analytics.sinistralidade_escola`.

---

## Lições Aprendidas

1. **Licença aberta ≠ livre de LGPD**: o caso SPTRANS CCZero prova que o nível do dado (individual vs. agregado) é o que importa, não a licença.
2. **Chave sem município não é dado utilizável**: ANTT acidentes sem município são inúteis sem o JOIN com geodados de trechos.
3. **Granularidade diferente ≠ incompatível, mas exige de-para**: RENAEST por localidade vs. IBGE por município exige de-para versionado.
4. **Supressão de célula pequena não é opcional**: `count < 5` → supressão obrigatória, coluna boolean explícita.