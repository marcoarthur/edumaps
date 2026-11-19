---
titulo: "Comparar redes"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [buscar-escola, rankings, base-de-analise, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/rede-municipal.md
ultima_revisao: 2026-11-19
---

# Comparar redes

> **Para quem:** quem quer ver, num município, como as redes federal,
> estadual, municipal e privada dividem a oferta e como se saem
> **Tempo de leitura:** ~4 min

## Em 30 segundos
Escolha um município e veja, lado a lado, as redes que atendem a educação
ali: escolas, matrículas, docentes, etapas e o IDEB ao longo dos anos. Cada
rede tem um perfil analítico, que a compara com a média da mesma rede no
Brasil.

## Passo a passo
1. **Onde ir:** na busca de escolas, escolha o município e clique em
   **Comparar Redes do Município**. Também dá para chegar pelo nome do
   município no [ranking de redes](rankings.md).
2. **O que ver:**
   - a **tabela** com escolas, matrículas, docentes, etapas, alunos por
     docente e docentes com ensino superior de cada rede;
   - os gráficos de **escolas e matrículas por rede** e de matrículas por
     etapa;
   - a **linha do IDEB** por rede e etapa, de 2005 até a edição mais recente;
   - o mapa com as escolas.
3. **Perfil analítico:** acima da tabela, **Ver perfil analítico** abre uma
   rede (ou todas juntas) comparada com o Brasil, e as escolas divididas pelo
   nível socioeconômico dos alunos (INSE).

## Entendendo os números
- **Só escolas em funcionamento.** As escolas paralisadas ou extintas no
  Censo Escolar não entram: não têm aluno, e contá-las inflava o número de
  escolas e baixava os alunos por escola. É a mesma contagem do perfil, da
  lista de escolas do ranking e da [base de análise](base-de-analise.md). O
  ranking de redes é outra conta: a média das escolas com IDEB naquela
  edição, inclusive as que fecharam depois.
- **Matrículas e docentes** são do Censo Escolar mais recente. Quem dá aula
  em mais de uma escola conta em cada uma.
- **Médias simples.** "Alunos por docente" e "% docentes com superior" são
  somas da rede (todas as matrículas sobre todos os docentes). As médias do
  IDEB e do perfil são médias das escolas, cada escola com o mesmo peso, sem
  ponderar por matrícula.
- **Linha do IDEB.** Cada ponto é a média das escolas da rede com IDEB
  naquela edição e etapa. Passe o mouse no ponto para ver em quantas escolas
  a média se apoia. Uma escola que fechou depois continua na edição em que
  teve nota.
- **Perfil analítico:**
  - **com qual Brasil:** com uma rede escolhida, a comparação é com a
    **mesma rede no país** (a rede municipal com as redes municipais do
    Brasil, por exemplo); sem filtro, com todas as redes. A linha
    "Comparada com" e o título da coluna dizem qual, com o número de escolas.
    Até 18/11/2026 a comparação era sempre com todas as redes, privadas
    inclusive: na rede municipal de Salvador, os docentes efetivos apareciam
    17,6 pontos acima do Brasil; contra as redes municipais, são 3,9;
  - **os níveis do INSE:** as escolas da rede ficam divididas pelo nível
    socioeconômico na classificação do INEP (Nível I, o mais baixo, a
    Nível VIII), com a média de cada indicador em cada nível. As faixas são
    do INEP e valem para o país todo. **Sem INSE** junta as escolas sem o
    indicador: as privadas e a maior parte das creches e pré-escolas. Até
    18/11/2026 essa seção mostrava os grupos do último agrupamento rodado na
    plataforma, que só existiam em alguns municípios;
  - a coluna **Escolas com dado** diz em quantas escolas cada média se
    apoia. O IDEB, a nota do SAEB e o INSE só existem em parte das escolas:
    as privadas não têm, e as creches e pré-escolas quase nunca;
  - o **IDEB e a nota do SAEB do perfil** vêm por etapa (anos iniciais,
    anos finais e ensino médio), cada linha comparada com o Brasil na mesma
    etapa. A escala do SAEB cresce com a série e o IDEB cai, então etapas
    diferentes não se comparam.
- **n/d ou –** = não disponível (#154). Ausência nunca é zero.

## Limitações conhecidas
- Só o Censo Escolar mais recente está carregado: matrículas e docentes não
  têm série histórica aqui. O IDEB tem.
- O mapa mostra só as escolas com coordenadas no cadastro.
- Para refazer as contas ou cruzar com outros dados, baixe a
  [base de análise](base-de-analise.md) do município.

## Privacidade
Somente dados públicos e agregados.

## Perguntas frequentes
- **Por que o número de escolas mudou?** Desde 17/11/2026, a comparação conta
  só as escolas em funcionamento. Antes contava também as paralisadas e
  extintas, cerca de 16% a mais no Brasil.
- **Por que a rede privada quase não tem IDEB?** O SAEB avalia todas as
  escolas públicas, mas só uma amostra das privadas, e o IDEB por escola
  quase não sai para elas. Quando a rede não tem nenhuma escola com nota
  numa etapa, a linha dela não aparece.
- **Por que a diferença para o Brasil mudou?** Desde 19/11/2026, uma rede
  escolhida é comparada com a mesma rede no Brasil. Antes, a média do Brasil
  juntava todas as redes; as privadas, sem docentes efetivos e com menos
  docentes licenciados, puxavam essa média para baixo.
- **Por que os grupos viraram níveis do INSE?** Os grupos antigos vinham de
  um agrupamento rodado na plataforma: mudavam quando alguém rodava outro e
  só existiam em parte dos municípios. Os níveis do INSE são públicos, do
  INEP, e iguais em todo lugar.

## Veja também
- [Rankings](rankings.md)
- [Base de análise](base-de-analise.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
- [Buscar escola](buscar-escola.md)
