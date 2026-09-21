# Nota técnica — Fix: município correto no SIOPE

> Data: 2026-09-21 · Ciclo: backend (Mojolicious) — bugfix

## 1. Contexto

No teste manual do SIOPE para **Cuiabá** (IBGE `5103403` → código antigo
`510340`), o job `query_siope` falhou com:

```
Cannot open /tmp/510655_2026.xlsx.Planilha.csv file: No such file or directory
```

Os args do job eram `["510655", 2026]`: o código passado era **o prefixo do
`cod_inep`** da escola, não o código do município.

## 2. Diagnóstico

A premissa original (de que o prefixo de 6 dígitos do INEP seria o código antigo
do IBGE do município) é **falsa**. Verificado no censo:

| `co_entidade` (INEP) | `co_municipio` (7d) | município (6d) | prefixo INEP |
|----------------------|---------------------|----------------|--------------|
| `51065592` (Cuiabá)  | `5103403`           | **510340**     | `510655`     |
| `35051780` (São Paulo) | `3550308`         | **355030**     | `350517`     |

Ou seja, `substr(cod_inep,0,6)` (`510655`) ≠ município (`510340`).

## 3. Correção

- `Roles/Business/School/Finance.pm`:
  - **`_cod_municipio_escola($cod_inep)`**: consulta
    `clean.censo_escolas.co_municipio` por `co_entidade` e corta para 6 dígitos
    (7→6); **fallback** por nome+UF da escola curada em
    `raw.br_municipios_2024` (com `eval` para não quebrar se a tabela faltar).
  - `siope_status`: `habilitado` passa a exigir **município derivável** (além de
    rede municipal); `anos_presentes` só consulta quando derivável.
  - Bug adicional: `map { $_[0] + 0 }` em sub com **assinatura** lia o `@_` da
    sub, não o `$_` da lista → `anos_presentes` retornava lixo
    (`93965870759752`). Corrigido para `map { $_->[0] + 0 }`.
- Teste `finance_siope.t`: passa a inserir `co_municipio` no censo e usa um INEP
  cujo **prefixo difere** do município (regressão garantida).

## 4. Validação

- `51065592` → `mun=510340`, `habilitado=1` (caso reportado); `35051780` →
  `355030`; `51065584` (privada) → `habilitado=0`.
- Backend: `prove -rl t/04-api/gestor/ t/04-api/pesquisa.t` — **68/68 PASS**.
- Smoke real (nginx): `GET /finance` → `siope.cod_municipio="510340"`;
  `POST .../financeiro/siope` → job com args **`["510340", 2024]`**; job
  removido sem raspar o FNDE.
- Deploy: `deploy_backend_dev` → **PR #87** (merge `0f221e8`).

## 5. Lições

- **Não inferir código de município pelo INEP** — usar a fonte oficial
  (`clean.censo_escolas.co_municipio`). O prefixo do INEP não tem essa semântica.
- **`$_[0]` em `map` dentro de sub com `-signatures`** é armadilha: use `$_->[0]`.
  (Vale para todos os roles; ficou registrado como convenção.)
- Testes de unidade devem **distinguir** a hipótese errada da certa (aqui, forçar
  prefixo ≠ município).
