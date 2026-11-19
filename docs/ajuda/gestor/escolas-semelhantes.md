---
titulo: "Encontrar escolas semelhantes"
publico: [gestor]
modulo: gestor
nivel: basico
status: ativo
relacionadas: [perfil-da-escola, agrupamentos-de-escolas, painel-do-gestor]
funcionalidade: ../../funcionalidades/busca/similaridade.md
ultima_revisao: 2026-11-19
---

# Encontrar escolas semelhantes

> **Para quem:** Gestor que procura escolas parecidas para comparar e trocar experiências  
> **Tempo de leitura:** ~3 min

## Em 30 segundos

O EduMaps sugere escolas **parecidas com a sua** para você comparar resultados
com quem vive uma realidade próxima e procurar práticas que funcionam. Cada
lugar da plataforma usa um critério; a seção "Entendendo os números" diz qual.

## Passo a passo

As sugestões aparecem em três lugares:

1. **Perfil da Escola**, seção **Escolas similares** (carrega sozinha): cartões
   com nome, INEP, **Similaridade NN%**, o IDEB e, entre parênteses, a
   diferença para o IDEB da sua escola ("IDEB 5,8 (+1,1)"). Clique num cartão
   para abrir o perfil daquela escola. Mostra até 10 escolas.
2. **Painel da Escola**, seção **Escolas semelhantes** (carrega sozinha):
   até 3 escolas do mesmo município, com ao menos uma etapa em comum,
   comparadas pelas seis notas da escola (atendimento, infraestrutura,
   docência, diversidade, gestão e sustentabilidade, de 0 a 10). Os cartões
   mostram rede, etapas, matrículas, a **distância em pontos** ("a 1,6
   ponto") e as seis notas da vizinha ao lado das da sua escola. Clique para
   abrir o painel daquela escola. A comparação se atualiza sozinha todo dia
   de madrugada.
3. **Painel do Gestor** (com login), **Escolas similares**: escolha o
   **Escopo** (Município, Estado ou Região) e clique em **Buscar escolas
   similares**. O resultado aparece no mapa e numa tabela com Escola,
   Município, Porte, Localização, INSE, Etapas e Similaridade.

**Como saber que deu certo:** aparecem cartões ou linhas com a medida de
quanto a escola se parece com a sua: a porcentagem de similaridade no Perfil
e no Painel do Gestor, a distância em pontos no Painel da Escola.

## Entendendo os números

Cada lugar usa um critério:

| Onde | O que compara | Medida |
|---|---|---|
| Perfil da Escola | o contexto, com o mesmo critério do grupo de referência: rede, localização, porte, etapas e INSE, no município inteiro (distância de Gower) | similaridade em %, quanto mais perto de 100%, mais parecida |
| Painel da Escola | as seis notas do painel, nota a nota (distância euclidiana) | distância em pontos, quanto menor, mais parecida |
| Painel do Gestor | porte, localização, nível socioeconômico (INSE) e etapas | similaridade em % |

- **Similaridade e distância** não são notas de qualidade: dizem só o quanto
  a escola se parece com a sua nos critérios daquele lugar.
- **Distância em pontos (Painel da Escola):** é a raiz da soma dos quadrados
  das diferenças entre as seis notas. Se a vizinha difere 0,5 ponto em cada
  nota, a distância é 1,2 ponto; se difere 3 pontos em cada uma, 7,3 pontos.
  Uma escola com o mesmo "perfil" de notas, mas num patamar mais alto ou mais
  baixo, **não** conta como parecida: até 2026-11-18 a comparação usava o
  cosseno, que olhava só esse perfil.
- A comparação não favorece a mesma UF nem a mesma rede: uma escola estadual
  de outro estado pode ser a mais parecida.
- No Painel do Gestor, um **INSE ausente** é ignorado na comparação (não vira
  zero).
- No Painel da Escola, se falta alguma das seis notas da escola, a seção diz
  **"Sem dado para comparar"**: a escola fica fora da comparação em vez de ser
  comparada como se tivesse nota zero.
- No Perfil da Escola, as similares são as escolas mais próximas do
  **grupo de referência** (ver [Perfil da escola](perfil-da-escola.md)),
  comparadas com **todas** as escolas do município. O IDEB e a nota SAEB não
  entram na escolha: escolas de contexto igual podem ter IDEB bem diferente,
  e a diferença entre parênteses mostra quanto. Até 18/11/2026 as similares
  do Perfil eram escolhidas pelos indicadores do perfil, IDEB inclusive, e só
  entre as primeiras 299 escolas do município: as sugeridas tinham quase
  sempre o mesmo IDEB da escola.

## Limitações conhecidas

- Só entram escolas dentro de um **limite de distância** de perfil; se nenhuma
  chegar perto o bastante, a tela avisa que não encontrou escolas semelhantes.
- Escolas com poucos dados no Censo podem ter sugestões menos precisas.
- Os três lugares usam critérios um pouco diferentes, então as listas podem
  não coincidir.

## Perguntas frequentes

- **Por que a escola mais parecida tem IDEB bem diferente?** O Painel do
  Gestor olha o contexto da escola, e o Painel da Escola olha as seis notas
  do painel, que medem condições da escola (atendimento, infraestrutura,
  docência, diversidade, gestão e sustentabilidade). As similares do
  **Perfil** usam o mesmo contexto do grupo de referência. Nenhum dos três
  usa o IDEB, e essa diferença é justamente o que vale investigar: uma escola
  de contexto parecido e IDEB mais alto é um bom ponto de partida para trocar
  experiências.
- **Posso entrar em contato com a escola sugerida?** O EduMaps mostra dados
  públicos da escola; o contato é feito pelos canais oficiais dela.

## Veja também

- [Perfil da escola](perfil-da-escola.md)
- [Agrupamentos de escolas](agrupamentos-de-escolas.md)
- Ficha da funcionalidade: [Escolas semelhantes](../../funcionalidades/busca/similaridade.md)
