# Nota técnica — Financeiro: card de profissionais (total distinto)

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) + frontend (Svelte 5)

## 1. Contexto

Foi reportado que a folha da escola `35268800` "mostrava apenas 1
profissional", sugerindo um bug no parsing dos gastos (SIOPE). Havia arquivos
`*.xlsx` reais em `/tmp` no `backend.edumaps` com vários servidores.

## 2. Investigação — não havia bug de parsing/gravação

- O CSV gerado por `xlsx2csv_fast` para `353650_2024.xlsx` tem 21 linhas da
  escola `35268800`; o banco tem **21 registros de 2024** — batem linha a linha
  (3+1+3+3+3+3+1+1+... por mês).
- Total da escola: **45 registros, 5 CPFs distintos, 14 competências**.
- O endpoint `/api/school/35268800/finance` devolve as 14 competências com 3–5
  profissionais e 3 categorias — tudo correto.
- O "1" era o card **"Profissionais (Out/2024)"**: ele exibia **a competência
  mais recente**, e Outubro/2024 realmente tem **1 servidor** na base. Rótulo
  ambíguo → parecia que a escola tinha só 1 profissional.

## 3. Fix

- **backend** (`School::Finance#financial_summary`): expõe
  `total_profissionais` = `COUNT(DISTINCT cpf)` da escola (todos os meses/anos).
- **frontend** (`SchoolFinance.svelte`): o card passa a **"Profissionais
  (total)"** com esse número; a competência mais recente vira **nota
  secundária** ("Competência mais recente (Out/2024): 1"). `SchoolFinancePage`
  repassa `totalProfissionais`.

## 4. Validação

| Item | Resultado |
|------|-----------|
| CSV do xlsx vs banco (2024) | 21 = 21 linhas |
| Escola 35268800 | 45 registros / 5 CPFs / 14 competências |
| Endpoint `/finance` | `total_profissionais: 5` |
| Backend | `prove -rl t/04-api/gestor/finance_siope.t t/04-api/gestor/ t/04-api/pesquisa.t` → 68 ok |
| Frontend | `SchoolFinancePage.test.js` → 5 ok; suite 301 ok (4 pré-existentes) |

Deploy: `deploy_backend_dev` + `deploy_frontend_dev` → **PR #89** (merge `177409a`).

## 5. Lições

- **Cuidado com "última competência"**: `remuneracao_municipal` é uma linha por
  servidor **por mês**; meses recentes podem ter poucos registros. Para "quantos
  profissionais a escola tem", usar `COUNT(DISTINCT cpf)` no total.
- **Não assumir parsing quebrado**: comparar o CSV do `xlsx2csv_fast` com o
  banco antes de mexer no parser — o dado estava íntegro; o problema era de
  apresentação/rótulo no painel.
