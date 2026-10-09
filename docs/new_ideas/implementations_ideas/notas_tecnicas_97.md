# Nota técnica 97 — INMET e MapBiomas: declarar em vez de mentir (#171 + #170)

## Resumo

Terceiro ciclo da família de "honestidade dos loaders" (depois do #172/#157):
fechar jobs que apontam para fontes que não existem ou que descarregam a fonte
errada.

- **#171 — INMET (decisão C)**: a API do INMET foi **retirada** (não é URL
  errada). `dados.inmet.gov.br` não resolve (sem registo A),
  `apitempo.inmet.gov.br/bdmep/estacao` e `/alertas/cap12` → **404**, e o
  restante host é interface web/feed RSS que não alimenta as tabelas
  pretendidas. Sem loader para endpoints mortos: `INMET.pm` falha alto com o
  motivo, `inmet_bdmep`/`inmet_alerta` declaram **NÃO CONSTRUÍDA** no schema e
  ficam **fora do objetivo da #156**.
- **#170 — MapBiomas (parte 1; loader real aguarda e-SIC)**: o job antigo
  baixava `BR_Municipios_2024.gpkg` (malha municipal do **IBGE**) para uma
  tabela de uso do solo e descarregava uma **página web** do MapBiomas como se
  fosse GPKG — geometria administrativa não é cobertura de uso do solo (o
  mesmo defeito da #154). Agora falha alto; `mapbiomas_cobertura` declara
  **NÃO CONSTRUÍDA**. A issue **segue aberta**: o loader real (URL verificado +
  scripts R + areolização) depende do **token da API MapBiomas** (e-SIC).

Entrega: 3 commits, branch `fix/inmet-mapbiomas-171-170` → **PR #197** (merge
`cad2426`). Antes, o 502 da busca local foi diagnosticado e corrigido como
infra (`docker compose up -d`) e registrado em `docs/e2e/cobertura.md`
(commit `12d7a38`, docs-only).

## Decisões de design

- **Decisão C à letra**: a issue recomendava "C ou B, por esta ordem". B (RSS de
  avisos) alimentaria uma única tabela, mal, e teria de ser uma decisão
  consciente; C é mais barata e não cria a ilusão de pipeline. C foi a escolha.
- **O job fica e morre — não é removido como o `CensoEscolar`**: no #172, o
  `CensoEscolar` era caminho **morto duplicado** (`clean.censo_escolas`/
  `censo_docentes` já carregados por outro caminho), logo a remoção era
  limpeza. Aqui não há caminho alternativo; manter o scaffold que declara
  "não disponível" preserva o registo de *porque* não existe loader e o ponto
  de retorno caso o INMET republique uma API. Um job que falha alto é honesto;
  um job que aponta para 404 dá a ilusão de pipeline.
- **Parar o dano antes de construir**: a #170 pedia o loader real, mas o
  loader *existente* descarregava dado errado para uma tabela de uso do solo.
  "Deixar vazio é honesto; encher com geometria do IBGE não é" (corpo da
  issue). A parte 1 na #170 é neutralizar o defeito; o loader real continua
  bloqueado pelo e-SIC (token), como o próprio corpo previa.
- **Change Sqitch nova, nunca editar deployadas**: `comments_inmet_mapbiomas_pendente`
  é **apêndice** ao plano (pai `comments_esic_pendente`) — o `change_id` é o
  SHA-1 dos metadados (requer `requires` + id do pai), logo editar uma change
  já deployada ou reordenar o plano quebra a cadeia. Confirmado antes de tocar
  no plano: `git status` limpo no `sqitch.plan` e pai deployado no local e no
  produto.
- **Verify que morde**: o verify usa `DO $$ … RAISE EXCEPTION $$` em vez de um
  `SELECT` — o `SELECT` devolve `f` e o Sqitch 1.6.1 reporta "ok" (issue #160).
  Testado com regressão plantada: comment sem "NÃO CONSTRUÍDA" derruba.
- **Não houve `docs/funcionalidades/`**: isto não é capacidade de produto — é
  higiene de ingestão, como no ciclo #172/#157.

## Medições

- `env -u PERL5LIB prove -l t/05-tasks/esic_jobs.t t/05-tasks/ingestion_runner.t`:
  **16/16 PASS**. O subteste novo cobre INMET (`success=0`, cita `#171`, declara
  NÃO CONSTRUÍDA, motivo "retirada") e MapBiomas (`success=0`, cita `#170`,
  motivo "e-SIC", explica o defeito do IBGE).
- Verify `comments_inmet_mapbiomas_pendente`: **normal → ok**;
  **regressão plantada → `ERROR: … inmet_bdmep sem declaração NÃO CONSTRUÍDA/decisão #171`**;
  restore → ok.
- Deploy local (serviço `sqitch` do compose, `build` + `up`):
  `+ comments_inmet_mapbiomas_pendente .. ok`.
- Produto (`database.edumaps`, SSH): os 3 comments começam por "NÃO CONSTRUÍDA";
  `sqitch.events` tem `deploy comments_inmet_mapbiomas_pendente`.
- Deploy remoto: `rex prepare` + `deploy_db_dev` + `deploy_backend_dev` +
  `deploy_minion_dev`; md5 dos dois jobs coincide local↔`backend.edumaps`;
  CensoEscolar ausente no host.

## Incidentes e armadilhas de ferramenta

- **502 da busca = container velho sem app escutando** (infra, não código): o
  `edumaps-backend` de ~5 dias parou de escutar na `:3000`; o nginx registrou
  `connect() failed (111)` de 12:07 a 12:40. `docker compose up -d` recriou o
  container com a imagem mergeada e o 502 cessou. A E2E confirmou o fluxo
  (suggestions + search/pageable) e que "mojuca" vazio é correto (escola
  inativa, `tp_situacao_funcionamento=2`). **A armadilha do AGENTS de novo**:
  imagem reconstruída ≠ container recriado.
- **Encoding no teste**: `esic_jobs.t` não tinha `use utf8`; o regex literal
  não casava com a string de erro (que chega como caracteres Unicode). Adicionar
  `use utf8` ao teste resolveu — a asserção passou a ser sobre o mesmo domínio
  de caracteres.
- **`rex prepare` não apaga removidos**: não se aplicou neste ciclo (só
  modificações e ficheiros novos), mas continua a ser a razão pela qual o
  `CensoEscolar.pm` teve de ser removido à mão no ciclo anterior.
