---
titulo: "Agrupar escolas parecidas no mapa"
publico: [gestor]
modulo: gestor
nivel: avancado
status: ativo
relacionadas: [perfil-da-escola, escolas-semelhantes, rede-municipal]
funcionalidade: ../../funcionalidades/analise/clusters.md
ultima_revisao: 2026-11-06
---

# Agrupar escolas parecidas no mapa

> **Para quem:** Gestor de rede ou analista que quer enxergar grupos de escolas para planejar  
> **Tempo de leitura:** ~5 min

## Em 30 segundos

Em **Análises**, você escolhe uma região e um conjunto de indicadores, e o
EduMaps separa as escolas em **grupos (clusters)** de perfil parecido,
mostrando cada grupo com uma cor no mapa. Serve para planejar ações por grupo
em vez de tratar toda a rede do mesmo jeito.

## Passo a passo

1. **Onde ir:** menu **Análises** (ou o botão **Ver análises** na página
   inicial). Não precisa de login.
2. **Recorte:** em **Recorte geotag**, escolha a **Região**; depois, se quiser,
   a **UF** e o **Município**. Cada campo só abre depois do anterior.
3. **Indicadores:** escolha um conjunto pronto (preset) ou monte sua lista com
   **Buscar indicador…**. Alguns conjuntos pedem o **Ano IDEB/SAEB**.
4. **Parâmetros:** escolha o **Algoritmo** e o **Nº de clusters** (de 2 a 10).
   Na dúvida, use **K-Means** com 4 ou 5 grupos.
5. **Gerar:** clique em **Gerar clusters** e aguarde (*"Processando clusters…
   aguarde"*).
6. **Como saber que deu certo:** o mapa mostra as escolas coloridas por grupo e
   a tabela **Resumo dos clusters** lista cada grupo com o número de escolas e
   os indicadores que mais o distinguem.

## Entendendo os resultados

- **Cluster** é só um rótulo de grupo (1, 2, 3…): o número não indica melhor ou
  pior. Leia a coluna **Indicadores principais** para saber o que caracteriza
  cada grupo.
- Mudar o recorte, os indicadores ou o número de grupos muda o resultado: é uma
  leitura exploratória, não uma classificação oficial.
- **Algoritmos:** *K-Means* separa em grupos de tamanho parecido; *Gaussian
  Mixture* aceita grupos de formatos diferentes; *DBSCAN* encontra grupos
  densos e deixa de fora escolas muito diferentes (pede **eps** e **min_pts**
  em vez do número de grupos); *Spectral* lida com grupos de formato irregular.

## Limitações conhecidas

- Escolas sem dado em algum indicador escolhido podem ficar de fora; se nenhuma
  sobrar, a tela avisa *"Nenhuma escola com cluster gerado para este recorte"*.
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
