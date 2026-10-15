# Área de influência da escola — metodologia (proposta)

> **Issues**: **#255** (MapBiomas por escola) — e é **gate** de **#137**
> (blocos B–F / entregável 3).
> **Data**: 2026-10-15 · **Versão da metodologia**: `influencia-v1`.
> **Estado**: **DECIDIDA** (2026-10-15, developer) — abordagem **híbrida
> Tier 0–3** com os *defaults* do §4. **Implementável.**

## 0. Resumo

O IVET é um índice **territorial** (`docs/analises/ivet.md` §1): os coeficientes
descrevem o **entorno** da escola, e a escola é o *ponto de observação*. As
fontes que alimentam os blocos **B–F** são todas medidas "na área de influência
da escola" — mas essa área **nunca foi definida**.

Hoje o dado territorial entra no grão **município** e é repassado **uniforme** a
todas as escolas do município — "a maior simplificação atual do IVET"
(`fontes/socioeconomico.md`). Só o OSM tem recorte por escola, num **buffer de
500 m** fixo e pontual (`fontes/mobilidade.md`).

Esta proposta define **uma** metodologia, com uma geometria-base determinística e
*upgrades* por dimensão, compatível com a reprodutibilidade do **#135/#137** e com
a **LGPD**.

**Recomendação**: abordagem **híbrida em camadas** (`Tier 0–3`) — **buffer de
raio documentado** como base canônica, **isócrona** para o bloco de mobilidade e
**setor censitário** como unidade da arealização socioeconômica.

---

## 1. O problema

Sem uma área de influência canônica, três coisas ficam travadas:

1. **#255** — a cobertura do solo (MapBiomas 30 m) e os produtos de risco
   climático precisam de **geometria por escola** para o *zonal statistics*; a
   estatística oficial (município) não recorta por buffer.
2. **#137 (blocos B–F / entregável 3)** — a extração dos componentes
   territoriais é a outra metade do "pipeline reprodutível": o núcleo da fórmula
   já existe (`analysis/edumapsr/R/ivet.R`), mas sem a geometria não há como
   puxar o componente de B–F.
3. **Arealização** — todo indicador abaixo do município (setor censitário, IVS,
   densidade) precisa da mesma geometria para ser "arealizado" ao entorno.

E há um risco de produto no caminho oposto: escolher uma geometria **errada**
(nem reprodutível, nem LGPD-segura) contamina **todos** os coeficientes
territoriais de uma vez — é uma decisão de alto impacto e difícil de reverter.

---

## 2. As opções

| # | Geometria | Como se calcula | Prós | Contras |
|---|-----------|-----------------|------|---------|
| **A** | **Buffer euclidiano** (raio fixo) | `ST_Buffer(escola, R)` | determinística, barata, reprodutível, sem dependência externa | ignora barreiras (rio/ferrovia/rodovia); o raio é arbitrário; **superestima** o alcance |
| **B** | **Setor censitário** | setor(es) que contêm/intersectam a escola | casa 1:1 com o dado IBGE; arealização trivial | o setor varia muito (urbano × rural); **não é "alcance"** — é unidade estatística |
| **C** | **Isócrona** (rede viária) | OSRM/Valhalla, a pé 15/30/45 min | **alcance real**; "o elo exato" entre malha OSM e malha censitária | exige **roteador auto-hospedado**; *snapshot* sem atualização contratual; mais caro |
| **D** | **Híbrida por camada** | base = A; mobilidade = C; socioeconômico = B | melhor de cada; degrada com elegância (sem rede → buffer) | mais regras a documentar |

### Por que não uma só

- **Só buffer** (A) é o mais barato e reprodutível, mas trata o entorno como
  disco isotrópico — inaceitável justamente para **mobilidade**, onde a barreira
  é o fenômeno (a isócrona foi desenhada para isso).
- **Só setor** (B) confunde *unidade de dado* com *área de influência*: o setor
  do Censo não expressa "a que distância a escola serve".
- **Só isócrona** (C) é o ideal teórico, mas cria **ponto único de falha**
  (roteador comunitário) e não serve para os indicadores de pixel/raster.

---

## 3. Evidência

### 3.1 Interna (o acervo do projeto)

- **Isócrona** — "o indicador mais **defensável** de alcance real do aluno";
  "o **elo exato** entre a malha do OSM e a malha censitária do IBGE"; prioridade
  `[alta]` 13 pts (`fontes/mobilidade.md` §Roteadores abertos).
  ⚠️ as instâncias OSRM/Valhalla verificadas são **demo, sem SLA** →
  recomendação explícita de **auto-hospedar** o roteador.
