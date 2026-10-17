# Nota técnica 143 — #137 fatia D: extração do bloco saúde

Esta nota documenta a **extração R do bloco territorial D (saúde)** do IVET
(#137, entregável 3), no mesmo padrão dos blocos B, E e G. PR **#273** (merge
`d4199f1`, commit `e138161`).

Com D, os blocos territoriais **E, G e D** estão extraídos. **C (mobilidade)**
continua bloqueado (sem isócrona — Tier 2) e o **agregado do IVET permanece
`NA`** enquanto C não existir.

## Contexto

O documento [`ivet.md`](../analises/ivet.md) fixava os blocos, mas a **composição
interna** de D não estava especificada — só a fonte. A fonte documentada era a
**PeNSE (#127)**, que **não está carregada** no banco. A fonte de facto é
[`analytics.acessibilidade_saude`](../analises/fontes/saude.md) (CNES + SISAB/
PMMB), sã desde o PR #271 (correção do filtro de tipos do CNES e da distância em
graus).

Como o IVET é **territorial** (§1: a escola é o ponto de observação), o bloco D
mistura dois grãos: a **distância** é da escola; a **provisão** de atenção básica
é do município.

## O que foi feito

### Bloco D — saúde (`R/ivet-saude.R`)

Fonte `analytics.acessibilidade_saude`, **uma linha por escola** (145.734), com
colunas de dois grãos:

| coluna | grão | semântica |
|---|---|---|
| `dist_min_km_ubs` | escola | distância esférica à UBS mais próxima (km) |
| `n_ubs_municipio` | município | nº de UBS ativas (CNES tipos 1+2) |
| `ativas_ff`, `equipe_esf` | município | equipes de atenção básica |
| `cobertura_aps` | município | ⚠️ **população** do PMMB (pessoas), não % |
| `efetividade_vagas_aps` | município | ocupação das vagas do PMMB (%) |
| `categoria_ivs` | município | categoria de vulnerabilidade **social** do MS |

A **distância** mede "mais = pior" (pior acesso espacial) e entra **direta**; a
**provisão** de atenção básica mede "mais = melhor" e é **invertida** (como a
renda do bloco B e o bloco G):

| componente | bruto (tabela) | normalização | direção |
|---|---|---|---|
| distância à UBS | `dist_min_km_ubs` (km) | `clamp(dist / 5)` | mais longe = + |
| cobertura de APS | `(equipe_esf + ativas_ff) / população × 1e4` | `1 − clamp(x / 8)` | menos equipes = + |
| presença de UBS *(fora do default)* | `n_ubs_municipio / população × 1e4` | `1 − clamp(x / 8)` | menos UBS = + |
| efetividade das vagas (fora do default) | `efetividade_vagas_aps` (%) | `1 − clamp(x / 100)` | menos ocupação = + |

Funções: `ivet_taxa_10k()`, `ivet_componente_distancia()`,
`ivet_componente_cobertura_aps()`, `ivet_componente_presenca_ubs()`,
`ivet_componente_efetividade_aps()`, `ivet_bloco_saude()` e
`ivet_bloco_saude_componentes()`.

O default é `componentes = c("distancia_ubs", "cobertura_aps")`.

**`cobertura_aps` da tabela NÃO é usada.** Apesar do nome, a coluna carrega a
**população** coberta do PMMB (pessoas), não uma fração: o máximo medido foi
≈ 25.421 por 10 mil habitantes — mais de 100% da população do município. A
cobertura usada é a razão de **equipes por 10 mil habitantes**
(`(Σ ativas_ff + equipe_esf) ÷ população × 10.000`), conforme a ficha
[`fontes/saude.md`](../analises/fontes/saude.md).

**Fora do default.** `presenca_ubs` (UBS por 10 mil) tem correlação bruta de
**0,78** com `cobertura_aps` — entram juntas e **duplicariam o sinal** de
provisão. `efetividade_vagas_aps` está **quase saturada** (p50 = 98,8%,
p90 = 100%) e tem direção ambígua. `categoria_ivs` **não entra**: é uma categoria
de vulnerabilidade **social** do Ministério da Saúde — duplicaria o bloco B e não
mede acesso a saúde.

**Ausência ≠ zero (#154).** `dist_min_km_ubs` `NULL` (município sem UBS no CNES)
vira componente `NA`, **fora do denominador**. Já `n_ubs_municipio = 0` é
**zero real** (município sem UBS) e vira componente `1` — vulnerabilidade máxima.

**Denominador populacional.** `clean.populacao_municipal` (snapshot, 5.571
municípios), o mesmo do bloco E: a população por ano não existe no banco
(`clean.v_ibge_municipio_ano.populacao` está 100% `NULL`).

## Medições (dev `database.edumaps`, 2026-10-17)

Fonte `analytics.acessibilidade_saude`, 145.734 escolas:

| bruto | p50 | p90 | p99 | máx |
|---|---|---|---|---|
| distância à UBS (km, escola) | 0,54 | 7,25 | 38,8 | 575,4 |
| UBS por 10 mil hab (município) | 4,48 | 8,45 | 15,5 | 34,3 |
| equipes de APS por 10 mil hab (município) | 3,30 | 8,39 | 12,4 | 21,9 |
| efetividade das vagas do PMMB (%) | 98,8 | 100 | 100 | 100 |

Classificação de acesso da view: excelente (<1 km) 102.972 · bom (1–3 km) 17.454
· regular (3–5 km) 5.797 · difícil (>5 km) 19.500 · sem UBS no município 11.

Os tetos foram calibrados pelo **p90** (e pela classificação da própria view, no
caso da distância — 5 km é o limiar "acesso difícil") e são **parâmetros de
produto**: mudá-los exige registro e nova versão da fórmula.

## Decisões de desenho

- **Dois grãos no mesmo bloco** — a distância é da escola (ponto de observação),
  a provisão é municipal (território). É legítimo no IVET territorial (§1) e o
  bloco capta as duas faces do acesso: local e territorial.
- **Um só componente de provisão no default** — `presenca_ubs` × `cobertura_aps`
  correlacionam 0,78; incluir as duas duplicaria o sinal. Escolheu-se a razão de
  **equipes** (o indicador documentado na ficha de saúde).
- **Distância entra direta; provisão é invertida** — direção única do IVET
  ("maior = mais vulnerável").
- **`categoria_ivs` fora** — vulnerabilidade social já é o bloco B; saúde mede
  acesso/oferta.
- **Fórmula `ivet-v1.2` inalterada** — o slot D já existia, os pesos continuam
  iguais e o `NA` já fica fora do denominador; nenhuma versão nova era necessária.

## Validação

| Checagem | Resultado |
|---|---|
| Testes `ivet` (R puro + contrato do card) | **270 PASS, 0 FAIL** |
| Suíte R completa | **1876 PASS**; 2 falhas **pré-existentes** (`censo-dictionary`, `cluster`) |
| Card YAML parseia e bate com o código (`bloco_d`) | ok |
| Deploy `rex prepare` + `deploy_analytics_dev` | ok (serviço reiniciado) |
| Imagem local `analytic` reconstruída + funções verificadas no contentor | ok |

## Pendências

- **C (mobilidade)** segue bloqueado (Tier 2 / isócrona): o IVET agregado
  continua **`NA`** enquanto C não existir (mínimos = C+D+E).
- **Bloco F (meio ambiente)** — adiado; só há proxy de cobertura do solo (#255).
- **População por ano** não existe no banco (denominador de D/E é o snapshot).
- Backlog: #137 → #255 → #168 → **#138** → **#139** (#268 adiada).
