# Versionamento de datasets — manifesto de hashes

> **Issue**: #135 · **Escopo**: fixar (pin) a versão dos dados do pipeline com
> uma chave de conteúdo, sem dependência nova.
> **Relacionadas**: [catálogo de fontes](fontes_de_dados.md) ·
> [IVET](ivet.md).

## O problema

O pipeline (`raw` → `clean` → `analytics`) já passa de 20 fontes. Sem versionar
o dado:

- não há como responder *"por que o indicador mudou entre a carga de terça e a
  de hoje?"*;
- uma carga parcial ou reprocessada **sobrescreve** o resultado anterior sem
  deixar rastro;
- reproduzir um número de seis meses atrás exige refazer a carga — e o upstream
  já mudou.

## A decisão: manifesto de hashes, não DVC

O #135 previa adotar o **DVC**. A decisão (2026-10-15) foi o **caminho mínimo**:
um **manifesto de hashes versionado no git**, sem dependência nova. O motivo é
que a peça difícil — o hash de conteúdo por arquivo — **já existia** desde o
#231:

- todo arquivo baixado é preservado em
  `<raw_dir>/<fonte>/<AAAA-MM-DD>/<arquivo>` (`raw_dir` default
  `/srv/edumaps/raw`, ou `EDUMAPS_RAW_DIR`), **fora do `pgdata`** — um restore do
  banco não apaga a única cópia;
- o job de ingestão calcula **`sha256` + bytes** de cada arquivo e grava em
  `clean.import_metadata.raw_manifest` (jsonb), com detecção de
  reaproveitamento.

O que faltava era **agregar** essas impressões digitais num artefato
determinístico e versionado. É isso que o lockfile faz.

## O lockfile

Arquivo: **`data_pipeline/datasets.lock.json`** (versionado no git).

```json
{
  "dataset_version": "a33c32ab…d1375d",
  "transform_version": "4b66f4c2…9c8198",
  "version": 2,
  "tables": [
    {
      "table_name": "clean.censo2022_setor",
      "source_url": "…",
      "source_license": "…",
      "row_count_loaded": 12345,
      "raw": [ { "url": "…", "sha256": "…", "bytes": 123 } ]
    }
  ],
  "transformations": [
    {
      "table_name": "clean.escola_entorno_socioeconomico",
      "method": "clean.refresh_escola_entorno_socioeconomico",
      "kind": "function",
      "row_count": 470448,
      "def_sha256": "…"
    }
  ]
}
```

- **`dataset_version`** é a **chave de conteúdo do conjunto**: o `sha256` do JSON
  canônico (chaves ordenadas, bytes UTF-8) de `{version, tables}`. É o
  identificador que responde *"este número veio de qual versão dos dados?"*.
- **`transformations`** fixa a **transformação** (`raw`→`clean`→`analytics`) que
  o IVET ([#137](ivet.md)) consome: para cada camada derivada, o objeto que a
  materializa (`method`), o tipo (`kind`: `function` de `refresh_*`, ou
  `matview`/`view`), o `row_count` observado e o **`def_sha256`** — o `sha256`
  da definição desse objeto (`pg_get_functiondef` para funções,
  `pg_get_viewdef` para views/matviews). O registry dos passos é declarado em
  `DatasetsLock.pm` (`@DERIVED_STEPS`): adicionar uma camada derivada nova é
  registá-la ali.
- **`transform_version`** é a chave de conteúdo da **transformação**: o `sha256`
  do JSON canônico de `{version, transformations}`. Responde *"o cálculo que
  gerou este número ainda é o vigente?"*. Hashear a **definição** do objeto (e
  não as centenas de milhares de linhas) fixa o código sem custo e sem depender
  da ordem física dos registos.
- **`tables`** é ordenado por `table_name`; **`raw`** por `(url, sha256)`. A
  forma é determinística entre execuções e entre máquinas.
- Ficam **de fora**, de propósito, os campos que mudam a cada execução sem
  mudar o conteúdo: `caminho` (tem a data do download), `baixado_em`,
  `reaproveitado`, `retrieved_at`/`import_timestamp`. A proveniência completa
  continua na base — `retrieved_at` + `source_url` + `sha256` respondem juntos
  de onde veio cada tabela.

## Uso

```bash
cd backend
# (re)gerar depois de uma carga e commitar:
carton exec -- perl -Ilib bin/datasets_lock.pl --write
# denunciar deriva (exit 1) — CI, ou antes de publicar um número:
carton exec -- perl -Ilib bin/datasets_lock.pl --verify
# re-hash dos blobs preservados em disco (integridade do raw):
carton exec -- perl -Ilib bin/datasets_lock.pl --check-files
# só a chave de conteúdo dos dados:
carton exec -- perl -Ilib bin/datasets_lock.pl --print-version
# só a chave de conteúdo da transformação:
carton exec -- perl -Ilib bin/datasets_lock.pl --print-transform-version
```

O lockfile descreve **o banco de desenvolvimento** (`database.edumaps`):
`--verify` só é significativo contra a **mesma base** que gerou o arquivo. No
ambiente local (`edumaps-db`), `--verify` acusa deriva por construção — as
cargas locais não são as de dev.

## Política de armazenamento

| O quê | Onde | No git? |
|---|---|---|
| Lockfile (`datasets.lock.json`) | `data_pipeline/` | **Sim** — é pequeno e é o pin |
| Blobs brutos preservados | `<raw_dir>` (`/srv/edumaps/raw`), por fonte e dia | **Não** — volumosos, e o `.gitignore` do repo já cobre `raw/` |
| Proveniência (URL, licença, data, hash) | `clean.import_metadata` | — (vive no banco) |

O lockfile **não** substitui o backup do `raw_dir`: ele diz *o que* deveria
estar lá (o hash), e `--check-files` confere. Perder o blob e ter o lockfile é
saber exatamente o que falta re-baixar.

## O que fica de fora (follow-ups)

- **DVC propriamente dito**: reavaliar só se surgir um *remote* (bucket/share)
  e o time quiser `dvc pull`/`dvc checkout`. Hoje o ganho não cobre a
  dependência (visão do próprio #135).

O **pipeline `analytics` reprodutível por hash** (entregável 3 do #135, também
do [#137](ivet.md)) passou a ser coberto: além da ponta de entrada (`raw`,
`dataset_version`), o lockfile fixa a **transformação** que o IVET consome
(`transformations`/`transform_version`). O registry em `DatasetsLock.pm` é
deliberadamente **declarado** — cobre as camadas que o IVET lê
(`clean.escola_influencia`, `clean.escola_entorno_socioeconomico`,
`clean.mv_escolas_scores`); uma camada nova que o índice passe a consumir entra
ali.

## Referências

- [#231](https://github.com/marcoarthur/edumaps/issues/231) — preservação do raw
  e manifesto por arquivo.
- [#124](https://github.com/marcoarthur/edumaps/issues/124) — Fase 0:
  proveniência com licença (`source_url`, `source_license`, `retrieved_at`).
- [#135](https://github.com/marcoarthur/edumaps/issues/135) — esta issue.
- `backend/lib/EduMaps/Ingestion/DatasetsLock.pm` — o núcleo (build, chave,
  diff).
- `backend/bin/datasets_lock.pl` — a CLI.
