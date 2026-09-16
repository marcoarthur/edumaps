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

### 2026-09-15 — 3ª rodada (INSE e regressão transversal)

Foco: avaliar `inse()` / `ideb_inse()` / `regressao_inse()` e o report
`analysis/regressao_inse_regiao.Rmd`.

**M9 — cobertura e natureza do INSE.**
- Resposta: `clean.inse` tem **só 2023** (`nu_ano_saeb`), 69.756 escolas,
  `tp_tipo_rede` ∈ {1,2,3} (federal/estadual/municipal) — **sem privadas**.
  `media_inse` sem NA (2,21–6,65). O join `ideb_inse()` devolve 97.521 linhas
  (2023), 68.937 escolas distintas, sem `Privada`.
- Status: **✓** com ressalva de escopo (corte 2023, só públicas).
- Follow-up: não há série histórica de INSE → o painel INSE×IDEB depende de
  carga de SAEBs anteriores.

**M10 — reprodutibilidade da regressão transversal.**
- Resposta: `regressao_inse(con, etapa)` devolve `eduBR_regressao_inse`; duas
  execuções com coeficientes **idênticos** (`all.equal` TRUE). Nível escola
  (fund. II: 31.084 escolas). Gradientes (IDEB/INSE) por região: CO 1,22 >
  SE 1,13 > N 1,09 > S 1,03 > **NE 0,61**.
- Status: **✓ atendido**.

**M11 — vazamento/contemporaneidade.**
- Resposta: INSE e IDEB são **do mesmo ano (2023)** → é associação
  **contemporânea**, não uma configuração de predição (sem holdout temporal).
  Para previsão, o correto seria INSE defasado (`t-1`) prevendo o IDEB de
  `t`.
- Status: **observação/sugestão**.
- Follow-up: marcar no report/README que é associação, e prever `ideb_t` com
  `inse_{t-1}` quando houver histórico.

**M12 — cardinalidade do join (1:n por etapa).**
- Resposta: 68.937 escolas → 97.521 linhas (~1,4/school): uma escola entra
  uma vez por etapa do IDEB, repetindo `media_inse`. Nos modelos por
  região×etapa isso é correto; se alguém agrupar etapas sem cuidado, duplica
  escolas.
- Status: **observação**.
- Follow-up: documentar/avisar o 1:n de `ideb_inse()` (por etapa).

**Observações extras da rodada.**
- Join por `id_escola` (bigint nos dois lados) — sem o problema de tipo do
  `co_municipio`×`codigo_ibge`; foi limpo.
- `regressao_inse()` materializa o corte inteiro (~97 mil linhas) por não
  haver `coletar(n=)`; aqui é necessário para o ajuste, mas reforça a
  pendência de controle de materialização.
- `eduBR_catalogo()` segue interno (M4) e `catalogo()` já lista `inse`.

### 2026-09-15 — 2ª rodada (tendência do IDEB e report)

Foco: avaliar o novo fluxo de modelagem (`ideb_regiao()` +
`tendencia_regiao()`) e o report de tendência por região.

**M5 — a tendência é reproduzível?**
- Resposta: `tendencia_regiao(con, etapa, rede)` devolve um
  `eduBR_tendencia` (tibble 5×9 em `fundamental_ii`) com list-cols
  `modelo`, `coeficientes`, `metricas`, `predicoes`. Duas execuções
  produzem coeficientes **idênticos** (`all.equal` TRUE); motor `lm` via
  `parsnip::linear_reg()`. O report
  (`analysis/tendencia_ideb_regiao.Rmd`) é parametrizado (`etapa`, `rede`).
- Status: **✓ atendido** (ressalva: é tendência linear bivariada, por design).
- Follow-up: a persona quer covariáveis (rede, infraestrutura) — quando o
  pacote expuser `perfil_escola()`/features, estender o report.