- **Buffer 500 m** — já usado, "sob demanda", para a completude da malha viária
  (`fontes/mobilidade.md`); e projetado para `frequencia_queimada_no_raio_500m`
  (`fontes/meio-ambiente.md`).
- **Setor censitário** — a única fonte com resolução **abaixo do município**
  (316.574 setores); habilita "o setor da escola está em qual classe de
  vulnerabilidade?"; a malha é **habilitadora** de toda a arealização
  (`fontes/socioeconomico.md`).
- **Malha OSM × IBGE** — "o setor dá a área, o OSM dá as vias e serviços"
  (`fontes/socioeconomico.md`).
- **LGPD** — derivar buffers por escola é **identificador de localização de
  menores** quando a escola atende poucos alunos; **agregar buffers**; isócrona
  deve ser **agregada em grade de 1 km** antes de exibir
  (`fontes/mobilidade.md`); setor censitário exige *geo-masking*/k-anonimato
  (`fontes/socioeconomico.md`).
- **#255** — "definir a geometria (buffer? setor? raio 500 m/1 km?) — **mesma
  metodologia do IVET**"; exige `sf`/`terra` + GDAL no `analytic`.

### 3.2 Externa (prática consolidada — ponteiros, não leitura profunda)

- A comparação **buffer × isócrona** é um *trade-off* conhecido: o buffer é
  simples e determinístico; a isócrona segue a rede real, é menor, mais
  irregular e **sensível a mudanças de conectividade e barreiras**
  ([AINO](https://www.aino.world/blog/demographic-data-for-real-estate),
  [Kolcsár 2021](https://www.sciencedirect.com/science/article/pii/S1618866720307597)).
- Para demografia, o padrão é **areal interpolation**: usar os setores/blocos
  censitários como zona intermediária e ponderar a área/buffer/isócrona
  ([Walker Data](https://walker-data.com/census-r/spatial-analysis-with-us-census-data.html),
  [Liu 2019](https://www.mdpi.com/2220-9964/8/7/302)).
- Modelos de *catchment* escolar combinados com geoestatística são o estado da
  arte para incerteza espacial
  ([Macharia 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC7613137/)).

> ⚠️ Os ponteiros externos acima são **contexto de prática**, sem o mesmo rastro
> de verificação das fontes internas. Se a decisão for por `influencia-v1`,
> vale registrar as referências no Zotero (coleção `EduMaps`) — é a direção
> `[baixa]` da **#139**, e o mesmo lastro que falta aos coeficientes.

---

## 4. Recomendação — `influencia-v1` (híbrida em camadas)

Uma geometria-base **determinística** + dois *upgrades* onde o fenômeno exige.

### Tier 0 — Ponto (coordenada da escola)

Para o que é **atributo do pixel** onde a escola está: `declividade_terreno_escola`,
`risco_hidrico_escola` (classe ISH do pixel), `ilha_de_calor_urbana`. Não é
"área"; é o ponto. Zero ambiguidade.

### Tier 1 — Buffer de raio documentado (base canônica)

`geom = ST_Buffer(escola, R)`, com **`R` documentado por indicador**:

| Fenômeno | Raio default | Racional |
|----------|--------------|----------|
| feições pontuais/linhas locais (OSM: vias, equipamentos) | **500 m** | já é o recorte atual; caminhável |
| uso/cobertura do solo, densidade, exposição (MapBiomas) | **1 km** | fenômeno de área; 30 m × 1 km é tratável |
| queimada/chuva (INMET, MapBiomas fogo) | **1–2 km** | escala do fenômeno |

Determinístico, sem router, reprodutível (mesma entrada → mesma saída) — é o que
fecha o entregável 3 sem criar dependência externa.

### Tier 2 — Isócrona de rede (upgrade da mobilidade)

**Bloco C** usa **isócrona** (a pé **15 min**; transporte **45 min**) via
**OSRM/Valhalla auto-hospedado** — a recomendação de arquitetura da própria
fonte, que elimina o SLA de servidores comunitários. O **buffer (Tier 1) é o
fallback** quando não há rede/roteador. A isócrona de 15 min é o indicador de
"alcance real" e a ponte para a população alcançável.

### Tier 3 — Setor censitário (unidade da arealização)

O dado socioeconômico (bloco B) chega por **setor** (Censo 2022) ou por
município. A área de influência (Tier 1/2) é **intersectada** com os setores e o
valor é **interpolado**:

```
componente_escola = Σ_setor ( valor_setor × peso(área_intersecção) ) / Σ peso
```

com `peso = área` (padrão) ou **população** (quando houver risco de viés em
setor gigante rural). O setor é a **unidade do dado**, não a geometria.

### Guarda LGPD (transversal, obrigatória)

- **Nunca** publicar/usar como feature a **geometria por escola** de baixo N
  (identificador de menores).
- Agregar antes de **expor**: grid de **1 km** (isócrona) / setores vizinhos
  (ZOT) ou k-anonimato (setor).
- Tratar **"suprimido" ≠ 0** (o IBGE suprime células pequenas — `#154` e
  `fontes/socioeconomico.md`).

---

## 5. Como isso se calcula (esboço)

1. **Geometria** — materializar em `clean.escola_influencia(escola_id, tier,
   raio_km, geom, versao)` (buffer) e, quando houver rede, `..._isocrona(...)`.
   É a "camada reusável" que a **#255** pede.
2. **Arealização** — `ST_Intersection` com os setores / zonal statistics
   (`ST_SummaryStats`/`terra`) do raster de 30 m contra a geometria.
3. **Componente** — o valor entra na fórmula `ivet-v1.0` pelo passo de
   normalização já implementado (`analysis/edumapsr/R/ivet.R` → `ivet_normalizar`).
4. **Versão** — a metodologia carrega `influencia-v1` no resultado, ao lado de
   `dataset_version` (#135) e `formula` (`ivet-v1.0`) — mesma disciplina de
   proveniência.

---

## 6. Impacto

| Item | Efeito |
|------|--------|
| **#255** | desbloqueia: define a geometria que o *zonal statistics* do MapBiomas 30 m consome |
| **#137** blocos B–F / entregável 3 | desbloqueia a **extração dos componentes** (metade que falta do pipeline) |
| **#137** entregável 4/5 | seguem a geometria (vigência/re-treino e card do modelo) |
| **`ivet-v1.0`** | os pesos da fórmula **não mudam**; muda *de onde vem o componente* |
| **Custo** | Tier 1 é barato (PostGIS puro); Tier 2 exige container do roteador + `sf`/`terra` no `analytic` |

---

## 7. Decisões tomadas (2026-10-15, developer)

| # | Pergunta | Decisão |
|---|----------|---------|
| 1 | Abordagem | **híbrida Tier 0–3** (`influencia-v1`) — não uma geometria única |
| 2 | Raio do buffer | **defaults do §4** — 500 m (feições locais), 1 km (uso do solo), 1–2 km (fogo/chuva) |
| 3 | Isócrona | **a pé 15 min + transporte 45 min**, OSRM/Valhalla **auto-hospedado** (buffer como *fallback*) |
| 4 | Arealização | ponderada por **área** (população como refino quando houver viés de setor) |
| 5 | LGPD | **agregar antes de expor** (grid 1 km / ZOT / k-anonimato); limiar exato a calibrar na implementação |

A decisão **não** altera a fórmula `ivet-v1.0` (nem os pesos) — altera **de onde
vem o componente** territorial. Ver §6 (impacto).

**Próximo passo de implementação (Tier 1, o mais barato):** materializar a
camada reusável `clean.escola_influencia(escola_id, tier, raio_km, geom,
versao)` via PostGIS — é o pré-requisito da arealização (#255 e blocos B–F).

---

## 8. Referências

- `docs/analises/ivet.md` §1 (leitura territorial), §4.2 (blocos A–G), §6 (gate).
- `docs/analises/fontes/mobilidade.md` — isócrona/OSRM/Valhalla, buffer 500 m, LGPD.
- `docs/analises/fontes/socioeconomico.md` — setor censitário, arealização, LGPD.
- `docs/analises/fontes/meio-ambiente.md` — MapBiomas 30 m, `frequencia_queimada_no_raio_500m`.
- `docs/specs/2026-10-13-ingestao-real-plano.md` §8 — decisão do grão município (#241).
- Issue **#255** · **#137** · **#125/#126/#127** (dimensões novas) · **#241** · **#154** (semântica `NULL`).
- Externas: AINO, Kolcsár 2021, Walker Data, Liu 2019, Macharia 2022 (ver §3.2).
