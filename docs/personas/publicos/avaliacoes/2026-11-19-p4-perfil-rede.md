# Reavaliação: P4 e o perfil analítico da rede (2026-11-19)

Vigésima segunda rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima primeira rodada:

| Entrega | O quê |
|---|---|
| #496 | escolas similares do perfil pelo contexto do grupo, no município inteiro, com a diferença de IDEB (RH-01, RH-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a ajuda `comparar-redes.md` ("Perfil analítico") e a ficha
    `analise/rede-municipal.md`;
  - a tela `/municipio/perfil` (seções "Rede vs. Brasil" e "Distribuição por
    grupo") e a resposta `/api/network/:codigo_ibge/profile` de Salvador
    (todas as redes e a municipal) e de Vitória;
  - o código (`model-datasource-postgres-network-profile-source.R`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** descrever a rede municipal de um município
  contra o Brasil, para a seção de contexto de um artigo ("a rede municipal
  de Salvador tem mais docentes efetivos que a média nacional"), e usar os
  grupos da rede para dizer como as escolas se dividem.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Rede municipal de Salvador contra o Brasil.** A tela compara a rede
   filtrada com "Brasil". Ela foi conferir qual Brasil é esse. O código usa
   a referência `brasil`, que é a média de **todas as redes**, inclusive as
   privadas, mesmo quando a rede é filtrada. A tela não diz isso.

   | Indicador | Salvador, municipal | "Brasil" da tela (todas) | Brasil, redes municipais | Diferença na tela | Diferença na mesma rede |
   |---|---|---|---|---|---|
   | Docentes efetivos | 57,8% | 40,2% | 53,9% | **+17,6 p.p.** | +3,9 p.p. |
   | Docentes com licenciatura | 99,7% | 79,6% | 80,6% | +20,2 p.p. | +19,1 p.p. |
   | IDEB 2023, anos finais | 4,24 | 4,74 | 4,58 | **−0,50** | −0,34 |
   | IDEB 2023, anos iniciais | 5,35 | 5,66 | 5,62 | −0,31 | −0,27 |

   - As privadas têm 0% de docentes efetivos (41.657 escolas): puxam a média
     "Brasil" para baixo, e qualquer rede pública parece muito acima.
   - No IDEB dos anos finais, a média "Brasil" mistura as estaduais (4,94) e
     as municipais (4,58).
   - O perfil da escola já compara com a **rede** no Brasil (#483); o da rede
     não.
2. **Os grupos da rede.** A ajuda diz que o perfil mostra "os grupos de
   escolas de contexto parecido", e a explicação da tela também.
   - Em **Salvador** há um único grupo, "Sem cluster", com as 1.432 escolas.
   - Em **Vitória** há dois: "Muito alta qualidade de infraestrutura" (119)
     e "Alta qualidade de infraestrutura" (61).
   - Os grupos são o `cluster_id` de `clean.school_indicators`: o último
     agrupamento que alguém rodou e gravou ali. Hoje são 3.046 escolas, todas
     do Espírito Santo (78 municípios), de um k-means de **infraestrutura**;
     um dos rótulos é "Grupo pequeno (8 escolas)".
   - A tela não diz qual agrupamento, de quando, nem com que variáveis. Outro
     agrupamento gravado amanhã muda os grupos sem aviso.
   - No grupo "Alta" de Vitória, o IDEB e o INSE se apoiam em uma escola.
   - O perfil da escola deixou de usar esse `cluster_id` na #494, pelo mesmo
     motivo.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o perfil da rede | a rede filtrada é comparada com o Brasil de todas as redes, privadas inclusive, sem dizer; os "grupos de contexto parecido" são o último agrupamento gravado (só ES, de infraestrutura), sem critério nem data (RG-01, RG-02) |

## O que funciona

- **Escolas com dado** em cada linha (#479).
- **IDEB e SAEB por etapa**, cada um com o Brasil da mesma etapa (#483).
- **O sentido de cada indicador** na cor da variação.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RG-01 | atrapalha | **A rede filtrada é comparada com o Brasil de todas as redes.** Com a rede municipal escolhida, o "Brasil" inclui privadas, estaduais e federais, e a tela não diz. Pedido: com uma rede filtrada, comparar com a mesma rede no Brasil (como o perfil da escola faz com a coluna "Rede"), e dizer na tela qual Brasil é. | Salvador, municipal: docentes efetivos +17,6 p.p. contra o Brasil de todas as redes, +3,9 p.p. contra as redes municipais; IDEB anos finais −0,50 contra −0,34 | P4, P2, P5 |
| RG-02 | atrapalha | **Os "grupos de contexto parecido" do perfil da rede são o último agrupamento gravado.** É o `cluster_id` de `clean.school_indicators`: hoje um k-means de infraestrutura, só em 78 municípios do ES; nos outros, tudo vira "Sem cluster". Sem critério, sem data, e muda quando alguém roda outro agrupamento. Pedido: um critério fixo e citável (por exemplo, o contexto do perfil da escola, #494), ou tirar a seção; o critério na ajuda. | Salvador: 1 grupo "Sem cluster" (1.432 escolas); Vitória: "Muito alta" e "Alta qualidade de infraestrutura"; 3.046 de 214.192 escolas com grupo | P4, P2 |

## Encaminhamento

Issue **#497** (RG-01 e RG-02 juntas), aberta com a aprovação do
developer.
