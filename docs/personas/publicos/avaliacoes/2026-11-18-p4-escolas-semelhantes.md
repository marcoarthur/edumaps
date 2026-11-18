# Reavaliação: P4 e as escolas semelhantes (2026-11-18)

Décima sétima rodada da P4 (academia), a pedido do developer, depois da
entrega da décima sexta rodada:

| Entrega | O quê |
|---|---|
| #486 | série do SAEB da evolução por etapa; sem variação com uma edição (RM-01, RM-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a ajuda `escolas-semelhantes.md`;
  - a ficha `busca/similaridade.md`;
  - a seção "Escolas semelhantes" do painel da escola
    (`/api/school/:inep/panel/info`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** escolher escolas pares para um estudo de
  caso em Salvador. A ideia é pegar escolas de recursos parecidos (as seis
  notas do painel) e resultados diferentes. A ferramenta que ela ainda não
  tinha testado era "escolas semelhantes".
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A ficha e a tela.**
   - O painel sugere até 3 escolas da mesma cidade, com uma etapa em comum
     e "as notas do painel (…) mais parecidas".
   - A escola sem alguma das notas fica de fora, e a tela diz isso. São
     2.073 das 180.540 escolas ativas.
   - A comparação está em dia com as notas `indices-v6`: nenhum vetor
     diverge da MV.
2. **Abriu o método.** A comparação usa a **distância de cosseno** sobre as
   seis notas (pgvector, `<=>`).
   - O cosseno mede o **ângulo** entre os vetores, não a distância entre as
     notas.
   - Duas escolas com o mesmo "formato" de notas ficam iguais, mesmo que
     uma tenha o dobro das notas da outra: (2, 2, 2, 2, 2, 2) e
     (8, 8, 8, 8, 8, 8) têm distância 0.
3. **O caso.** No painel do Centro de Integração Familiar (CEIFAR,
   29445906, Salvador), a escola mais parecida é o Centro Educacional
   Multiplicando o Saber (29486947).

   | Escola | Atendimento | Infraestrutura | Docência | Diversidade | Gestão | Sustentabilidade |
   |---|---|---|---|---|---|---|
   | CEIFAR (a escola) | 6,76 | 8,22 | 4,11 | 4,12 | 7,07 | 6,25 |
   | 1ª pelo cosseno (29486947) | 4,44 | 5,06 | 2,25 | 1,98 | 3,89 | 3,75 |
   | 1ª pela distância entre as notas (29398037) | 7,81 | 7,39 | 3,50 | 3,61 | 7,00 | 6,25 |

   - A "mais parecida" tem notas de 2 a 3 pontos abaixo em todas as seis.
     Pela distância entre as notas, ela está a 6,3 pontos do CEIFAR; a
     escola de fato mais próxima está a 1,6.
   - Para o estudo dela, o par "recursos parecidos, resultado diferente"
     vira "recursos muito diferentes", e a diferença de IDEB seria lida como
     efeito da escola.
4. **Mediu em escala** (amostra de 2.000 escolas ativas no embedding; 1ª
   vizinha do mesmo município).

   | Critério | Diferença média de nível (média das 6 notas) | Pares com 1 ponto ou mais de diferença |
   |---|---|---|
   | cosseno (atual) | 0,39 | 133 (6,7%) |
   | distância entre as notas (euclidiana) | 0,22 | 10 (0,5%) |

   - O cosseno quase não separa as escolas. A distância da 3ª vizinha tem
     mediana 0,0088, e a #421 já tinha tirado o número do cartão porque
     saía "0.00" para todas.
5. **A ajuda.**
   - A pergunta frequente diz que "a similaridade olha o contexto, não o
     resultado". No painel, porém, ela olha as seis notas, que já são
     recursos e condições da escola.
   - O "Como saber que deu certo" fala de "porcentagem de similaridade",
     que o painel não mostra.
   - O cartão não mostra as notas da vizinha. Só abrindo os painéis um a um
     ela viu que a "mais parecida" estava em outro patamar.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem as escolas semelhantes do painel | o cosseno junta escolas de níveis diferentes; a tela diz "notas mais parecidas" (RL-01) |

## O que funciona

- **A ausência honesta:** a escola sem nota fica fora, e a tela diz o
  motivo.
- **A comparação em dia** com as notas da versão atual.
- **A etapa em comum**, que evita a creche como par de uma escola de
  fundamental.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RL-01 | atrapalha | **As escolas semelhantes do painel usam o cosseno, que ignora o nível das notas.** A tela promete "notas mais parecidas". Pedido: a distância entre as notas (euclidiana, pgvector `<->`, índice `vector_l2_ops`), com o critério escrito na ajuda. | CEIFAR × 29486947: cosseno 0,0034, mas 6,3 pontos de distância; 133 de 2.000 pares com 1 ponto ou mais de diferença de nível (10 com a euclidiana) | P4, P1, P2 |
| RL-02 | detalhe | **O cartão da vizinha não mostra o quanto ela se parece.** A ajuda fala de porcentagem, e a pergunta frequente diz que a comparação olha o contexto, não o resultado. Pedido: no cartão, as seis notas da vizinha ou a distância em pontos; a ajuda dizendo o critério de cada um dos três lugares. | cartão sem número desde a #421; ajuda "Similaridade NN%" e "olha o contexto" | P4, P1 |

## Encaminhamento

Issue **#487** (RL-01 e RL-02 juntas, como nas rodadas anteriores), aberta
com a aprovação do developer.

## Andamento

- 2026-11-18: #487 (PR #488) mergeado: RL-01 e RL-02 resolvidos (vizinhas
  pela distância euclidiana entre as seis notas; distância em pontos e
  notas no cartão; ajuda com os três critérios). O CEIFAR passa a ter a
  29398037 em primeiro (1,56 ponto). Fechamento em
  [`../ciclos/2026-11-18-semelhantes-distancia-notas.md`](../ciclos/2026-11-18-semelhantes-distancia-notas.md).
  Nenhum achado aberto.
