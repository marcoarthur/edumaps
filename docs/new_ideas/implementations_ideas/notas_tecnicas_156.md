# Nota técnica 156 — o segundo acesso entra no bloco C e o MapBiomasEscola deixa de morrer com OOM

Ciclo de fechamento das **pendências da #278** (issue já fechada no ciclo da
nota 155): o componente de transporte de 45 min entrou na fórmula do IVET e a
cópia antiga de `exportar_buffers` do `MapBiomasEscola` foi corrigida com o
mesmo padrão de lotes que salvou o `MapBiomasRisco`. As duas pendências
**grandes** demais para o ciclo viraram issues: **#295** (expansão MG/BA +
recalibração dos tetos) e **#296** (isócrona como capacidade de produto).

## Entregas

| PR / commit | Escopo |
|---|---|
| **PR #293** (`1b6bfa6`, commit `413a132`) | `feat(analytics)` `acesso_auto_45min` no default do bloco C |
| **PR #294** (`7e1675c`, commit `beb3e6e`) | `fix(backend)` `MapBiomasEscola` exporta buffers em lotes; helpers sobem para o `Job::Base` |

## 1. `acesso_auto_45min`: a decisão foi de produto, não de código

O piloto do ES (#278) já carregava a isócrona de **45 min de carro** em
`clean.isocrona_escolar` — 666.979 linhas fora da fórmula. Antes de decidir,
duas medições:

- **Correlação** com o acesso de 15 min a pé: Pearson 0,685 / **Spearman
  0,715** — os dois acessos capturam coisas diferentes (alcance local a pé vs.
  alcance regional de carro), logo não são redundantes; mas adicioná-los juntos
  muda o **peso do construto**: acesso passa de 1 de 3 para 2 de 4 no bloco C.
- **Viés de fronteira**: o anel de 45 min cruza MG/BA, cujos setores
  censitários não estão carregados na arealização. Medido: **2,90%** das
  células saem `NULL`, a mediana por escola é 0,003, mas **125 escolas** têm
  >20% e **10 escolas** >50% de subestimação da soma.

Levadas ao developer (question tool), o resultado foi **entrar no default
agora**, com a ressalva do viés documentada no card (`vies_nota`) e a correção
prometida pela expansão (#295). O teto `IVET_TETO_ACESSO_45MIN` = **1.750.000`
segue a mesma prática dos demais tetos de acesso: **provisório = p99 medido**
(p50 168.496 / p99 1.765.458 no piloto do ES) e recalibrável.

Detalhe de implementação que se repete do ciclo anterior: o `sum()` sobre
coluna INTEGER devolve **BIGINT**, e o DBI o traz ao R como `integer64` — no
qual `quantile()`/`summary()` voltam **lixo em silêncio**. As duas faixas da
CTE `c_isocrona` usam `(...)::double precision`, e o teste do SQL fixa o cast.

Validação no produto (`analytic.edumaps`, deployado via rex): percentis batem
com o piloto (168.496 / 1.765.458), `pop_acessivel_45min` em **2.897 escolas
do ES e 0 fora**, bloco C médio do ES **0,6377** (era 0,6263 com três
componentes) contra 0,3634 do resto do país, e **145.732 publicáveis**
inalterados.

## 2. MapBiomasEscola: a mesma cópia que já tinha matado o Risco

O `MapBiomasRisco` tinha um `exportar_buffers_lotes` porque o R morre com
**SIGKILL** acima de ~1.000–1.500 buffers (`terra::extract(weights=TRUE)`
materializa uma linha por célula×buffer — ~35 mil células de 30 m por buffer
de 1 km). O `MapBiomasEscola` **manteve a cópia single-shot**: um arquivo
GeoJSON com todos os buffers e **uma** chamada do R — o mesmo defeito,
adiado.

A correção remove a duplicação em vez de corrigi-la duas vezes:

- `exportar_buffers_lotes`, `conferir_lote`, `_garantir_dir` e a constante
  `TAMANHO_LOTE` (400) **sobem para `Job::Base`**; os dois jobs passam a
  herdar, e as cópias saem dos dois arquivos.
- O `run()` do Escola passa a rodar **um lote por chamada do R**, com
  `unlink` do CSV/órfãos antes de cada lote (sobra de execução anterior nunca
  conta como resultado — armadilha medida no Risco em 2026-10-19) e a
  invariante `linhas + órfãos = buffers` por lote.
- `registrar_orfaos` ganha o rótulo do lote nos logs, como no Risco.

A mecânica de lotes já é coberta por `mapbiomas_risco_loader.t`; o teste do
Escola foi reescrito para verificar o que **este** job usa (recorte, formato e
guarda), não para duplicar a suite.

> Nota de escopo: `_garantir_dir` segue duplicado em `BrazilCrime.pm` (corpo
> idêntico) e `IBGE.pm` (sem a linha de log) — dedup oportunista, fora do
> arco desta issue.

## 3. O que ficou de fora vira issue, com rastro

O usuário pediu para **prosseguir as pendências e abrir issue quando grande
demais**. O critério aplicado foi: altera infraestrutura externa, execução
longa ou escopo multi-camada?

- **#295 — expansão MG/BA + recalibração**: exige setores censitários daquelas
  UF, tiles Valhalla do extract Nordeste (BA) e reprocessamento nacional —
  infra + execução longa. Corrige de passagem o viés de fronteira medido.
- **#296 — isócrona como capacidade de produto**: API + camada no Leaflet +
  regra LGPD de agregação + capacidade em `docs/funcionalidades/` —
  multi-camada. No ciclo da #278 ficou decidido que a isócrona **não** era
  capacidade de produto (era insumo interno do IVET); esta issue é o passo
  seguinte, quando for decisão de produto torná-la visível.

## Rastreabilidade

`main` = `7e1675c` · PRs #293/#294 · issues #295/#296 · suíte `filter="ivet"`
verde (648 asserções) · loaders de mapbiomas + `job_base_scripts` +
`ingestion_runner` + `brazilcrime`/`ibge`/`cgu`/`siconfi` PASS · validações no
produto (`analytic.edumaps`, `backend.edumaps`) e na stack local
(`analytic`/`backend`/`minion` reconstruídos, md5 conferido).
