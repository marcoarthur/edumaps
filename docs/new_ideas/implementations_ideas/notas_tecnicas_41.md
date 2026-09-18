# Nota técnica — Random Forest para classificar o desempenho escolar (eduBR)

> Data: 2026-09-18 · Ciclo: eduBR — classificação alto/médio/baixo (fund. I/II)

## 1. Contexto

O pacote R `eduBR` (`~/Projects/eduBR`, repo separado do `edumaps`) ganhou,
nos ciclos anteriores, acesso de alto nível à base (objetos S3), regiões,
tendência do IDEB, INSE transversal e uma camada declarativa de regressões.
Faltava um **modelo preditivo** sobre as features do censo: classificar as
escolas públicas em **alto/médio/baixo desempenho** — uma resposta a uma
demanda recorrente da curadoria (persona *especialista em ML*), e um
contraponto de aprendizado supervisionado aos métodos descritivos já
entregues.

A literatura brasileira recente embasa o desenho (anotada em
`~/Documents/Notas/pesquisa.md`): Fusco et al. (2025) aplica Random Forest a
infraestrutura × fluxo escolar; Cechinel et al. (2026, *Scientific Reports*)
usa RF com **seleção de variáveis por importância** a partir de features do
Censo Escolar. O usuário definiu: **modelo simples (RF; nada de XGBoost)**,
alvo = **média SAEB** (matemática + português), etapas = **fundamental I e II**.

## 2. Problema / decisões de desenho

- **Alvo**: terços globais de `nota_media` **dentro de cada etapa** →
  classes balanceadas `baixo/medio/alto` (`classificar_desempenho()`).
- **Features**: MV `analytics.escola_features` (~80 colunas, ~77 preditores),
  materialização da função `analytics.prepare_school_data()` (censo 2025 ×
  IDEB/SAEB 2023). A relação é **associativa/diagnóstica** (features de 2025 ×
  nota de 2023), não previsão de resultado futuro — `analytics.view_escolas_ml`
  é o caminho futuro para forecasting.
- **Modelo**: `ranger` — floresta de classificação com **probabilidade** e
  **importância por permutação** (`importance = "permutation"`), usada para
  **redução de dimensão** (treinar só o topo das features).
- **Identificadores espaciais nunca viram preditor**: `sg_uf`, `uf`,
  `co_municipio` etc. entram na lista de exclusão padrão do
  `treinar_floresta()`. Na primeira validação o join escola↔UF que criamos
  para o gráfico por UF **vazou UF como feature** (n_features era 78 ao invés
  de 77); corrigido e travado com teste.

## 3. Solução — `R/desempenho.R` + `R/floresta.R`

| Função | Papel |
|--------|-------|
| `features_escola(con, etapa, publica = TRUE)` | consulta lazy sobre a MV, filtrando `tp_dependencia ∈ {1,2,3}` |
| `classificar_desempenho(d)` | tercis por etapa → fator ordenado; tercis em `limites_desempenho()` |
| `dividir_dados(d)` | split estratificado 80/20 preservando os terços |
| `treinar_floresta()` | ranger (probabilidade + permutação); exclui alvo, ids e ids espaciais |
| `importancia_floresta()` | tibble `var`/`importancia` decrescente (guia de redução) |
| `predizer_floresta()` | `nivel_pred` + probabilidades `p_<classe>` |
| `metricas_floresta()` | acurácia, F1 *macro*, AUC *macro* (postos/Wilcoxon, sem dependência), `baseline_acerto`; attrs com matriz de confusão e métricas por classe |

`ranger` entrou em **Suggests**; **não** usamos `vip` (não instala no R local;
daria NOTA no check). Relatório de exemplo: `analysis/classificacao_desempenho_rf.Rmd`
(pipeline por etapa, confusão, importância top-20, perfil médio por nível, %
por UF).

## 4. Resultados reais (base completa, 2023)

| Etapa | N escolas | Tercis (baixo/médio, médio/alto) | Acurácia | F1 macro | AUC macro | Baseline |
|-------|-----------|-----------------------------------|----------|----------|-----------|----------|
| Fundamental I | 41.229 | 5,42 / 6,26 | 0,594 | 0,591 | 0,780 | 0,333 |
| Fundamental II | 31.078 | 4,72 / 5,33 | 0,566 | 0,564 | 0,758 | 0,333 |

- **top-15 features** (importância por permutação): preserva o desempenho
  (fund. I: 0,575/0,759) — valida o uso da importância para reduzir dimensão.
- **variante sem INSE** (`media_inse` + `pc_nivel_*` fora): cai ~0,05 — o nível
  socioeconômico domina, mas sobra sinal estrutural/de gestão.
- Features no topo (fund. I/II): proporção de docentes com superior,
  equipamentos por aluno, INSE, tablet por aluno.

## 5. Ambiente de execução e armadilhas operacionais

- **Testes e render rodam SÓ no container `rstudio.dev` (rsuser)** — nunca na
  máquina local (mesma regra dos testes do `edumaps`). Sync via
  `tools/sync-rstudio.sh` (post-commit).
- O enlace do container com o banco (`Database`) é **intermitente**: pulls
  grandes às vezes morrem sem rastro. Mitigação: **snapshot RDS**
  (`analysis/capturar_dados_rf.R` → `dados_classificados_rf.rds`, gitignored);
  quando o arquivo existe, o Rmd pula a coleta ao vivo.
- O treino com a base completa estoura a memória do container (**OOM
  `Killed`**, host ~8 GB; ranger com permutação duplica dados por thread).
  Mitigação: **amostra estratificada de 15 mil escolas por etapa**
  (preserva os terços), `num.threads = 2`, `trees = 250`. Predição, perfil e
  mapa por UF continuam sobre a **base completa**.
- knitr não renderiza ggplot armazenado em listas (`map()`) — usar
  `.map(...) |> lapply(print)`.

## 6. Validação

Suite de testes **verde** no container (unitários + smoke com `EDUBR_SMOKE=1`);
`R CMD check` **0 errors / 0 warnings / 0 notes**. PR #2 do `eduBR` mergido
(`cdd741f`).

## 7. Próximos passos

- `analytics.view_escolas_ml` para uma variante **preditora** (features
  defasadas × nota futura).
- Calibrar/fornecer o ganho marginal do modelo completo vs top-k (curva de
  desempenho × nº de features).
- Explorar `perfil_escola()`/`comparar()` (escola vs média UF/município) com o
  mesmo vetor de features.