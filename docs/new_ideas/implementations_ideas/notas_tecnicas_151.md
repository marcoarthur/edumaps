# Nota técnica 151 — Bloco F do IVET: componentes, tetos provisórios e o lastro que faltava

Esta nota fecha o ciclo iniciado no **lastro dos tetos** do IVET (§5) e conclui
**duas filas** de revisão de [`ivet-coeficientes.md`](../../analises/ivet-coeficientes.md):
a **fila 1** (lastro do proxy de C) e a **fila 5** (bloco F — meio ambiente).
Uma pergunta guiou o ciclo: *o IVET mede coisas que a literatura reconhece, ou
mede coisas que só o projeto inventou?* Para C e F, a resposta passou a ser a
primeira — com ressalvas registradas.

Issues de contexto: **#278** (bloco F), **#255** (cobertura do solo), **#137**
(IVET como produto versionado), **#268** (entorno, em curso).

## Entregas

| PR / commit | Merge | Escopo |
|---|---|---|
| (direto) `3b8b2ff` | — | `docs`: lastro **externo** do proxy do bloco C (`ivet-coeficientes.md` §2/§5/§5.1/§7.2, `ivet.md` §4.5.5) |
| **#285** | `f0ceda1` | `feat(analytics)`: **bloco F** — 3 componentes, card `bloco_f`, testes e docs |

## 1. Fila 1 — o proxy de C ganhou lastro externo

A ficha do bloco C dizia "**sem lastro na literatura do acervo**". Buscado fora,
o construto é **padrão**: medir *exposição viária* por **veículos registados** é
o que a OMS faz (WHO GHO, *registered vehicles*, IMRID 194) e o que a **GSRRS
2023** publica (mortalidade **por 100 mil habitantes e por 100 mil veículos**).
O **ITF/IRTAD** (*Road Safety Annual Report 2024*, Fig. 7) vai além: lista
**frota** e **população** sob ***exposure data*** e publica as mortes **por
10.000 veículos registados**. Logo `exposicao_frota` (veíc/hab) mede **exposição**
consagrada e `risco_sinistros` usa a forma-padrão da taxa.

⚠️ **Ressalva honesta**: a literatura mede **mortes** (*fatalities*); a RENAEST
mede **sinistros** (acidentes) — um *superset* de morbidade, mais sensível e
**não** comparável 1:1 às taxas internacionais. Registrado na ficha e na §5.1.

Os **tetos** de C (500 sinistros; 1 veíc/hab) continuam **empíricos** (≈ p90) —
lastro é do **construto**, não do número.

## 2. Fila 5 — o bloco F, enfim definido

O F tinha **duas metades extraídas** mas **nenhum componente na fórmula**: o card
`ivet-card.yml` não tinha `bloco_f` e não havia R do F. Definido agora, com **peso
igual** entre os disponíveis:

| componente | fonte | normalização | direção |
|---|---|---|---|
| `risco_fogo` | MapBiomas Fogo (`fogo_frequencia_media`) | `clamp(freq/teto)` | **+** (mais fogo = pior) |
| `vegetacao_natural` | Coleção 11 (`v_mapbiomas_escola_grupos.fracao`) | `1 − clamp(fracao)` | **invertida** (mais = melhor) |
| `carbono_solo` | MapBiomas Carbono (`solo_carbono_medio`) | `1 − clamp(carbono/teto)` | **invertido** |

Peso igual dentro da dimensão é o **default reprodutível** (§3, Z:10456) — nada
justifica ponderação desigual, então **não** sobe a versão da fórmula
(`ivet-v1.2` já declarava o bloco). O efeito é de **transformação**, não de
fórmula: onde F passa a ter valor, ele entra na média das dimensões disponíveis.

**Código**: `analysis/edumapsr/R/ivet-meio-ambiente.R`
(`ivet_componente_risco_fogo`, `ivet_componente_vegetacao_natural`,
`ivet_componente_carbono_solo`, `ivet_bloco_meio_ambiente_componentes`,
`ivet_bloco_meio_ambiente`), testes em `test-ivet-meio-ambiente.R`, contrato no
card (`bloco_f`) e teste em `test-ivet-card.R`.

## 3. Os dois lastros do F — e o que eles não são

- **Fogo × criança na escola.** A fumaça de incêndio é risco respiratório
  documentado para crianças: o **CDC** (2021, *Health Effects of Wildfire Smoke
  in Children*) revisa os efeitos e trata do **ambiente escolar**; o **EPA**
  (2018) orienta a proteção da criança; e o estudo das queimadas do sul da
  Califórnia (2003) mediu **dias de aula perdidos** (*missed school*).
- **Cobertura + solos.** Os **índices brasileiros de vulnerabilidade/fragilidade
  ambiental** (Ross, 1994; a família AHP) combinam **uso e cobertura da terra**
  com **solos** — e apontam a cobertura da terra como variável de **influência
  predominante**.

⚠️ Em ambos, o lastro é de **construto**, **não de coeficiente**: os tetos são
**calibração empírica**. O acervo do projeto **não** tem literatura de meio
ambiente (nem de trânsito) — a árvore da coleção EduMaps é só de educação/índice.

## 4. Tetos provisórios e os caveats de dado

Medido em `edumaps_dev` (SP, ano 2020, raio 1 km): **fogo** p50 = 0,005,
p90 = 0,117, p99 = 0,563 (máx 14,4); **carbono** p50 = 180, p90 = 462, p99 = 791.
Tetos **provisórios**: fogo = **1**, carbono = **500** — a recalibrar com a
corrida nacional do F (#278).

Três caveats ficam registrados:

1. **Amostras disjuntas.** As duas metades do F cobrem escolas **diferentes**:
   fogo/carbono em **SP/MG** (23.292 escolas, ano 2020), cobertura do solo no
   **ES** (3.156 escolas, ano 2024). Não há interseção hoje. Isso **não** quebra o
   bloco — cada componente ausente cai fora do denominador (#154) e F degrada
   para **fogo+solo** onde a vegetação não existe.
2. **Carbono negativo.** O bruto tem mínimo **−169,7** tC/ha (76 linhas, 0,3%) —
   artefato de *nodata* fisicamente impossível; a inversão o satura em 1
   (pior caso). A extração deveria transformá-lo em `NULL`.
3. **Viés de bioma.** O carbono do solo varia naturalmente (Amazônia × Caatinga);
   um teto único penaliza solos naturalmente pobres. Decisão de produto — o
   número nacional vai expor a magnitude.

## 5. Lições

- **Ausência de lastro ≠ ausência de construto.** O C e o F pareciam arbitrários
  só porque o **acervo** não tinha a literatura — ela existe, mas **fora**
  (OMS/IRTAD; CDC/EPA/Ross).
- **`docs/funcionalidades/` não mudou**, e é correto: a capacidade (usar MapBiomas
  Fogo/Solo/cobertura) já estava documentada em `fontes-de-dados.md` desde a
  extração. O que mudou é a **fórmula**, que vive em `docs/analises/`. O aviso do
  pre-commit é falso-positivo neste caso.
- **Degradação graciosa por `NA`** (#154) pagou dividendo: o F entra onde há dado
  e desaparece onde não há, sem número falso — exatamente o que permite definir o
  bloco com metade da cobertura ainda parcial.
