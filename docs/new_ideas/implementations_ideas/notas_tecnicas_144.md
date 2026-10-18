# Nota técnica 144 — #255: uso do solo na área de influência da escola

Esta nota documenta a **arealização do raster de cobertura do solo de 30 m do
MapBiomas (Coleção 11)** sobre a área de influência da escola — o primeiro
pedaço do bloco **F (meio ambiente)** do IVET. PR **#274** (branch
`feat/analytics-mapbiomas-escola`, commits `5b1ae42` e `192485f`).

Com esta entrega, o bloco **F** deixa de ter só o *proxy municipal*
(`clean.mapbiomas_cobertura`, Coleção 10) e passa a ter **cobertura do solo por
escola**. **A exposição a risco** (ISH, declividade, queimada) e **C
(mobilidade)** continuam pendentes — o **agregado do IVET permanece `NA`**.

## Contexto

A #255 tinha cinco entregáveis; dois já estavam atendidos (fonte pinada;
geometria em `clean.escola_influencia`, PR #260). Faltavam a **arealização**
(3), os **indicadores** (4) e as **dependências `sf`/`terra` + GDAL** (5).

A decisão de produto de 2026-10-17 (spec §8) já havia separado a **estatística
municipal** (Coleção 10, job `MapBiomas`) do **raster por escola** (Coleção 11,
esta change). O raster **não cabe** no banco: ~22 GB/ano descomprimido contra
~5,5 GB livres na base do produto. Logo, a arealização tem de **ler o COG em
*streaming*** no host de ingestão e gravar só as frações.

### Decisões alinhadas com o developer (2026-10-17)

