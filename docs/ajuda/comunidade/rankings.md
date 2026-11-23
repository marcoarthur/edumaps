---
titulo: "Rankings de redes e de escolas"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [comparar-redes, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/ranking.md
ultima_revisao: 2026-11-23
---

# Rankings de redes e de escolas

> **Para quem:** quem quer comparar redes municipais ou as escolas de um município
> **Tempo de leitura:** ~3 min

## Em 30 segundos
A página **Rankings** (botão na página inicial, ou `/ranking`) tem duas
abas: **Redes municipais**, que compara as redes dos municípios de um estado
pelo IDEB/SAEB ou os municípios pela taxa de atendimento da educação
infantil, e **Escolas de um município**, que lista as escolas por um
indicador. Não precisa de login.

## Passo a passo
1. **Redes municipais:** em **Abrangência**, escolha **uma UF**, **uma
   região** (Norte, Nordeste, Sudeste, Sul ou Centro-Oeste) ou o **Brasil
   inteiro**; depois o **indicador** e a **ordem**: pelo valor da edição mais recente ou por
   **quanto mudou** desde a edição anterior. Em **Mínimo de escolas por
   rede** dá para deixar de fora as redes muito pequenas (3, 5, 10 ou 20).
   Em **Porte do município** dá para comparar só redes de cidades do mesmo
   tamanho (ex.: de 10 mil a 20 mil habitantes). O botão **Maior primeiro /
   Menor primeiro** inverte a lista. Em **Destacar município**, digite o
   seu: a linha da rede fica marcada na tabela, e um quadro acima diz a
   posição dela no recorte. Se a rede não estiver na lista, o quadro diz por
   quê (outra UF ou região, outro porte, poucas escolas com dado ou sem dado
   na edição). Os botões **Comparar com os de mesmo porte na região** e
   **Comparar na UF** trocam o recorte para o do município, sem tirar o
   destaque. O município destacado também vem escolhido na aba **Escolas de
   um município**.
2. **Escolas de um município:** digite o município, escolha o indicador e,
   se quiser, a rede (municipal, estadual ou privada). **Menor primeiro**
   mostra o fim da lista. Para "escolas sem infraestrutura básica", use o
   indicador **Infraestrutura básica**: ele mostra "2 de 4" e, na coluna
   **Falta**, quais itens faltam (água, energia, esgoto, banheiro). A nota
   da tabela diz como cada indicador é calculado. Nos indicadores do
   IDEB/SAEB, a nota diz também quantas escolas do município oferecem a
   etapa no Censo, públicas e privadas, e quantas têm o dado: a lista não é
   o município inteiro.
3. **Para levar a outro lugar:** **Baixar CSV** exporta a tabela (separador
   `;`, abre no Excel); o endereço da página guarda os filtros, então o link
   reabre a mesma consulta. O arquivo de redes traz as duas posições,
   `posicao_valor` (pelo valor da edição) e `posicao_variacao` (por quanto
   mudou), na ordem em que a tabela está. Cada linha do arquivo diz o recorte em que a
   posição e o INSE parecido foram calculados: nas redes, `recorte` (`UF:ES`,
   `regiao:NE` ou `BR`), `porte_filtro` e `minimo_escolas`; nas escolas, o
   município e a rede escolhida (`rede_filtro`). Assim, arquivos de recortes
   diferentes podem ser juntados sem misturar as posições.
4. Da **Comparação de redes** de um município há atalhos para os dois
   rankings.
5. **Educação infantil (meta 1 do PNE):** no **Indicador** das redes
   municipais, o grupo **Educação infantil** tem **Creche (0 a 3 anos)** e
   **Pré-escola (4 e 5 anos)**. Cada linha é um município, e a lista vem
   da menor taxa para a maior, com quem está mais longe da meta no topo (o
   botão inverte).
   - Somem **Ordenar por** e **Mínimo de escolas**, que são só do IDEB.
     A abrangência, o porte e o destaque continuam.
   - A nota diz quantos municípios do recorte estão abaixo da meta, e a
     tabela marca cada um.
   - O CSV (`ranking-atendimento-creche-MT-2022.csv`) traz as três taxas,
     as crianças, as matrículas de cada conta, a meta e o recorte em toda
     linha.

## Taxa de atendimento da educação infantil

- **A conta:** matrículas na etapa ÷ crianças na idade (0 a 3 anos na
  creche, 4 e 5 na pré-escola). A meta do PNE é 50% na creche e 100% na
  pré-escola.
- **Três taxas:**
  - **todas as redes:** é a conta da meta, e a posição sai dela;
  - **rede municipal:** só as escolas da prefeitura;
  - **municipal + conveniadas:** soma as escolas privadas conveniadas com
    a prefeitura. É um teto, porque o Censo marca a escola conveniada, não
    a vaga. Só aparece quando o município tem conveniadas.
- **Anos diferentes:** as crianças são do Censo Demográfico de 2022 (IBGE),
  e as matrículas, das escolas em funcionamento no Censo Escolar mais
  recente.
- **Pode passar de 100%,** com crianças de outros municípios e fora da
  idade. Em município com poucas crianças, poucas matrículas mudam muito a
  taxa: veja a coluna **Crianças**.
- **Exemplo:** em MT, 116 dos 141 municípios estão abaixo dos 50% na
  creche. Cuiabá tem 44,9% em todas as redes (101ª de 141, da menor para a
  maior), 34,3% na rede municipal e 38,1% com as conveniadas.

## Entendendo os números
- **Escolas de um município, IDEB e SAEB:** só entram as escolas em
  funcionamento no Censo mais recente que têm o indicador na edição. O IDEB
  e o SAEB faltam sobretudo nas escolas pequenas, rurais e sem
  infraestrutura, e as privadas quase nunca têm: no Brasil, só cerca de
  metade das escolas públicas que oferecem os anos iniciais tem IDEB 2023,
  e entre as rurais, cerca de um quarto. A falta não é aleatória, então a
  lista não representa todas as escolas da etapa. Até 18/11/2026 a lista
  incluía também escolas paralisadas, extintas ou fora do Censo.
- **Valor da rede** é a **média simples das escolas municipais** com o
  indicador naquela edição. Não é o IDEB oficial da rede calculado pelo INEP.
  Só entram as escolas **em funcionamento na rede municipal no Censo mais
  recente**, como na lista de escolas e na base de análise: a escola
  paralisada, extinta, fora do Censo ou que hoje é de outra rede fica de
  fora, e a nota da tabela diz quantas são. O CSV traz essas escolas por
  rede (`escolas_fora`) e o ano do Censo da regra (`ano_censo`).
- **Para refazer a conta:** baixe a [base de análise](base-de-analise.md)
  da UF com a rede municipal e o bloco "IDEB e SAEB" (do mesmo Censo do
  `ano_censo`) e tire a média do indicador por município, com o mesmo
  mínimo de escolas. A variação se refaz com a base da edição anterior,
  nas escolas que têm o dado nas duas.
- **Variação** é a diferença para a edição anterior **nas mesmas escolas**:
  só as que têm o indicador nas duas edições. Quando nem todas as escolas da
  rede estão nas duas, o número delas aparece entre parênteses ao lado da
  variação, e o CSV traz a coluna `escolas_variacao`. A variação fica "–"
  quando a rede tem menos escolas nas duas edições que o mínimo do ranking;
  a nota da tabela conta essas redes. Em 2021, por exemplo, muitas escolas
  ficaram sem IDEB, e redes grandes podem aparecer sem variação.
  Comparar só as mesmas escolas evita que a troca de escolas entre as
  edições pareça melhora ou piora: até 18/11/2026 a variação era a média de
  uma edição menos a da outra, com escolas diferentes, e em 129 das 2.476
  redes com IDEB dos anos iniciais o sinal saía trocado.
- **INSE médio** é o nível socioeconômico médio dos alunos das escolas da
  rede. **Contexto** compara a rede com a média dos municípios do **mesmo
  quinto de INSE** no recorte: uma rede abaixo da média do estado pode estar
  acima das de contexto parecido.
- Entram só redes com **pelo menos 3 escolas** com dado (ou o mínimo que
  você escolher); as demais ficam de fora e a página diz quantas.
- **Salto atípico**: a variação da rede (nas mesmas escolas) ficou a mais de
  2 desvios padrão da média das redes do recorte (para cima ou para baixo).
  O IDEB de cada escola é o publicado pelo INEP, não um erro, mas o salto
  costuma vir de rede com poucas escolas nas duas edições ou de mudança fora
  do comum: confira os dados da rede antes de citar.
- **População** é a estimativa do IBGE para o município (o ano aparece na
  nota da tabela). O **porte** usa as classes de tamanho do IBGE: até 5 mil,
  5 a 10 mil, 10 a 20 mil, 20 a 50 mil, 50 a 100 mil, 100 a 500 mil e mais de
  500 mil habitantes. Com um porte escolhido, a posição, o INSE parecido e o
  salto atípico comparam só as redes desse porte.
- Com uma **região** escolhida, a lista junta as redes das UFs dela, e a
  posição, o INSE parecido e o salto atípico são calculados entre elas (a UF
  aparece ao lado do município). Região e porte se combinam: "municípios de
  porte e região semelhantes".
- Em **Menor primeiro**, a coluna **#** continua com a posição publicada
  (a última escola aparece no topo com o número dela).
- Escolas empatadas dividem a posição.

## O que cada índice mede
Os índices do Censo vão de 0 a 10, e maior é melhor. Os pesos de cada
parte são uma escolha do EduMaps para resumir o tema num número; não foram
estimados contra o IDEB nem contra outro resultado. Índice alto não quer
dizer IDEB alto. Para um modelo, use as partes: as da capacitação docente
estão na [base de análise](base-de-analise.md), bloco "Docência". Em todos, item sem
resposta no Censo conta como ausente. A escola sem o registro de que o
índice depende fica **sem o índice** e fora da lista daquele índice, não com
0: sem matrículas no Censo, sem capacidade de atendimento e sem diversidade;
sem docentes, sem capacitação docente; sem gestores, sem capacidade gestora.
São sobretudo centros de atendimento especializado e outras escolas sem turma
regular, que antes apareciam no fim da lista com 0.

**Versão da fórmula:** os seis índices são calculados pelo EduMaps, e cada
mudança de fórmula ganha uma versão nova. A atual é a **`indices-v7`**, de
22/11/2026: na capacitação docente, a parte de concursados fica de fora nas
escolas privadas, onde o Censo não pergunta o vínculo do docente. A
`indices-v6`, de 17/11/2026, fez o mesmo na capacidade gestora com a parte
de gestores por aluno na escola sem matrículas e a de acesso ao cargo nas
escolas privadas. A `indices-v5`, do mesmo dia, passou a lotação da capacidade de atendimento
para por turno. A `indices-v4`, também do mesmo dia, mediu a cor/raça da diversidade só com quem
declarou a cor. A `indices-v3`, ainda do mesmo dia, deixou sem o índice a escola
sem registro, em vez de 0. A
`indices-v2`, de 16/11/2026, corrigiu a inclusão na diversidade, e a
`indices-v1`, de 04/06/2026, é a fórmula original. A tela
mostra a versão ao lado de "Como se calcula", e o CSV do ranking de escolas
traz a coluna `versao_indice` em toda linha e a versão no nome do arquivo
(ex.: `ranking-escolas-2927408-diversidade_discente-2025-indices-v7.csv`).
Para os índices de todas as escolas de uma UF de uma vez, use a
[base de análise](base-de-analise.md), bloco "Índices do EduMaps". Para citar, informe a versão:
notas de versões diferentes não são comparáveis. O histórico está em
[Fontes e metodologia](fontes-e-metodologia.md).
- **Infraestrutura básica** (não é índice): quantos dos 4 itens a escola
  tem, de 0 a 4. Os itens são água, energia elétrica, esgotamento sanitário
  e banheiro. "Sem" é a resposta "inexistente" do Censo: poço, gerador,
  energia solar e fossa contam como tem. Escola sem resposta num dos itens
  fica fora da lista.
- **Infraestrutura (índice):** média de quatro grupos de peso igual:
  - básico: água potável, energia da rede pública, esgoto da rede ou fossa
    séptica, lixo e banheiro;
  - salas e equipamentos;
  - acessibilidade;
  - tecnologia.

  O básico pesa um quarto, e a energia de gerador ou solar conta como
  falta. Uma escola sem água, energia e esgoto pode ficar no meio da
  lista, à frente de escolas que têm o básico mas poucas salas e
  equipamentos.
- **Capacidade de atendimento:** alunos por sala e por turno (40%), etapas
  oferecidas (20%), tempo integral (20%) e alimentação escolar (20%). A
  lotação divide as matrículas pelas salas e pelos turnos com matrícula
  (matutino, vespertino e noturno). Antes da `indices-v5` (17/11/2026), a
  conta não considerava os turnos, e a escola de dois ou três turnos
  parecia lotada.
- **Capacitação docente:** ensino superior (30%), pós-graduação (30%),
  concursados (20%) e formação continuada (20%). O Censo só pergunta o
  vínculo do docente na escola pública: na privada, a parte de concursados
  fica de fora, e o peso dela vai para as outras. Antes da `indices-v7`
  (22/11/2026), ela contava 0, e toda escola privada ficava com no máximo
  8.
- **Diversidade discente:** cor/raça (35%), equilíbrio entre meninas e
  meninos (25%), inclusão (20%: a proporção de alunos da educação especial
  em classe comum) e EJA (20%). A cor/raça é calculada sobre as matrículas
  com cor declarada. Com menos de metade declarada, ela fica de fora e o
  peso dela vai para as outras três partes. Antes da `indices-v4`
  (17/11/2026), era sobre o total de matrículas, e a escola que não
  declarava a cor parecia mais diversa. A parte da inclusão foi corrigida na
  `indices-v2` (16/11/2026): antes ela somava as matrículas dos turnos,
  que são quase todas, e quase toda escola recebia esses pontos. Por isso
  as notas de diversidade caíram, e as da `indices-v1` não são
  comparáveis.
- **Capacidade gestora:** formação dos gestores (30%), formação em gestão
  (20%), gestores por aluno (20%), órgãos colegiados (20%) e acesso ao
  cargo por concurso, eleição ou seleção (10%). O acesso ao cargo só se
  aplica à rede pública: na privada, o gestor é escolhido pela mantenedora,
  e o Censo não tem essa categoria. Por isso, na escola privada essa parte
  fica de fora, e o peso dela vai para as outras. Na escola sem matrículas,
  a parte de gestores por aluno também fica de fora. Antes da `indices-v6`
  (17/11/2026), as duas contavam 0, e toda escola privada perdia até 1
  ponto por construção.
- **Sustentabilidade:** energia renovável, reciclagem do lixo, área verde e
  de plantio, e educação ambiental, com peso igual.

## Limitações conhecidas
- Por ora, só redes **municipais** entram no ranking de redes.
- Indicadores do Censo (infraestrutura, docentes…) entram no ranking de
  escolas, não no de redes. A exceção é a taxa de atendimento da educação
  infantil, que é do município (todas as redes), e não da rede municipal.

## Perguntas frequentes
- **Por que a posição da minha rede mudou?** Desde 20/11/2026 o ranking de
  redes conta só as escolas em funcionamento na rede municipal do Censo mais
  recente. Antes, uma escola paralisada ou extinta continuava na média da
  edição em que teve nota. Em Mário Campos/MG, por exemplo, uma escola
  paralisada com IDEB 3,0 nos anos iniciais puxava a média para 5,68, e a
  rede ficava em 216º de 302 em MG; só com as 4 em funcionamento, a média é
  6,35 e a rede fica em 68º de 298.
- **Por que a variação da minha rede mudou?** Desde 19/11/2026 ela é medida
  nas mesmas escolas das duas edições. Antes, uma rede que ganhou escolas
  novas com IDEB alto, ou perdeu escolas fracas, parecia ter melhorado sem
  que nenhuma escola tivesse mudado. Em São Sebastião da Boa Vista/PA, por
  exemplo, a variação dos anos iniciais de 2021 para 2023 era +1,15; nas 4
  escolas com IDEB nas duas edições, é +0,03.

## Veja também
- [Comparar redes](comparar-redes.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
