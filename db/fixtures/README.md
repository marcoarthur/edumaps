# Fixtures de CI (db/fixtures/)

Subconjunto **real** dos datasets do EduMaps para subir o banco do CI e da
máquina de dev sem depender dos ~765 MB originais nem da rede.

O `sqitch deploy` das 64 migrations roda inteiro contra eles: os arquivos ficam
**por baixo** das migrations (montados em `/data`, o caminho que os `COPY`
declaram) e produzem o mesmo schema — nenhuma migration foi alterada, então o
checksum do Sqitch nos bancos já implantados não quebra.

## O que tem aqui

| Artefato | Conteúdo |
|----------|----------|
| `*.csv` (12) | `Tabela_Escolas`, `Tabela_Matricula/Docente/Gestor`, `escolas.csv` (catálogo INEP), `inep.csv`, 3× `divulgacao_*_escolas_2023.csv`, `inse_2023.csv`, `pop_2025_mun.csv`, `populacao_faixas_etarias.csv` — headers verbatim do IBGE/INEP, linhas reais filtradas |
| `BR_Municipios_2024.zip` | Shapefile IBGE 2024 com os 18 municípios do fixture (EPSG:4674) — consumido por `raw_municipios_sp` via OGR FDW |
| `countries.geo.json` | GeoJSON de países consumido por `raw_countries` via `/vsicurl` — servido pelo espelho local (abaixo) |
| `fix-manifest.json` | O que o fixture contém (INEPs exigidos, municípios, taxonomia de origem) |
| `gerar.py` | Regenera os 12 CSVs a partir dos datasets reais |
| `gerar_zip_municipios.sh` | Regenera `BR_Municipios_2024.zip` (precisa `gdal-bin`) |
| `mirror_countries.py` | Espelho HTTPS local para a migration `raw_countries` (nginx-like: responde `Range`/206) |
| `ci_db.sh` | Sobe/destrói o banco de CI completo (imagem, rede, espelho, deploy) e roda o gate das migrations (`verify`) |

## Subir o banco de CI localmente

```bash
db/fixtures/ci_db.sh up      # Postgres + PostGIS + espelho + sqitch deploy
```

Depois, a suíte roda com as variáveis que o script imprime:

```bash
cd backend
EDUMAPS_CONF=./t/ci/edu_maps.conf \
EDUMAPS_DB_HOST=127.0.0.1 EDUMAPS_DB_PORT=55432 \
EDUMAPS_DB_NAME=edumaps_ci EDUMAPS_DB_USER=ci EDUMAPS_DB_PASS=ci \
EDUMAPS_FIXTURES=1 prove -r -l t/
```

É o mesmo caminho do `.github/workflows/backend-tests.yml`; rodar o script
localmente reproduz (e permite depurar) o banco do CI byte a byte.

O **gate das migrations** roda em separado, depois do `up`:

```bash
db/fixtures/ci_db.sh verify   # sqitch verify: cada change roda o seu verify/*.sql
```

No banco recém-deployado as changes estão em ordem de plano, portanto o gate não
esbarra nos erros *out of order* do registry de produção (ver `AGENTS.md`). Os
`verify/*.sql` falham de fato porque escrevem `DO $$ … RAISE EXCEPTION $$`; o
Sqitch 1.6.1 só considera a verificação falhada quando o script produz **erro**,
e um `SELECT` que devolve `f` passaria como ok (issue #160). O workflow do
backend roda `up` seguido de `verify` antes da suíte Perl.

## Por que um espelho HTTPS para o GeoJSON de países

A migration `raw_countries` lê

```
/vsicurl/https://cdn.jsdelivr.net/gh/johan/world.geo.json/countries.geo.json
```

O `cdn.jsdelivr.net` é Cloudflare e, dependendo do edge, responde
`Transfer-Encoding: chunked` sem `Content-Length`; o callback de escrita do
`/vsicurl` recusa corpo chunked e o GDAL reporta *unable to connect to data
source* mesmo com HTTP 200. A migration **não pode ser alterada** (checksum), e
nenhuma knob do GDAL resolve isso de forma confiável. A solução é o container
do Postgres confiar numa CA própria e o hostname resolver para um espelho local
na rede Docker:

```bash
# ci_db.sh faz isto por você; a versão manual:
db/fixtures/mirror_countries.py cert /tmp/edumaps-ci
docker run -d --name edumaps-ci-mirror --network edumaps-ci-net \
  --network-alias cdn.jsdelivr.net \
  -v /tmp/edumaps-ci:/m -v "$PWD/db/fixtures:/f:ro" \
  python:3-alpine python3 /f/mirror_countries.py serve /m 443 --de /f/countries.geo.json
```

O espelho implementa `Range` (206 + `Content-Range`), que o `/vsicurl` exige
(`Range downloading not supported by this server!`), e o container do Postgres
recebe `CURL_CA_BUNDLE=/m/ca.crt`.

## Regenerar os fixtures

Só é necessário quando os arquivos-fonte do IBGE/INEP mudarem de formato (o
`COPY` exige os mesmos headers e nomes de coluna):

```bash
python3 db/fixtures/gerar.py --entrada /caminho/para/as/tabelas/reais
bash db/fixtures/gerar_zip_municipios.sh /caminho/para/BR_Municipios_2024.zip
```

Detalhes de composição (municípios, INEPs exigidos e critérios de seleção de
escolas) no docstring de `gerar.py`.

## Limites conhecidos

- `clean.school_indicators` fica **vazia**: é populada pelo job de análise (R),
  não por migration. Desativa (não dorme) os testes que a exigem — ver
  `backend/t/lib/CI.pm`.
- Três INEPs citados por testes não existem nos subconjuntos possíveis
  (`23027010` ausente de todas as fontes; `33064164`/`33069395` só no IDEB do
  Rio de Janeiro) — os próprios testes tratam a ausência (`_escolas_notas_na_forma`
  em `backend/t/02-models/school/grades.t`).