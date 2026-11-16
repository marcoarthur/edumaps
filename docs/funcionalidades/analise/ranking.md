---
titulo: Ranking de escolas
modulo: analise
status: ativo
audiencia: [gestor, pesquisador, investidor]
relacionadas: [painel-escola, clusters, rede-municipal]
---

# Ranking de escolas

> Módulo: `analise` · Status: 🟢 ativo · Público: gestor, pesquisador, investidor

## Resumo

A plataforma posiciona uma escola frente às demais por indicadores diversos,
dentro do município e do estado, ajudando a situar seu desempenho.

## Para quem

Gestores e redes que querem entender onde a escola está em relação às
comparáveis; pesquisadores e investidores que avaliam desempenho relativo.

## O que o sistema permite

- Sistema pode comparar a escola com as demais por indicadores educacionais.
- Sistema pode mostrar a posição no município e no estado.
- Sistema pode combinar múltiplos indicadores em uma leitura de conjunto.
- Sistema pode **listar todas as escolas de um município** ordenadas por um
  indicador, com filtro de rede, o nível socioeconômico (INSE) ao lado e
  exportação em CSV. Os arquivos exportados dizem o recorte em cada linha
  (UF, região ou Brasil, porte e mínimo; ou o município e a rede), porque a
  posição só vale dentro dele.
- Sistema pode **comparar as redes municipais** dos municípios de um estado
  (ou de uma região, ou do Brasil) por um indicador do IDEB/SAEB: valor da edição mais recente
  (média das escolas da rede), quanto mudou desde a edição anterior e o
  contexto socioeconômico — a média dos municípios de INSE parecido —, para
  responder "quais redes mais melhoraram?" e "este município entrega parecido
  com os semelhantes?" sem leitura punitiva. Redes com poucas escolas com dado
  ficam de fora e são contadas; o mínimo de escolas por rede é ajustável.
- Sistema pode **avisar do salto atípico**: a rede cuja variação fica muito
  acima ou abaixo das outras do recorte (mais de 2 desvios padrão) é marcada,
  com o convite a conferir o dado antes de citar.
- Sistema pode **comparar redes de municípios do mesmo porte**: a população
  estimada pelo IBGE aparece ao lado de cada rede, e o filtro pelas classes
  de tamanho do IBGE refaz o ranking só entre as cidades daquele tamanho.
- Sistema pode **comparar redes de uma região** (Norte, Nordeste, Sudeste,
  Sul, Centro-Oeste): a posição, o contexto de INSE e o salto atípico passam a
  ser medidos entre as redes da região, inclusive junto com o porte.
- Sistema pode **destacar um município** na lista de redes: a posição dele
  no recorte, o motivo quando a rede fica de fora (outro recorte, outro
  porte, poucas escolas ou sem dado) e a sugestão de comparar com os de
  mesmo porte na região ou na UF dele.
- Sistema pode **ordenar do menor para o maior**, nas duas listas, para achar
  quem está no fim (ex.: escolas com menos infraestrutura).

## Valor

Transforma indicadores isolados em posição relativa, orientando metas e
prioridades de melhoria.

## Relacionadas

- [Painel da escola](painel-escola.md)
- [Clusters de escolas](clusters.md)
- [Comparação de redes](rede-municipal.md)
