# Reavaliação: P4 e a oferta por porte de município (2026-11-17)

Décima rodada da P4 (academia), depois da entrega da nona rodada:

| Entrega | O quê |
|---|---|
| #472 | cor/raça do índice de diversidade sobre as matrículas com cor declarada e as partes na base (`indices-v4`, `ivet-v1.6`); motivo do INSE vazio (RT-01 a RT-03) |

- **Avaliou:** só a P4, a pedido do developer, que deixou a rodada e o
  encaminhamento em modo autônomo por 4 horas.
- **Material:**
  - as ajudas `rankings.md` e `base-de-analise.md`;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** a pergunta do perfil que ainda não tinha
    testado, "municípios de porte e região semelhantes têm oferta
    parecida?", com o índice de capacidade de atendimento.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A diversidade corrigida** (RT-01 a RT-03 resolvidos).
   - A parte racial não acompanha mais a cor não declarada (correlação
     0,04).
   - As cinco partes refazem o índice.
   - O dicionário explica o INSE vazio.
2. **A oferta por porte.**
   - Nas escolas públicas, o índice de capacidade de atendimento cai com o
     porte do município: 5,42 nos de menos de 20 mil habitantes, 5,13 nos
     de 20 a 100 mil, 4,66 nos de 100 a 500 mil e 4,36 nos de mais de 500
     mil.
   - A leitura direta seria "as cidades grandes atendem pior".
3. **Abriu o método.**
   - A maior parte do índice (40%) é "alunos por sala": 10 sem lotação, 0
     com 50 ou mais alunos por sala.
   - A conta divide **todas** as matrículas da escola pelas salas
     utilizadas. A escola de dois turnos põe duas turmas na mesma sala e
     aparece com o dobro de "alunos por sala".
4. **Mediu os turnos** (Censo 2025; 178.766 escolas com matrícula e salas).
   O número de turnos é contado pelas matrículas no matutino, no
   vespertino e no noturno.

   | Turnos | Escolas | Alunos por sala (conta atual) | Por sala e turno | Com 0 na parte | Delas, menos de 35 por turno |
   |---|---|---|---|---|---|
   | 1 | 56.699 | 17,2 | 17,2 | 527 | 0 |
   | 2 | 98.448 | 28,1 | 14,0 | 8.035 | 7.303 |
   | 3 | 23.619 | 43,8 | 14,6 | 7.658 | 7.370 |

   - **16.220 escolas** ficam com 0 na parte de alunos por sala. **14.673
     delas (90%)** usam dois ou três turnos e têm menos de 35 alunos por
     sala em cada turno.
   - Por turno, a lotação média é parecida em todos os grupos (14 a 17).
   - A parte mede o número de turnos, não a lotação.
5. **Recalculou por turno** (escolas públicas, com a mesma regra: 0 com 50
   ou mais).

   | Porte do município | Turnos (média) | Índice atual | Índice com a lotação por turno |
   |---|---|---|---|
   | menos de 20 mil | 1,82 | 5,42 | 6,20 |
   | 20 a 100 mil | 1,87 | 5,13 | 6,04 |
   | 100 a 500 mil | 1,92 | 4,66 | 5,75 |
   | mais de 500 mil | 1,95 | 4,36 | 5,57 |

   - A diferença entre o menor e o maior porte cai de 1,06 para 0,63
     ponto: **cerca de 40% do "pior atendimento" das cidades grandes vem
     dos turnos.**
6. **Tentou refazer com a base.**
   - A base não traz as salas, os turnos, a proporção em tempo integral
     nem a alimentação.
   - As etapas oferecidas estão lá, mas o índice usa as etapas do ensino
     regular (`in_comum_*`), que não são as colunas `oferece_*`.
   - Ela só descobriu o problema com as tabelas do Censo (RS-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o índice de capacidade de atendimento | a pergunta do porte se responde com a base e o ranking; mas a parte de "alunos por sala" do índice de atendimento mede os turnos, e o índice põe as cidades grandes abaixo do que elas estão (RS-01) |

## O que funciona

- **A diversidade corrigida** e as partes da capacitação e da diversidade
  na base.
- **O porte do município** na base e no ranking, para separar as cidades
  por tamanho.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RS-01 | atrapalha | **A parte "alunos por sala" do índice de capacidade de atendimento ignora os turnos.** Ela divide todas as matrículas pelas salas: a escola de dois ou três turnos parece lotada. Pedido: alunos por sala **por turno**, isto é, matrículas ÷ (salas × turnos com matrícula, contando matutino, vespertino e noturno), com a mesma régua (0 com 50 ou mais). Muda a fórmula: `indices-v5` e `ivet-v1.7`. | 16.220 escolas com 0 na parte, 14.673 com menos de 35 por turno; diferença entre portes de 1,06 para 0,63 | P4, P2, P6, P1 |
| RS-02 | atrapalha | **As partes do índice de capacidade de atendimento não estão na base.** Pedido, como na #469 e na #471: alunos por sala por turno, turnos, etapas do ensino regular, proporção em tempo integral e alimentação, com as expressões da MV. | base sem salas, turnos, integral e alimentação | P4 |

## Encaminhamento

Issue **#473** (RS-01 e RS-02), aberta em modo autônomo, com decisões do
avaliador e aviso ao developer pelo Telegram:
- **uma issue** para RS-01 e RS-02 juntas, como na #471;
- **turnos** contados pelas matrículas no matutino, no vespertino e no
  noturno, no mínimo 1;
- **a mesma régua** de 50 alunos por sala e turno;
- **as partes no fim do bloco** Índices do EduMaps.
