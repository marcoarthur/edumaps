# Reavaliação: P6 depois dos itens inexistentes, das coordenadas e das duas posições (2026-11-16)

Quarta rodada da P6 (terceiro setor e jornalismo de dados), depois de
#452 (PR #455) e #453 (PR #456), que resolveram VJ-01 a VJ-04 da terceira
rodada. VJ-05 (#454, carga do IDEB) é operacional e segue aberto.

- **Avaliou:** só a P6, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md` e `rankings.md`;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ele faria:** voltar às duas pautas da rodada anterior e
    dar o passo seguinte de cada uma.
- ⚠️ Simulação: não substitui um jornalista de verdade.
- Feita a pedido do developer. Issue **#457**, aberta com a aprovação dele.

## As pautas

1. **"Escolas sem infraestrutura básica no Piauí", agora com mapa.**
   - **Contagem:** a base do PI com as colunas `_inexistente` dá **258** de
     4.017 escolas sem água, energia ou esgoto, ou sem banheiro (179 sem
     esgoto).
   - **Muda a pauta:** os municípios com mais escolas nessa situação passam
     a ser Teresina (13), Floriano (12), Gilbués (11) e União (11). Com a
     conta errada da rodada anterior ("rede pública = 0"), Luzilândia
     liderava.
   - **Mapa:** o exemplo da ajuda (`sf::st_as_sf(...)`) roda como está.
     - 147 das 179 escolas sem esgoto têm coordenada.
     - A cobertura não esconde as escolas da pauta: 83% entre as sem
       infraestrutura básica, contra 79% nas demais (rural 81%, urbana
       79%).
     - Nenhuma coordenada fica fora do PI.
   - **O passo seguinte deu errado.** A lista das escolas de Gilbués no
     ranking de escolas, pelo indicador **Infraestrutura** e com "menor
     primeiro", não bate com a base (VK-01).
     - A escola 22063960 não tem água, energia nem esgoto. No índice, ela
       fica em **20º de 27** (1,56), e não entre as últimas.
     - As últimas (0,5 e 0,78) têm água e esgoto.
2. **"Redes do Nordeste que mais pioraram".**
   - `ordem=variacao&sentido=asc&minimo=10`: Orobó (PE, −1,06), Reriutaba,
     Quixeramobim e São Francisco do Conde, as quatro com salto atípico.
   - A nota diz "105 redes sem variação: tinham menos de 10 escolas com
     dado em 2021", e essas redes ficam no fim da lista.
   - O CSV traz `posicao_valor` e `posicao_variacao`, e a variação zero sai
     "0".

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P6 | adotaria | **adotaria** (mantido) | as duas pautas da rodada anterior saem certas, com mapa e as duas posições; o índice de infraestrutura do ranking de escolas é um número sem método na tela e não mede o que o nome sugere (VK-01) |

## O que funciona

- **A base responde a pergunta certa:** "sem" é "sem". O aviso está no
  dicionário e na ajuda, e o mapa sai pelo exemplo da própria ajuda.
- **O ranking de redes se cita sem armadilha:** as duas posições, o motivo
  da variação vazia, o salto atípico e o recorte em cada linha.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| VK-01 | atrapalha | **O índice "Infraestrutura" do ranking de escolas não tem método na tela e não é "infraestrutura básica".** A tela diz só "com Infraestrutura em 2025" e mostra 0,5, 0,78…, sem escala; a ajuda não explica. O índice (0 a 10) é a média de quatro grupos de peso igual: básico (água potável, energia **da rede pública**, esgoto da rede ou fossa séptica, lixo, banheiro), salas e equipamentos, acessibilidade e tecnologia. O básico pesa um quarto. Em Gilbués (PI), uma escola sem água, energia e esgoto fica em 20º de 27; as últimas têm água e esgoto, mas poucas salas e equipamentos. A pauta "escolas com menos infraestrutura" sai com a lista errada, e a energia solar conta como falta de energia. Pedido: (1) o método na nota e na ajuda: o que entra, os grupos, a escala; (2) um indicador de **infraestrutura básica** (água, energia e esgoto inexistentes e banheiro), ou ao menos o aviso de que o índice não mede isso. | `/ranking?aba=escolas&indicador=infraestrutura&codigo_ibge=2204402&sentido=asc`; `data_pipeline/deploy/escolas_scores.sql` | P6, P2, P4 |

## Encaminhamento

Issue aberta com a aprovação do developer (2026-11-16): **#457** (VK-01).

### Proposta original

1. **Método na tela e na ajuda** (barato, só texto): a nota do ranking de
   escolas diz a escala e os grupos de cada índice do Censo, com link para
   a explicação na ajuda.
2. **Infraestrutura básica** como indicador próprio no ranking de escolas.
   É uma decisão de produto: mexer no índice atual mudaria também o
   agrupamento e as escolas semelhantes, que o usam. Um indicador novo não
   mexe no índice.
