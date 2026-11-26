# Reavaliação: P2 calcula quanto custa pôr a rede no piso (2026-11-26)

Sétima rodada da P2 (secretaria municipal), a pedido do developer. A
anterior (2026-11-26, a resposta ao tribunal ponta a ponta) teve o veredito
**adotaria, em piloto numa rede**, e os dois achados viraram issues
entregues: QC-01 → #601 e QC-02 → #602 (#603), a lista do ano dos abaixo
do piso com CSV e a ordenação da lista filtrada inteira.

- **Avaliou:** só a P2.
- **Material:** o painel financeiro da rede municipal de Cuiabá (pela escola
  51091194), em 2026 e em 2025; a página nova da lista do ano
  (`/municipio/piso`), em 2026 e em 2025, e o CSV; a ajuda de financeiro e
  folha. Telas no Chrome, com os dados de demonstração locais.
- **O trabalho que ele faria:** respondido o tribunal, o prefeito pergunta
  "quanto custa pôr essa gente no piso, para entrar na LOA de 2027?" e "isso
  piorou? no ano passado não era assim". Ele quer um número para o
  orçamento e a explicação da mudança de um ano para o outro.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **A lista do ano (#601):** abre pelo painel, diz 1.559 (1.417
   temporários, 142 efetivos), baixa o CSV. Cada linha traz a carga, a base
   mensal e a base por 40 h. Ordenada pela base, as menores aparecem
   primeiro, na lista toda.
2. **O custo:** a plataforma não diz quanto falta. Com o CSV numa planilha,
   ele calcula por pessoa (piso − base por 40 h) × carga / 40 e soma:
   **R$ 1,03 milhão por mês** (R$ 939 mil dos temporários, R$ 88 mil dos
   efetivos); a diferença mediana é de R$ 635 por pessoa. Com 13 salários,
   **R$ 13,4 milhões por ano**, cerca de 3% da folha anualizada (R$ 296 mi
   em 8 meses). É a conta que o prefeito pediu, e ela sai de dados que a
   página já tem, mas fora dela.
3. **"No ano passado não era assim":** ele troca o ano para 2025. O painel
   diz **6** abaixo do piso (5 temporários, 1 efetivo); 2026 diz 1.559. O
   magistério da rede passa de 3.485 para 6.578 profissionais. Nada na tela
   explica o salto. A causa está na folha carregada: em 2025 o total da
   Secretaria tem 79 pessoas do magistério; em 2026, 6.378 (os temporários
   de 30 h quase todos pagos ali). O município mudou a forma de declarar ao
   SIOPE, e a comparação entre os anos não se sustenta. Se ele levar "de 6
   para 1.559" ao prefeito (ou o tribunal fizer a conta), a leitura é
   errada.
4. **A frase do perfil em 2025:** "O mais comum entre eles: 20 horas, com
   salário base mediano de R$ 3.380,70 por mês (o piso proporcional a 20
   horas é R$ 2.433,89)". A base fica acima do piso proporcional: a frase
   se contradiz. A carga é a mais comum, mas a base mediana é a de todas as
   cargas (os seis têm de 10 a 40 h). Em 2026 não aparece porque 97% têm
   30 h.
5. **Linhas que não fecham:** em 40 das 1.559 linhas, a base mensal e a
   base por 40 h da mesma pessoa não batem pela carga (ex.: 30 h, base
   mensal de R$ 3.322,09 e base por 40 h de R$ 4.283,61, que é a de
   R$ 3.212,71). São medianas tiradas em separado, nos meses em que o valor
   mudou. Na conta do custo ele usou a base por 40 h (a da regra); quem
   usar a base mensal chega a outro número.

## O que funciona para ele

- A lista do ano é o anexo do ofício: mesma regra e mesmo total do painel,
  com CSV (QC-01 resolvido). A ordenação vale para a lista inteira (QC-02).
- O CSV permite a conta do custo sem pedir nada a ninguém.
- Os avisos de limite continuam claros (não é a verificação legal; a
  Secretaria pode ter pagamentos parciais).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QD-01 | atrapalha | **A plataforma não diz quanto custa pôr os abaixo do piso no piso.** A lista tem a base e a carga de cada um, mas não a diferença; o total, que é a pergunta do orçamento, só sai numa planilha. Pedido: a diferença mensal até o piso proporcional por pessoa (coluna e CSV) e o total na página da lista e no painel da rede, aberto por situação, com a regra dita (base por 40 h do mês típico, carga mais comum, sem 13º nem encargos). | Cuiabá 2026: R$ 1,03 mi por mês (R$ 939 mil temporários, R$ 88 mil efetivos); mediana R$ 635 por pessoa | P2, P5, P6 |
| QD-02 | atrapalha | **O salto entre anos não tem aviso.** De 2025 para 2026 a contagem vai de 6 para 1.559 e o magistério de 3.485 para 6.578, porque a forma de declarar ao SIOPE mudou (o total da Secretaria tinha 79 pessoas do magistério em 2025 e 6.378 em 2026). A tela mostra os dois anos como comparáveis. Pedido: avisar no painel da rede e na lista quando a folha de um ano não se compara à do anterior (mudança forte no magistério declarado ou na parte paga pela Secretaria), dizendo o que mudou. | Cuiabá: 6 → 1.559; magistério 3.485 → 6.578; Secretaria 79 → 6.378 | P2, P4, P5, P6 |
| QD-03 | incômodo | **A frase do perfil se contradiz quando as cargas variam.** A carga é a mais comum, mas a base mediana é a de todas as cargas; em 2025 a base (R$ 3.380,70) fica acima do piso proporcional dito (R$ 2.433,89). Pedido: a base mediana de quem tem a carga mais comum (ou a base por 40 h contra o piso cheio). | Cuiabá 2025, seis abaixo do piso de 10 a 40 h | P2, P5 |
| QD-04 | incômodo | **Base mensal e base por 40 h não fecham em parte das linhas.** São medianas separadas; quando o valor mudou no ano, a linha mostra uma base mensal que não dá a base por 40 h pela carga. Pedido: derivar a base mensal mostrada da mesma mediana (ou dizer na página que são medianas separadas). | Cuiabá 2026: 40 de 1.559 linhas | P2 |

Não é achado: 15 pessoas com carga acima de 40 h (50 h) e 31 com base por
40 h abaixo de R$ 2.500 (pagamentos parciais prováveis) estão na lista;
o aviso de pagamentos parciais cobre o caso, e ele os confere um a um.

## Veredito

**Adotaria, em piloto numa rede** (mantido). A resposta ao tribunal está
completa; a pergunta seguinte, a do orçamento, ainda pede uma planilha
(QD-01), e o salto entre anos é uma armadilha para quem compara (QD-02).
QD-02 é o mais perigoso: a tela induz a uma leitura errada.

## Encaminhamento

Achados para o developer decidir se viram issues. Sugestão: QD-02 primeiro
(evita uma leitura errada), QD-01 em seguida (a pergunta do orçamento);
QD-03 e QD-04 são pequenos e podem ir juntos com o QD-01, por tocarem a
mesma conta.
