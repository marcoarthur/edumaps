# Nota técnica 152 — A primeira medição do IVET `v1.2` nacional

O IVET tem fórmula versionada, card contratual e sete blocos extraídos — mas
nunca havia sido **medido no país inteiro**. Esta nota fecha o **entregável 3 do
#137** nessa parte: um harness que mede o `ivet-v1.2` sobre as ~180 mil escolas
do Censo Escolar, **sem materializar o índice no banco**, e reporta o primeiro
número nacional.

Issues de contexto: **#137** (IVET como produto versionado), **#278** (bloco F,
cobertura nacional em curso), **#154** (ausência ≠ 0), **#135** (pin `raw`).

## Entregas

| PR / commit | Merge | Escopo |
|---|---|---|
| **#286** | `c9ee810` | `feat(analytics)`: harness `R/ivet-nacional.R`, CLI `inst/scripts/medir-ivet-nacional.R`, 50 testes, docs `ivet.md` §4.8 |

## 1. O harness, em duas camadas

A decisão de projeto é antiga e não mudou: **o IVET não é materializado no
banco** (`with_vulnerability_score` segue `die` — `ivet.md` §3). O índice é um
**cálculo**, não uma tabela. Logo a medição nacional não é um `REFRESH`, é uma
consulta + uma função pura.

Daí a separação de `R/ivet-nacional.R`:

- **`ivet_painel(dados)`** — pura, sem banco. Recebe um `data.frame` (1
  linha/escola) com as colunas brutas e devolve `bloco_A`..`bloco_G`, `ivet` e
  `publicavel`. Coluna ausente vira `NA`. É a única parte que precisa de teste,
  e é testável sem serviço nenhum (50 asserções).
- **`ivet_medir_nacional()`** — abre `analytics_db_connection()`, roda o SQL de
  extração (`ivet_sql_escolas()`) e chama `ivet_painel()`. Não escreve nada.

A semântica de agregação é a do núcleo (`ivet_v1()`): bloco `NA` cai fora do
**numerador e do denominador** (#154), e o `ivet` sai `NA` enquanto faltar algum
bloco territorial mínimo (C+D+E — `ivet_blocos_territoriais_minimos()`). O
atributo `formula` carimba a versão, e uma asserção do teste compara
`ivet_painel()` com `ivet_v1()` para travar *drift* entre as duas implementações.

## 2. O SQL e três armadilhas do schema

A extração é uma espinha (`clean.censo_escolas`, `tp_situacao_funcionamento=1`)
com `LEFT JOIN` de uma subconsulta por bloco. Três coisas custaram tempo:

1. **`codigo_ibge` tem três tipos diferentes**: `integer` em mobilidade e
   acessibilidade, `text` em crime e esforço fiscal, `varchar` em população. A
   junção por município exige *cast* explícito para texto.
2. **`clean.mv_escolas_scores` é materialized view**: não aparece em
   `information_schema.tables`/`.columns`. Soube-se que ela existia por
   `pg_class`/`pg_attribute`, não pelo catálogo padrão.
3. **A espinha não tem `codigo_ibge`** — ela tem `co_municipio`, que é
   convertido. E o grão de E/G/C/D é o **município**, replicado para cada escola
   dele.

Safras ficam explícitas: `censo_ano` = 2025 (A/B/F), `crime_anos` = 2021–2023
(média), G = último exercício (`DISTINCT ON … exercicio DESC`), `raio_m` = 1000
(B e F). Os anos de crime entram como inteiros validados num `IN (...)`; os
demais são parâmetros vinculados (`$1`/`$2`).

## 3. A medição (censo 2025, raio 1.000 m)

| | |
|---|---|
| escolas (espinha) | 180.540 |
| publicáveis (C+D+E) | **145.732 (80,7%)** |
| cobertura A · B · C · D · E · G | 180.540 · 145.718 · 145.734 · 145.734 · 180.533 · 177.397 |
| cobertura F | **46.923** *(parcial)* |
| `ivet` p25 · p50 · p75 | 0,305 · **0,339** · 0,376 |
| `ivet` p90 · máx | 0,418 · 0,634 |

## 4. O que os números dizem

- **A distribuição é estreita** (p25–p75 ≈ 0,30–0,38), e isso é um artefato do
  **gate de publicação**, não do país: o `ivet` só existe quando C, D e E estão
  presentes, e esses três são justamente os blocos de cobertura quase total
  (145.7 mil). A cauda que os blocos com cobertura menor (B, F, G) produziriam
  fica de fora do denominador. **Medir o IVET sobre os publicáveis e medir a
  cobertura são duas perguntas diferentes** — o resumo responde às duas.
- **A espinha é maior que os blocos.** O Censo 2025 tem 180.540 escolas em
  atividade; C e D cobrem 145.734. A diferença (~35 mil) é escola **sem
  território calculado** (fora da área de influência / sem dado no município).
  Elas aparecem no painel com `ivet = NA` — que é o comportamento correto (#154),
  e é o número que a cobertura expõe.
- **F é a variável de folga.** Com ~5 UFs cobertas (SP/MG/RJ/BA + RS em curso),
  só 46.923 escolas têm meio ambiente. É a razão de os números **não** serem a
  medição final.

## 5. Pendências

- **Calibrar os tetos do F** (fogo = 1, carbono = 500 — provisórios) quando a
  corrida nacional fechar (21 UFs restantes) → nova versão da fórmula.
- **Bloco C**: a isócrona (`clean.isocrona_escolar`) segue **vazia** — falta um
  motor de roteamento (OSRM/Valhalla); C é proxy de exposição viária.
- A distribuição nacional sugere revisitar, **depois do F completo**, se o gate
  C+D+E é a régua certa de publicação ou se vale publicar com cobertura parcial
  anotada.