**M6 — compor features sem baixar tudo (revisita de M1).**
- Resposta: `consulta(ideb_regiao(con, etapa="fundamental_ii"))` é
  `tbl_sql`; `group_by/summarise` antes do `collect` reduz **322.831 linhas
  → 50** no banco. A fronteira lazy→collect é controlável **se** se compõe a
  query. O risco persiste no `as_tibble()` direto (sem limite/aviso).
- Status: **✓ parcial**.
- Follow-up: `coletar(x, n=)`/`cabeça()` + aviso de custo quando o objeto
  não foi filtrado/agregado.

**M7 — categóricas do IDEB.**
- Resposta: no IDEB, `rede` (`Municipal/Estadual/Federal/Privada`) e
  `etapa` (`fundamental_i/ii`, `ensino_medio`) já vêm como texto legível —
  não precisa de dicionário nesse fluxo. Os códigos crus
  (`tp_dependencia`, `tp_localizacao`) seguem no Censo.
- Status: **✓ para o IDEB** (lacuna de dicionário persiste no Censo).

**M8 — `integer64` em agregações `bigint`.**
- Resposta: `count()`/agregações que devolvem `bigint` chegam como
  `integer64`; sem `bit64` carregado imprimem como denormal
  (ex.: `1.6e-318` para 322.831) — risco de leitura errada.
- Status: **sugestão**.
- Follow-up: normalizar (`as.numeric`) nas funções de contagem ou documentar.

**Observações extras da rodada.**
- `pdflatex`/`tinytex` disponíveis: o report dá para exportar em **PDF**,
  hoje só HTML (preferência do usuário).
- Região derivada da UF (mapa `case_when`), então **não** resolve o join
  escola→município por código — são lacunas distintas.

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

- [ ] Amostragem/limite na materialização (`coletar(n=)`) + aviso de custo.
- [ ] Dicionário/rótulos para categóricas do Censo.
- [ ] Reprodutibilidade dos `scores()` (documentar ou recalcular).
- [ ] Ponto de extensão do catálogo.
- [ ] Normalizar/avisar `integer64` em agregações (`count()`).
- [ ] Report: export em PDF + parâmetros de recorte (UF/região).
- [ ] Série histórica de INSE (hoje só 2023) para permitir painel temporal.
- [ ] Documentar/avisar contemporaneidade e o 1:n de `ideb_inse()` (por etapa).

## Sugestões priorizadas

- **[alta]** `coletar(x, n=)` / `head`-like + aviso de custo no `collect`.
- **[alta]** `dicionario()` para as variáveis categóricas (código → rótulo).
- **[média]** Documentar origem/fórmula dos `scores()`.
- **[média]** `registrar_relacao()` para estender o catálogo.
- **[média]** Expor covariáveis (via `perfil_escola()`) para ampliar a
  tendência além do modelo bivariado.
- **[média]** Carregar SAEBs anteriores (INSE histórico) → painel para
  previsão (`inse_{t-1}` → `ideb_t`).
- **[baixa]** Normalizar `integer64` em agregações (ou avisar).
- **[baixa]** Report: `pdf_document` + params de recorte (UF/região).
- **[baixa]** Avisar associação contemporânea / 1:n por etapa em
  `ideb_inse()`.
- **[baixa]** Aviso amigável quando `escola_id` for string em coluna numérica.

## Veredito

- **Aprova com ressalvas** (2026-09-15, 3ª rodada): o fluxo de INSE
  (`inse()`/`ideb_inse()`/`regressao_inse()`) entrega uma regressão
  transversal **reprodutível** por região×etapa e o gradiente
  socioeconômico fica comparável entre regiões. Ressalvas: INSE só em 2023
  (sem painel), amostra restrita a públicas, associação contemporânea (não
  predição) e o 1:n por etapa precisa de aviso. Pendências estruturais
  (controle de materialização, dicionário do Censo, reprodutibilidade dos
  `scores()`, extensão do catálogo) seguem abertas.
