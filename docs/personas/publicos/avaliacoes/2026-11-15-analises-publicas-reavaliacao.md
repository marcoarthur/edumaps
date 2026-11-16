# Reavaliação: análises públicas, P4 e P6 (2026-11-15)

Segunda rodada de P4 (academia) e P6 (terceiro setor e jornalismo) depois de
os bloqueios delas serem entregues no mesmo dia:

| Achado | O quê | Entrega |
|---|---|---|
| AN-01 | total da rosca | #425 |
| AN-05 | universo do agrupamento | #433 |
| AN-08 | fonte e versão dos dados | #435 |
| AN-09 | agrupamento reprodutível | #433 e #434 |
| AN-11 | ranking de redes | #436 |

- **Avaliaram:** P4 e P6. P3 e P5 ficam como estavam: P3 depende da #429
  (decisão de produto) e P5 da decisão de posicionamento.
- **Material:**
  - as fichas de ranking, clusters, fontes de dados e comparação de redes, e
    as ajudas novas (`rankings.md`, `fontes-e-metodologia.md`);
  - **sessão no navegador** contra a stack local, só leitura, com os dados
    reais.
- **Recortes:**
  - Vitória (ES) no agrupamento (Infraestrutura, K-Means 3 e 5);
  - ranking das redes do ES e do Brasil (IDEB anos iniciais e finais);
  - `/fontes`.
- ⚠️ Simulação: não substitui uma pesquisadora e um jornalista de verdade.
- Feita durante a ausência do developer. Os achados abaixo **não viraram
  issue**: pela regra, issue só com a aprovação do developer.

## Vereditos

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | não adotaria por ora | **adotaria com ressalvas** (exploração e recortes citáveis; ainda não como base de artigo) | o agrupamento se cita e se reproduz (link, CSV com valores, parâmetros e versão dos dados) e há uma página de fontes com hash; falta um conjunto de dados multi-indicador direto, e os resultados atípicos não têm aviso |
| P6 | adotaria com ressalvas, só a comparação de redes | **adotaria** | "quais redes mais melhoraram?" tem resposta com ano, universo, CSV e link; cada tela diz a fonte |

## O que funciona

- **Citar** (P4, P6): o selo de fonte em cada tela e a página `/fontes`
  (órgão, ano lido da base, data da carga, SHA-256 dos arquivos, "carga não
  registrada" quando é o caso).
- **Reproduzir** (P4): o agrupamento guarda recorte, parâmetros, universo e a
  versão dos dados. O link reabre o mesmo resultado por 90 dias, e o CSV traz
  os valores dos indicadores por escola.
- **Ranking de redes** (P6, P4):
  - a nota de método diz que o valor é a média das escolas e não o IDEB
    oficial;
  - mostra o mínimo de 3 escolas e quantas redes ficaram de fora;
  - a variação entre edições e o contexto de INSE ("acima dos de INSE
    parecido") evitam a manchete punitiva.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RV-01 | atrapalha | **Resultados atípicos sem aviso no topo do ranking.** No IDEB anos finais do Brasil, ordenado pela variação, o topo é de redes pequenas com saltos grandes (Santana do Mundaú-AL: 3 escolas, de cerca de 7 em 2021 para 9,3 em 2023, aprovação de 100%). O dado é o publicado pelo INEP, não um erro de carga, mas um jornalista apressado faz a manchete. Pedido: marcar o salto atípico (ex.: variação acima de 2 desvios no recorte) e/ou deixar subir o mínimo de escolas na tela. | `/ranking?aba=redes&indicador=ideb_anos_finais&nacional=1&ordem=variacao` | P6, P4 |
| RV-02 | atrapalha | **Não há exportação de um conjunto multi-indicador direto.** Para "quanto do IDEB se associa à infraestrutura, controlando por rede", a pesquisadora precisa usar o agrupamento como exportador (escolhendo os indicadores na seleção livre) só para baixar o CSV. | `/cluster/geotag`, CSV da execução | P4 |
| RV-03 | detalhe | **O CSV do agrupamento não traz a versão dos dados.** A caixa Universo diz "Censo Escolar 2025 · IDEB 2023", mas o arquivo baixado sozinho só tem o `run_id` no nome. | `agrupamento-run_….csv` | P4 |
| RV-04 | detalhe | **Ranking de escolas só em ordem decrescente.** "Onde estão as escolas sem infraestrutura básica?" pede o fim da lista; dá para ler, mas não ordenar nem filtrar. | `/ranking?aba=escolas&indicador=infraestrutura` | P6 |
| RV-05 | detalhe | **Porte do município fora do ranking de redes.** "Municípios de porte e região semelhantes" (P4) só tem o contexto de INSE, não de porte. | `/ranking` | P4 |

## Encaminhamento

Issues abertas com a aprovação do developer (2026-11-15): **#437** (RV-01 e
RV-04), **#438** (RV-03) e **#439** (RV-02 e RV-05, decisão de produto).

### Proposta original

1. RV-01 e RV-04 cabem num PR pequeno: marca de salto atípico, mínimo
   ajustável e ordem crescente.
2. RV-03 é um ajuste no CSV, com colunas `ano_censo` e `ano_ideb` ou o nome do
   arquivo com a versão.
3. RV-02 e RV-05 são uma decisão de produto: uma exportação de "base de
   análise" para a P4 (assinatura de dados/API, no plano de negócios).

## Andamento

- 2026-11-15: #437 (PR #440) mergeado: RV-01 e RV-04 resolvidos. Fechamento em
  [`../ciclos/2026-11-15-ranking-atipico.md`](../ciclos/2026-11-15-ranking-atipico.md).
