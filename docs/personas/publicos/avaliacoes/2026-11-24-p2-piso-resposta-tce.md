# Reavaliação: P2 prepara a resposta sobre o piso (2026-11-24)

Quarta rodada da P2 (secretaria municipal), no modo autônomo autorizado
pelo developer (até 25/11, 9h). A anterior (2026-11-24, a folha do Fundeb
em Cuiabá) teve o veredito **adotaria, em piloto numa rede**, e os achados
viraram a #557 e a #558, entregues. Desde então: o piso na rede inteira
(#575), o aviso do mês incompleto com a carga (#576), o Fundeb da folha
inteira e a folha por município (#579, #580).

- **Avaliou:** só a P2.
- **Material:** o painel financeiro da Secretaria e de uma escola de
  Cuiabá, a tela da base e a folha por município de MT, a ajuda de folha de
  pagamento.
- **O trabalho que ele faria:** o secretário de Cuiabá recebeu do tribunal
  a pergunta "por que 1.559 profissionais do magistério aparecem abaixo do
  piso em 2026?" e prepara a resposta: quem são, se é complemento, admissão
  ou erro na declaração ao SIOPE.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **O número:** a tela da base e a folha por município dizem 1.559 abaixo
   do piso no mês típico, 1.421 só no total da Secretaria, com o aviso de
   que não é a verificação legal e de que o total da Secretaria pode ter
   pagamentos parciais. Ele entende o que o tribunal viu.
2. **Por escola:** a base mostra 4 casos nas escolas (soma por escola). Ele
   abre a folha detalhada da escola e confere cada pessoa: nome, categoria,
   carga e salário base. Ali dá para responder.
3. **Os 1.421 da Secretaria:** aqui ele para.
   - Desde março de 2026 a rede declara quase tudo no código da Secretaria
     (#558). Em abril, são 12.125 pessoas nesse código.
   - O painel da Secretaria mostra custo, categorias e o salário da rede,
     mas a folha detalhada (por pessoa) existe só por escola: "a folha
     detalhada não existe" para o total da Secretaria, diz a ajuda.
   - O SIOPE traz o nome, a categoria, a carga e o salário de cada pessoa
     também nessas linhas; a plataforma carrega e não mostra.
   - Para responder ao tribunal, ele precisa cruzar a lista que o tribunal
     vê com o sistema de RH: quem, em que mês, com que carga e salário base.
     Sem a lista, só pode dizer "vamos verificar".
4. **A causa provável:** pelo painel, 2026 está quase todo na Secretaria e
   junho está incompleto já na planilha do SIOPE (#576). Ele desconfia que
   parte dos 1.421 são lançamentos parciais (férias, complementos) feitos
   no código da Secretaria. Não consegue provar sem a lista.

## O que funciona para ele

- O número do tribunal reproduzido, com a regra e os avisos.
- A folha detalhada por escola, para os casos nas escolas.
- O registro da carga, para dizer de que planilha veio cada número.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QE-01 | atrapalha | **A folha detalhada do total da Secretaria não aparece.** A folha por pessoa existe só por escola; onde o município declara no código da Secretaria, a lista (nome, categoria, carga, salário base e total, por mês) está carregada e não se vê. A contagem do piso na rede (#575) aponta 1.421 pessoas só na Secretaria que ninguém consegue conferir pela plataforma. Pedido: a folha detalhada do total da Secretaria, por mês, como a das escolas (pública, pela mesma decisão da folha por escola), a partir do painel da Secretaria. | Cuiabá 2026: 12.125 pessoas no código da Secretaria em abril; 1.421 abaixo do piso só ali; a ajuda diz "a folha detalhada não existe" | P2, P5, P6 |

## Veredito

**Adotaria, em piloto numa rede** (mantido). A resposta ao tribunal sai
para as escolas; para o total da Secretaria, onde está quase todo o
número, falta a lista (QE-01).

## Encaminhamento

Issue **#585** (QE-01), aberta no modo autônomo autorizado pelo developer.

## Andamento

- 2026-11-24: #585 (PR #586) mergeado: QE-01 resolvido. A folha do total da
  Secretaria abre pelo painel (Cuiabá, abril de 2026: 13.019 registros, com
  busca e páginas de 100).
