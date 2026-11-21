---
titulo: "Painel público da escola"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [buscar-escola, posicao-da-escola, fontes-e-metodologia, privacidade]
funcionalidade: ../../funcionalidades/analise/painel-escola.md
ultima_revisao: 2026-11-21
---

# Painel público da escola

> **Para quem:** quem quer conhecer uma escola: famílias, a comunidade, quem pesquisa
> **Tempo de leitura:** ~4 min

## Em 30 segundos

O painel mostra o retrato de uma escola com dados públicos: as etapas que ela
oferece, a infraestrutura, as matrículas, a posição nos indicadores, a
vulnerabilidade de acesso, o mapa, escolas parecidas e a série do IDEB. Cada
bloco diz de onde vem o dado. Um × quer dizer "não tem"; **n/d** quer dizer
que o dado não existe, e nunca é lido como "não tem".

## Passo a passo

1. **Onde ir:** busca de escolas → escolha a escola → **Painel**.
2. **O que ver:** os blocos, de cima para baixo (tabela abaixo).
3. **O que fazer:** passe o mouse num ícone para ler o item e o estado; num
   cartão de indicador, **ver a posição →** abre a posição da escola no
   município, no estado e no Brasil.

| Bloco | O que mostra | Fonte e ano |
|---|---|---|
| Cabeçalho | rede e matrículas | Censo Escolar (o mais recente carregado, dito ao lado do número) |
| Etapas de ensino | creche, pré-escola, anos iniciais e finais, médio, EJA e educação profissional | Censo Escolar, mesmo ano |
| Infraestrutura | água potável, energia, esgoto, coleta de lixo, internet, biblioteca, laboratórios, quadra, rampas de acessibilidade e alimentação | Censo Escolar, mesmo ano |
| Indicadores | os seis índices do EduMaps, o IDEB e a taxa de aprovação, com a posição no município | índices: Censo Escolar; IDEB e aprovação: INEP, edição dita no cartão |
| Vulnerabilidade de acesso | o IVET da escola | ver [IVET](../gestor/ivet.md) |
| Localização | o mapa e a área de influência | coordenadas do Censo Escolar |
| Escolas semelhantes | as três escolas do município com as notas mais parecidas | os seis índices |
| Desempenho | a série do IDEB por etapa | INEP |

## Entendendo os números

- **Ícone aceso:** a escola oferece a etapa ou tem o item.
- **Ícone com ×:** não oferece ou não tem, segundo o Censo.
- **Ícone com n/d:** o Censo não traz o dado da escola. Ausência nunca é
  zero (#154).
- **Esgoto e energia:** o ícone acende quando a escola tem o serviço, seja da
  rede pública, seja por outra solução (fossa, gerador, placa solar). O
  texto abaixo do ícone diz qual: "rede pública" ou "outra solução". O × fica
  só para a escola que não tem esgoto ou energia nenhuma. É a mesma regra da
  [base de análise](base-de-analise.md) (`in_esgoto_inexistente`,
  `in_energia_inexistente`).
- **Rampas de acessibilidade:** o ícone mede só as rampas, a mesma coluna da
  base (`in_acessibilidade_rampas`). As outras partes da acessibilidade
  (corrimão, piso tátil, sinalização, banheiro adaptado) entram no índice de
  infraestrutura.
- **Matrículas:** o total da educação básica da escola no Censo
  (`qt_mat_bas`), que já inclui a educação infantil, a EJA e o médio. O
  painel não classifica a escola por porte: não há uma classificação oficial
  de porte de escola, e o número com o ano basta.
- **Cartões de indicadores:** "N de T" é a posição no município; quando
  outras escolas têm o mesmo valor, o cartão diz "empatada com N escolas", e
  "acima de X% das outras escolas" conta só as de valor menor. A regra está
  em [Posição da escola](posicao-da-escola.md).

## Limitações conhecidas

- Os dados do Censo são de um ano só (o mais recente carregado); o painel
  ainda não mostra a série do Censo.
- Os números do painel são os mesmos da base de análise, que é a fonte para
  quem quer refazer as contas.

## Privacidade

- **Sem dado pessoal:** nada de alunos, professores ou famílias aparece aqui;
  só dados da escola.
- O princípio é o do mínimo necessário (LGPD). Ver [Privacidade](privacidade.md).

## Perguntas frequentes

- **Por que o painel diz menos matrículas do que antes?** Até novembro de
  2026 o número somava a educação infantil, a EJA e o médio de novo ao total
  da educação básica, que já os contém. Agora é o total do Censo.
- **A escola tem fossa. Por que o esgoto aparece aceso?** Porque ela tem
  esgotamento sanitário, só que não da rede pública: o texto do ícone diz
  "outra solução".
- **Por que um ícone tem n/d e não ×?** O Censo não informa aquele item para
  a escola. Não dá para dizer que ela não tem.

## Veja também

- [Buscar escola](buscar-escola.md)
- [Posição da escola](posicao-da-escola.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
- [Base de análise](base-de-analise.md)
- [Privacidade](privacidade.md)
- Ficha da funcionalidade: [Painel da escola](../../funcionalidades/analise/painel-escola.md)
