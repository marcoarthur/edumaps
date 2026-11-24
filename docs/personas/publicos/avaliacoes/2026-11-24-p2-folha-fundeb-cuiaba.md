# Reavaliação: P2 presta contas da folha do Fundeb em Cuiabá (2026-11-24)

Terceira rodada da P2 (secretaria municipal), a pedido do developer. A
anterior (2026-11-23, expansão da creche) teve o veredito **adotaria, em
piloto numa rede**, e o QK-01 virou a #547 (vagas que faltam, entregue).
Desde então, na folha:

| Entrega | O quê |
|---|---|
| #553 | a folha do ano por fonte (parcela de 70% do Fundeb, de 30% e outras), no painel e na base |
| #554 | o fechamento da folha na base: escolas, Secretaria e escolas fora da lista do Censo |

São as duas entregas que o conselheiro do Fundeb (P5) pediu. Esta rodada é
o outro lado: quem presta as contas.

- **Avaliou:** só a P2.
- **Material:**
  - o painel financeiro de uma escola municipal grande (EMEB Prof. Zeferino
    Leite de Oliveira), em 2025 e 2026;
  - a base de análise da rede municipal de Cuiabá (blocos Etapas,
    Matrículas, Docência, INSE e Remuneração), folha de 2025 e de 2026;
  - as ajudas de financeiro e folha e da base.
- **Por que Cuiabá (MT):** é o único município com a folha de um ano
  inteiro por escola (2025) e com parte de 2026.
- **O trabalho que ele faria:** o secretário de Cuiabá monta a parte da
  folha no relatório anual ao conselho do Fundeb (CACS):
  - quanto a rede pagou em 2025 e com que fonte;
  - quanto foi para as escolas e quanto ficou na Secretaria;
  - a tabela por escola, anexa;
  - a prévia de 2026.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **A folha de 2025 por fonte:** pelo painel e pela base, R$ 489,5 mi
   declarados. R$ 457,2 mi (93,4%) pela parcela de 70% do Fundeb e R$ 32,3
   mi (6,6%) por outras fontes. O aviso de que não é a verificação do
   mínimo legal está lá, e ele concorda: a conta dos 70% sai do balanço,
   não da folha.
2. **Escolas e Secretaria:** a tela da base fecha a conta. R$ 472,4 mi nas
   escolas da base e R$ 17,1 mi na Secretaria, sem escola fora da lista. É
   o parágrafo que o conselho pede, pronto.
3. **A tabela por escola:** 167 escolas com folha, com o gasto por fonte, o
   magistério por mês e os docentes do Censo ao lado. Ele anexa.
4. **Um buraco em setembro e outubro de 2025:** no gráfico mensal da escola
   Zeferino, o custo cai de R$ 457 mil (agosto) para R$ 347 mil (setembro)
   e os profissionais de 92 para 55. Na rede inteira, a folha das escolas
   cai de R$ 43 mi por mês para R$ 22 mi nesses dois meses.
   - Conferido no banco: em setembro e outubro só há os profissionais do
     magistério (3,2 mil registros contra 9,7 mil nos outros meses, 115
     escolas contra 168). Os auxiliares educacionais e as merendeiras
     somem.
   - Nada na tela avisa. A base conta 2025 como ano completo (12 meses), e
     o `gasto_pessoal_ano` e os auxiliares por mês ficam abaixo do real.
   - Se é a declaração do município ao SIOPE ou a carga, a plataforma não
     diz, e ele não sabe. Ele quase anexou ao relatório um gasto anual
     menor que o da própria contabilidade.
5. **A prévia de 2026:** a cobertura diz "2026: 6 meses, 168 escolas".
   - O fechamento mostra outra coisa: de R$ 354,2 mi declarados, R$ 295,9
     mi (84%) estão na Secretaria e só R$ 58,3 mi nas escolas.
   - Por mês: em janeiro e fevereiro a folha é por escola; de março em
     diante, quase tudo vai para o código da Secretaria (em março, R$ 0,3
     mi nas escolas e R$ 54,6 mi na Secretaria).
   - Na base, 134 escolas têm `meses_folha` = 2. Os "6 meses" contam os
     meses com qualquer centavo numa escola.
   - O fechamento (#554) salvou a leitura. A frase da cobertura, sozinha,
     engana.

## O que funciona para ele

- A folha por fonte e o fechamento: a parte do relatório sobre o Fundeb sai
  da plataforma, com os números que o conselho vai conferir.
- A tabela por escola, sem nomes, para anexar.
- O painel da escola diz os meses de verdade ("jan a fev (2 meses)" em
  2026).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QT-01 | atrapalha | **Mês com a folha pela metade não é avisado.** Um mês em que somem categorias inteiras de profissionais conta como mês completo: no gráfico só aparece uma queda, e a base trata o ano como completo. O gasto do ano e os auxiliares ficam abaixo do real, sem aviso. Pedido: marcar o mês com queda brusca (bem menos escolas ou categorias que os vizinhos) na cobertura, no painel e na base (ex.: os meses incompletos numa coluna ou no aviso), sem afirmar a causa: pode ser a declaração do município ou a carga. | Cuiabá 2025: setembro e outubro com 3,2 mil registros (9,7 mil nos outros meses), 115 escolas (168) e só o magistério; a folha das escolas cai de R$ 43 mi para R$ 22 mi por mês | P2, P5, P4 |
| QT-02 | incomoda | **A cobertura conta como "por escola" o mês que é da Secretaria.** A frase "2026: 6 meses, 168 escolas" conta qualquer mês com algum valor numa escola. Em Cuiabá, de março em diante quase toda a folha está no código da Secretaria. Pedido: a cobertura dizer em que meses a folha é por escola e em quais é só (ou quase só) da Secretaria. | Cuiabá 2026: R$ 295,9 mi de R$ 354,2 mi na Secretaria; 134 escolas com `meses_folha` = 2; em março, R$ 0,3 mi nas escolas e R$ 54,6 mi na Secretaria | P2, P5 |

## Veredito

**Adotaria, em piloto numa rede** (mantido). A parte do relatório sobre a
folha do Fundeb sai da plataforma, com a fonte e o fechamento. Antes de
anexar, o secretário precisa saber que setembro e outubro estão pela
metade (QT-01) e que 2026 é, quase todo, da Secretaria (QT-02).

## Encaminhamento

Issues **#557** (QT-01) e **#558** (QT-02), abertas com a aprovação do developer.

## Andamento

- 2026-11-24: #557 (PR #559) mergeado: QT-01 resolvido.
  - O mês com bem menos profissionais que o resto do ano é marcado no
    painel financeiro, na cobertura da folha e na base
    (`meses_folha_incompletos`), sem corrigir os números nem afirmar a
    causa.
- 2026-11-24: #558 (PR #560) mergeado: QT-02 resolvido.
  - A cobertura diz em que meses a folha é por escola e em quais é só da
    Secretaria (Cuiabá 2026: por escola só em janeiro e fevereiro), e o
    painel da escola avisa os meses em que a folha dela não aparece.
- 2026-11-24: a recarga do SIOPE (#564) trouxe setembro e outubro de 2025
  iguais: a falta está na declaração publicada, não na carga.
