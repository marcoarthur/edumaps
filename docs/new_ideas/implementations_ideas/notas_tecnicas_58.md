# Nota técnica — Financeiro: agregado da Secretaria (SIOPE sem folha por escola)

> Data: 2026-09-22 · Ciclo: backend (Mojolicious) + frontend (Svelte 5)

## 1. Contexto

Reportado que, em **Taubaté**, várias escolas municipais não mostravam o painel
financeiro (sem dados), apesar de os arquivos `*.xlsx` baixados terem milhares
de registros.

## 2. Diagnóstico — não era bug do EduMaps

- Taubaté tem **75.081 registros** na base, mas **todos sob `cod_inep=99999999`**
  e `escola="SEC MUN DE EDUC DE TAUBATE"`.
- Conferido no **xlsx bruto** de Taubaté (2023/2024/2025): todas as linhas trazem
  `99999999` — a prefeitura declarou a folha **agregada na Secretaria**, não por
  unidade.
- Num município que declara por escola (ex.: `353650`), o xlsx traz **1 cod_inep
  por escola** (52 distintos). Logo, a diferença é do **dado de origem** (FNDE),
  não do EduMaps.
- Extensão: **~3819 municípios** usam o `99999999` como "escola" agregadora.

## 3. Fix

- `Roles/Business/School/Finance.pm#financial_summary`:
  - tenta a folha da **escola** (`cod_inep`);
  - se vazia, cai para o **agregado do município** (`cod_municipio::text`);
  - devolve `origem` (`'escola'` | `'secretaria'`) e `rotulo_origem`.
- `SchoolFinancePage.svelte`: aviso âmbar quando `origem === 'secretaria'`
  ("Folha da Secretaria municipal... total da rede, não apenas desta unidade").
- `docs/funcionalidades/analise/financeiro.md` atualizado.

## 4. Validação

| Item | Resultado |
|------|-----------|
| Endpoint real (escola só com agregado) | `origem=secretaria`, 12 competências, **3.632** profissionais |
| Escolas com folha própria | `origem=escola` (sem aviso) |
| Backend | `prove -rl t/04-api/school/ t/04-api/gestor/` (novo `finance_secretaria.t`) |
| Frontend | `SchoolFinancePage.test.js` 6 ok; suite 303 ok (4 pré-existentes) |

**Pré-existentes** (não regressões): `t/04-api/school/clustering.t` falha no HEAD
(depende de R/serviço) e `search_paginated.t` é flaky de performance.

Deploy: `deploy_backend_dev` + `deploy_frontend_dev` → **PR #91** (merge `fefa1a8`).

## 5. Lições

- **"Sem dados" pode ser dado de origem, não bug**: antes de mexer no código,
  comparar o arquivo baixado (`xlsx2csv_fast`) com o banco — aqui o parser estava
  correto e o SIOPE é que agrega.
- **Fallback por município**: `remuneracao_municipal.cod_municipio` permite ligar
  a escola ao agregado da Secretaria; sinalizar a origem evita interpretar o
  total da rede como se fosse da unidade.
