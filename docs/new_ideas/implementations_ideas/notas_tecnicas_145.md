# Nota técnica 145 — #168: loader ANTT (acidentes por trecho)

Esta nota documenta a reescrita do loader **ANTT** sobre a API CKAN real e a
carga da **primeira das quatro tabelas** — `clean.antt_acidente_trecho`. PR
**#275** (branch `feat/data-loader-antt`, commit `2622afa`).

## Contexto

A #168 listava quatro tabelas ANTT vazias (`antt_acidente_trecho`,
`antt_contagem_equipamento`, `antt_od_municipio`, `antt_trecho_geodados`) e um
job de 85 linhas que **invocava dois scripts R inexistentes**. O job antigo
baixava **páginas HTML de dataset** como se fossem CSV/GPKG e nunca carregou
nada; desde 2026-10-13 respondia `nao_carregada` (host fora do ar).

## Descoberta (2026-10-18)

O portal responde e é CKAN puro:

- `GET /api/3/action/package_list` → **106 datasets**.
- `GET /api/3/action/package_show?id=acidentes-rodovias` → **44 recursos CSV**,
  um por concessionária (`Demonstrativos de Acidentes - <CONCESSIONÁRIA>`),
  servidos em `/dataset/ef0171a8-.../resource/<uuid>/download/<arquivo>.csv`.
- Formato: separador `;`, codificação **ISO-8859-1**, colunas estáveis entre
  concessionárias.

Os paths do allowlist (`/dataset/acidentes`, `/dataset/trechos`) davam **404** —
foram substituídos pelos reais.

## O que foi feito

### Job `EduMaps::Ingestion::Job::ANTT` (reescrito)

1. Descobre os recursos via `package_show`; a concessionária sai do nome do
   recurso.
2. Baixa cada CSV (raw preservado, manifesto/sha256) e faz o parse (`;`,
   ISO-8859-1).
3. Desduplica pela chave do **evento** e carrega num `COPY ... FROM STDIN`
   (transacional; o recorte por concessionária é substituído).
4. `upsert_metadata` com a proveniência.

Mapeamento: `data`→`data_acidente`, `horario`, `n_da_ocorrencia`→`n_ocorrencia`,
`km` (vírgula decimal), `trecho`, `tipo_de_acidente`, `tipo_de_ocorrencia`→
`classificacao`, `tipo_de_pista`→`pista`, `mortos`, `gravemente_feridos`→
`feridos_graves`, `levemente_feridos`→`feridos_leves`, `ilesos`, e a soma das
colunas de veículos → `veiculos_envolvidos`. **`causa_provavel` e
`condicao_tempo` não existem na planilha** → **NULL** (#154), nunca 0.

### Migration nova `antt_acidente_trecho_grao`

A chave única original `(concessionaria, data_acidente, km, trecho)` era
**grossa demais**: medido no CSV real da RODOVIA DO AÇO (12.650 linhas), **79
acidentes partilham km+dia+trecho** — dois eventos no mesmo ponto, em horários
diferentes. O grão real do evento é `(concessionaria, data_acidente, horario,
n_ocorrencia)`: medido, **0 duplicados**. A change (nova, não edita a deployada)
adiciona `horario TIME` e `n_ocorrencia TEXT` e troca a constraint.

## Defeitos encontrados e corrigidos no ciclo

O piloto pegou **quatro** defeitos que o teste unitário não pegava:

1. **Truncagem silenciosa.** Os CSVs têm `"` no meio de campos; o `Text::CSV`
   parava cedo com `EIQ - QUO character not allowed` e o loop terminava —
   **56 mil linhas viravam 44**. Corrigido com `allow_loose_quotes` e
   `allow_loose_escapes`, mais uma guarda por `eof($fh)` que **morre alto** se o
   fim do arquivo não for alcançado (truncar em silêncio é o defeito).
2. **COPY × watchdog.** O watchdog do Runner (`SIGALRM`) consulta a BD a cada
   60 s **na mesma conexão**, abortando o `COPY FROM STDIN` a meio ("no COPY in
   progress"). Corrigido bloqueando o `SIGALRM` (`POSIX::sigprocmask`) durante a
   carga; o sinal pendente é entregue ao desbloquear. Este é um defeito de
   **interação**, não do job — qualquer job que faça um COPY longo cai nele.
3. **NUL (0x00)** no dado → removido no campo do COPY (Postgres recusa em texto).
4. **Duplicados por sentido.** A fonte repete o evento (linhas idênticas salvo
   `sentido` Crescente/Decrescente). Desduplicado pela chave do evento antes da
   carga (1.876 descartados).

## Validação

Rodado em `backend.edumaps`:

| Métrica | Resultado |
|---|---|
| Linhas em `clean.antt_acidente_trecho` | **958.043** |
| Datas | 2010-01-01 → 2026-08-31 |
| Concessionárias | 41 |
| Chave do evento repetida | **0** |
| `causa_provavel` / `condicao_tempo` | NULL (ausentes na fonte, #154) |
| Tempo | 124 s |

## Testes

`backend/t/05-tasks/antt_loader.t` — **55/55**: descoberta CKAN, conversores
(data/hora/km/inteiros/texto), contrato do CSV (pulado sem derrubar a carga),
COPY, dedupe, aspas soltas (regressão), NUL. Regressão: `mapbiomas_escola_loader`,
`brazilcrime_loader`, `ingestion_runner`, `esic_jobs`, `ingestao_p0`,
`check_dependencies`, `allowlist_real` — verdes.

## Pendências (as outras 3 tabelas)

- **`antt_trecho_geodados`**: **não há geometria de trecho (LineString) no
  CKAN**. Os únicos geo-recursos são **KMZ de equipamentos** (radar, SAT, PMV,
  praça, PRF, CFTV) e um **SHP de pontos** de km. Sem fonte de geometria, a
  tabela — e, por **FK**, `antt_contagem_equipamento` — ficam bloqueadas.
- **`antt_contagem_equipamento`**: depende de `antt_trecho_geodados` (FK). A
  fonte de volume (`volume-radar`/`volume-sat`) tem `identificador`/`rodovia`/`uf`
  mas **nenhum código de trecho** que case com o desenho da tabela.
- **`antt_od_municipio`**: MONITRIIP é grão de **viagem individual**
  (CNPJ/placa/IMEI/lat-long por viagem) — negado por LGPD na allowlist; a
  agregação a município é decisão de produto.

Estas três precisam de **decisão de produto** (o desenho das tabelas assume um
"código de trecho" que a ANTT não publica). Registradas no relatório de fontes.
