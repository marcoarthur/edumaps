# Reavaliação: P4 mede a oferta de creche com as matrículas da base (2026-11-21)

Trigésima segunda rodada da P4 (academia), a pedido do developer, depois
da entrega da trigésima primeira rodada:

| Entrega | O quê |
|---|---|
| #517 | bloco "Matrículas" na base (10 colunas por etapa), creche e pré-escola separadas na comparação de redes e link da comparação para a base do município (QX-01, QX-02) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise de SP, redes municipal, privada e estadual, blocos
    "Matrículas" e "Porte" (`base-analise-SP-municipal-censo2025.csv` e as
    outras duas);
  - o R do host (`read.csv2`, o `aggregate` da ajuda);
  - a comparação de redes de Franca (3516200);
  - as ajudas da base e da comparação de redes;
  - o banco local, só leitura (`clean.censo_escolas`, para medir o que a
    base não traz: `in_poder_publico_parceria`, `tp_poder_publico_parceria`
    e `tp_categoria_escola_privada`).
- **O trabalho que ela faria:** a mesma pergunta da rodada anterior,
  "municípios de porte e região semelhantes têm oferta parecida?", agora
  com o número de matrículas: a oferta de creche das prefeituras nos 71
  municípios de SP de 100 a 500 mil habitantes, por mil habitantes.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Baixou e somou como a ajuda ensina.** A base da rede municipal de SP
   (13.435 escolas, 645 municípios) lê no R com `read.csv2`, e o
   `aggregate` da ajuda dá as matrículas em creche e pré-escola por
   município, com o porte.
   - As 198 escolas sem linha de matrículas vêm vazias e não mudam as
     somas.
   - O total de SP bate com o banco: 579.970 matrículas em creche na rede
     municipal.
2. **Ordenou os 71 municípios de 100 a 500 mil habitantes** pelas
   matrículas municipais em creche por mil habitantes.
   - No alto: Araras (30,3), Barueri (28,8), Caraguatatuba (27,5).
   - No pé: Mogi das Cruzes (2,9), Sumaré (1,3) e **Franca (0)**.
3. **Estranhou Franca com zero** e foi à comparação de redes. Ela mostra 0
   matrícula em creche na rede municipal e 9.191 na privada. A leitura
   direta: em Franca, a creche é do mercado.
4. **Conferiu no banco o que a base não traz.** O Censo marca a escola
   privada que tem parceria ou convênio com o poder público
   (`in_poder_publico_parceria`) e com qual esfera
   (`tp_poder_publico_parceria`: municipal, estadual ou as duas).
   - Em Franca, 7.758 das 9.191 matrículas privadas em creche estão em 78
     escolas conveniadas com a prefeitura.
   - Somando as conveniadas com a prefeitura, Franca vai de 0 a 21,2 por mil
     habitantes e da 71ª para a 21ª posição. Sumaré vai da 70ª para a 20ª;
     Mogi das Cruzes, da 69ª para a 9ª; Guarujá, da 68ª para a 17ª.
   - Nos 71 municípios, a correlação de postos entre as duas medidas é de
     0,51, e 25 municípios mudam 20 posições ou mais.
   - Em SP, as conveniadas com a prefeitura têm 41% das matrículas em
     creche custeadas pelo poder público municipal (404 mil contra 580 mil
     na rede própria); na capital, 262 mil contra 48 mil. Nas outras UFs
     que ela olhou: RS 24%, GO 9%, BA 8%, PA 2%.
5. **Tentou separar pela base.** A base da rede privada traz as 559.613
   matrículas em creche das privadas de SP, sem dizer quais são
   conveniadas, nem a categoria da escola (particular, comunitária,
   confessional, filantrópica). Não há como separar sem os microdados.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com as matrículas, sem as conveniadas | o bloco Matrículas resolve a contagem; a oferta de creche da prefeitura fica subestimada onde ela se faz por convênio, e a base não deixa separar as conveniadas (QW-01) |

## O que funciona

- **O bloco Matrículas** lê no R e soma por município com a linha da
  ajuda; o total bate com o Censo.
- **O dicionário** diz que as etapas não somam o total e o que é o vazio.
- **A comparação de redes** separa creche e pré-escola e leva à base do
  município.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QW-01 | atrapalha | **As creches conveniadas com o poder público não aparecem como tais.** A oferta da prefeitura feita por convênio fica na rede privada, junto das particulares, e a base não traz a parceria nem a categoria da escola privada. Pedido: na base, as colunas da parceria com o poder público (sim ou não, e a esfera: municipal, estadual ou as duas) e da categoria da escola privada; na comparação de redes, as matrículas da privada conveniada separadas das da privada sem convênio; na ajuda, o aviso de que medir a oferta da prefeitura pede somar as conveniadas com ela, com o exemplo de Franca. | SP: 404 mil matrículas em creche em privadas conveniadas com a prefeitura contra 580 mil na rede municipal (41%). Franca: 0 na rede municipal e 7.758 em 78 conveniadas; nos 71 municípios de 100 a 500 mil, correlação de postos de 0,51 entre as duas medidas | P4, P2, P5, P6 |

## Encaminhamento

Issue **#518** (QW-01), aberta com a aprovação do developer.

## Andamento

- 2026-11-21: #518 (PR #519) mergeado: QW-01 resolvido.
  - A base tem o bloco "Parceria com o poder público": a parceria (0/1), a
    esfera (municipal, estadual ou as duas) e a categoria da escola
    privada.
  - A comparação de redes diz, na rede privada, quantas escolas são
    conveniadas com a prefeitura e quantas matrículas de creche e
    pré-escola têm (Franca: 82 conveniadas, 7.758 em creche).
  - A ajuda mostra o filtro no R e explica por que as conveniadas ficam na
    rede privada.
