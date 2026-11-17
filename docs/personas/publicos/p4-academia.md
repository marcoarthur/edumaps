# Persona P4: pesquisadora em políticas educacionais

> Público **P4 — Pesquisadores e academia** 🥈 do plano de negócios
> (`publicos-alvo.md`). Perfil **e** memória: as avaliações entram em
> "Entradas" (mais recente no topo). Protocolo em [`README.md`](README.md).

## Perfil

- **Quem é:** economista da educação, doutora em políticas públicas, num
  programa de pós-graduação ou instituto. Usa microdados do Censo Escolar,
  IDEB e IBGE para estudar desigualdades regionais.
- **Quem paga:** agência de fomento, instituto ou assinatura institucional
  (R$ 20 mil a 80 mil por ano, dados ou API).
- **Dor central:** montar bases de análise **reprodutíveis** sem escrever SQL
  nem federar fontes à mão.
- **Perguntas típicas:**
  - "Municípios de porte e região semelhantes têm oferta parecida?"
  - "Quanto da variação do IDEB se associa à infraestrutura, controlando por
    rede?"
  - "Como o perfil docente muda entre regiões?"
- **O que usa:** clusters, ranking, escolas similares, comparação de redes,
  fontes de dados, busca de análises, histórico de conversas.
- **O que valoriza:** metodologia explícita e citável, versão dos dados
  fixada, dado ausente tratado como ausente (#154), possibilidade de refazer
  a conta.
- **O que a faz desistir:** número sem método, base que muda sem aviso,
  resultado que não se reproduz.
- **Fonte de leitura:** a pesquisadora educacional do repositório `eduBR` (só
  leitura) é a mesma figura do lado do pacote de dados.

## Progresso por ciclo

Veredito ao fim de cada ciclo ([fechamentos](ciclos/README.md)):

- [2026-11-12 — planos de gestão](ciclos/2026-11-12-planos-de-gestao.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — visão da rede](ciclos/2026-11-13-visao-da-rede.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — fluxo do INEP](ciclos/2026-11-13-fluxo-inep.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-13 — escolas semelhantes em dia](ciclos/2026-11-13-embedding-diario.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — botão de salvar sem réplica](ciclos/2026-11-14-duplo-envio.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — envio sem duplicidade no servidor](ciclos/2026-11-14-envio-sem-duplicidade.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-14 — suíte em paralelo e backend sem o PDL](ciclos/2026-11-14-build-e-testes.md#p4--academia-pesquisadora): sem impacto direto.
- [2026-11-15 — análises públicas legíveis e ausência honesta](ciclos/2026-11-15-analises-legiveis.md#p4--academia-pesquisadora): não adotaria por ora (mantido; sem reavaliação). Regra dos sinais versionada; ficam AN-05, AN-08, AN-09.
- [2026-11-15 — busca por município, menus em PT-BR e menos jargão](ciclos/2026-11-15-busca-e-linguagem.md#p4--academia-pesquisadora): não adotaria por ora (mantido). IDEB com edição e etapa; ficam #427 e #428.
- [2026-11-15 — agrupamento que presta contas e se reproduz](ciclos/2026-11-15-agrupamento-reprodutivel.md#p4--academia-pesquisadora): não adotaria por ora (mantido). AN-05 e AN-09 resolvidos; fica #428. Reavaliar depois dela.
- [2026-11-15 — fonte, ano e versão dos dados na tela](ciclos/2026-11-15-fontes-e-metodologia.md#p4--academia-pesquisadora): não adotaria por ora (mantido). AN-08 resolvido: os três bloqueios saíram; reavaliar.
- [2026-11-15 — ranking de redes municipais e de escolas por município](ciclos/2026-11-15-ranking-de-redes.md#p4--academia-pesquisadora): não adotaria por ora (mantido; reavaliação pendente). CSV de redes com INSE.
- [2026-11-15 — ranking com salto atípico, mínimo e ordem crescente](ciclos/2026-11-15-ranking-atipico.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido). RV-01 resolvido; ficam #438 e #439.
- [2026-11-16 — versão dos dados no CSV do agrupamento](ciclos/2026-11-16-csv-versao.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido). RV-03 resolvido; fica #439.
- [2026-11-16 — porte no ranking e base de análise](ciclos/2026-11-16-base-analise.md#p4--academia-pesquisadora): adotaria com ressalvas (mantido até nova rodada). RV-02 e RV-05 resolvidos; nenhum achado da reavaliação aberto.
- [2026-11-16 — avisos da base de análise](ciclos/2026-11-16-avisos-base.md#p4--academia-pesquisadora): adotaria (mantido). BA-01, BA-03 e BA-04 resolvidos; fica #445.
- [2026-11-16 — recorte por região no ranking](ciclos/2026-11-16-ranking-regiao.md#p4--academia-pesquisadora): adotaria (mantido). BA-02 resolvido no ranking (região e porte); base por região fica na assinatura. Nenhum achado aberto.
- [2026-11-16 — região na base e recorte nos CSVs](ciclos/2026-11-16-regiao-base-csv.md#p4--academia-pesquisadora): adotaria (mantido). RG-01 e RG-02 resolvidos; fica #449 (RG-03).
- [2026-11-16 — município destacado no ranking](ciclos/2026-11-16-destaque-municipio.md#p4--academia-pesquisadora): adotaria (mantido). RG-03 resolvido; nenhum achado da P4 aberto.
- [2026-11-16 — itens inexistentes e coordenadas na base](ciclos/2026-11-16-infra-inexistente.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: infraestrutura básica sem confusão e coordenadas.
- [2026-11-16 — posição pela variação e variação vazia](ciclos/2026-11-16-variacao-csv.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: as duas posições no arquivo.
- [2026-11-16 — infraestrutura básica e método dos índices](ciclos/2026-11-16-infraestrutura-basica.md#p4--academia-pesquisadora): adotaria (mantido). Impacto pequeno: índices com método, inclusive a falha da diversidade (#459).
- [2026-11-16 — diversidade discente com a educação especial](ciclos/2026-11-16-diversidade-especial.md#p4--academia-pesquisadora): adotaria (mantido). Impacto direto: índice sem componente constante; IVET ivet-v1.4.
- [2026-11-16 — etapas oferecidas e cobertura do IDEB](ciclos/2026-11-16-etapas-cobertura.md#p4--academia-pesquisadora): adotaria (mantido). RX-02 resolvido; fica #462.
- [2026-11-16 — versão citável dos índices](ciclos/2026-11-16-versao-indices.md#p4--academia-pesquisadora): adotaria (mantido). RX-01 resolvido; nenhum achado aberto da quinta avaliação.
- [2026-11-16 — índices do EduMaps na base de análise](ciclos/2026-11-16-indices-na-base.md#p4--academia-pesquisadora): adotaria (mantido). RY-01 e RY-02 resolvidos; nenhum achado aberto da sexta avaliação.
- [2026-11-17 — índice vazio, não 0, sem registro](ciclos/2026-11-17-indices-sem-registro.md#p4--academia-pesquisadora): adotaria (mantido). RZ-01 e RZ-02 resolvidos; nenhum achado aberto da sétima avaliação.
- [2026-11-17 — partes do índice de capacitação docente](ciclos/2026-11-17-partes-capacitacao.md#p4--academia-pesquisadora): adotaria (mantido). RW-01 e RW-02 resolvidos; nenhum achado aberto da oitava avaliação.
- [2026-11-17 — cor/raça sobre os declarados](ciclos/2026-11-17-diversidade-cor-declarada.md#p4--academia-pesquisadora): adotaria (mantido), com a diversidade. RT-01 a RT-03 resolvidos; nenhum achado aberto da nona avaliação.
- [2026-11-17 — lotação por sala e por turno](ciclos/2026-11-17-atendimento-por-turno.md#p4--academia-pesquisadora): adotaria (mantido), com o atendimento. RS-01 e RS-02 resolvidos; nenhum achado aberto da décima avaliação.
- [2026-11-17 — capacidade gestora sem o zero imposto](ciclos/2026-11-17-gestora-partes.md#p4--academia-pesquisadora): adotaria (mantido). RR-01 e RR-02 resolvidos; nenhum achado aberto da décima primeira avaliação.

## Pendências

- Planos de gestão: **não se aplica** (motivo na matriz do
  [`README.md`](README.md)).
- Análises públicas: reavaliada em 2026-11-16 (**adotaria**). Os achados
  RV-01 a RV-05 foram entregues (#440 a #443). BA-01, BA-03 e BA-04 entregues
  (#446). BA-02 entregue no ranking (#447); a base por região fica na
  assinatura (decisão de produto). Quarta rodada (2026-11-16, **adotaria**):
  RG-01 a RG-03, detalhes, entregues (#450 e #451). Nenhum achado aberto. Quinta rodada
  (2026-11-16, **adotaria**): RX-02 entregue (#463) e RX-01 entregue
  (#464). Sexta rodada (2026-11-16, **adotaria**): RY-01 (índices fora da
  base) e RY-02 (versão no nome do CSV) → #465, entregues
  (#466). Sétima rodada
  (2026-11-17, **adotaria**): RZ-01 (índice 0 para escola sem registro) e
  RZ-02 (dicionário da infraestrutura) → #467 (opção A, `indices-v3`),
  entregues (#468). Oitava rodada (2026-11-17, **adotaria**): RW-01 (partes do
  índice de capacitação fora da base) e RW-02 (pesos normativos não ditos),
  → #469, entregues (#470). Nona rodada (2026-11-17, **adotaria**, sem
  a diversidade): RT-01 (parte racial mede a cor não declarada), RT-02
  (partes da diversidade fora da base) e RT-03 (motivo do INSE vazio)
  → #471, entregues (#472). Décima rodada (2026-11-17, **adotaria**, sem o
  atendimento): RS-01 (alunos por sala sem os turnos) e RS-02 (partes do
  atendimento fora da base) → #473, entregues (#474). Décima primeira rodada
  (2026-11-17, **adotaria**): RR-01 e RR-02, detalhes da capacidade gestora
  → #475 (fórmula, `indices-v6`), entregues (#476).
- Voltar a checar quando houver mais de um Censo carregado (séries) ou base
  nacional (assinatura).

## Entradas

### 2026-11-17 — Análises públicas (décima primeira rodada, capacidade gestora)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-gestora.md`](avaliacoes/2026-11-17-p4-gestora.md).

**O que tentou:**
- Fechar a revisão dos seis índices, procurando dado ausente que vira valor.

**O que funciona para ela:**
- a lotação por turno e as partes do atendimento;
- infraestrutura, sustentabilidade e colegiados sem resposta vazia.

**Barreiras:**
- RR-01 (detalhe): a escola sem matrícula conta 0 em "gestores por aluno"
  (1.774 escolas).
- RR-02 (detalhe): "acesso ao cargo" vale 0 em toda privada, por
  construção.

### 2026-11-17 — Análises públicas (décima rodada, oferta e turnos)

**Veredito:** **adotaria** (mantido), sem o índice de capacidade de
atendimento. Consolidação em
[`avaliacoes/2026-11-17-p4-oferta-e-turnos.md`](avaliacoes/2026-11-17-p4-oferta-e-turnos.md).

**O que tentou:**
- "Municípios de porte semelhante têm oferta parecida?", com o índice de
  capacidade de atendimento.
- Abrir o método e recalcular a lotação por turno.

**O que funciona para ela:**
- a diversidade corrigida e as partes na base;
- o porte na base e no ranking.

**Barreiras:**
- RS-01 (atrapalha): "alunos por sala" ignora os turnos. 14.673 das
  16.220 escolas com 0 nessa parte têm menos de 35 alunos por turno.
- RS-02 (atrapalha): as partes do índice de atendimento não estão na base.

### 2026-11-17 — Análises públicas (nona rodada, regiões e diversidade)

**Veredito:** **adotaria** (mantido), sem o índice de diversidade.
Consolidação em
[`avaliacoes/2026-11-17-p4-regioes-e-diversidade.md`](avaliacoes/2026-11-17-p4-regioes-e-diversidade.md).

**O que tentou:**
- Perfil docente por região, com SP, BA, RS, PA e GO (72.151 escolas).
- O modelo do IDEB com os seis índices e as partes da capacitação.
- Entender por que a diversidade sai negativa.

**O que funciona para ela:**
- cinco UFs baixadas em segundos;
- as partes da capacitação, que mostram o efeito dos efetivos mudando de
  sinal entre regiões.

**Barreiras:**
- RT-01 (atrapalha): a parte racial do índice de diversidade mede a cor não
  declarada (correlação 0,78; 0,99 com mais de 80% não declarada).
- RT-02 (atrapalha): as partes do índice de diversidade não estão na base.
- RT-03 (detalhe): o dicionário não diz por que o INSE é vazio (63% da
  base).

### 2026-11-17 — Análises públicas (oitava rodada, índice vazio sem registro)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-indices-v3.md`](avaliacoes/2026-11-17-p4-indices-v3.md).

**O que tentou:**
- Conferiu o vazio dos índices contra o registro de docentes e matrículas.
- Refez a comparação das redes municipais e o modelo do IDEB.
- Tentou decompor o índice de capacitação docente com a base.

**O que funciona para ela:**
- vazio só onde falta o registro, e o 0 de volta a ser nota;
- `indices-v3` em `/fontes`, no arquivo e na coluna.

**Barreiras:**
- RW-01 (atrapalha): o índice de capacitação junta partes de sinais
  opostos no modelo (licenciatura +0,34, efetivos −0,30), e a base não traz
  as partes para separá-lo.
- RW-02 (detalhe): a ajuda não diz que os pesos são uma escolha do EduMaps.

### 2026-11-17 — Análises públicas (sétima rodada, índices na base)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-17-p4-indices-na-base.md`](avaliacoes/2026-11-17-p4-indices-na-base.md).

**O que tentou:**
- Baixou a BA e o ES com os seis índices e conferiu com o ranking.
- Pôs os índices no modelo do IDEB.
- Comparou as redes municipais pela capacitação docente.

**O que funciona para ela:**
- os índices no arquivo da UF, com a versão no nome e na linha;
- a base igual ao ranking escola a escola;
- o índice de infraestrutura associado ao IDEB (0,084 por ponto,
  p < 0,001), onde a contagem básica não se associa.

**Barreiras:**
- RZ-01 (atrapalha): 312 escolas sem registro de docentes e matrículas
  ficam com 0, não vazio. Elas baixam médias municipais em até 2 pontos e
  ficam no fim do ranking de escolas.
- RZ-02 (detalhe): o dicionário da infraestrutura aponta para uma coluna
  que não está na base.

### 2026-11-16 — Análises públicas (sexta rodada, seleção do IDEB e versão dos índices)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-16-p4-versao-e-selecao.md`](avaliacoes/2026-11-16-p4-versao-e-selecao.md).

**O que tentou:**
- Refez a seleção do IDEB só com a base (BA e ES) e modelou "tem IDEB".
- Citou o índice de diversidade com a versão.
- Tentou pôr o índice de infraestrutura do EduMaps no modelo.

**O que funciona para ela:**
- as etapas oferecidas e o exemplo da ajuda, que se reproduz;
- a versão `indices-v2` em `/fontes`, na tela e no CSV, com o histórico.

**Barreiras:**
- RY-01 (atrapalha): os índices não estão na base de análise, só no ranking
  de um município por vez.
- RY-02 (detalhe): o nome do CSV do ranking de escolas não traz a versão.

### 2026-11-16 — Análises públicas (quinta rodada, índices e cobertura do IDEB)

**Veredito:** **adotaria** (mantido). Consolidação em
[`avaliacoes/2026-11-16-p4-indices-e-cobertura.md`](avaliacoes/2026-11-16-p4-indices-e-cobertura.md).

**O que tentou:**
- Juntou a BA e o ES (19.152 escolas, com a coluna `regiao`).
- Refez o modelo do IDEB com a infraestrutura básica.
- Montou os pontos com as coordenadas.
- Tentou citar a diversidade corrigida hoje.

**O que funciona para ela:**
- a região, as coordenadas e o "sem" que é "sem";
- o método de cada índice, com a data da correção.

**Barreiras:**
- RX-02 (atrapalha): o IDEB falta sobretudo nas escolas sem infraestrutura
  (12,7% contra 44,3% com nota), e a base não traz as etapas oferecidas
  para separar a falta da não oferta.
- RX-01 (atrapalha): os índices próprios não têm versão citável nem lugar
  em `/fontes`.


### 2026-11-16 — Análises públicas (quarta rodada, região no ranking)

**Veredito:** **adotaria** (mantido), agora também para comparar regiões no
ranking. Consolidação em
[`avaliacoes/2026-11-16-p4-ranking-regiao.md`](avaliacoes/2026-11-16-p4-ranking-regiao.md).

**O que tentou:**
- "Porte e região semelhantes": o ranking do Nordeste com 10 a 20 mil
  habitantes (519 redes), contra o Sul e o Brasil do mesmo porte.
- "Perfil docente entre regiões": baixou a docência das 27 UFs (22 s),
  juntou no R (180.540 escolas) e comparou a licenciatura por região e porte.

**O que funciona para ela:**
- região e porte no mesmo link, com o salto atípico e o INSE medidos no
  recorte;
- as bases das UFs se juntam sem ajuste (mesmo cabeçalho, versão na linha,
  `NA` como ausência).

**Barreiras (detalhes):**
- RG-01: a base não traz a região, e o mapa UF → região vai à mão;
- RG-02: o CSV do ranking não diz o recorte nas colunas;
- RG-03: não dá para achar um município na lista de redes.


### 2026-11-16 — Análises públicas (terceira rodada, base de análise)

**Veredito:** adotaria com ressalvas → **adotaria**, como base de artigo para
um corte transversal de uma UF; séries e Brasil inteiro, ainda não.
Consolidação em
[`avaliacoes/2026-11-16-p4-base-analise.md`](avaliacoes/2026-11-16-p4-base-analise.md).

**O que tentou:** as três perguntas do perfil.
- "IDEB × infraestrutura, controlando por rede": baixou a base do ES, abriu
  com `read.csv2()` e rodou `lm(ideb_ai ~ infra + rede + inse_media)` (822
  escolas).
- "Porte e região semelhantes": o ranking nacional de 10 a 20 mil
  habitantes.
- "Perfil docente entre regiões": o bloco de docência da base.

**O que funciona para ela:**
- a base sai sem SQL e com o IDEB por etapa ao lado do Censo;
- a versão vem em cada linha e no nome do arquivo;
- o dicionário dá a fonte e o link de cada coluna;
- ausente é `NA`, nunca zero;
- o porte refaz o ranking entre cidades do mesmo tamanho.

**Barreiras:**
- BA-01 (atrapalha): o IDEB de uma edição antiga é cruzado com o Censo 2025
  sem aviso.
- BA-02 (detalhe): não há recorte por região.
- BA-03 (detalhe): o link não fixa a versão.
- BA-04 (detalhe): falta a fórmula das proporções de docência.


### 2026-11-15 — Análises públicas (reavaliação)

**Veredito:** não adotaria por ora → **adotaria com ressalvas** (exploração e
recortes citáveis; ainda não como base de artigo). Consolidação em
[`avaliacoes/2026-11-15-analises-publicas-reavaliacao.md`](avaliacoes/2026-11-15-analises-publicas-reavaliacao.md).

- **Resolveu:** os três bloqueios (AN-05, AN-08 e AN-09).
  - O agrupamento diz o universo, guarda parâmetros e versão dos dados, tem
    link por 90 dias e CSV com os valores.
  - `/fontes` traz o ano lido da base, a data da carga e o SHA-256.
- **Atrapalha:**
  - RV-01: resultados atípicos sem aviso no topo do ranking de redes;
  - RV-02: sem exportação multi-indicador direta; o agrupamento serve de
    exportador.
- **Detalhes:**
  - RV-03: o CSV do agrupamento não traz o ano dos dados;
  - RV-05: falta o porte do município como contexto no ranking.


### 2026-11-14 — Análises públicas (primeira avaliação)

**Material:** agrupamento, escolas semelhantes, ranking, perfil da escola e
da rede, comparação de redes, numa sessão no navegador com a stack local
(Vitória, ES). Consolidação em
[`avaliacoes/2026-11-14-analises-publicas.md`](avaliacoes/2026-11-14-analises-publicas.md).

**O que tentou:** agrupar as escolas de Vitória por infraestrutura e
relacionar com o IDEB; ver onde a escola fica contra o município, a rede e
o Brasil.

**O que funciona para ela:** o perfil diz o Censo usado (2025) e quando foi
atualizado; a evolução do IDEB e do SAEB vem desde 2005; o ranking diz o
universo ("de 180").

**Barreiras:**
- AN-09 (bloqueia): o agrupamento não se reproduz. A URL não guarda os
  parâmetros, e não há exportação nem lista das escolas.
- AN-08 (bloqueia): não há página pública de fontes, metodologia e versão dos
  dados.
- AN-05 (atrapalha): 167 escolas no mapa, 180 no resumo e 226 no município,
  sem dizer quem ficou de fora. Para ela, o dado ausente tem que aparecer
  como ausente.
- AN-02 (atrapalha): o sinal de atenção lê ao contrário os indicadores em
  que menor é melhor.
- AN-03 (atrapalha): a distância das escolas semelhantes aparece como
  "0.00", sem método.

**Veredito:** **não adotaria** por ora. Usaria para explorar, não para
publicar: número sem método e resultado que não se reproduz são o que a faz
desistir.
