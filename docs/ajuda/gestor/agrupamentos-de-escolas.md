---
titulo: "Agrupar escolas parecidas no mapa"
publico: [gestor]
modulo: gestor
nivel: avancado
status: ativo
relacionadas: [perfil-da-escola, escolas-semelhantes, rede-municipal]
funcionalidade: ../../funcionalidades/analise/clusters.md
ultima_revisao: 2026-11-22
---

# Agrupar escolas parecidas no mapa

> **Para quem:** Gestor de rede ou analista que quer enxergar grupos de escolas para planejar  
> **Tempo de leitura:** ~5 min

## Em 30 segundos

Em **Análises**, você escolhe uma região e um conjunto de indicadores, e o
EduMaps separa as escolas em **grupos** de perfil parecido (no método
estatístico, *clusters*),
mostrando cada grupo com uma cor no mapa. Serve para planejar ações por grupo
em vez de tratar toda a rede do mesmo jeito.

## Passo a passo

1. **Onde ir:** menu **Análises** (ou o botão **Ver análises** na página
   inicial). Não precisa de login.
2. **Recorte:** em **Recorte**, escolha a **Região**; depois, se quiser,
   a **UF** e o **Município**. Cada campo só abre depois do anterior.
3. **Indicadores:** escolha um conjunto pronto ou monte sua lista com
   **Buscar indicador…**. Com indicadores do IDEB/SAEB (o conjunto
   **Desempenho dos alunos**, ou uma lista sua com alguma nota), escolha o
   **Ano IDEB/SAEB** e a **Etapa**: anos iniciais, anos finais ou ensino
   médio.
4. **Parâmetros:** escolha o **Algoritmo** (cada um com uma frase sobre como
   forma os grupos) e o **Nº de grupos** (de 2 a 10).
   Na dúvida, use **K-Means** com 4 ou 5 grupos.
5. **Agrupar:** clique em **Agrupar escolas** e aguarde (*"Agrupando as
   escolas… aguarde"*).
6. **Como saber que deu certo:** o mapa mostra as escolas coloridas por grupo e
   a tabela **Resumo dos grupos** lista cada grupo com o número de escolas e
   o que mais distingue cada grupo.
7. **Guardar e compartilhar:** a caixa **Universo** tem **Copiar link** (reabre
   este mesmo resultado, com o formulário preenchido, por 90 dias) e **Baixar
   CSV** (uma linha por escola: INEP, nome, município, rede, grupo e os
   valores dos indicadores; separador `;`, abre direto no Excel). As três
   últimas colunas, `ano_censo`, `ano_ideb` e `etapa_ideb`, dizem a versão
   dos dados e a etapa do IDEB/SAEB agrupada. Os anos também vão no nome do
   arquivo (`agrupamento-censo2025-ideb2023-….csv`):
   guardado ou renomeado, o arquivo continua dizendo de que base veio.

## Entendendo os resultados

- **Universo:** a caixa diz quantas escolas o recorte tinha, quantas foram
  agrupadas e quantas ficaram de fora, com o motivo. Escolas que **não
  funcionam mais** saem antes de agrupar. Escolas **sem dado** em algum
  indicador escolhido também saem (uma escola sem dois indicadores conta nos
  dois). Escolas agrupadas **sem coordenada** não aparecem no mapa, mas estão
  no CSV.

- **Desempenho é por etapa.** Só entram as escolas com nota na etapa
  escolhida, e o rótulo diz a etapa (*"Alto desempenho dos alunos nos anos
  iniciais"*). A escala do SAEB cresce com a série (no Brasil, em 2023,
  matemática 217 nos anos iniciais e 268 no ensino médio), e o IDEB cai.
  Até 17/11/2026, a nota da escola era a média entre as etapas dela, e os
  grupos separavam sobretudo a etapa oferecida. Uma execução guardada
  daquele tempo aparece com "etapas misturadas" e não serve para comparar
  desempenho.
- **Infraestrutura:** o conjunto conta como falta a escola **sem** energia ou
  **sem** esgoto. Energia de gerador e esgoto em fossa não são falta. Até
  17/11/2026, o conjunto usava "da rede pública", e cerca de 70 mil escolas
  com fossa contavam como sem esgoto.
- **Docência e escolas privadas:** o Censo só pergunta o vínculo do
  docente (concursado, contrato, terceirizado) na escola pública. Por isso,
  a proporção de concursados fica vazia nas privadas, e o conjunto
  **Qualidade de docência**, que usa os concursados, deixa as privadas de
  fora: a caixa **Universo** mostra quantas escolas ficaram sem dado em
  "Proporção de docentes concursados". Até 22/11/2026 a privada entrava
  com 0 concursados e caía nos grupos de baixa qualidade só por isso. Para
  comparar privadas, monte uma lista sua sem os concursados.
- **Nome dos indicadores:** a tela mostra o nome curto (*"Proporção de
  docentes concursados"*). Passe o mouse sobre o indicador para ver a
  descrição inteira, com a fórmula.
- **Sem formação continuada:** a coluna
  `prop_sem_formacao_continuada` do CSV (no **Buscar indicador…**,
  "Docentes sem formação continuada") é a proporção de docentes sem curso
  de formação continuada de 80 horas ou mais. Não é a falta de
  pós-graduação. É a mesma coluna da
  [base de análise](../comunidade/base-de-analise.md).
- **Rótulo do grupo:** com um conjunto pronto, o grupo recebe uma gradação
  (*"Alta qualidade de infraestrutura"*). Grupo com menos de 5 escolas (ou
  menos de 2% das agrupadas) aparece como **Grupo pequeno (N escolas)**, sem
  gradação: é pouco para dizer muito. Sem conjunto pronto, o rótulo é só
  **Grupo 1, 2, 3…**, e o número não indica melhor ou pior.
- **O que mais o distingue:** para cada grupo, os indicadores em que ele mais
  se afasta da média das escolas agrupadas, com o valor do grupo e a média
  geral (▲ acima, ▼ abaixo). Indicadores de sim/não aparecem como % das
  escolas do grupo.
- Mudar o recorte, os indicadores ou o número de grupos muda o resultado: é uma
  leitura exploratória, não uma classificação oficial.
- **Algoritmos:** *K-Means* separa em grupos de tamanho parecido; *Gaussian
  Mixture* aceita grupos de formatos diferentes; *DBSCAN* encontra grupos
  densos e deixa de fora escolas muito diferentes (pede **eps** e **min_pts**
  em vez do número de grupos); *Spectral* lida com grupos de formato irregular.

## Limitações conhecidas

- Escolas sem dado em algum indicador escolhido ficam de fora (a caixa
  **Universo** diz quantas); se nenhuma sobrar, a tela avisa *"Nenhuma escola
  agrupada neste recorte"*.
- O link de um agrupamento vale **90 dias**; depois, a tela avisa que a
  execução venceu. O CSV baixado continua valendo.
- Recortes grandes (uma região inteira) demoram mais para processar.
- Os grupos desta tela são gerados na hora e não alteram o grupo de referência
  usado no [Perfil da escola](perfil-da-escola.md).

## Perguntas frequentes

- **Quantos grupos devo pedir?** Comece com 4 ou 5. Se um grupo ficar com
  pouquíssimas escolas, reduza; se os grupos parecerem misturados, aumente.
- **A tela pediu para selecionar a região.** O recorte mínimo é a região;
  escolha uma antes de gerar.

## Veja também

- [Perfil da escola](perfil-da-escola.md)
- [Escolas semelhantes](escolas-semelhantes.md)
- Ficha da funcionalidade: [Agrupamentos de escolas](../../funcionalidades/analise/clusters.md)
