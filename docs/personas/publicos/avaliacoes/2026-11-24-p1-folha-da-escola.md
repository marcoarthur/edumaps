# Reavaliação: P1 lê a folha da própria escola (2026-11-24)

Segunda rodada da P1 (gestor escolar), a pedido do developer. A anterior
(2026-11-23, painel e perfil para o conselho) teve o veredito **adotaria**,
e os achados viraram a #541 (posição sem verde fixo) e a #542 (sinal de
atenção com os números), entregues. Desde então, no painel financeiro:

| Entrega | O quê |
|---|---|
| #553 | o cartão "Por fonte de recurso" (Fundeb 70%, 30%, outras) |
| #557 | o aviso do mês com a folha pela metade |
| #558 | o aviso dos meses só com o total da Secretaria |
| #564 | a data da carga da folha (recarregada hoje: "carga em 24/11/2026") |

- **Avaliou:** só a P1.
- **Material:** o painel financeiro da EM Presidente Tancredo de Almeida
  Neves (Ubatuba, SP; INEP 35070212), folha de 2026, só a tela pública, e a
  ajuda de financeiro e folha.
- **O trabalho que ela faria:** a diretora prepara a reunião do conselho
  escolar: quanto custa a equipe da escola, de onde vem o dinheiro e
  quantas pessoas trabalham ali.
- ⚠️ Simulação: não substitui uma diretora de verdade.

## O que ela fez

1. **O custo:** "Custo total em 2026 (jan a ago (8 meses))": R$ 2,43 mi.
   Entende sem ajuda. O gráfico mensal mostra maio mais alto (R$ 414 mil,
   contra cerca de R$ 260 mil); ela imagina férias ou um pagamento extra e
   segue.
2. **De onde vem:** o cartão "Por fonte de recurso" diz 100% pela parcela
   de 70% do Fundeb, com o aviso de que não é a verificação do mínimo da
   lei. É a frase que ela leva ao conselho.
3. **Quantas pessoas:** "Profissionais em 2026: 57", e nas categorias,
   Docentes 36, Administrativo 18, Outros 5. Aqui ela para.
   - A escola tem 1.316 alunos e, no Censo Escolar de 2025, 62 docentes.
     Ela sabe que tem perto de 60 professores. A folha diz 36.
   - O painel não mostra os docentes do Censo nem diz por que os números
     diferem. Diante da secretaria, "36 docentes" a coloca mal: parece que
     a escola tem metade dos professores, ou que a folha está errada.
   - Conferido no banco: em Ubatuba, em 2026, 658 profissionais do
     magistério aparecem só no código da Secretaria, sem escola (sobretudo
     em julho e agosto). Parte dos professores desta escola pode estar ali,
     mas o painel não tem como dizer quem.
   - A ajuda da base explica a diferença entre folha e Censo; a do painel,
     não.
4. **As contas que não fecham:** as categorias somam 59 pessoas; o cartão
   diz 57. Quem está em duas categorias conta nas duas, mas nada diz isso.
5. **As palavras:** "Competências com dados: 8" e "Competência mais recente
   (Ago/2026): 47". "Competência" é o mês de referência da folha, palavra
   da contabilidade. Ela entende "meses", não "competências".
6. **Imprimir:** continua sem botão de imprimir no painel; ela usa o do
   navegador.

## O que funciona para ela

- O custo do ano com os meses ditos, e a fonte do dinheiro, numa frase que
  ela repete ao conselho.
- A data da carga em `/fontes`, para dizer "dados do SIOPE de 24/11/2026".

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| P1-FL-01 | atrapalha | **A folha diz 36 docentes, o Censo diz 62, e o painel não explica.** O painel financeiro não mostra os docentes do Censo ao lado, nem diz que parte dos professores da rede pode ser paga no total da Secretaria, sem escola, ou por outra rede. A diretora lê "metade dos professores". Pedido: os docentes do Censo ao lado dos profissionais do magistério da folha, com a frase de por que podem diferir (professor pago no total da Secretaria, de outra rede ou contratado por outra fonte; quem esteve só parte do ano), e o aviso quando o município tem muitos profissionais só no total da Secretaria. | EM Tancredo Neves (35070212): 36 docentes na folha de 2026, 62 no Censo 2025; Ubatuba 2026: 658 profissionais do magistério só no código da Secretaria | P1, P2, P5 |
| P1-FL-02 | incomoda | **Palavras de contabilidade e uma soma que não fecha.** "Competências com dados" e "Competência mais recente" em vez de meses; as categorias somam 59 pessoas e o cartão diz 57, sem dizer que quem está em duas categorias conta nas duas. Pedido: "meses com folha" e "último mês (ago/2026)", e uma nota curta sob as categorias. | painel financeiro da 35070212, 2026 | P1, P2 |

Observação mantida: sem botão de imprimir no painel (já registrada na
rodada anterior).

## Veredito

**Adotaria** (mantido). O custo e a fonte do dinheiro saem prontos para o
conselho. O número de docentes da folha, sozinho, a deixa em situação ruim
diante da secretaria (P1-FL-01).

## Encaminhamento

Issues **#567** (P1-FL-01) e **#568** (P1-FL-02), abertas com a aprovação do developer.
