# Nota técnica 131 — #135: manifesto de hashes versionado (datasets.lock.json)

## Título
#135 — Manifesto de hashes versionado (datasets.lock.json)

## Contexto
Após #231, a ingestão já preserva `sha256` + `bytes` por arquivo bruto em `clean.import_metadata.raw_manifest`. O #135 tinha o objetivo "versionar datasets com DVC", mas o próprio issue aponta que um manifesto de hashes versionado resolve ~80% do problema sem dependência nova. Como o pin de conteúdo já estava em DB, optou-se por versionar um lockfile canônico no git.

## Decisão
Optar pelo **manifesto de hashes versionado** (via `data_pipeline/datasets.lock.json`) em vez de DVC completo. Razões:
- `raw_manifest` já tem hash por arquivo (#231) + preservação em `/srv/edumaps/raw/<fonte>/<data>/` fora do `pgdata`.
- lockfile é pequeno, determinístico, sem remote externo, sem nova dependência (usa JSON::PP core).
- fácil de verificar `--verify` (deriva) e `--check-files` (integridade de blobs).
- canónico (keys ordenadas) + `dataset_version` = sha256 do {version,tables}.

## O que foi feito
- `backend/lib/EduMaps/Ingestion/DatasetsLock.pm`: módulo puro — `build_lock`, `dataset_version`, `document`, `diff`, `from_db`, `canonical_json`/`pretty_json` (JSON::PP, `utf8` na forma canônica para Digest::SHA).
- `backend/bin/datasets_lock.pl`: CLI — `--write/--verify/--print-version/--check-files`. Usa `EduMaps::Schema->go`, I/O UTF-8 explícito, reporta deriva por tabela e exit 1 em caso.
- `data_pipeline/datasets.lock.json`: gerado a partir de `database.edumaps` (dev produto). 49 tabelas, 13 com `raw_manifest`. `dataset_version` validado (self-consistente, re-geração determinística).
- `backend/t/05-tasks/datasets_lock.t`: testes unitários (23 asserts) — ordenação, exclusão de campos voláteis, derivação de chave, diff (mudança de RC/source_url/raw, ausente/nova), `from_db` decodifica JSON/arrayref/NULL, regressão com acentos.
- `docs/analises/versionamento_datasets.md`: política operacional (lockfile × raw_dir × git), comandos, entenda diferenças vs DVC.
- `docs/funcionalidades/plataforma/fontes-de-dados.md`: acrescentado "fixar a versão exata dos dados".
- `docs/analises/ivet.md`: entrega 3 ajustada para refletir #135 resolvido e o que falta (`raw`→`clean`→`analytics`).
- `docs/indice.md`: referenciado o novo doc.
- `check_dependencies.t` e `check_dependencies.pl` OK (deps core + Mojo presentes).

## Validação
- `prove -l t/05-tasks/datasets_lock.t t/05-tasks/ingestao_p0.t t/06-tools/check_dependencies.t` → 51/51 OK.
- `script/check_dependencies.pl` → 0 módulos não declarados (Digest::SHA/Getopt::Long/JSON::PP já declarados).
- `--verify` em `backend.edumaps` (via carton, contra `database.edumaps`): OK com o lockfile versionado.
- `--check-files`: 26 blobs OK, 0 faltando, 0 alterados (integridade verificada).
- `--verify` com lock adulterado → detecta deriva; campo/tabela → mensagens corretas.
- Imagens locais `backend`/`minion`/`sqitch` reconstruídas e up; md5 dos arquivos bate local↔container.

## Impacto
- Infra (dados): traz reprodutibilidade auditável via hash. Não altera schema (só artefatos + docs).
- Deploy: sync normal (`rex prepare`) + `deploy_backend_dev` (script/bin + lib); `deploy_db_dev` não tocado. Imagens locais precisam rebuild (feito).
- Backlog: #135 coberto pelo manifesto; entregável 3 do #137 ainda precisa versionar etapa `raw`→`clean`→`analytics`.

