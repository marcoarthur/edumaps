# Nota técnica 132 — #137 (entregável 3, núcleo): fórmula `ivet-v1.0` como código R

A **#137** já tinha entregado os entregáveis **1** (fórmula `ivet-v1.0`
documentada em `docs/analises/ivet.md`) e **2** (decisão de leitura
**territorial**), além da reconciliação de origem **B/A/D** (PR #257). Esta nota
cobre o **entregável 3**: o *pipeline reprodutível* — mais precisamente, a sua
metade **determinística**, agora em código.

## Contexto

O entregável 3 pedia "pipeline de treino reprodutível: mesma entrada → mesmo
modelo, com a versão do dataset de entrada registrada". Duas leituras do termo
"modelo" eram possíveis: (a) o **RandomForest** (Z:10450); (b) o **índice IVET**
remodelado pelo doc. O próprio doc (§4.4/§6) empurra para (b) e o §6 avisava que
a **reconciliação *de fórmula* B↔C** é decisão de produto (muda
similaridade/ranking) e conflita com o alvo `ivet-v1.0`.

Ou seja, o entregável 3 completo tem **duas metades**:

1. **determinística** — a fórmula `componente → dimensão → IVET`, pura, sem
   banco: mesma entrada → mesma saída;
2. **de extração** — puxar os componentes das tabelas (B/C) e reconciliar B↔C.

A metade (2) depende de decisão de produto ainda não tomada. Esta nota entrega a
metade (1), que é *toda* especificada em §4.1/§4.3.

## Decisão de escopo

Entregar a **metade determinística** como módulo R **puro**, sem inventar a
reconciliação B↔C. É o núcleo que qualquer pipeline reprodutível precisa ter, e
não fixa prematuramente a decisão de fórmula que §6 reserva para o produto.

## O que foi feito

`analysis/edumapsr/R/ivet.R` (novo), versão de fórmula `ivet-v1.0`:

- **`ivet_normalizar(x, tipo, teto)`** — `binario` (`in_*` → {0,1}),
  `proporcao` (clamp(0,1)) e `contagem` (razão contra **teto documentado**, nunca
  crua — o defeito do `iqd` em §2.3); `NA`/não-numérico → `0`.
- **`ivet_dimensao(componentes, pesos)`** — média ponderada; `undef`/`NA` de
  *componente* vira `0` (§4.1).
- **`ivet_agregar(dimensoes, pesos)`** — média das dimensões **disponíveis**; a
  **ausente não é `0`**: sai do numerador **e** do denominador (§4.3, coerente
  com #154).
- **`ivet_v1(blocos, dataset_version, lock_path)`** — fórmula completa sobre os
  blocos A–G: publica o agregado **só** quando as territoriais mínimas
  (**mobilidade/saúde/segurança** = C–E) existem; senão `ivet = NA` e publica-se
  só o **bloco escola**. Devolve `dimensoes_disponiveis`,
  `territoriais_faltando`, `dataset_version`, `computado_em`.
- **`ivet_dataset_version(lock_path)`** — lê `dataset_version` do
  `data_pipeline/datasets.lock.json` (#135) para carimbar a proveniência do
  dataset de entrada.

Proveniência e *defaults* de design relevantes:

- **peso igual** entre dimensões é o *default* reprodutível (o doc marca os pesos
  territoriais como pendentes de dado — §4.2/§4.3);
- a **chave de conteúdo** dos dados entra no resultado (fecha o laço com o #135:
  "mesmo dataset → mesma saída").

### Arquivos

- `analysis/edumapsr/R/ivet.R` — o núcleo.
- `analysis/edumapsr/tests/testthat/test-ivet.R` — **31 asserts** (normalização,
  pesos, dimensão ausente, gate C–E, `dataset_version`, escola ausente).
- `analysis/edumapsr/{DESCRIPTION,NAMESPACE}` — `'ivet.R'` no Collate e 7
  exports.
- `docs/analises/ivet.md` — §5 ganha o núcleo; §6 marca o entregável 3 como
  **"núcleo pronto"**.

## Validação

- `tests/testthat/test-ivet.R`: **31/31 PASS**.
- Suíte completa: **PASS 1634 / FAIL 2** — `test-censo-dictionary.R:112` e
  `test-cluster.R:96`, ambas **pré-existentes em HEAD** (reproduzidas com
  `git stash`, sem esta mudança).
- `devtools::load_all()` limpo.

## Deploy

- `rex prepare` + `rex -H analytic.edumaps deploy_analytics_dev`; verificado no
  host (`ivet_versao()` → `"ivet-v1.0"`, `ivet_v1()` responde).
- Imagem Docker local `analytic` reconstruída + `up -d`.

## Armadilha registrada (roxygen)

O roxygen local é **8.1.0**; o repositório foi gerado com **8.0.0**. Rodar
`roxygen2::roxygenise()` **reordena o `NAMESPACE` inteiro** e reformata os
`importFrom`, gerando um diff enorme e não relacionado. Solução adotada: editar
o `NAMESPACE` **à mão** (bloco `ivet_*` em ordem alfabética) e manter
`Config/roxygen2/version: 8.0.0`. Quem for mexer em `@export` no `edumapsr` deve
repetir esse cuidado (ou fixar a versão do roxygen).

## Pendências (não nesta nota)

- **Extração dos componentes B/C** (reconciliação *de fórmula* B↔C) — decisão de
  produto; é o que liga este núcleo aos dados.
- Entregáveis **4** (vigência/retreino) e **5** (card do modelo).
- **Gate comum** com a #255: a **metodologia da área de influência da escola**
  (buffer/raio/setor/isócrona) — próxima investigação, decidida com o usuário.
