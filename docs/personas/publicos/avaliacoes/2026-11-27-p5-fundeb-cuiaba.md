# Reavaliação: P5 confere o painel da rede de Cuiabá no conselho do Fundeb (2026-11-27)

Sexta rodada da P5 (órgãos de controle e conselhos), a pedido do
developer, **só registro**: a persona não orienta produto até a decisão de
posicionamento (vender ao fiscal, ao fiscalizado ou aos dois). A anterior
(2026-11-24, a fiscalização do piso em Cuiabá) teve o veredito **não
adotaria** (registro), com QH-01 → #575 (#577) e QH-02 → #576 (#578)
entregues. Desde então, quatro ciclos mexeram no que ela vê: o painel da
rede com toda a folha (#610), a folha e o Fundeb (#611), o painel pelo
município e o ano no endereço (#614, #615).

- **Avaliou:** só a P5.
- **Material:** o link `/municipio/financeiro?codigo_ibge=5103403&ano=2025`
  (o painel da rede de Cuiabá pelo município), a folha do mês da rede, a
  lista do piso, `/fontes` e as ajudas de financeiro e folha e da base.
  Telas no Chrome, com os dados de demonstração locais.
- **O trabalho que ele faria:** o conselheiro do CACS-Fundeb recebe da
  secretaria o link do painel de 2025 com a prestação de contas da folha; o
  auditor do tribunal usa o mesmo painel para a matriz de achados.
  Perguntas: "a parte do Fundeb na remuneração se sustenta?" e "o recurso
  do Fundeb chegou às escolas que mais precisam?"
- ⚠️ Simulação: não substitui um auditor ou conselheiro de verdade.

## O que ele fez

1. **O link abre no ano certo** (2025), pelo município, com a declaração do
   ano ("por escola em todos os meses, 167 escolas"), o total de
   R$ 489.472.996,81 e as partes (R$ 472,4 mi nas escolas, R$ 17,1 mi na
   Secretaria). Bate com a folha por município da base.
2. **A parte do Fundeb:** "Em 2025, a rede pagou R$ 457,2 mi da remuneração
   pela parcela de 70% do Fundeb: 77,8% da receita do Fundeb do ano
   (R$ 588,0 mi…)", com a fonte (DCA) e o aviso de que não é a verificação
   legal. Mas, mais acima, o painel avisa que **setembro e outubro de 2025
   vieram pela metade** (3.269 e 3.253 registros contra 9.680 num mês
   típico; R$ 22,2 mi e R$ 22,6 mi contra R$ 41 a 45 mi nos outros meses),
   e que "o total do ano também" fica abaixo do real. O bloco do Fundeb não
   diz isso: divide uma folha a que faltam cerca de R$ 44 mi (a parcela de
   70% desses dois meses, pelo mês típico) por uma receita inteira. Com os
   dois meses no nível dos outros, a parte passaria de 77,8% para perto de
   85%. A secretaria leva ao conselho um percentual 7 pontos abaixo, e o
   conselheiro, que lê o bloco sem o aviso de cima, não sabe.
3. **"O Fundeb chegou às escolas que mais precisam?"** O painel diz quanto
   foi para as escolas e quanto para a Secretaria, mas não como a folha se
   distribui entre as escolas. Ele tenta pela base de análise: o CSV das
   escolas tem o gasto com pessoal de cada uma, os meses completos e o INSE;
   cruzando numa planilha com as matrículas, a folha por aluno de 2025 é
   **R$ 6.521 nas escolas de INSE nível IV** (25 escolas, as mais
   vulneráveis da rede), **R$ 7.141 no nível V** (26) e R$ 7.749 no nível
   VI (1); entre as escolas, de R$ 3.887 a R$ 21.675 por aluno. 115 escolas
   (creches e pré-escolas, na maioria) não têm INSE. A resposta existe nos
   dados e aponta o contrário do que a lei pede, mas só sai de uma
   planilha.
4. **`/fontes`:** o cartão "Receita do Fundeb dos municípios (SICONFI,
   DCA)" tem órgão, período 2024–2025, data da carga e licença; sem
   arquivo nem hash (a carga é por API).

## O que funciona para ele

- O painel da rede tem porta, endereço estável e o ano no link; o total e
  as partes batem com a base.
- A receita do Fundeb vem de fonte oficial, com o anexo, a data e o aviso
  de que não é a verificação legal.
- O aviso do mês incompleto, com o registro da carga ("a falta está na
  fonte"), continua no lugar.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QG-01 | atrapalha | **A parte do Fundeb ignora os meses que vieram pela metade.** O bloco "A folha e o Fundeb" só avisa quando a folha tem menos de 12 meses; com 12 meses e dois deles pela metade, divide uma folha incompleta pela receita inteira e dá o percentual sem ressalva. Pedido: no bloco, dizer quais meses vieram incompletos e dar também a parte estimada pelos meses completos (a folha dos meses completos levada a 12 meses, como a base já faz com `gasto_pessoal_meses_completos`), com o aviso de que é estimativa. | Cuiabá 2025: setembro e outubro com R$ 22 mi cada (meses típicos R$ 41 a 45 mi); 77,8% na tela, perto de 85% pelos meses completos | P2, P5, P6 |
| QG-02 | atrapalha | **A pergunta do conselho e do tribunal não tem resposta na tela: o recurso chegou às escolas que mais precisam?** O painel da rede divide a folha entre escolas e Secretaria, mas não mostra como ela se distribui entre as escolas conforme a necessidade. A resposta só sai cruzando o CSV da base com as matrículas numa planilha. Pedido: no painel da rede, nos anos declarados por escola, um bloco "a folha por aluno nas escolas da rede" pelo nível socioeconômico (INSE) das escolas, com a mediana por nível, as escolas nos extremos e o que fica de fora (escolas sem INSE, folha da Secretaria sem escola, meses incompletos), com o aviso de que a etapa pesa (creche custa mais por aluno) e de que não é a avaliação legal da equidade (VAAR). | Cuiabá 2025: R$ 6.521 por aluno no INSE IV, R$ 7.141 no V, R$ 7.749 no VI; de R$ 3.887 a R$ 21.675 entre as escolas; 115 escolas sem INSE | P5, P2, P6 |

Não é achado: o cartão da receita do Fundeb em `/fontes` não tem arquivo
nem hash, porque a carga é pela API do Tesouro e não baixa arquivo. A data
e a fonte reproduzível bastam para o registro; guardar o retorno da API
fica para quando a persona orientar produto.

Não é achado (detalhe da exportação): a descrição das colunas de fonte do
CSV da base ainda diz que a receita do Fundeb "não está na base". Não muda
a tela; corrigir junto da próxima mudança na base.

## Veredito

**Não adotaria** (registro; mantido, mais perto). O painel da rede agora
sustenta a conferência do total e da fonte, e o link é citável; mas o
percentual que vai à ata do conselho pode estar 7 pontos abaixo sem
ressalva no bloco (QG-01), e a pergunta central do tribunal, se o recurso
chegou a quem precisa, ainda pede planilha (QG-02). A decisão de
posicionamento segue em aberto: estes achados valem também para a P2, que
apresenta o mesmo painel ao conselho.

## Encaminhamento

Propostas duas issues (só com a aprovação do developer): QG-01 primeiro
(o número que vai à ata está errado sem aviso; correção pequena no bloco
existente), depois QG-02 (um bloco novo no painel da rede).

## Andamento
