# Reavaliação: P1 compara o salário da escola com o da rede (2026-11-25)

Terceira rodada da P1 (gestor escolar), no modo autônomo autorizado pelo
developer (até 25/11, 9h). A anterior (2026-11-24, a folha da própria
escola) teve o veredito **adotaria**, e os achados viraram a #567 e a #568,
entregues. Desde então, no painel financeiro: o salário da rede inteira
(#571), a carga fora de horas (#572), o aviso do mês incompleto com a carga
(#576) e a folha do total da Secretaria (#585).

- **Avaliou:** só a P1.
- **Material:** o painel financeiro da EM Presidente Tancredo de Almeida
  Neves (Ubatuba; INEP 35070212), 2026, e a ajuda de financeiro e folha.
- **O trabalho que ela faria:** a diretora ouve dos professores que "na
  escola do centro se ganha mais" e quer responder no conselho: o salário
  dos professores da escola está acima ou abaixo do da rede?
- ⚠️ Simulação: não substitui uma diretora de verdade.

## O que ela fez

1. **O salário da rede:** a linha "Magistério na rede municipal em 2026"
   diz salário total de R$ 7.186 e base de R$ 5.572 (medianas por mês, sem
   dezembro, de 1.374 profissionais), carga mais comum de 31 horas. Ela
   entende.
2. **O salário da escola:** não está no painel. O painel da escola mostra o
   custo, as categorias (com o total pago a cada uma), os docentes da folha
   e do Censo e o salário da rede. Para o salário da própria escola, ela
   teria de dividir o custo dos docentes pelos docentes, à mão, ou ir à base
   de análise.
3. **Na base:** a escola tem `salario_medio_magisterio` de R$ 9.353 (a
   **média** por pessoa e mês) e R$ 8.299 de salário base por 40 horas. A
   rede, no painel, está em **mediana** e sem conversão para 40 horas. Os
   dois números não se comparam: média contra mediana, por mês contra por
   40 horas.
4. **No conselho:** ela não consegue dizer "a escola está X% acima da rede"
   com um número que se sustente.

## O que funciona para ela

- O salário da rede, com a carga e os avisos.
- Os docentes da folha e do Censo, com o porquê.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| P1-FL-03 | atrapalha | **O salário da escola não aparece ao lado do da rede, na mesma conta.** O painel mostra o salário da rede (mediana por pessoa e mês, sem dezembro), mas não o da escola. Na base, a escola está em média e por 40 horas: não se compara com a rede. Pedido: no painel da escola, o salário do magistério da escola com a mesma conta da rede (mediana por pessoa e mês, sem dezembro, total e base, carga mais comum), ao lado da linha da rede. | EM Tancredo Neves 2026: rede R$ 7.186 (mediana, total); escola só na base, R$ 9.353 (média) | P1, P2, P6 |

Observação mantida: sem botão de imprimir no painel.

## Veredito

**Adotaria** (mantido). Falta o número que responde a pergunta dos
professores (P1-FL-03).

## Encaminhamento

Issue **#589** (P1-FL-03), aberta no modo autônomo autorizado pelo developer.
