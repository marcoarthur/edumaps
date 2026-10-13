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

### Dicionário de dados do Censo Escolar

- Sistema pode **explicar cada coluna do Censo Escolar** (escolas, matrículas,
  docentes e gestores) com a descrição, o significado de cada código (ex.:
  "0 – Não oferece, 1 – Não exclusivamente, 2 – Exclusivamente") e os anos em
  que a informação foi coletada, a partir do **dicionário oficial do INEP**.
- Sistema pode **distinguir o que é do INEP do que é calculado pela
  plataforma** (localização no mapa, grupo de escolas semelhantes, contagens
  derivadas).
- Sistema **não aceita em silêncio** um código ou uma coluna que o dicionário
  não conhece: a verificação automática acusa o problema antes de o dado virar
  um rótulo errado na tela ou um número sem significado numa análise.
- O Assistente do Censo usa esse dicionário para entender as tabelas e
  responder com os rótulos oficiais.

### Mobilidade e trânsito

- Sistema pode **contar sinistros de trânsito por município e dia**, com o total
  de mortos e de veículos envolvidos.
- Sistema pode **manter o cadastro das localidades usadas pela fonte de
  acidentes**, resolvendo cada uma ao município correspondente pelo código
  oficial que a própria fonte publica e registando o que não resolve, com o
  motivo, em vez de o descartar.
- Sistema pode **contabilizar a frota de veículos por município**, com a
  fotografia datada de cada levantamento.
- Sistema pode **deixar por vazio o que não consegue avaliar**: a quantidade de
  feridos graves, leves e ilesos, e a quebra da frota por tipo de veículo, só
  ficam preenchidas quando a fonte as publica. Onde não há dado, o valor é
  vazio — nunca zero.
- Sistema pode **relatar o que ficou de fora**: municípios que a fonte publica e
  o cadastro não reconhece saem num relatório com o número de registos
  afectados, e localidades de acidentes que não resolvem ficam registadas com o
  motivo — nada desaparece em silêncio.

### Carga e proveniência

- Sistema pode **registrar o estado de cada carga** de fonte: carregada, em
  carga, falhou ou **não carregada**, com o motivo e a data da última
  tentativa. Uma falha **não apaga** o registro da última carga boa.
- Sistema pode **declarar o que não carrega e por quê**, em vez de fingir
  sucesso. Os motivos são concretos: o pedido de acesso à informação ainda não
  foi protocolado, o servidor da fonte está fora do ar, ou a fonte está fora do
  objetivo atual.
- Sistema pode **guardar o arquivo bruto de cada carga**, fora do banco e com
  um manifesto de integridade (origem, tamanho, assinatura, data). Assim, uma
  restauração do banco não apaga dados que não podem ser baixados de novo.
- Sistema **só busca dados de origens autorizadas**: cada carga confere a
  origem contra uma lista de fontes aprovadas. As regras de proteção de dados
  pessoais, que vetam bases individualizadas, valem para todas as cargas.
- Operador pode **escolher o recorte da carga** (por exemplo UF ou exercício)
  e ensaiar a carga sem gravar, conferindo o acesso à fonte antes de uma carga
  longa.

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
