# Avaliação: análises públicas (2026-11-14)

Primeira rodada de P3 a P6, que até aqui só tinham registrado "não se aplica".
Protocolo em [`../README.md`](../README.md).

- **Avaliaram:** P3 (rede privada), P4 (academia), P5 (órgãos de controle) e
  P6 (terceiro setor e jornalismo), cada uma pelo "o que usa" do perfil.
- **Não avaliaram:** P1 e P2, que já avaliaram os planos e a visão da rede.
  Os achados abaixo também valem para eles quando abrem o painel e o perfil
  da escola.
- **Material:**
  - as fichas de busca, painel e perfil da escola, ranking, clusters,
    comparação de redes, painel financeiro, folha e fontes de dados;
  - **sessão no navegador** contra a stack Docker local (`localhost:8080`),
    só leitura, com os dados reais carregados ali.
- **Recortes:**
  - Vitória (ES), código IBGE 3205309, com a EMEF de INEP 32040164;
  - Cuiabá (MT), com a EMEB de INEP 51037343, para o financeiro e a folha,
    porque só lá há folha por escola.
- ⚠️ Continua sendo um ensaio com personas simuladas. Não substitui mostrar o
  produto a uma pesquisadora, um auditor ou um jornalista de verdade.

## Vereditos

| Persona | Veredito | Motivo principal |
|---|---|---|
| P3 | **não adotaria** | a dor central (mercado local: crianças no entorno, concorrentes) não tem tela; o benchmark do perfil é bom, mas as "escolas semelhantes" trazem creche para escola de fundamental |
| P4 | **não adotaria** por ora (usaria para explorar, não para publicar) | o agrupamento não se reproduz (sem link, sem exportação, contagens que não fecham) e não há página pública de fontes e versão dos dados |
| P5 | **não adotaria** (registro; a persona não orienta produto até a decisão de posicionamento) | folha e financeiro só em 3 municípios; a ausência aparece como erro; total do custo em "NaN" |
| P6 | **adotaria com ressalvas**, só a comparação de redes | link estável e CSV por gráfico; mas sem o ano do dado na tela, um total errado e nenhum ranking de redes |

## O que funciona

- **Comparação de redes** (P5, P6): as quatro redes lado a lado, com link
  estável (`/municipio/compare?codigo_ibge=…`), tabela comparativa e
  exportação de cada gráfico em CSV, PNG e JPG. É a tela que P6 citaria.
- **Perfil da escola** (P3, P4): diz o Censo usado (2025) e quando foi
  atualizado. Mostra a escola contra o município, a rede, o Brasil e o
  próprio grupo, e a evolução do IDEB e do SAEB desde 2005.
