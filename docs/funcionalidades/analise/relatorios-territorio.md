---
titulo: Relatórios do território
modulo: analise
status: parcial
audiencia: [gestor]
relacionadas: [assistente-censo, perfil-escola, rede-municipal, painel-escola]
---

# Relatórios do território

> Módulo: `analise` · Status: 🟡 parcial · Público: `gestor`

## Resumo

O gestor escolhe um recorte geográfico (a própria escola, um município, um
estado ou uma região) e um tema, e recebe um **relatório pronto** com números,
tabelas, gráficos e um texto explicativo em linguagem simples. O relatório é
montado a partir da base pública de educação: Censo Escolar, IDEB e cadastro
de municípios. Além do relatório por tema, o gestor pode pedir uma **EDA do
município**: um relatório exploratório completo, em capítulos, com um resumo
geral.

## Para quem

Gestores escolares que precisam situar a escola e o território em que ela
está: para planejar, apresentar à comunidade ou à secretaria, ou comparar com
outros lugares do país. Pelo nível de detalhe disponível, o gestor faz hoje
também o papel de pesquisador; quando houver um perfil próprio de
pesquisador, ele concentrará as análises mais profundas.

## O que o sistema permite

- Gestor pode **escolher o assistente** que vai montar o relatório:
  - **Relatório por tema**: um relatório sobre um tema escolhido, para o
    recorte que o gestor quiser (é o funcionamento descrito abaixo);
  - **EDA do município**: um **relatório exploratório completo** de um
    município, organizado em **capítulos** (redes de ensino, professores,
    IDEB do município, escolas do município pelo IDEB e, quando a escola do
    gestor fica no município, a própria escola), com um **sumário** para
    navegar e um **resumo geral** e uma leitura do conjunto escritos de uma
    vez só. O gestor escolhe a etapa de ensino, que vale para todos os
    capítulos de IDEB. Se um capítulo não tiver dados, a EDA sai mesmo
    assim, com o aviso.
- Sistema permite que a equipe **crie novos assistentes sem programação**,
  apenas descrevendo quais temas entram, em que ordem, para quais níveis e
  para quais perfis de usuário. Os assistentes novos aparecem sozinhos na
  tela do gestor.
- Sistema pode gerar relatórios para **a escola do gestor, um município, um
  estado ou uma região**. O recorte padrão vem da escola do gestor, e ele pode
  escolher qualquer outro lugar do país.
- Sistema pode oferecer, para cada nível, **apenas os temas que os dados
  realmente cobrem**:
  - IDEB do território, por etapa e rede, comparado ao nível de cima;
  - redes de ensino (escolas, matrículas, professores, IDEB);
  - professores (quantidade, formação, vínculo);
  - perfil dos gestores escolares (estado e região);
  - tendência do IDEB (região);
  - a escola do gestor diante do município e do estado;
  - **IDEB escola a escola** no município, com mediana, intervalo, faixas e a
    posição da escola do gestor, sempre como descrição e não como julgamento;
  - **infraestrutura e IDEB** no estado: quais itens (biblioteca, internet,
    laboratório, número de professores e de matrículas) andam junto com um
    IDEB maior ou menor, com o grau de segurança estatística e o aviso de que
    associação não é causa;
  - **histórico da escola**: o IDEB da escola desde 2005 e os indicadores de
    recursos;
  - **escolas parecidas**: as escolas do país mais parecidas em
    infraestrutura, porte, professores e gestão, para comparar.
- Sistema pode apresentar o relatório em **seções**: resumo, indicadores
  principais com referência de comparação, tabelas, gráficos e um guia de
  "como ler" os números.
- Sistema pode **redigir o texto do relatório com inteligência artificial**,
  usando só os números apresentados, sem fazer contas próprias e sem afirmar
  causa. Se a IA estiver indisponível, o relatório sai mesmo assim, com um
  resumo automático.
- Sistema pode separar **análises aprofundadas** (escola a escola e
  associações) das descritivas, mostrando primeiro a leitura em linguagem
  simples e deixando os detalhes técnicos (coeficientes, margens, ajuste do
  modelo) recolhidos para quem quiser conferir.
- Sistema pode **citar a fonte de cada número** (edição do IDEB ou do Censo,
  recorte e quantidade de escolas ou municípios) e avisar quando os dados
  estão incompletos.
- Sistema pode **reaproveitar relatórios já gerados** no mesmo dia, entregando
  na hora o mesmo pedido repetido.
- Gestor pode **exportar** o relatório em **PDF**, pela impressão do
  navegador, numa versão limpa (sem menus, com os detalhes técnicos abertos e
  as fontes), ou em **Markdown**, para colar em documentos e apresentações.
- Gestor pode **salvar** os relatórios que quiser em "Meus relatórios",
  reabri-los depois exatamente como foram gerados (uma fotografia da data,
  sem novo custo de IA) e **gerar de novo** com os dados atuais. Os salvos
  ficam até o gestor excluir e são visíveis só para ele A
  lista indica qual assistente gerou cada relatório, e exportação, salvos e
  "gerar de novo" funcionam igual para a EDA, mantendo a divisão em
  capítulos.
- Sistema garante que **nenhum dado pessoal** aparece nos relatórios, que
  trazem só dados públicos e agregados.

## Valor

Dá ao gestor uma leitura **pronta e confiável** do território em minutos, sem
planilhas nem conhecimento técnico, com fonte e edição sempre explícitas. É a
base para novos assistentes que entregam análises completas a partir do mesmo
acervo público: a EDA do município já é o primeiro deles, e outros podem ser
criados pela equipe sem desenvolvimento.

## Relacionadas

- [Assistente do Censo](assistente-censo.md)
- [Perfil analítico da escola](perfil-escola.md)
- [Comparação de redes](rede-municipal.md)
- [Painel da escola](painel-escola.md)
