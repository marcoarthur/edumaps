---
titulo: Base de análise
modulo: analise
status: ativo
audiencia: [pesquisador, jornalista, terceiro-setor, gestor]
relacionadas: [ranking, clusters, rede-municipal]
---

# Base de análise

> Módulo: `analise` · Status: 🟢 ativo · Público: pesquisador, jornalista, terceiro setor, gestor

## Resumo

A plataforma entrega, sem login, uma planilha com uma linha por escola e os
indicadores escolhidos, pronta para cruzar no Excel, no R ou no Python, com a
versão dos dados e um dicionário das colunas.

## Para quem

Pesquisadores que querem testar uma relação ("quanto do IDEB se associa à
infraestrutura, controlando por rede?"), jornalistas de dados e organizações
que montam diagnósticos, sem precisar juntar as bases do INEP e do IBGE à mão.

## O que faz

- Sistema pode **exportar uma base por escola** de uma UF, de um município ou
  de uma rede, só com as escolas em funcionamento.
- Sistema pode **juntar blocos de indicadores** à escolha: infraestrutura,
  docência, IDEB e SAEB por etapa (anos iniciais, finais e ensino médio, na
  edição escolhida), nível socioeconômico (INSE) e porte do município, com
  as crianças na idade da creche e da pré-escola (Censo Demográfico), para
  a taxa de atendimento.
- Sistema pode **dizer a versão dos dados** em cada linha e no nome do
  arquivo (ano do Censo, edição do IDEB e do INSE, ano da população e do
  Censo Demográfico).
- Sistema pode **entregar as matrículas de cada escola** na educação
  básica, por etapa (creche e pré-escola separadas), na educação especial e
  em tempo integral, para medir e comparar a oferta entre municípios.
- Sistema pode **dizer quais escolas privadas são conveniadas com o poder
  público** (e com qual esfera) e a categoria da escola privada, para somar
  à oferta da prefeitura a que ela faz por convênio, avisando que a soma é
  um teto (o Censo marca a escola, não a vaga), com o código pronto para a
  soma por município.
- Sistema pode **avisar quando o IDEB e o Censo são de anos diferentes**,
  com a distância em anos e o que isso muda num modelo (escolas fechadas
  fora, infraestrutura medida depois da prova), inclusive na edição mais
  recente do IDEB, e dizer se o INSE é da mesma edição do SAEB.
- Sistema pode **identificar a região** de cada escola, para juntar as bases
  de várias UFs e comparar regiões sem tabela auxiliar.
- Sistema pode **dizer se a escola não tem água, energia ou esgoto**, além
  de se o serviço vem da rede pública, para contar as escolas sem
  infraestrutura básica sem confundir "fora da rede" com "sem".
- Sistema pode **dizer as etapas que cada escola oferece**, para separar
  "não oferece a etapa" de "não teve IDEB", e avisa, no dicionário e na
  ajuda, que a falta do IDEB se concentra nas escolas pequenas, rurais e sem
  infraestrutura.
- Sistema pode **incluir os seis índices do EduMaps** (infraestrutura,
  capacidade de atendimento, capacitação docente, diversidade discente,
  capacidade gestora e sustentabilidade, de 0 a 10), com a versão da
  fórmula em toda linha e no nome do arquivo, e o método de cada índice no
  dicionário. A escola sem o registro de que um índice depende fica com a
  célula vazia, não com 0.
- Sistema pode **entregar as partes do índice de capacidade de
  atendimento** (alunos por sala e por turno, turnos, etapas do ensino
  regular, tempo integral e alimentação), que refazem o índice.
- Sistema pode **entregar as partes do índice de capacidade gestora**
  (formação dos gestores, formação em gestão, alunos por gestor, órgãos
  colegiados e acesso ao cargo por seleção, que fica vazio nas privadas),
  que refazem o índice.
- Sistema pode **entregar as partes dos índices de infraestrutura** (básico,
  salas e equipamentos, acessibilidade e tecnologia) **e de
  sustentabilidade** (energia renovável, reciclagem, área verde e plantio,
  educação ambiental), para separar, num modelo, o saneamento dos
  equipamentos.
- Sistema pode **dar a conta pronta para refazer os seis índices** a partir
  das partes da base, conferida por um teste automático contra uma amostra
  da base.
- Sistema pode **entregar as partes do índice de diversidade discente**
  (cor/raça sobre os declarados, proporção sem cor declarada, equilíbrio de
  gênero, inclusão e EJA), que refazem o índice, e diz no dicionário por
  que o nível socioeconômico fica vazio.
- Sistema pode **entregar as partes do índice de capacitação docente**
  (ensino superior, pós-graduação, concursados e formação continuada), com as
  mesmas definições do índice, para refazê-lo e separar o efeito de cada
  parte, e **dizer que a formação continuada não é a especialização**: a
  proporção de docentes sem formação continuada tem o nome do que mede, e o
  dicionário separa a contagem de cursos da de professores. Os concursados
  ficam vazios nas privadas, onde o Censo não pergunta o vínculo do docente.
  Entrega o CEP, o bairro e o endereço de cada escola, para situar a que não
  tem coordenada (cerca de um terço das privadas). Entrega também os
  docentes por etapa, para o modelo de uma etapa separar
  as escolas pela parte do quadro naquela etapa. O dicionário diz que os pesos dos índices são uma escolha da
  plataforma, não estimados contra o IDEB.
- Sistema pode **entregar a remuneração por escola**, da folha que o
  município declara ao SIOPE, no ano escolhido: profissionais do magistério
  (cada pessoa uma vez), salário médio mensal e carga horária média sem o
  13º, salário para 40 horas e gasto com pessoal do ano. Sem nomes nem CPF;
  vazio fora da rede municipal e onde o SIOPE não separa as escolas, com o
  ano no arquivo.
- Sistema pode **dizer quem tem a folha**: os municípios da UF com folha,
  os anos e os meses de cada um, e quantas escolas do recorte têm folha no
  ano escolhido, que por padrão é o último ano completo da própria UF; e
  avisar quando o recorte sai vazio. Fecha a conta da folha de cada
  município: o total declarado, o que está nas escolas da base, o da
  Secretaria (sem escola) e o das escolas que a lista do Censo não tem.
- Sistema pode **separar pessoas pagas no ano e por mês**, e entregar os
  **auxiliares e assistentes educacionais**, que na educação infantil podem
  ser quem trabalha com as crianças quando a folha não tem magistério.
- Sistema pode **localizar cada escola** (latitude e longitude declaradas ao
  Censo Escolar), para mapas.
- Sistema pode **entregar o dicionário das colunas**, com a descrição, a
  fonte, o ano e o link oficial de cada uma.
- Sistema pode **mostrar o tamanho do recorte** (quantas escolas) antes de
  baixar.

## Valor

Tira a pesquisa do desvio de usar o agrupamento como exportador e torna a
base citável: quem recebe o arquivo sabe de onde e de que ano é cada número.

## Limites

- Uma UF por vez. A base por região ou nacional, as séries históricas e o
  acesso programático ficam fora desta capacidade (decisão de produto de
  2026-11-16, confirmada na #445; o recorte por região existe no ranking de
  redes).

## Relacionadas

- [Ranking de escolas](ranking.md)
- [Clusters de escolas](clusters.md)
- [Comparação de redes](rede-municipal.md)
