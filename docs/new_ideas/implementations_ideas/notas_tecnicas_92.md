# Nota técnica 92 — Loader SICONFI (receitas RREO): fase 1 + deriva de migration no produto (#165, #177)

**Data**: 2026-10-08
**Escopo**: PRs #191 (fase 1 da #165 — loader de receitas SICONFI), #190
(#177 passo 2 — inventário de dependências) e #192 (correção de diagnóstico
medida em produção).
**Issues**: #165 (fase 1), #177 (passo 2).

## Resumo

Fase 1 da #165: carga de **receitas** do SICONFI pela API DataLake do
Tesouro, para `clean.siconfi_receita`, com o mapeamento decidido no issue e a
carga idempotente. O ciclo entregou também o passo 2 da #177 (inventário
`use`/`require` vs `cpanfile` + gate de CI) e fechou duas questões que só a
primeira execução real no ambiente produto revelou: o `ON CONFLICT` do
`upsert_metadata()` partia-se em qualquer base sem a migration da #164 (a
atinge **todos** os jobs, não só este), e a própria captura de erro do loader
destruía a mensagem que permitiria diagnosticar isso.

Estado final: **88 linhas** em `clean.siconfi_receita` no banco produto, com
os valores de `Impostos` de São Paulo (2026, previsão e realizado) **idênticos**
à API crua.

## Decisões de design

1. **Fonte = RREO-Anexo 01, filtrado por `anexo`.** O `/rreo` devolve **todos**
   os anexos de uma vez, e vários deles trazem receita com rótulos de coluna
   próprios: `RREO-Anexo 06` usa `PREVISÃO ATUALIZADA` (sem o `(a)`), o
   `03` usa `PREVISÃO ATUALIZADA 2025`, o `14` usa `Até o Bimestre 2025 (b)`.
   O pior caso é o **`RREO-Anexo 04`, que reusa literalmente
   `PREVISÃO ATUALIZADA (a)`** — a mesma string do Anexo 01. Sem o filtro, as
   duas linhas cairiam na mesma PK e o `ON CONFLICT` ficaria à mercê da ordem
   em que a API pagina. Os anexos temáticos expõem ainda o detalhamento RPPS
   (`ReceitaDeContribuicoesDosSegurados*`, `ReceitaPatrimonialRPPSBruta*`, ...),
   que não é a classificação econômica de receita. O `anexo` é fiável **dentro
   do que descreve** (o Anexo 01 é o Balanço Orçamentário, logo traz receita
   **e** despesa); a despesa sai depois, pela allowlist de coluna.

2. **`classificacao` decidida pela coluna, nunca pelo rótulo.**
   `PREVISÃO ATUALIZADA (a)` → `estimativa`; `Até o Bimestre (c)` → `realizada`.
   `PREVISÃO INICIAL` e `No Bimestre (b)` ficam de fora **deliberadamente**:
   são o mesmo `cod_conta` da atualizada/até-o-bimestre, e guardar as quatro
   colidiria na PK. O mesmo vale para `% (b/a)`, `% (c/a)` e `SALDO (a-c)`,
   que não são valor monetário de linha.

3. **`tipo_receita` por allowlist de folhas.** 50 `cod_conta` mapeados para
   `propria`/`transferencia`/`outros`. Totais e subtotais (`ReceitasCorrentes`,
   `TransferenciasCorrentes`, `TotalReceitas`, `OutrasReceitasCorrentes`, ...)
   ficam de fora: guardar o agregado **e** os filhos duplica qualquer soma
   posterior. Esses agregados conhecidos vivem numa tabela separada
   (`%AGREGADO`) e saem **em silêncio** — o warning ficou reservado para chave
   realmente desconhecida, que é o único caso que exige decisão humana.
   `fundeb` fica reservado no schema: o RREO não expõe a linha detalhada
   1.7.5.x, e adivinhar pelo nome da conta seria inventar dado.

4. **Paginação por `hasMore`, não por `count`.** Medido: o `count` do ORDS é
   **por página** (`limit=2` → `count=2`), não o total. A página curta só
   desencadeia o fim quando a resposta **não** traz `hasMore` — com `hasMore`
   presente, o sinal é autoritativo.

5. **`count == 0` com HTTP 200 morre.** É a armadilha clássica do esqueleto
   original: o parâmetro correto é `an_exercicio` (não `exercicio`), e com o
   nome errado a API respondia "sucesso" e a contagem zero passava como carga
   concluída.

