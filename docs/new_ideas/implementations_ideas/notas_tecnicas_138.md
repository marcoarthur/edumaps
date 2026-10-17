# Nota técnica 138 — #266: renda do responsável no bloco B (ivet-v1.2)

Esta nota documenta como a dimensão **renda** do bloco **B (socioeconômico)** do
IVET (#137) ganhou **fonte real por setor**, ponta a ponta — loader → coluna do
setor → arealização do entorno → componente do índice. PR **#267**
(merge `d253f54`); issue **#266**. Sobe a fórmula para **`ivet-v1.2`**.

## Contexto

A decisão registrada na **#238** era: *"o Censo 2022 não publica renda por setor
— não há ZIP a carregar"*. A decisão estava **incompleta**: os *Agregados por
Setores Censitários* de facto não trazem renda, mas o IBGE publica a **renda do
responsável** num **produto irmão**:

```
Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/
  Agregados_por_setores_renda_responsavel_BR_20260508_csv.zip
  dicionario_de_dados_renda_responsavel_20260508.xlsx
```

| variável | conteúdo |
|---|---|
| `V06001` | nº de responsáveis (peso da arealização) |
| `V06004` | rendimento nominal médio mensal do responsável (R$) |
| `V06006` | rendimento nominal mediano mensal do responsável (R$) |

Duas diferenças de formato face aos demais temas: o CSV usa **ponto** decimal
(os outros usam vírgula pt-BR) e a célula suprimida/`X`/vazio vira `NULL` (nunca
0 — #154).

O que segue **sem fonte por setor**: escolaridade 25+ (`esc_*`) e renda
**per capita** (`rend_per_capita` — o produto é do responsável, não da
população). Nada disso é estimado.

## O que foi feito

### Loader — `backend/lib/EduMaps/Ingestion/Job/SetoresCenso2022.pm`

- Novo tema `renda_responsavel`, lido da **base irmã** (`URL_RENDA`) via
  `_url_zip($tema)`.
- Ramo de **ponto decimal** no parser (`%DECIMAL_PONTO`), separado do caminho
  vírgula; `%TIPO_COLUNA` marca `rend_media`/`rend_mediana` como `numeric` e
  `rend_resp_count` como `integer`.
- `rend_media` (V06004) **sai** de `@SEM_FONTE`; entram `rend_mediana` (V06006)
  e `rend_resp_count` (V06001).
- Campos sem fonte permanecem: `pct_sem_instrucao`/`pct_fund_incomp`
  (`esc_*`), `renda_per_capita` e `cor_sem_decl`.

### Changes Sqitch (append ao plano; nada reordenado/reescrito)

1. **`censo2022_setor_renda_responsavel`** — `ALTER TABLE clean.censo2022_setor`
   adiciona `rend_mediana NUMERIC` e `rend_resp_count INTEGER`; re-`COMMENT` de
   `rend_media` (fonte V06004) e de `rend_per_capita` (segue sem fonte).
   `requires: censo2022_setor comments_ingestao_p2`.
2. **`escola_entorno_socioeconomico_renda`** — adiciona
   `renda_resp_media`/`renda_resp_mediana` a
   `clean.escola_entorno_socioeconomico` e redefine
   `refresh_escola_entorno_socioeconomico()`. `requires:
   escola_entorno_socioeconomico_saneamento censo2022_setor_renda_responsavel`.

### Decisão de desenho: peso da arealização de renda

Instrução e saneamento pesam pela **área** de interseção. A renda **não** — o
que importa é **quantas pessoas recebem** aquele rendimento. O peso passa a ser

```
w_renda(setor) = rend_resp_count × w / area_setor
```

ou seja, o nº estimado de responsáveis do setor dentro da área de influência.
`w` é o peso da interseção espacial e `area_setor` normaliza a parte do setor que
cai no buffer. A **mediana** arealizada é a média ponderada das medianas
setoriais — **aproximação** documentada (não é a mediana da distribuição de
pessoas, que o agregado não permite reconstruir).

### Núcleo da fórmula — `analysis/edumapsr/R/ivet*.R` (`ivet-v1.2`)

- Componente `renda` ligado a `renda_resp_media`; entra no **default** do bloco
  B: `componentes = c("analfabetismo", "renda", "saneamento")`.
- `ivet_versao()` → `"ivet-v1.2"`.
- Teto `IVET_TETO_RENDA` (2 SM jul/2022 = R$ 2.424) mantido e **documentado como
  renda do responsável** (não per capita): `1 − clamp(renda/teto, 0, 1)`.
- Componente ausente entra `NA` (fora do denominador, `ivet_agregar`) — #154.

### Verifies

`sqitch verify` roda **todos** os verifies no estado final do banco, por isso o
assert de versão do verify antigo `escola_entorno_socioeconomico_saneamento.sql`
foi editado de `ivet-v1.1` → `ivet-v1.2`. Editar o **corpo** de um script já
verificado **não** altera o `change_id` (o que alteraria seria mexer em
`requires`/posição). Os dois verifies novos usam o padrão `DO … RAISE` (assert
real, não `SELECT` que nunca falha).

## Validação

| Checagem | Resultado |
|---|---|
| `sqitch deploy` + `verify` no `dev_docker` | verde (todas as changes + as 2 novas) |
| `backend/t/05-tasks/setores_censo_loader.t` | PASS — renda lê `2453.03` (não `245303`); `X`/vazio → `NULL` + flag |
| `backend/t/escola_entorno_socioeconomico.t` | PASS — ponderação por responsáveis; ausência → `NULL`; `versao` = `ivet-v1.2` |
| `testthat::test_local(filter="ivet")` | PASS |
| CI "Perl contra o banco de fixtures" | **pass** (7m 37 s) |

## Estado e deploy

- Código mergeado (#267) e deployado: `rex prepare` + `deploy_db_dev` +
  `deploy_backend_dev` + `deploy_minion_dev` + `deploy_analytics_dev`.
- Produto (`database.edumaps`) conferido: `censo2022_setor` tem
  `rend_media/rend_mediana/rend_resp_count`; `versao` default = `ivet-v1.2`.
- Imagens locais `sqitch`/`backend`/`minion`/`analytic` reconstruídas pós-merge.

## Pendências

- **Materializar o conteúdo de renda no produto**: re-executar o loader (tema
  renda) e re-materializar o entorno (`refresh_entorno_socioeconomico` /
  `clean.refresh_escola_entorno_socioeconomico`, ~2 h+ para o país). Não rodado
  neste ciclo (que foi código + deploy). Até lá, `renda_resp_media` fica `NULL`
  no produto e o bloco B agrega só instrução+saneamento (renda fora por `NA`,
  não por 0).
- Instrução 25+ (`esc_*`): segue sem fonte por setor — limitação de dado, não
  bloqueio.
