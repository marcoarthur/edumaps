# Reavaliação: P4 soma as conveniadas à oferta de creche das prefeituras (2026-11-21)

Trigésima terceira rodada da P4 (academia), a pedido do developer, depois
da entrega da trigésima segunda rodada:

| Entrega | O quê |
|---|---|
| #519 | bloco "Parceria com o poder público" na base (parceria, esfera e categoria da escola privada) e nota das conveniadas com a prefeitura na comparação de redes (QW-01) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise de SP, redes municipal, privada e estadual, blocos
    "Matrículas", "Parceria com o poder público" e "Porte"
    (`base-analise-SP-privada-censo2025.csv` e as outras duas);
  - o dicionário do bloco novo;
  - o R do host (`read.csv2`, o `aggregate` e o `subset` da ajuda);
  - a comparação de redes de Franca (3516200) e de Guarulhos (3518800);
  - as ajudas da base e da comparação de redes;
  - o banco local, só leitura (`clean.censo_escolas`, para conferir a
    mantenedora das conveniadas).
- **O trabalho que ela faria:** refazer a conta da rodada anterior pela
  base, sem o banco: a oferta pública de creche (rede municipal mais as
  conveniadas com a prefeitura) por mil habitantes nos 645 municípios de
  SP, e ver se municípios do mesmo porte têm oferta parecida.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Baixou as três redes com o bloco novo.** A base da rede privada de SP
   (11.644 escolas) traz `parceria_poder_publico`, `parceria_esfera` e
   `categoria_privada`; o dicionário diz o que conta como oferta da
   prefeitura e para filtrar a rede privada.
   - 3.564 privadas conveniadas com a prefeitura e 215 com o estado e a
     prefeitura: 3.779 escolas, 404.650 matrículas em creche e 60.532 na
     pré-escola. Bate com o banco e com a rodada anterior.
   - As 87 conveniadas só com o estado são, quase todas, de educação
     especial (7.118 das 7.455 matrículas); ficam fora da conta, como a
     ajuda diz.
2. **Refez o ranking da rodada anterior pela base.** Nos 71 municípios de
   100 a 500 mil habitantes, a correlação de postos entre a rede municipal
   e a rede municipal mais as conveniadas é de 0,51, e 25 municípios mudam
   20 posições ou mais, os mesmos números que ela tinha tirado do banco.
   Franca vai a 21,2 matrículas em creche por mil habitantes.
3. **Respondeu à pergunta do perfil.** Com as conveniadas, a mediana da
   oferta pública de creche fica entre 18 e 25 por mil habitantes em todos
   os portes; o que muda com o porte é o convênio: 0 na mediana até 100 mil
   habitantes, 12% de 100 a 500 mil e 29% acima de 500 mil (308 mil das 449
   mil matrículas públicas em creche dos 10 maiores municípios).
4. **Tropeçou ao juntar as duas bases.** A ajuda para no `subset` das
   conveniadas. O passo seguinte natural no R, `merge(municipal, conv)`,
   junta só os municípios que têm conveniadas: sobram 271 dos 645, e os
   outros 374 somem da conta em vez de entrar com 0 conveniadas. Ela só
   percebeu porque a tabela por porte encolheu; o certo é
   `merge(..., all.x = TRUE)` e trocar o vazio por 0.
5. **Conferiu o que "somar" quer dizer.** A ajuda diz que as conveniadas
   têm "41% das matrículas em creche custeadas pelas prefeituras", e a
   nota da comparação de redes manda somá-las "para a oferta pública".
   - O Censo marca a **escola** como conveniada, não a **vaga**. Uma
     conveniada pode ter também alunos pagantes, e a soma é um teto.
   - O caso mais provável de mistura são as conveniadas da categoria
     "Particular": 155 escolas com creche, 9.844 matrículas (2,4% das
     conveniadas de SP), em 16 municípios.
   - Nas comunitárias e filantrópicas (97% das matrículas) a soma deve
     estar perto do real, mas nenhum texto do produto diz que é teto.
6. **Olhou a mantenedora**, para saber quantas organizações operam as
   conveniadas. Em Guarulhos, 109 das 110 conveniadas com a prefeitura vêm com o CNPJ da
   mantenedora `99999999999999` (não informado). O dado não serve para
   isso; não é pedido ao produto.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com a oferta pública somando as conveniadas | o bloco Parceria refaz pela base a conta que antes pedia o banco, e a pergunta do perfil tem resposta; ficam dois detalhes de texto: a soma é um teto (QV-01) e a junção no R perde os municípios sem conveniadas (QV-02) |

## O que funciona

- **O bloco Parceria com o poder público** separa as conveniadas pela base;
  os números batem com o banco.
- **O dicionário** diz o que contar como oferta da prefeitura e para filtrar
  a rede privada.
- **A nota da comparação de redes** aparece em Franca e em Guarulhos com os
  mesmos números da base.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QV-01 | detalhe | **A soma das conveniadas é um teto, e nenhum texto diz isso.** O Censo marca a escola conveniada, não a vaga; uma conveniada pode ter alunos pagantes. A ajuda fala em matrículas "custeadas pelas prefeituras" e a nota manda somar "para a oferta pública". Pedido: na nota, no dicionário (`parceria_poder_publico`) e na ajuda, dizer que a soma é o máximo da oferta conveniada, e que as conveniadas da categoria Particular são o caso mais provável de mistura. | SP: 155 conveniadas da categoria Particular com creche, 9.844 matrículas (2,4% das conveniadas), em 16 municípios | P4, P5, P6 |
| QV-02 | detalhe | **O código da ajuda para no `subset` e o passo seguinte perde municípios.** O `merge` padrão do R junta só os municípios com conveniadas. Pedido: na ajuda, o código completo, da soma por município à junção com `all.x = TRUE` e o vazio trocado por 0. | SP: o `merge` padrão deixa 271 dos 645 municípios; 374 somem em vez de entrar com 0 conveniadas | P4, P6 |

## Encaminhamento

Aguarda a decisão do developer sobre abrir a issue (QV-01 e QV-02).
