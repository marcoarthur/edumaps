---
titulo: "Posição da escola no município e no estado"
publico: [comunidade]
modulo: comunidade
nivel: basico
status: ativo
relacionadas: [rankings, buscar-escola, fontes-e-metodologia]
funcionalidade: ../../funcionalidades/analise/ranking.md
ultima_revisao: 2026-11-19
---

# Posição da escola no município e no estado

> **Para quem:** quem quer saber onde uma escola fica entre as do município e do estado num indicador
> **Tempo de leitura:** ~3 min

## Em 30 segundos

A página de posição mostra, para um indicador (um índice do EduMaps, o IDEB,
uma nota do SAEB ou a aprovação), em que lugar a escola está entre as escolas
do município e do estado, quantas escolas empatam com ela e de quantas ela
está acima.

## Passo a passo

1. **Onde ir:** na busca de escolas, no cartão da escola, abra **Ranking**
   (o endereço é `/escola/ranking?inep=<código>`). Não precisa de login.
2. **O que ver:** o valor do indicador e, no município e no estado, "**Nº de
   T**", "**empatada com N escolas**" (quando há empate) e "**Acima de X% das
   outras escolas**". O (?) ao lado de **Posição** resume as regras.
3. **O que fazer:** troque o **Indicador** e, se quiser comparar só com a
   mesma rede, a **Rede** (municipal, estadual ou privada).
4. **Como saber que deu certo:** os números mudam com o indicador e a rede, e
   o ano do dado aparece embaixo.

## Entendendo os números

- **O total ("de T")** são as escolas que têm o indicador naquela edição, não
  todas as escolas. No IDEB e no SAEB, só entram as escolas em funcionamento
  no Censo mais recente que têm a nota; muitas, sobretudo as pequenas, as
  rurais e as privadas, não têm (veja [Rankings](rankings.md)).
- **Empate:** escolas com o mesmo valor dividem a posição. Alguns
  indicadores têm poucos valores possíveis, e o empate é grande: a
  sustentabilidade só tem 9 notas, e mais de 52 mil escolas têm 0; na
  aprovação dos anos iniciais, um terço das escolas tem 100%.
- **"Acima de X% das outras escolas"** conta só as escolas com valor
  **menor**. As empatadas não contam como abaixo. Uma escola com a nota
  mínima, empatada com outras, fica "acima de 0%".
- **Ausência não é zero:** sem o indicador, a escola não tem posição, e o
  seletor marca o indicador como indisponível.

## Limitações conhecidas

- A posição é calculada sobre as escolas com dado; ela não diz nada sobre as
  escolas sem o indicador.
- Os índices do EduMaps têm versão da fórmula (veja
  [Fontes e metodologia](fontes-e-metodologia.md)); posições de versões
  diferentes não se comparam.

## Perguntas frequentes

- **Por que a escola que tem a nota mínima aparecia "acima de 29%"?** Até
  18/11/2026 a conta tratava as escolas empatadas como se estivessem abaixo.
  Desde 19/11/2026, só contam as de valor menor, e o empate aparece na tela.
- **Por que o total do IDEB diminuiu?** Desde 19/11/2026 a posição do IDEB
  conta só as escolas em funcionamento no Censo mais recente, como a lista de
  escolas do município no [ranking](rankings.md).

## Veja também

- [Rankings de redes e de escolas](rankings.md)
- [Buscar escola](buscar-escola.md)
- [Fontes e metodologia](fontes-e-metodologia.md)
- Ficha da funcionalidade: [Ranking](../../funcionalidades/analise/ranking.md)
