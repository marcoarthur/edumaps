---
titulo: "Rankings de redes e de escolas"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [comparar-redes, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/ranking.md
ultima_revisao: 2026-11-16
---

# Rankings de redes e de escolas

> **Para quem:** quem quer comparar redes municipais ou as escolas de um município
> **Tempo de leitura:** ~3 min

## Em 30 segundos
A página **Rankings** (botão na página inicial, ou `/ranking`) tem duas
abas: **Redes municipais**, que compara as redes dos municípios de um estado
pelo IDEB/SAEB, e **Escolas de um município**, que lista as escolas por um
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
   da tabela diz como cada indicador é calculado.
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

## Entendendo os números
- **Valor da rede** é a **média simples das escolas municipais** com o
  indicador naquela edição. Não é o IDEB oficial da rede calculado pelo INEP.
- **Variação** é a diferença para a edição anterior ("–" quando a rede não
  tinha escolas suficientes com dado nela). A nota da tabela conta essas
  redes e diz o mínimo. Em 2021, por exemplo, muitas escolas ficaram sem
  IDEB, e redes grandes podem aparecer sem variação.
- **INSE médio** é o nível socioeconômico médio dos alunos das escolas da
  rede. **Contexto** compara a rede com a média dos municípios do **mesmo
  quinto de INSE** no recorte: uma rede abaixo da média do estado pode estar
  acima das de contexto parecido.
- Entram só redes com **pelo menos 3 escolas** com dado (ou o mínimo que
  você escolher); as demais ficam de fora e a página diz quantas.
- **Salto atípico**: a variação da rede ficou a mais de 2 desvios padrão da
  média das redes do recorte (para cima ou para baixo). O número é o publicado
  pelo INEP, não um erro, mas costuma vir de rede pequena ou de mudança fora
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
mudança de fórmula ganha uma versão nova. A atual é a **`indices-v3`**, de
17/11/2026: a escola sem registro fica sem o índice, não com 0. A
`indices-v2`, de 16/11/2026, corrigiu a inclusão na diversidade, e a
`indices-v1`, de 04/06/2026, é a fórmula original. A tela
mostra a versão ao lado de "Como se calcula", e o CSV do ranking de escolas
traz a coluna `versao_indice` em toda linha e a versão no nome do arquivo
(ex.: `ranking-escolas-2927408-diversidade_discente-2025-indices-v3.csv`).
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
- **Capacidade de atendimento:** alunos por sala (40%), etapas oferecidas
  (20%), tempo integral (20%) e alimentação escolar (20%).
- **Capacitação docente:** ensino superior (30%), pós-graduação (30%),
  concursados (20%) e formação continuada (20%).
- **Diversidade discente:** cor/raça (35%), equilíbrio entre meninas e
  meninos (25%), inclusão (20%: a proporção de alunos da educação especial
  em classe comum) e EJA (20%). A parte da inclusão foi corrigida na
  `indices-v2` (16/11/2026): antes ela somava as matrículas dos turnos,
  que são quase todas, e quase toda escola recebia esses pontos. Por isso
  as notas de diversidade caíram, e as da `indices-v1` não são
  comparáveis.
- **Capacidade gestora:** formação dos gestores (30%), formação em gestão
  (20%), gestores por aluno (20%), órgãos colegiados (20%) e acesso ao
  cargo por concurso, eleição ou seleção (10%).
- **Sustentabilidade:** energia renovável, reciclagem do lixo, área verde e
  de plantio, e educação ambiental, com peso igual.

## Limitações conhecidas
- Por ora, só redes **municipais** entram no ranking de redes.
- Indicadores do Censo (infraestrutura, docentes…) entram no ranking de
  escolas, não no de redes.

## Veja também
- [Comparar redes](comparar-redes.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
