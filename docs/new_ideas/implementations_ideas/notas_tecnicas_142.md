# Nota técnica 142 — #137 fatia E/G: extração dos blocos segurança e recursos

Esta nota documenta a **extração R dos blocos territoriais E (segurança) e G
(recursos)** do IVET (#137, entregável 3), no mesmo padrão do bloco B. PR
**#272** (merge `2cb95c0`, commit `c5109a8`).

Foi decidido **adiar F** (meio ambiente): a única fonte carregada
(`clean.mapbiomas_cobertura`) é **cobertura do solo**, não a "exposição a risco"
do §4.2 — essa depende de #241/#255. **C (mobilidade)** e **D (saúde)** seguem
pendentes; o agregado do IVET permanece `NA`.

## Contexto

O documento [`ivet.md`](../analises/ivet.md) fixa os blocos do índice, mas a
**composição interna** de E/F/G não estava especificada — só a **fonte** de cada
um. Antes de escrever código, a fórmula foi alinhada com o developer (o alvo é
decisão de produto). Ficou: **E + G neste PR**, F adiado.

Como o IVET é **territorial** (§1: a escola é o ponto de observação), E e G são
atributos **municipais** que entram por junção no município da escola. O grão
fino (por escola) é a #255.

## O que foi feito

### Bloco E — segurança (`R/ivet-seguranca.R`)

Fonte `clean.brazilcrime_municipio` (SINESP via pacote R BrazilCrime; #126),
município × ano. Componente = **taxa por 100 mil habitantes**, normalizada por um
teto documentado:

| componente | bruto | normalização |
|---|---|---|
| homicídio doloso | `homicidio_doloso` | `clamp(taxa / 50)` |
| latrocínio | `latrocinio` | `clamp(taxa / 5)` |
| lesão corporal seguida de morte | `lesao_corporal_seguida_de_morte` | `clamp(taxa / 5)` |

Funções: `ivet_taxa_100k()`, `ivet_componente_taxa()`, `ivet_componente_crime()`,
`ivet_bloco_seguranca()` e `ivet_bloco_seguranca_componentes()`.

**Ausência ≠ zero (#154).** A fonte **suprime células pequenas** (valores 1..4
são ocultados; `supressao_celula_pequena`). A contagem ocultada vira `NA` — é
**ausência**, e o componente sai do denominador da dimensão. Uma contagem `0`
publicada é `0` real ("nenhum crime registrado"), e é isso que mantém os dois
estados distintos. Na tabela, a supressão já vem como `NULL` na coluna de
contagem; `ivet_taxa_100k(..., suprimido = TRUE)` permite forçar o `NA` quando o
chamador tem o sinal por célula.

### Bloco G — recursos (`R/ivet-recursos.R`)

Fonte `analytics.esforco_fiscal_educacao` (SIOPE/SICONFI; catálogo #123),
município × exercício. Indicadores de recurso medem "quanto maior, melhor", logo
são **invertidos** para a direção do IVET (`1 − clamp(valor / teto)`, como a
renda do bloco B):

| componente | bruto | normalização |
|---|---|---|
| FUNDEB por aluno | `fundeb_por_aluno` | `1 − clamp(x / 10000)` |
| despesa em educação por aluno | `despesa_educ_por_aluno` | `1 − clamp(x / 15000)` |
| autonomia fiscal | `autonomia_fiscal_pct` | `1 − clamp(x / 50)` |

Funções: `ivet_componente_investimento()`, `ivet_bloco_recursos()` e
`ivet_bloco_recursos_componentes()`.

**`pct_receita_em_educ` é excluído**: a coluna está **corrompida** na origem
(valores fora de `[0,100]` — achado da medição no dev a 2026-10-17). Fica
registrado em `nao_usados` no card.

### Card e testes

- `inst/ivet-card.yml` ganhou `bloco_e`/`bloco_g` (componentes, tetos, unidade,
  `nao_usados`) e a lista de validação; `test-ivet-card.R` ganhou o contrato
  (card × código).
- `tests/testthat/test-ivet-seguranca.R` e `test-ivet-recursos.R` cobrem a
  matemática, o `NA` (#154) e os tetos como parâmetro.

## Medições (dev `database.edumaps`, 2026-10-17)

**E** — taxa/100 mil, média municipal 2021–2023, em 5.570 municípios (4.523 com
≥1 ano suprimido):

| evento | p50 | p90 | p99 | máx |
|---|---|---|---|---|
| homicídio doloso | 0,0 | 46,3 | 103,5 | 3501,7 |
| latrocínio | 0,0 | 0,0 | — | 27,1 |
| lesão seguida de morte | 0,0 | 0,0 | — | 92,9 |

**G** — `analytics.esforco_fiscal_educacao` (5.525 municípios):

| indicador | p50 | p90 | máx |
|---|---|---|---|
| FUNDEB por aluno (R$) | 5.651 | 9.336 | 16.370 |
| despesa educ. por aluno (R$) | 9.848 | 14.521 | 50.710 |
| autonomia fiscal (%) | 13,2 | 30,9 | 100 |

Os tetos foram calibrados pelo **p90 municipal** e são **parâmetros de produto**
(como `IVET_TETO_RENDA`): mudá-los exige registro e nova versão da fórmula.

**Achado de dado:** **não existe população por ano**.
`clean.v_ibge_municipio_ano.populacao` está **100% `NULL`** (a nota anterior, que
dizia "2014–2023", estava errada). O denominador do bloco E é
`clean.populacao_municipal` (snapshot, 5.571 municípios), documentado; a série
anual é pendência.

## Decisões de desenho

- **Taxa, não contagem crua** (§4.1): a contagem absoluta favoreceria municípios
  grandes e é o defeito do `iqd` no sistema C. A taxa entra normalizada por teto.
- **Supressão no dado, não heurística em R**: a célula ocultada já chega como
  `NULL`; a camada R preserva o `NA` em vez de o transformar em 0 (#154).
- **F adiado**: um proxy de cobertura do solo não responde à pergunta do bloco
  (exposição a risco ambiental); é melhor não medir do que medir outra coisa.
- **Fórmula `ivet-v1.2` inalterada**: os slots de E/G já existiam, os pesos
  continuam iguais e o `NA` já fica fora do denominador — nenhuma versão nova era
  necessária.

## Validação

| Checagem | Resultado |
|---|---|
| Testes `ivet` (R puro + contrato do card) | **216 PASS, 0 FAIL** |
| Suíte R completa | **1822 PASS**; 2 falhas **pré-existentes** (`censo-dictionary`, `cluster`) |
| Card YAML parseia e bate com o código | ok |
| Deploy `rex prepare` + `deploy_analytics_dev` | ok (serviço reiniciado) |
| Imagem local `analytic` reconstruída + verificação das funções | ok |

## Pendências

- **Extração R do bloco D (saúde)** — a fonte (`analytics.acessibilidade_saude`)
  está sã desde o PR #271; PR à parte.
- **Bloco F (meio ambiente)** — adiado; só há proxy de cobertura do solo.
- **C (mobilidade)** segue bloqueado (Tier 2 / isócrona): o IVET agregado
  continua **`NA`** enquanto C não existir.
- **População por ano** não existe no banco (denominador de E é o snapshot).
- Backlog: #137 → #255 → #168 → **#138** → **#139** (#268 adiada).
