# Persona: Especialista em Machine Learning

> Curadoria do pacote `eduBR` (repo `~/Projects/eduBR`).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".

## Perfil

- **Papel**: cientista de dados sênior; domina `tidymodels`/`mlr3` e já
  aplicou de k-means/GMM a gradient boosting e modelos multinível
  (hierárquicos) em bases públicas. Foco em **reprodutibilidade** e em
  **ausência de vazamento**.
- **Objetivo com o `eduBR`**: obter as tabelas já tipadas e "preguiçosas" o
  suficiente para compor features em `dplyr`/`dbplyr` e treinar modelos
  (predição de desempenho, clusterização, efeitos por escola/município).
- **Funções que mais usa**: `conecta()`, `consulta()`, `as_tibble()`,
  `scores()`, `indicadores()`, `censo_escolar()`, `censo_docentes()`,
  `censo_matriculas()`, `clusters()`, `catalogo()`.
- **Critérios de avaliação**: (1) fronteira lazy→`collect` explícita e
  controlável; (2) tipos corretos (numérico vs fator) e tratamento de NA;
  (3) sem pré-processamento/vazamento implícito; (4) extensibilidade sem
  reescrever `conecta`/catálogo; (5) performance previsível.

## Perguntas canônicas

1. O acesso preguiçoso (`consulta()`) deixa eu **compor features sem baixar
   tudo**? Onde está a fronteira lazy → `collect`?
2. Como trato NA e variáveis categóricas de **alta cardinalidade**
   (`tp_dependencia`, `tp_localizacao`)? Há dicionário de rótulos?
3. Os `scores()` compostos já vêm prontos? Posso **recalcular/reproduzir**?
4. Consigo **estender** o pacote (novas relações/pipelines) sem reescrever
   `conecta()`/catálogo?

## Entradas

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**M1 — fronteira lazy → collect.**
- Resposta: `consulta(x)` devolve `tbl_sql` (lazy) e `as_tibble(x)` faz o
  `collect`. O default é materializar **tudo**: `ideb()` tem 814.448 linhas,
  `censo_escolas` 214.192, e `escolas(uf="SP")` levou ~40 s para 28.710
  linhas. Não há `n`/amostra nem aviso.
- Status: **lacuna**.
- Follow-up: API de amostragem/limite (ex.: `coletar(x, n=)` ou
  `cabeça(x)`) e aviso de custo na materialização total.

**M2 — NA e categóricas de alta cardinalidade.**
- Resposta: `tp_dependencia` e `tp_localizacao` são `smallint` (códigos
  1..4), sem rótulo nem fator — o usuário precisa do dicionário do Censo
  fora do pacote. Não há função de dicionário.
- Status: **sugestão**.
- Follow-up: expor `dicionario()`/`rotular()` para as categóricas do Censo.

**M3 — scores prontos e reprodutíveis.**
- Resposta: `scores()` lê `clean.mv_escolas_scores` (matview pré-calculada,
  9 colunas; populada). Os valores vêm prontos, mas **não há função para
  recalcular** nem documentação da fórmula/origem no pacote.
- Status: **sugestão**.
- Follow-up: documentar a origem dos scores e/ou oferecer recálculo.

**M4 — extensibilidade.**
- Resposta: `catalogo()` é público (só leitura), mas `eduBR_catalogo()` e
  `eduBR_tbl()` são **internos**; não há ponto de extensão para registrar
  uma relação nova.
- Status: **sugestão**.
- Follow-up: expor um `registrar_relacao()`/overrides do catálogo.

**Observações extras da rodada.**
- `escola()`/`scores()` aceitam `escola_id` como string **e** como número
  (o Postgres faz o cast), então não trava por tipo — bom.
- `municipios_similares()` está **vazia** em dev (0 linhas).

## Pendências

- [ ] Amostragem/limite na materialização (`coletar(n=)`).
- [ ] Dicionário/rótulos para categóricas do Censo.
- [ ] Reprodutibilidade dos `scores()` (documentar ou recalcular).
- [ ] Ponto de extensão do catálogo.

## Sugestões priorizadas

- **[alta]** `coletar(x, n=)` / `head`-like + aviso de custo no `collect`.
- **[alta]** `dicionario()` para as variáveis categóricas (código → rótulo).
- **[média]** Documentar origem/fórmula dos `scores()`.
- **[média]** `registrar_relacao()` para estender o catálogo.
- **[baixa]** Aviso amigável quando `escola_id` for string em coluna numérica.

## Veredito

- **Aprova com ressalvas** (2026-09-15): a base preguiçosa e o `catalogo()`
  são boa fundação para modelagem, mas faltam controle de materialização,
  dicionário de rótulos, reprodutibilidade dos scores e extensão.
