# Nota Técnica 80 — Fase 4: Financeiro e Investimento SICONFI + Transparência (#128)

**Data**: 2026-09-30  
**PR**: #145 (merge commit `af8adf9`)  
**Branch**: `feat/data/fase4-siconfi-transparencia` → `main`  
**Commit**: `1a24654`

---

## Contexto

Issue #128 (prioridade `[média]`) — **Fecha a lacuna 4 (investimentos planejados)** e abre a dimensão de **capacidade fiscal municipal** que o IVET não tinha.

Hoje o IVET diz "insuficiência de recursos" com base só em **repasse federal**. Isso mede o que veio, não o que o município consegue fazer com o que tem.

---

## Entregas

| Migration | Tabela/View | Status | Descrição |
|-----------|-------------|--------|-----------|
| `siconfi_receita` | `clean.siconfi_receita` | ✅ Vazia (estrutura) | Receitas municipais SICONFI/Tesouro Nacional. PK composta, `classificacao` separa `realizada` de `estimativa`. |
| `siconfi_despesa` | `clean.siconfi_despesa` | ✅ Vazia (estrutura) | Despesas municipais função 12 (educação) com funcao/subfuncao (361=Ensino Fundamental, 362=Ensino Médio, etc.), valores empenhado/liquidado/pago. |
| `transferencia_educ` | `clean.transferencia_educ` | ✅ Vazia (estrutura) | CGU Portal da Transparência transferências educação (FUNDEB, PNATE, PROINFANCIA, PDDE). WAF intermitente 405. |
| `analytics_esforco_fiscal` | `analytics.esforco_fiscal_educacao` | ✅ View | Cruzamento SICONFI (receitas/despesas realizadas) + CGU transferências + Censo Escolar (matrículas) + População. Indicadores: FUNDEB/aluno, despesa/aluno, % receita em educação, autonomia fiscal, dependência FUNDEB/federal. |

---

## Decisões de Design

### 1. **`classificacao` separa `realizada` de `estimativa`** — critério crítico

O catálogo de fontes estabeleceu como regra: **nunca misturar realizada com estimativa**. A coluna `classificacao` (`realizada` | `estimativa`) é parte da PK composta e **obriga o filtro explícito** em qualquer query.

```sql
-- SEMPRE filtrar:
WHERE classificacao = 'realizada'
```

Misturar as duas produz indicador sem sentido (execução vs. orçamento).

### 2. **WAF intermitente no Portal da Transparência** → retry com backoff obrigatório

O `api.portaldatransparencia.gov.br` responde **405 "Human Verification"** intermitentemente.

- **Não é opcional**: retry com backoff exponencial é obrigatório
- **Job noturno com cache** não é otimização — é o que torna a carga confiável
- O retry deve ser implementado no job de ingestão (R/Perl), não na migration

### 3. **SICONFI ≠ SIOPE** — não confundir

| Fonte | Domínio | API |
|-------|---------|-----|
| **SIOPE** | Educação (gastos com educação) | `apidadosabertos.saude.gov.br` (conta教育专用) |
| **SICONFI** | Finanças públicas (receitas/despesas gerais) | `tesouror.transparencia.gov.br` |

O `tesouror` traz **as duas** APIs. SIOPE é específico de educação; SICONFI é finanças públicas gerais (função 12 = educação).

### 4. **FNDE (PNATE, Novo PAC, Proinfância) fora de escopo** — acesso, não valor

A melhor especificação do lote (mensal, conteúdo declarado) está atrás de **portal inacessível a cliente não-browser (SPA sem SSR)**. Depende de e-SIC (#132). Issue própria condicionada a e-SIC.

### 5. **Banco Central (SGS/SCR) descartado por licença** — ODbL share-alike

Materializar no Postgres do EduMaps abriria a base derivada sob copyleft. Descartado **por licença, não por mérito**.

---

## Allowlist Atualizada (Fase 4)

| Fonte | Endpoints Permitidos |
|-------|---------------------|
| **Tesouro Nacional (SICONFI)** | `/api/v1/receitas`, `/api/v1/despesas`, `/api/v1/entes` |
| **CGU Portal da Transparência** | `/api-de-dados/transferencias`, `/api-de-dados/entes` |

---

## Deploy Sqitch

```
Deploying changes to db:pg://devel@db/edumaps_dev
  + siconfi_receita ........... ok
  + siconfi_despesa ........... ok
  + transferencia_educ ........ ok
  + analytics_esforco_fiscal .. ok

Verifying db:pg://devel@db/edumaps_dev
  * siconfi_receita .................... ok
  * siconfi_despesa .................... ok
  * transferencia_educ ................. ok
  * analytics_esforco_fiscal ........... ok
```

---

## Indicadores Derivados (view `analytics.esforco_fiscal_educacao`)

| Indicador | Fórmula | Interpretação |
|-----------|---------|---------------|
| `fundeb_por_aluno` | `fundeb_receita / total_matriculas` | Recurso FUNDEB por aluno matriculado |
| `despesa_educ_por_aluno` | `despesa_educ_paga / total_matriculas` | Gasto efetivo por aluno |
| `pct_receita_em_educ` | `despesa_educ_paga / receita_total * 100` | Prioridade orçamentária da educação |
| `autonomia_fiscal_pct` | `receita_propria / receita_total * 100` | Capacidade de gerar recursos próprios |
| `dependencia_fundeb_pct` | `fundeb_receita / receita_total * 100` | Dependência do FUNDEB |
| `dependencia_federal_pct` | `(fundeb_receita + transferencias_educ) / receita_total * 100` | Dependência de recursos federais |

---

## Dependências Desbloqueadas

| Issue | Fase | Status |
|-------|------|--------|
| **#129** | 5 — BrazilCrime segurança | ✅ Desbloqueada |
| **#130** | 6 — ANTT/Transportes | ✅ Desbloqueada |
| **#131** | — Overpass/OSM viés | ✅ Desbloqueada |
| **#132** | — e-SIC INEP/MEC/FNDE | ✅ Desbloqueada |

---

## Próximos Passos

1. **Jobs de ingestão** (R/Perl) para popular as 3 tabelas via allowlist com retry/backoff.
2. **#129 (Fase 5)**: BrazilCrime (segurança) — allowlist já tem `api.seguranca.gov.br` ou similar.
3. **Indicador de esforço fiscal no IVET**: integrar `autonomia_fiscal_pct` e `dependencia_fundeb_pct` como dimensão nova do IVET.

---

## Lições Aprendidas

1. **`classificacao` é regra de negócio, não detalhe técnico** — misturar realizada/estimativa quebra o indicador. A coluna na PK força o desenvolvedor a escolher.
2. **WAF 405 não é erro, é feature do Portal** — retry com backoff é arquitetural, não opcional.
3. **SICONFI ≠ SIOPE** — confundir os dois é erro comum; SICONFI é finanças públicas, SIOPE é específico de educação.
4. **FNDE condicionado a e-SIC** — quando o portal não tem API, a solução é administrativa (e-SIC), não técnica.