- **Perfil da rede** (P4, P5): rede contra Brasil e a distribuição por grupo.
- **Ranking** (P4, P5, P6): diz o ano e o universo ("133º de 180", "2429º de
  3046") e exporta relatório.
- **Folha por escola** (P5), em Cuiabá: custo mensal, profissionais por mês e
  custo por categoria, com a folha detalhada por competência.

## Achados

### Defeitos (corrigir, sem decisão de produto)

| Id | Gravidade | O quê | Evidência |
|---|---|---|---|
| AN-01 | atrapalha (número errado na tela) | O total no centro das roscas sai errado: o componente recebe o número já formatado em texto. "77.662" vira **77**; "R$ 8,9 mi" vira **NaN**. | Comparação de redes de Vitória, "Matrículas por rede" (77 no lugar de 77.662); financeiro da EMEB 51037343, "Custo por categoria" (NaN). Causa: `center.number` recebe `formatInt(...)`/`formatBRLCompact(...)` em `NetworkShareDonut.svelte` e `SchoolFinance.svelte` |
| AN-02 | atrapalha | Indicador em que "menor é melhor" lido ao contrário. O sinal de atenção diz "sem especialização **no quartil superior**", enquanto a tabela marca **Q1 ⚠** para 4% (a escola está melhor que o grupo). O perfil da rede pinta de vermelho a queda de "docentes sem especialização" (−43,6%) e de "alunos por docente" (−2,7), que são melhoras. E um sinal dispara com escola e grupo em 0% ("doutorado 0,0% × 0,0%"). | Perfil da escola 32040164; perfil da rede municipal de Vitória |
| AN-03 | atrapalha | Escolas semelhantes: para uma EMEF de fundamental (anos iniciais e finais), as duas primeiras sugestões incluem creches **sem** fundamental (CMEI). A distância (0,0006 a 0,002) aparece como "Distância: 0.00" para todas. | Painel da escola 32040164; API `panel/info`, `similar_schools[].distance` |
| AN-04 | atrapalha | Ausência mostrada como erro: a folha de uma escola sem dado abre "Erro ao carregar". O financeiro diz "Sem dados" sem dizer que só 3 municípios têm folha e sem oferecer a busca do SIOPE sob demanda que a ficha descreve. | `/escola/payroll` e `/escola/financeiro` da EMEF 32040164 (Vitória) |
| AN-05 | atrapalha | Agrupamento sem prestar contas do universo. O mapa soma 167 escolas, o resumo 180, e o município tem 226. O que ficou de fora não é dito. Um grupo de **1 escola** recebe o nome "Média qualidade de infraestrutura". Os indicadores aparecem com o nome da variável ("in esgoto rede publica"). | `/cluster/geotag`, Vitória, conjunto "Infraestrutura escolar", K-Means com 3 grupos |
| AN-06 | detalhe | A busca por município não pede a UF e ordena pelo nome da escola. "Vitória" traz Porto Vitória (PR), União da Vitória (PR) e Vitória da Conquista (BA) na primeira página; Vitória (ES) não aparece (85 páginas). A comparação de redes tem autocompletar com UF, mas põe "Vitória · ES" em 8º lugar. | `/escola/search`, `/municipio/compare` |
| AN-07 | detalhe | O menu dos gráficos está em inglês ("Export to CSV"). Os links do município usam parâmetros diferentes (`codigo_ibge` na comparação, `ibge` no perfil da rede). Há jargão na tela pública: "geotag", "K-Means", "Processando clusters no motor R". "IDEB observado" no perfil não diz a etapa. | comparação de redes, perfil da rede, `/cluster/geotag`, perfil da escola |

### Lacunas (decisão de produto)

| Id | Gravidade | O quê | Para quem |
|---|---|---|---|
| AN-08 | bloqueia | Não há página pública de **fontes, metodologia e versão dos dados**. A capacidade "Fontes de dados" existe (hashes, vigência), mas só na documentação. A comparação de redes diz "Censo Escolar e IDEB" sem o ano; o financeiro e a folha não dizem fonte nem data de extração. | P4, P6 (citar), P5 (rastro) |
| AN-09 | bloqueia | O **agrupamento não se reproduz nem se cita**: a URL não guarda o recorte nem os parâmetros, e não há exportação nem lista das escolas por grupo. | P4, P6 |
| AN-10 | bloqueia | **Mercado local** para a rede privada: nada responde "quantas crianças em idade escolar há em volta da unidade e quem as atende". A população do entorno (Censo 2022) existe na área de influência, mas só no painel do gestor. | P3 |
| AN-11 | atrapalha | O **ranking é só da escola**. Não lista escolas de um recorte nem compara redes ou municípios, então "quais redes mais melhoraram no IDEB?" e "este município entrega parecido com os semelhantes?" ficam sem resposta. | P6, P5 |
| AN-12 | atrapalha | A **cobertura da folha** é de 3 municípios (Cuiabá, com 168 escolas; Taubaté (SP), só o agregado da secretaria; Alta Floresta D'Oeste, com 18 escolas — a primeira contagem incluía o agregado; o município 355410 é Taubaté, não Ubatuba, como estava aqui). Para o fiscal, a folha ainda é uma amostra. | P5 |

### Ambiente local (engenharia, fora das personas)

- **ENV-01:** a stack Docker local **não tem worker da fila `analytics`**. O
  compose sobe só `minion worker`, que atende só a fila `default`. No LXC
  existe o `edumaps-minion-analytics`. Com isso, no `localhost` agrupamento,
  Assistente do Censo, relatórios do território e resumo da cidade ficam em
  "Processando…" para sempre. Nesta rodada subi um worker temporário
  (`minion worker -q analytics` dentro do contêiner) e o derrubei no fim.

## Encaminhamento proposto

**Issues só com a aprovação do developer.** Proposta de agrupamento:

1. **Defeitos de leitura numérica** (#421): AN-01, AN-02 e AN-03, mais o "0.00".
   É o que dá número errado ou sinal trocado na tela.
2. **Ausência e cobertura honestas** (#422): AN-04 e AN-12, ou seja, dizer o que
   falta e onde há dado, e oferecer a busca do SIOPE.
3. **Agrupamento prestando contas e reprodutível** (#427): AN-05 e AN-09.
4. **Fonte, data e versão na tela, com uma página pública de fontes**
   (#428): AN-08. Destrava P4 e P6.
5. **Ranking de recorte (escolas, redes, municípios)** (#430): AN-11. Decisão de
   produto.
6. **Mercado local para a rede privada** (#429): AN-10. Decisão de produto, ligada
   ao posicionamento de P3 como público de entrada.
7. **Detalhes** (#431): AN-06 e AN-07, que cabem num PR pequeno.
8. **ENV-01** (#423): um serviço `minion-analytics` no `docker-compose.yml`
   (código, então branch e PR).

## Andamento

- 2026-11-15: #421 (PR #425), #422 (PR #426) e #423 (PR #424) mergeados.
  Resolvidos AN-01, AN-02, AN-03 (com o "0.00"), AN-04, a cobertura na tela
  (AN-12) e ENV-01. Fechamento em
  [`../ciclos/2026-11-15-analises-legiveis.md`](../ciclos/2026-11-15-analises-legiveis.md).
  AN-05 a AN-11 viraram as issues #427 a #431.
- 2026-11-15: #431 (PR #432) mergeado: AN-06 e AN-07 resolvidos. Fechamento em
  [`../ciclos/2026-11-15-busca-e-linguagem.md`](../ciclos/2026-11-15-busca-e-linguagem.md).
- 2026-11-15: #427 (PRs #433 e #434) mergeado: AN-05 e AN-09 resolvidos. Fechamento em
  [`../ciclos/2026-11-15-agrupamento-reprodutivel.md`](../ciclos/2026-11-15-agrupamento-reprodutivel.md).
- 2026-11-15: #428 (PR #435) mergeado: AN-08 resolvido. Fechamento em
  [`../ciclos/2026-11-15-fontes-e-metodologia.md`](../ciclos/2026-11-15-fontes-e-metodologia.md).
- 2026-11-15: #430 (PR #436) mergeado: AN-11 resolvido. Fechamento em
  [`../ciclos/2026-11-15-ranking-de-redes.md`](../ciclos/2026-11-15-ranking-de-redes.md).
  Fica só AN-10 (#429, decisão de produto) e AN-12 (cobertura da folha, carga).
