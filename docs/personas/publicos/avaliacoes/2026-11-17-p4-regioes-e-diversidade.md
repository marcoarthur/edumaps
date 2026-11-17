# Reavaliação: P4 com as partes da capacitação, por região (2026-11-17)

Nona rodada da P4 (academia), depois da entrega da oitava rodada:

| Entrega | O quê |
|---|---|
| #470 | partes do índice de capacitação docente na base (`prop_superior`, `prop_pos_graduacao`, `prop_formacao_continuada`) e pesos ditos normativos (RW-01, RW-02) |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md` e `rankings.md`, e o dicionário da base;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** a pergunta do perfil "como o perfil
    docente muda entre regiões?", com uma UF por região (SP, BA, RS, PA e
    GO), e o modelo do IDEB com os seis índices.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Cinco UFs, uma por região.**
   - Baixou a base com todos os blocos: 72.151 escolas. SP, a maior, levou
     4,8 s e tem 9 MB.
   - Juntou tudo com `rbind`. A base nacional segue fora (decisão de
     produto: assinatura), mas cinco downloads servem a pergunta.
2. **Perfil docente por região** (escolas públicas; RW-01 resolvido).

   | Região | Superior | Pós | Efetivos | Formação continuada | Índice |
   |---|---|---|---|---|---|
   | Centro-Oeste (GO) | 0,95 | 0,71 | 0,69 | 0,66 | 7,70 |
   | Nordeste (BA) | 0,77 | 0,47 | 0,54 | 0,69 | 6,16 |
   | Norte (PA) | 0,86 | 0,32 | 0,41 | 0,61 | 5,56 |
   | Sudeste (SP) | 0,96 | 0,47 | 0,61 | 0,39 | 6,29 |
   | Sul (RS) | 0,92 | 0,64 | 0,64 | 0,71 | 7,38 |

   - SP tem o maior superior e a menor formação continuada, e o índice
     esconde as duas coisas.
   - Os efetivos mudam por rede e região: 0,94 nas estaduais da BA, contra
     0,29 nas do RS.
3. **O modelo do IDEB** (anos iniciais, escolas públicas; 15.357 escolas;
   com rede, localização, UF e INSE; R² 0,61).
   - Cinco índices saem positivos.
   - **A diversidade discente sai negativa:** −0,095 por ponto, p < 0,001.
   - Nas partes da capacitação, a pós soma (+0,37) e os efetivos subtraem
     (−0,20).
   - Com a interação, o efeito dos efetivos é positivo no Centro-Oeste
     (+0,18) e negativo no Nordeste e no Norte (−0,44 nos dois, contando a
     interação). O efeito muda de sinal entre regiões, e só as partes
     mostram isso.
4. **Tentou entender a diversidade negativa.**
   - A base não traz as partes do índice: cor/raça, gênero, inclusão e EJA.
   - O avaliador reconstruiu as partes do Censo, com as expressões da MV:
     o índice refeito bate em 71.360 de 71.360 escolas.
   - **A parte de cor/raça mede, sobretudo, a cor não declarada.**
     - A fórmula é 1 menos a soma dos quadrados das proporções de branca,
       preta, parda, amarela e indígena, todas sobre o **total** de
       matrículas. As não declaradas ficam fora da soma, mas dentro do
       denominador.
     - A correlação entre a parte racial e a proporção sem cor declarada é
       0,78.
     - Média da parte racial pela proporção não declarada:

       | Não declarada | até 10% | 10% a 30% | 30% a 50% | 50% a 80% | mais de 80% |
       |---|---|---|---|---|---|
       | Parte racial | 0,39 | 0,58 | 0,76 | 0,91 | 0,99 |

     - 5.874 escolas (8%) têm mais da metade das matrículas sem cor
       declarada, e 199 não declaram nenhuma: essas ganham a nota máxima de
       "diversidade". A não declaração vai de 7% (GO) a 17% (SP), e é de 24%
       nas privadas.
   - No modelo com as partes, a não declaração entra com +0,29 e a parte
     racial com −0,68. A inclusão (educação especial em classe comum) é
     positiva (+0,53, p < 0,001), mas o índice soma tudo e sai negativo.
   - **Para ela, a parte racial do índice não é citável** como medida de
     diversidade (RT-01), e a base não traz as partes para conferir (RT-02).
5. **O INSE vazio.**
   - 63% da base não tem INSE: 100% das privadas e 60% das municipais
     (sobretudo creches e pré-escolas, fora do SAEB).
   - Entre as escolas com IDEB, só 8 de 15.368 ficam sem INSE, então o
     modelo dela não é afetado.
   - Mas o dicionário diz só "INSE médio dos alunos da escola", sem o
     motivo do vazio, ao contrário do IDEB (RT-03).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o índice de diversidade | as partes da capacitação respondem à pergunta das regiões e mostram um efeito que muda de sinal; mas a parte racial do índice de diversidade mede a cor não declarada, e ela não cita esse índice até a correção (RT-01) |

## O que funciona

- **Cinco UFs em segundos:** a pergunta regional cabe na base por UF.
- **Capacitação decomposta:** as partes contam o que o índice esconde
  (SP: superior alto, formação continuada baixa).
- **Reprodutível:** índice refeito exatamente com as partes.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RT-01 | atrapalha | **A parte de cor/raça do índice de diversidade mede a cor não declarada.** As proporções são sobre o total de matrículas, e as não declaradas ficam fora da soma dos quadrados. Quanto menos a escola declara, mais "diversa" ela fica: com mais de 80% não declarada, a parte racial é 0,99. Pedido: proporções sobre as matrículas **com cor declarada** e, abaixo de um mínimo de declaração (ex.: metade), a parte racial vazia, com o peso redistribuído ou o índice vazio. Muda a fórmula: `indices-v4`. | correlação 0,78; 5.874 escolas (8%) com mais de 50% não declarada, 199 com 100%; parte racial −0,68 e não declaração +0,29 no modelo do IDEB | P4, P6, P5 |
| RT-02 | atrapalha | **As partes do índice de diversidade não estão na base.** Sem elas, a diversidade negativa no modelo não se explica: a inclusão é positiva, e a cor/raça e a EJA são negativas. Pedido, como na #469: as partes (diversidade racial, proporção sem cor declarada, equilíbrio de gênero, inclusão e EJA) num bloco ou no bloco dos índices, com as expressões da MV. | índice refeito pelo avaliador: 71.360 de 71.360 | P4 |
| RT-03 | detalhe | **O dicionário não diz por que o INSE é vazio.** O INSE só existe para as escolas com alunos no SAEB: as privadas nunca têm, e as creches e pré-escolas quase nunca. Pedido: o motivo do vazio na descrição de `inse_media` e `inse_classificacao`, como no IDEB. | 63% da base sem INSE (privadas 100%, municipais 60%) | P4, P6 |

## Encaminhamento

Issue aberta com a aprovação do developer (2026-11-17): **#471** (RT-01 a
RT-03 juntas). O mínimo de declaração e o tratamento abaixo dele ficam para o
plano.

### Proposta

1. **RT-01:** decisão de produto antes do código.
   - **Mínimo de declaração:** metade das matrículas ou outro valor.
   - **O que fazer abaixo dele:** a parte racial vazia com o peso dela
     redistribuído entre as outras partes, ou o índice inteiro vazio.
   - Change nova na MV e `indices-v4`. O IVET muda junto (`ivet-v1.6`).
2. **RT-02:** as partes na base, como na #469. Combina com a RT-01 no
   mesmo PR, porque a parte racial nova é que vai para a base.
3. **RT-03:** texto do dicionário. Pode ir junto ou à parte.
