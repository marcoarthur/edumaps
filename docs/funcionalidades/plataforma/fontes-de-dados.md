---
titulo: Fontes de dados
modulo: plataforma
status: ativo
audiencia: [pesquisador, gestor, investidor]
relacionadas: [painel-escola, ranking, folha-pagamento, inventario]
---

# Fontes de dados

> Módulo: `plataforma` · Status: 🟢 ativo · Público: pesquisador, gestor, investidor

## Resumo

A plataforma se sustenta em bases públicas de educação e território, tratadas e
organizadas para virar indicadores e painéis. Essas bases não são apenas
consumidas: a plataforma **mantém um catálogo próprio delas**, avaliando o que
pode ou não pode entrar, e por quê.

## Para quem

Toda a plataforma; e quem precisa saber de onde vêm os números.

## O que o sistema permite

### Bases em uso

- Sistema pode usar o **Censo Escolar** (escolas, matrículas, docentes,
  infraestrutura, equipamentos).
- Sistema pode usar o **IDEB/SAEB** para desempenho ao longo do tempo.
- Sistema pode usar o **SIOPE** para dados de financiamento da educação.
- Sistema pode usar bases do **IBGE** para território e população.
- Sistema pode usar o **OpenStreetMap** para os equipamentos públicos ao redor
  das escolas (transporte, saúde, cultura e lazer, segurança etc.).
- Sistema pode usar **dados oficiais de trânsito** (acidentes registados e frota
  municipal) para melhorar a leitura de mobilidade e segurança no entorno das
  escolas e do município.

### Mobilidade e trânsito

- Sistema pode **contar sinistros de trânsito por município e dia**, com o total
  de mortos e de veículos envolvidos.
- Sistema pode **manter o cadastro das localidades usadas pela fonte de
  acidentes**, resolvendo cada uma ao município correspondente e distinguindo o
  que casou exactamente do que casou por semelhança de nome.
- Sistema pode **contabilizar a frota de veículos por município**, com a
  fotografia datada de cada levantamento.
- Sistema pode **deixar por vazio o que não consegue avaliar**: a quantidade de
  feridos graves, leves e ilesos, e a quebra da frota por tipo de veículo, só
  ficam preenchidas quando a fonte as publica. Onde não há dado, o valor é
  vazio — nunca zero.
- Sistema pode **relatar o que ficou de fora**: municípios que a fonte publica e
  o cadastro não reconhece saem num relatório com o número de registos
  afectados, e não desaparecem em silêncio.

### Curadoria de novas fontes

- Plataforma pode **catalogar fontes de dados abertas candidatas**, além do
  Censo, do OSM e do SIOPE, cobrindo saúde, segurança pública, conectividade,
  investimentos planejados, mobilidade e meio ambiente.
- Plataforma pode **avaliar cada candidata** antes de adotar: licença de
  reutilização, formato de acesso (API oficial ou não), granularidade
  (escolar, municipal, estadual), cobertura geográfica, periodicidade,
  risco de proteção de dados e o quanto complementa o que já existe.
- Plataforma pode **classificar a prioridade de adoption** de forma explícita e
  rastreável, com critérios pontuados e registro do motivo de cada rebaixamento.
- Plataforma pode **descartar formalmente** uma fonte — e registrar por quê.
  Fontes com licença restritiva, sem desagregação municipal, dependentes de
  coleta automatizada frágil ou com risco de dados pessoais sem mitigação ficam
  fora do escopo, com a decisão documentada.
- Plataforma pode **exigir evidência**: nenhuma fonte é prioritária sem licença,
  endpoint e granularidade confirmados em fonte oficial. Campo não confirmado
  mantém a fonte fora da prioridade máxima.
- Plataforma pode **planejar a incorporação em fases**, do esboço de ingestão à
  promoción para uso na interface, priorizando o que mais destrava os
  indicadores que faltam.

## Limites conhecidos

- Nem toda dimensão de vulnerabilidade tem dado público utilizável: algumas
  áreas só existem em sistemas restritos, e o catálogo registra isso como
  lacuna aberta em vez de estimar valor.
- Prioridade alta **não** significa licença liberada: em vários casos falta
  confirmação formal de uso por parte do órgão, e isso é uma pendência
  explícita, não um detalhe.
- Conectividade e segurança têm uma **assimetria**: existe a fonte primária,
  mas seu acesso automatizado é frágil ou restrito.

## Valor

Rastreabilidade e credibilidade: os indicadores derivam de fontes oficiais e
reprodutíveis. O catálogo acrescenta a garantia de que **nenhuma fonte entra por
oportunismo** — entra porque foi verificada, pontuada e justificada, e o que
ficou de fora também está escrito.

## Relacionadas

- [Painel da escola](../analise/painel-escola.md)
- [Ranking de escolas](../analise/ranking.md)
- [Folha de pagamento](../analise/folha-pagamento.md)
- [Inventário escolar](../gestor/inventario.md)
