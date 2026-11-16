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
  edição escolhida), nível socioeconômico (INSE) e porte do município.
- Sistema pode **dizer a versão dos dados** em cada linha e no nome do
  arquivo (ano do Censo, edição do IDEB e do INSE, ano da população).
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