6. **Carga transacional com `ON CONFLICT` na PK exata.** A inserção roda entre
   `begin_work`/`commit`, o `dt_snapshot` entra como parâmetro (nunca
   interpolado), e o `DO UPDATE` reprocessa a linha em vez de duplicar.

## Achados medidos (fora do escopo planeado)

1. **Deriva de migration no banco produto.** O `--job=SICONFI` falhou de
   imediato, e a causa não era do loader: `clean.import_metadata` **não tinha
   UNIQUE em `table_name`**, então o `ON CONFLICT (table_name)` do
   `Base.pm::upsert_metadata` explodia. A correção existe no repo desde
   2026-10-01 22:15 (a change `import_metadata_uniq_table_name`, issue #164),
   mas o último deploy do produto tinha sido às 18:52 do mesmo dia — **o
   produto ficou com 89 de 92 changes**. Confirmação pela contagem
   (`sqitch.plan` tem 92; registry, 89) e por `sqitch status` (limpo, 3
   undeployed: `brazilcrime_contrato_sinesp`, `brazilcrime_sem_patrimoniais`,
   `import_metadata_uniq_table_name`). Aplicado com `sqitch deploy` direto no
   `database.edumaps` (o passo 7 do `deploy_db_dev`, sem a provisão de
   pacotes/task inteira que a task arrasta consigo).
   ⚠️ **Isto afetava todos os jobs de ingestão** que chamam `upsert_metadata`:
   a ingestão "falhava" no último passo, depois de todo o trabalho carregado,
   e quem não lesse o log julgava que tinha corrido.

2. **Captura de erro destruída pelo rollback.** O `_load_receita` fazia
   `if ($@) { eval { $dbh->rollback }; die "... falhou: $@" }` — o `eval` interno
   limpa `$@`, então o `die` saía com a mensagem **vazia**. Medido em
   produção: `falhou:  at ... line 357`, impossível de diagnosticar. Captura-se
   `my $err = $@` antes do rollback; há regressão no teste.

3. **Vocabulário de receita cresce por exercício.** As chaves
   `ReceitasDeValoresMobiliariosIntra` e `TransferenciasCorrentesDoExterior`
   (1.7.5, filha de `TransferenciasCorrentes`) só apareceram em 2026 e caíram
   no warning — resolvido, mas confirma que a allowlist é um artefato a
   acompanhar, não um número fechado.

## Entregas

| PR | Conteúdo |
|----|----------|
| #190 (#177 passo 2) | `script/check_dependencies.pl`, +19 declarações no `cpanfile` (`YAML::XS` era o achado genuíno; o resto são core ou bases em string do dist), `t/06-tools/check_dependencies.t` e step na CI |
| #191 (#165 fase 1) | `SICONFI.pm` reescrito + `t/05-tasks/siconfi_loader.t` |
| #192 | Preservação da mensagem de erro + 2 chaves de 2026 + regressão |

## Testes e validação

- `t/05-tasks/siconfi_loader.t`: **10 subtestes PASS**, sem rede (UA mockado
  no mesmo shape real da API), com e sem BD real. O subteste de idempotência
  só roda com `EDUMAPS_DB_HOST` explícito — sem isso, um `prove -l t/` cru
  apontaria para o default do `edu_maps.conf` (`ubatexu.lan`), que é a base
  **errada** (armadilha dos dois contentores).
- Validação local (Docker): SP 2025 = 86 linhas, Solânea (2516003) = 22;
  `Impostos` e `TransferenciasCorrentesDaUniaoEDeSuasEntidades` batem com a
  API crua nas duas classificações.
- Validação no produto: `--job=SICONFI` → **88 linhas, 0 falhas, 0 warnings**;
  `Impostos` de SP 2026 = `72485148668` (estimativa) e `25773238399.96`
  (realizada), idênticos à API. `clean.import_metadata` registado com
  `rows=88`.
- CI verde nos três PRs (a do #191 incluiu o step novo de dependências do #177).

## Pendências

- Fase 2 da #165: despesas, FUNDEB detalhado, esforço fiscal, recorte IBGE.
- A `allowlist` de `cod_conta` precisa de acompanhamento por exercício (ver
  achado 3) — o warning é o mecanismo de detecção, e agora está calibrado
  para não ser ruido de agregados.
- A deriva do banco produto (achado 1) sugere tornar o `deploy_db_dev` rotina:
  três changes acumuladas em uma semana.
