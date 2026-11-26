# Reavaliação: P2 responde ao tribunal sobre o piso só pela plataforma (2026-11-26)

Sexta rodada da P2 (secretaria municipal), a pedido do developer. A anterior
(2026-11-25, os abaixo do piso na folha da Secretaria) teve o veredito
**adotaria, em piloto numa rede**, e os dois achados viraram issues
entregues: QB-01 → #597 (#599), a contagem por situação e o perfil; QB-02 →
#598 (#600), a marca e os filtros na lista da folha.

- **Avaliou:** só a P2.
- **Material:** o painel financeiro da rede municipal de Cuiabá (pela escola
  51091194, sem folha própria), a folha do total da Secretaria de abril de
  2026 com os filtros novos, a ajuda de financeiro e folha. Telas no Chrome,
  com os dados de demonstração locais.
- **O trabalho que ele faria:** responder ao tribunal de contas, do começo
  ao fim, sem sair da plataforma: quantos ficam abaixo do piso em 2026,
  quem são, por quê, e a lista dos casos para conferir.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **O painel da rede:** a frase do piso agora responde quase tudo:
   1.559 abaixo, 1.421 só na Secretaria; "Deles, 1.417 temporários e 142
   efetivos"; o mais comum, 30 h com base mediana de R$ 3.212,71, contra o
   piso proporcional de R$ 3.847,97; e o aviso de que não é a verificação
   legal. É a resposta ao tribunal em um parágrafo.
2. **A lista de abril da Secretaria:** a nota diz 1.504 abaixo do piso no
   ano nesta lista, com a regra. Com "só abaixo do piso" e "efetivo": 143
   registros em 2 páginas, cada um com a base por 40 h no ano. Os efetivos,
   que ele precisa justificar um a um, aparecem.
3. **A lista para o tribunal:** o tribunal pede os 1.559 nome a nome. A
   lista é de um mês e de um lugar: abril da Secretaria tem 1.504; os outros
   **55** abaixo do piso não receberam em abril (estão em outros meses ou
   só em escolas). Para montar a lista do ano ele teria de abrir 8 meses da
   Secretaria e as escolas, e copiar à mão: não há como baixar a lista
   filtrada.
4. **Ordenar:** ordenar pela base por 40 h ordena só a página de 100, não
   os 143 (nem os 1.504) filtrados.

## O que funciona para ele

- A pergunta "por quê" tem resposta na própria tela (QB-01 resolvido).
- Os casos se conferem na lista, com a mesma regra do painel (QB-02
  resolvido).
- Os textos avisam do limite: não é a verificação legal; o total da
  Secretaria pode ter pagamentos parciais.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QC-01 | atrapalha | **Não há a lista do ano de quem fica abaixo do piso.** A marca está na folha de um mês e de um lugar (uma escola ou a Secretaria); quem não recebeu naquele mês, ou só recebeu numa escola, fica de fora, e a lista não se baixa. O tribunal pede os casos nome a nome. Pedido: a lista do ano dos abaixo do piso na rede (uma linha por pessoa: nome, CPF mascarado, situação, carga, base por 40 h no mês típico, meses e onde recebeu), aberta do painel da rede, com download em CSV. Pública, pela mesma decisão da folha por escola. | Cuiabá 2026: 1.559 abaixo; 1.504 na lista de abril da Secretaria, 55 fora dela; 8 meses de folha | P2, P5, P6 |
| QC-02 | incômodo | **A ordenação vale só para a página.** Com os filtros, ordenar pela base por 40 h (ou pelo nome) ordena as 100 linhas da página, não o resultado filtrado. Pedido: ordenar o resultado filtrado inteiro antes de paginar. | 143 efetivos abaixo do piso em 2 páginas; 1.504 em 16 | P2, P5 |

Não é achado: a frase do painel diz "1.421 deles só no total da
Secretaria. Deles, 1.417 temporários…"; o segundo "Deles" se lê como os
1.559 pelo contexto (a soma bate), e ele não se confundiu.

## Veredito

**Adotaria, em piloto numa rede** (mantido). A resposta ao tribunal sai da
plataforma; falta a lista do ano para anexar ao ofício (QC-01). Com ela, o
argumento para sair do piloto é forte: o trabalho que levaria uma semana
de planilha fica em uma tela.

## Encaminhamento

Duas issues, abertas com a aprovação do developer: QC-01 → #601 e
QC-02 → #602. QC-01 vem primeiro: é o anexo do ofício. QC-02 é pequeno e pode ir junto.

## Andamento

- 2026-11-26: #601 e #602 (PR #603) mergeados: QC-01 e QC-02 resolvidos.
  A lista do ano dos abaixo do piso abre pelo painel da Secretaria e pela
  base, com CSV; Cuiabá 2026: 1.559 pessoas (1.417 temporários, 142
  efetivos), o mesmo total do painel. A ordenação vale para a lista
  filtrada inteira. Os dois achados desta rodada estão entregues.
