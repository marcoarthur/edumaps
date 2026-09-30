# Nota Técnica 78 — Fase 2: Bloco de Saúde CNES + SISAB + Acessibilidade (#126)

**Data**: 2026-09-30  
**PR**: #143 (merge commit `45ae322`)  
**Branch**: `feat/data/fase2-saude-cnes` → `main`  
**Commit**: `a071293`

---

## Contexto

Issue #126 (prioridade `[alta]`) — **primeira lacuna do IVET que fecha**: saúde deixa de ser proxy municipal uniforme e passa a ser medida com oferta em ponto (CNES) + efetividade APS (SISAB).

---

## Entregas

| Migration | Tabela/View | Status | Descrição |
|-----------|-------------|--------|-----------|
| `cnes_estabelecimentos` | `clean.cnes_estabelecimentos` | ✅ Vazia (estrutura) | PK composta `(codigo_cnes, dt_snapshot)`. Sanitizado: **sem PII**. Apenas `codigo_cnes`, `codigo_municipio`, `codigo_tipo_unidade`, `status`, lat/long, `data_atualizacao`, `dt_snapshot`. Índice GIST espacial. |
| `sisab_aps` | `clean.sisab_aps` | ✅ Vazia (estrutura) | Indicadores APS SISAB/PIMMB agregados por município/mês. PK composta `(codigo_municipio, dt_referencia, dt_snapshot)`. Campos: `cobertura_aps`, `ativas_ff`, `equipe_esf`, `equipe_emsi`, `total_vagas_ativas`, `ocupadas`, `categoria_ivs`. |
| `analytics_acessibilidade_saude` | `analytics.acessibilidade_saude` | ✅ View | Cruza CNES (oferta em ponto UBS/USF) + SISAB (efetividade APS) + Censo Escolar (demanda). Distância haversine escola→UBS/USF, classificação de acesso, efetividade APS (`ocupadas/total_vagas_aps`). |

---

## Decisões de Design

### 1. **Sanitização na ingestão (fail-fast LGPD)**

O CNES bruto expõe `nome_razao_social` (frequentemente **nome de pessoa física**), CNPJ, telefone, e-mail, endereço/bairro. **Regra arquitetural**: descartar na entrada, não depois.

```sql
-- Mantidos:
codigo_cnes, codigo_municipio, codigo_tipo_unidade, status,
latitude, longitude, data_atualizacao, dt_snapshot

-- Descartados na entrada:
nome_razao_social, nome_fantasia, numero_cnpj_entidade,
numero_telefone_estabelecimento, endereco_email_estabelecimento,
endereco_estabelecimento, bairro_estabelecimento
```

### 2. **Allowlist explícita de endpoints (Fase 0 aplicada)**

| Fonte | Endpoints Permitidos | Endpoints Negados |
|-------|---------------------|-------------------|
| **DATASUS/SISAB** | `/atencao-primaria/pmmb-serie-historica`, `/atencao-primaria/pmmb-consolidado`, `/macrorregiao-e-regiao-de-saude/municipio` | — |
| **CNES** | `/cnes/estabelecimentos` (sanitizado), `/cnes/tipounidades` | `/cnes/estabelecimentos` **bruto** (PII) |

**Recursos negados explicitamente** (mesmo host):
- SISVAN `/sisvan/estado-nutricional` (peso, IMC, documento por pessoa)
- Vacinação PNI `/vacinacao/doses-aplicadas-pni-*` (data, documento, raça por pessoa)
- CNES bruto `/cnes/estabelecimentos` (nome pessoa física, CNPJ, telefone, e-mail)

### 3. **`dt_snapshot` em ambas as tabelas (versionamento temporal)**

O CNES e SISAB são snapshots mensais. A tabela guarda `dt_snapshot` (data do snapshot) como parte da PK composta, permitindo:
- Série temporal de abertura/fechamento de unidades
- Evolução de cobertura APS
- Reprocessamento histórico sem perda

### 4. **View analítica `analytics.acessibilidade_saude`**

Cruza três fontes:
- **CNES** (oferta em ponto): UBS (tipo 11) + USF (tipo 12) ativas, lat/long
- **SISAB** (efetividade APS): cobertura, equipes, vagas, ocupação, IVS
- **Censo Escolar** (demanda): escolas ativas com lat/long

**Indicadores derivados**:
- `dist_min_km_ubs`: distância haversine escola→UBS/USF mais próxima (km)
- `classificacao_acesso`: excelente (<1km), bom (1-3km), regular (3-5km), difícil (>5km), sem UBS
- `efetividade_vagas_aps`: `ocupadas / total_vagas_ativas * 100`
- Metadados de snapshot (`aps_snapshot`, `cnes_snapshot`)

**Limitação conhecida**: distância haversine (linha reta). Substituir por roteamento OSRM/Valhalla quando malha viária estiver disponível.

---

## Allowlist Atualizada (Fase 2)

Adicionados a `data_pipeline/allowlist.yaml`:

```yaml
sources:
  - id: datasus_sisab
    host: apidadosabertos.saude.gov.br
    resources:
      - path: "/atencao-primaria/pmmb-serie-historica"
      - path: "/atencao-primaria/pmmb-consolidado"
      - path: "/macrorregiao-e-regiao-de-saude/municipio"
  
  - id: cnes_estabelecimentos
    host: apidadosabertos.saude.gov.br
    resources:
      - path: "/cnes/estabelecimentos"
      - path: "/cnes/tipounidades"

denied:
  - id: sus_sisvan_individual        # microdado individual
  - id: sus_vacinacao_individual     # microdado individual
  - id: sus_cnes_individual          # CNES bruto com PII
```

---

## Deploy Sqitch

```
Deploying changes to db:pg://devel@db/edumaps_dev
  + cnes_estabelecimentos ........... ok
  + sisab_aps ....................... ok
  + analytics_acessibilidade_saude .. ok

Verifying db:pg://devel@db/edumaps_dev
  * cnes_estabelecimentos .............. ok
  * sisab_aps .......................... ok
  * analytics_acessibilidade_saude ..... ok
```
> ⚠️ Falha em `rede_escolas_etapas` (divisão por zero) é **pré-existente**.

---

## Dependências Desbloqueadas

| Issue | Fase | Fonte | Status |
|-------|------|-------|--------|
| **#127** | 3 | MapBiomas/INMET | ✅ Desbloqueada |
| **#128** | 4 | SICONFI/Transparência | ✅ Desbloqueada |
| **#129** | 5 | BrazilCrime segurança | ✅ Desbloqueada |
| **#130** | 6 | ANTT/Transportes | ✅ Desbloqueada |
| **#131** | — | Overpass/OSM viés | ✅ Desbloqueada |
| **#132** | — | e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Riscos e Próximos Passos

### Riscos
- **Paginação CNES**: `limit ≤ 20` → ~20k requisições para 400k estabelecimentos. Filtrar por `codigo_tipo_unidade` e `codigo_municipio`.
- **Cobertura histórica**: API não expõe série → `dt_snapshot` essencial.
- **Presença cadastral ≠ operação**: combinar **obrigatoriamente** com SISAB (efetivo vs. cadastro).
- **Viés de localização**: UBS de interior podem ter geometria imprecisa.

### Próximos Passos
1. **Jobs de ingestão** (R/Perl) para popular `cnes_estabelecimentos` e `sisab_aps` via allowlist.
2. **#127 (Fase 3)**: MapBiomas (cobertura solo) + INMET (clima) — allowlist já pronta.
3. **Roteamento OSRM**: substituir haversine por distância rodoviária real.