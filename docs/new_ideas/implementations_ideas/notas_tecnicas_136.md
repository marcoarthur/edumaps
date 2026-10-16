# Nota técnica 136 — #137: loader do bloco B (instrução/saneamento) e arealização por célula

Esta nota cobre a fatia seguinte da #137 (IVET versionado) coberta pela NT_135:
carregar as **fontes do Censo 2022 que faltavam por setor** e corrigir a
**arealização** do bloco **B (socioeconômico)**. PR **#263** (merge `6303075`).

## Contexto

A NT_135 entregou o molde do bloco B (arealização + fórmula v1.0), mas o loader
do setor (`EduMaps::Ingestion::Job::SetoresCenso2022`) só carregava básico,
demografia e cor/raça. Os componentes de **instrução** e **saneamento** ficavam
`NULL` porque as variáveis **não existiam no banco**, não porque o Censo as
suprime. Esta fatia carrega os dois temas que faltavam e liga-os à arealização.

## O que foi feito

### Loader — `backend/lib/EduMaps/Ingestion/Job/SetoresCenso2022.pm`

- Dois temas novos, lidos dos brutos do IBGE:
  - **`alfabetizacao`** (V00900/V00901) → `alf_sabe_15mais`,
    `alf_nao_sabe_15mais`;
  - **`caracteristicas_domicilio2`** → água (V00111..V00118), esgoto
    (V00309..V00316), lixo (V00397..V00402) e banheiro (V00494/V00495), em
    **contagens por categoria** (a classificação adequado/inadequado vive na
    arealização SQL, onde é auditável e versionada — não no loader).
- **Escrita refatorada para `jsonb` em lote** (`encode_json` por linha). O
  método anterior (`VALUES` gigantes num único `INSERT`) quebrava com o
  *stall watch* do `Runner`: o `$SIG{ALRM}` dispara um `PQexec` entre o
  `do(COPY)` e o `pg_putcopyend`, e o Postgres aborta com
  `COPY from stdin failed: COPY terminated by new PQexec`. A carga real caiu
  de "aborta no stall de 1 h" para **701 s**.

### Banco — changes `censo2022_setor_instrucao_saneamento` + `escola_entorno_socioeconomico_saneamento`

- 24 colunas cruas em `clean.censo2022_setor`.
- 5 `pct_*` em `clean.escola_entorno_socioeconomico` (`pct_analfabeto`,
  `pct_agua_sem_rede`, `pct_esgoto_inadequado`, `pct_lixo_inadequado`,
  `pct_sem_banheiro`), `versao` default **`ivet-v1.1`** e
  `CREATE OR REPLACE FUNCTION clean.refresh_escola_entorno_socioeconomico`.
- **Ausência por célula (#154)**: cada componente exclui do numerador e do
  denominador apenas os setores cuja **sua própria variável-fonte** está `NULL`
  (célula suprimida pelo IBGE). O flag de setor `supressao_celula_pequena` **não**
  é mais gate de componente.

### Fórmula — `analysis/edumapsr/R/ivet-socioeconomico.R`

- `ivet_bloco_socioeconomico()` mapeia os 5 componentes brutos para a dimensão
  B (`ivet_agregar()`), em `[0,1]`, maior = mais vulnerável. `renda`/`esc_*`/
  `cor_sem_decl` continuam fora — sem fonte por setor (#238).

## Achado central — o filtro de supressão estava errado

A arealização (NT_135) descartava o **setor inteiro** quando
`supressao_celula_pequena = true`. Esse flag é o **OR de dezenas de variáveis**
(o loader o marca se *qualquer* célula do setor vem `X`). Com os dois temas
novos o flag passou a valer para **87,6%** dos setores — só ~12% da área
alimentava *todos* os indicadores, apesar de cada variável estar bem presente:

| indicador | presença individual |
|---|---|
| alfabetização | 86,7% |
| banheiro | 82,2% |
| lixo | 58,9% |
| água | 54,5% |
| esgoto | 43,7% |
| filtro antigo (`NOT supressao`) | **12,4%** |

O flag é útil como **proveniência** (quantos setores têm alguma célula
suprimida), não como gate. Corrigido para **ausência por célula**: cada `pct_*`
exclui só os setores sem a sua variável. `n_setores_suprimidos`/`cobertura_pct`
seguem o flag e foram **documentados** como proveniência — `cobertura_pct = 0`
não implica componente `NULL` (comentários em `COMMENT ON COLUMN`, na change e
no revert).

## Validação

- `backend/t/escola_entorno_socioeconomico.t` — **7 subtests PASS**; o teste
  passou a simular a supressão como **`NULL` das colunas-fonte** (o loader grava
  `NULL`), não só o flag do setor.
- `backend/t/05-tasks/setores_censo_loader.t` — **PASS** (12 testes).
- Suíte R: `[FAIL 2 | PASS 1667]` (2 falhas pré-existentes).
- **Carga real no produto** (`database.edumaps`): **701 s**, 468.097 setores,
  409.856 com supressão, 2 descartados (FK). Ausência = `NULL` confirmada
  (zeros legítimos preservados).
- **Subset** (`co_municipio=4302105`, Bento Gonçalves/RS): 219 buffers (0,23 s)
  + 219 linhas de entorno (13 s); os 5 `pct_*` presentes nas **73** escolas —
  antes o analfabetismo só existia em 51/68/71 (500/1000/2000 m).
  `pct_agua_sem_rede` 1,5–5,2%; `pct_esgoto_inadequado` 1,6–2,8%.
- Pós-merge: imagens locais `sqitch`/`backend`/`minion` reconstruídas;
  `md5` do loader no container == working tree.

## Deploy

Changes deployadas no produto (**`database.edumaps`** — não `database.dev`):
`data_pipeline/` via `sqitch`, mas a **função** da change B precisou de
`psql -f` manual (o Sqitch não re-executa uma change já deployada — o corpo pode
mudar sem que o `change_id` mude, desde que `requires` e ordem fiquem iguais).
`rex prepare` + `deploy_backend_dev` para o loader.

## Caveat de ambiente

`t/escola_influencia.t` falha 2/5 **no ambiente local** por poluição de dados: a
base local já tem 470.448 buffers, então o `count=2` do teste vira 3. Idêntico
no `main` — pré-existente, não regressão.

## Próximos passos (não nesta nota)

- **Materializar influência + entorno de facto** para o bloco B sair do `NA` no
  produto: depende de `clean.escola_influencia` (#255), que estava a 0 linhas no
  produto. Escopo **país vs subset** em aberto — 156.816 escolas × 3 raios
  ≈ 470k buffers.
- Extração dos blocos **C–G**; reconciliação de fórmula **B↔C** (§6).
