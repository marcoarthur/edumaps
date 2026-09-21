# Nota técnica — Perfil modal dos diretores escolares (Censo Escolar 2025)

> Data: 2026-09-21 · Ciclo: análise (eduBR) — pacote R

## 1. Contexto

A pesquisadora educacional levantou, a partir da literatura, um perfil
narrativo do diretor de escola brasileiro (documento de referência
`~/Documents/Notas/gestor_edumaps_perfil.md`). Para **não** apenas repetir
números da literatura, o ciclo construiu — no pacote `eduBR` — a análise **a
partir da nossa base** (`clean.censo_gestor` 2025, cruzado com
`clean.censo_escolas`), rede a rede. As decisões do usuário: **só a análise no
eduBR** (sem backend/frontend), **unidade gestor** como principal e **escola**
como sensibilidade, **base válida por dimensão**, recortes Brasil/rede/região/
UF, **nossos números primeiro** (o documento vira referência à parte).

## 2. Solução

### Dados
- `clean.censo_gestor` (2025): **contagens de gestores por escola**
  (`qt_gest_bas`, `qt_gest_bas_fem`, `qt_gest_bas_esco_*`,
  `qt_gest_bas_vinculo_*`, `qt_gest_bas_acesso_cargo_*`,
  `qt_gest_bas_espec_gestao`, `qt_gest_bas_pcd`, faixas etárias…). Uma linha
  por escola — somar `qt_gest_bas` dá o total de diretores (~190 mil).
- Join com `clean.censo_escolas` por `(nu_ano_censo, co_entidade)` para
  anexar rede, categoria da escola privada, localização e UF/macrorregião.
- **Pegadinha**: as colunas da tabela `clean` real são **minúsculas**
  (`tp_dependencia`, `no_municipio`…), não o `UPPER_CASE` do script `.sql`.

### `R/gestor.R` (pacote eduBR)
- `censo_gestor(con)` — domínio novo do catálogo (`clean.censo_gestor`).
- `gestores(con, rede, uf, regiao, localizacao, ano = 2025)` — consulta
  **lazy**; filtros e rótulos empurrados para o SQL. Rótulos (rede/categoria
  privada/localização) são gerados por `eduBR_case_when_lookup()`, que
  constrói `case_when` a partir do vetor nomeado de códigos — **evita**
  indexação R (`vetor[col_sql]`) e `.env$fn(...)` dentro de `filter`, que
  dbplyr não traduz bem.
- `perfil_gestor(dados, corte = brasil/rede/regiao/uf/categoria_privada,
  unidade = gestor/escola)` — materializa e agrega **em R**. 9 dimensões:
  sexo, cor/raça (`qt_gest_bas_nd` fora do denominador), escolaridade,
  pós-graduação, faixa etária, vínculo (**só públicas**), forma de acesso ao
  cargo, formação continuada em gestão (≥80h, denominador complemento) e
  deficiência/TEA/superdotação (idem). Retorna `$proporcoes`, `$modal`
  (categoria modal + Herfindahl) e `$n`.

### Report
- `analysis/perfil_gestor.Rmd` — narrativa Brasil → rede → região/UF, com
  tabela de sensibilidade gestor×escola (a categoria **não muda** em nenhuma
  rede; só a proporção varia até ~3pp). Snapshot de dados em
  `analysis/capturar_gestor.R` → `analysis/dados_gestores.rds` (padrão RDS já
  usado pelo report RF; `analysis/*.rds` e `analysis/*.html` gitignored).

## 3. Principais números (base 2025, nossos)

- **190.641 diretores** em **180.540 escolas**; proporção entre redes:
  municipal 59,8% / estadual 16,6% / privada 23,2% / federal 0,4%.
- **Sexo**: maioria **feminina** (municipal 82,1%, privada 83,9%, estadual
  65,6%); **federal é a exceção masculina** (73,7%).
- **Cor/raça**: modal **branca** em todas as redes; na municipal o branco é
  45,6% (vs 52,4% no Brasil) — quase o "não-majoritário".
- **Escolaridade**: superior entre 85% (privada) e ~99% (federal).
- **Forma de acesso ao cargo — o traço que mais separa as redes**:
  proprietário/sócio na privada (52,1%), eleição com a comunidade na federal
  (81,6%), três vias próximas na municipal (processo seletivo 33,8%,
  indicação 32,9%, eleição 15,2%) e estadual (eleição 25,7%, processo
  seletivo+eleição 24,2%, processo seletivo+nomeação 19,7%).
- **Formação continuada em gestão (≥80h) minoritária**: 7,2% na federal,
  19,2% privada, 23,1% estadual, 27,0% municipal.
- **Emprego do documento de referência**: números da literatura ficam como
  comparação à parte (loop de curadoria) — não são afirmados neste ciclo.

## 4. Validação

- `devtools::test()`: **282 ok** (+1 skip smoke) no container `rstudio.dev`.
- `devtools::check()`: **0 erros / 0 warnings / 0 notas**.
- Smoke real contra `edumaps`: join, tradução SQL e distribuições conferidos
  (validou também o nome real das colunas).

## 5. Entregas

- `~/Projects/eduBR`: `R/gestor.R`, `R/catalogo.R` (+`censo_gestor`),
  testes (`test-gestor.R`, `test-perfil-gestor.R`, `test-catalogo.R`),
  `analysis/perfil_gestor.Rmd` + `analysis/capturar_gestor.R`, README e
  skill `r-edubr.md`. **PR #3** (`feat/edubr-perfil-gestor`).
- Rendering do report no container `rstudio.dev`; HTML em `analysis/`
  (gitignored).