1. **Orquestração**: `backend.edumaps` + **Job Minion** — o host que já tem
   GDAL 3.6.2 (`gdal-bin`, #238) e onde o Rex instala as dependências.
2. **Recorte do 1º ciclo**: **piloto 1 UF (ES), 2024, raio 1 km**; escala
   nacional e demais raios nos ciclos seguintes.
3. **Saída**: **fração por classe-folha** + **view de grupos** (reagrupar sem
   reprocessar o raster).

## O que foi feito

### Fonte (pinada)

```
https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/
  collection11/lulc/coverage/brazil_coverage/brazil_coverage-col11_<ANO>.tif
```

Coleção **11**, **1985–2025**, ~748 MB/ano, EPSG:4326, 30 m, categórico
(código da legenda), **CC BY 4.0**, sem token. O `ano` é validado no intervalo
(`1985..2025`) e o caminho **nunca** é montado com texto do usuário — a URL sai
de um `sprintf` com o ano inteiro validado. O host `storage.googleapis.com` já
estava no allowlist (`mapbiomas_cog`, prefixo `/mapbiomas-public/initiatives/brasil`).

### Migration `mapbiomas_escola`

- `clean.mapbiomas_escola(co_entidade, nu_ano_censo, ano, raio_m, classe,
  classe_desc, fracao, colecao, versao, computado_em)`, PK `(co_entidade,
  nu_ano_censo, ano, raio_m, classe)`, `fracao NUMERIC(7,6)` com check
  `[0,1]`, check de ano `1985..2025`.
- View `clean.v_mapbiomas_escola_grupos` — taxonomia **nível 1** adaptada ao
  IVET: `vegetacao_natural` (níveis 1+2), `agropecuario` (nível 3),
  `urbano_infra` (nível 4 antrópico: 24, 25, 30, 75), `agua` (31, 33),
  `outros_naturais` (23), `nao_observado` (0) e `outros` (código fora da
  taxonomia — nunca em silêncio).
- **Mapeamento por código, não pelo prefixo de `classe_desc`**: o prefixo não é
  confiável (6 = `1.4 Floodable Forest` sem ponto; 29 e 50 partilham `2.4`).

### Job `EduMaps::Ingestion::Job::MapBiomasEscola`

1. exporta os buffers (`clean.escola_influencia`, `tier='buffer'`) em **GeoJSON**
   (o R **não** toca na base);
2. baixa o COG do ano (preservado no raw, com manifesto/sha256);
3. roda `extract_mapbiomas_escola.R` (`terra::extract`, `weights=TRUE`);
4. carga **transacional** (o recorte `ano × raio` é substituído) + metadados.

Args: `anos=2024` (lista/intervalo), `uf=ES`, `raio=1000` (500/1000/2000 — os
raios materializados), `nu_ano_censo=` (opcional).

### Script R `extract_mapbiomas_escola.R`

- Lê o GeoJSON (`terra::vect`) e o COG (`terra::rast`) e extrai com
  `terra::extract(r, v, weights = TRUE)` — `weight` = fração da célula dentro
  do polígono; a composição por classe é o peso normalizado.
- **SRID**: o buffer é 4674 (SIRGAS2000) e o raster 4326 (WGS84); a diferença é
  sub-métrica, abaixo de um pixel de 30 m — o script **atribui** o CRS do raster
  à geometria em vez de reprojetar (evita uma passagem PROJ quase-identidade).
- Modo **`--dados=<csv>`** (pesos crus) para testar a normalização **sem**
  raster nem `terra` — é o que o teste unitário usa.
- Legenda nível 4 embutida (31 classe-folha); código desconhecido →
  `(classe N, ausente da legenda)`.

### Rex

`deploy_minion_dev` ganhou `r-base`/`r-base-dev`,
`libgdal-dev`/`libgeos-dev`/`libproj-dev`/`libudunits2-dev` e a instalação
**idempotente** do `terra` do CRAN (só compila se faltar). `terra::vect` lê o
GeoJSON pelo driver do GDAL, logo **não** foi preciso o `sf`.

### Refactor

`_comparar_colunas` (contrato de cabeçalho de CSV) foi movida do `BrazilCrime`
para o `Base` — é comum aos loaders que orquestram R. O teste do BrazilCrime
continua a chamá-la via herança, sem mudanças.

## Regra #154 (ausência ≠ 0)

Buffer sem interseção com o raster fica **sem linha** (nunca 0) e vai para o
relatório de órfãos do job. Um peso 0 é descartado na normalização. Um consumo
que precise somar usa a view de grupos.

## Validação (piloto)

Rodado em `backend.edumaps`, recorte **ES · 2024 · raio 1 km**:

| Métrica | Resultado |
|---|---|
| Linhas em `clean.mapbiomas_escola` | **19.898** (3.156 escolas × 21 classes) |
| Órfãos (buffer sem interseção com o raster) | **0** |
| Soma das frações por escola | **1** em todas (0 fora de 1e-4) |
| Tempo | download 748 MB ~12 min (1ª vez) · arealização **155 s** |
| Proveniência | `ultimo_status=ok`, `row_count=19898`, `CC-BY-4.0 (MapBiomas)` |

Grupos (média das frações): `urbano_infra` 0,46 · `agropecuario` 0,46 ·
`vegetacao_natural` 0,15 · `agua` 0,06 · `outros_naturais` 0,02 ·
`nao_observado` 0,003. Amostra coerente: as escolas com mais água são
litorâneas (mangue + praia/restinga + rio/lago/oceano).

## Dois defeitos que o teste unitário não pegava

Ambos achados **no piloto**, corrigidos e com regressão no teste:

1. **Notação científica**: `write.csv` do R escrevia frações minúsculas como
   `5.1e-05`, que o contrato do loader recusava. Agora a fração sai com **6
   casas fixas** (`sprintf("%.6f")`) — a precisão do `numeric(7,6)`.
2. **Acumulador**: `my (@todas, $n_orfaos) = ((), 0)` deixa `@todas = ("0")` e
   `$n_orfaos = undef` — a lista `((), 0)` é avaliada como **um escalar**, e o
   `"0"` entra no array; a carga recebia `"0"` como se fosse linha
   (`Can't use string as HASH ref`). Trocado por `my @todas; my $n_orfaos = 0;`,
   com **guarda explícita** no `carregar` (morre com o índice, não com erro
   críptico).

## Testes

- `backend/t/05-tasks/mapbiomas_escola_loader.t` — **49/49**: URL pinada,
  validação de args (ano/raio/UF), contrato do CSV, carga (DELETE do recorte +
  `ON CONFLICT`), órfãos, guarda do `carregar`, normalização R via `--dados`.
- Regressão: `brazilcrime_loader`, `ingestion_runner`, `esic_jobs`,
  `check_dependencies`, `allowlist_real`, `ingestao_p0` — verdes.

## Deploy

- `rex prepare`.
- Migration deployada em `database.edumaps` (`sqitch deploy` — registry limpo,
  só `mapbiomas_escola` pendente; deploy/verify/revert validados numa transação
  com rollback antes).
- `rex -H backend.edumaps deploy_minion_dev` → `terra 1.9.50` + GDAL 3.6.2.

## Pendências e próximos passos

- ⚠️ **O agregado do IVET continua `NA`**: **F** só entra na fórmula com a
  **exposição a risco** (ISH, declividade) extraída; **C (mobilidade)** segue
  bloqueado (sem isócrona/Tier 2).
- Escala nacional e raios 500/2000 m entram nos ciclos seguintes.
- Após merge: reconstruir as imagens Docker locais (`sqitch`, `backend`/`minion`).
- Seguem: **#168** (loader ANTT), **#138** (similaridade/PgVector), **#139**
  (coeficientes na literatura). **#137** segue aberta (faltam C e F-exposição).
