# Reavaliação: P2 presta contas da folha ao conselho do Fundeb (2026-11-27)

Oitava rodada da P2 (secretaria municipal), a pedido do developer. A
anterior (2026-11-26, quanto custa pôr a rede no piso) teve o veredito
**adotaria, em piloto numa rede**, e os quatro achados viraram issues
entregues: QD-02 → #604 (#608), o aviso da folha que não se compara ao ano
anterior; QD-01, QD-03 e QD-04 → #605, #606 e #607 (#609), o custo até o
piso, o perfil pela carga e a base do mês típico.

- **Avaliou:** só a P2.
- **Material:** o painel financeiro da rede municipal de Cuiabá (pela escola
  51091194, sem folha própria), em 2025 e 2026; a tela da base de análise
  de MT com o bloco da remuneração; o CSV da folha por município de MT; as
  ajudas de financeiro e folha e da base. Telas no Chrome, com os dados de
  demonstração locais.
- **O trabalho que ele faria:** na reunião do conselho de acompanhamento do
  Fundeb (CACS), apresentar quanto a rede gastou com a folha da educação em
  2025 e em 2026 (até agosto), quanto saiu da parcela de 70% do Fundeb, e
  se a adequação ao piso (R$ 13,4 milhões no ano, da rodada anterior) cabe.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **O painel da rede, 2025:** "Custo total em 2025 (jan a dez) · Rede
   municipal (Secretaria): **R$ 17.050.529,49**", 816 profissionais, e o
   texto: "O SIOPE não detalha a folha por escola neste município; … Os
   números abaixo são o total da rede". Ele estranha: a rede tem ~3.500
   profissionais do magistério. A folha por município de MT diz outra
   coisa: em 2025 o município declarou **R$ 489.472.996**, com 12 meses
   por escola em 167 escolas; os R$ 17 mi são só o código da Secretaria
   (sem escola). O painel chama de "total da rede" 3,5% do que a rede
   declarou, e diz que o SIOPE não detalha por escola num ano em que
   detalha.
2. **O painel da rede, 2026:** R$ 295.872.842,55 de janeiro a agosto. A
   folha por município: **R$ 354.211.029**. Janeiro e fevereiro vieram por
   escola (R$ 26,2 mi e R$ 31,8 mi nas escolas, contra R$ 2,2 mi e
   R$ 19,1 mi na Secretaria); de março em diante, quase tudo na
   Secretaria. O painel perde R$ 58,3 mi (16%), e o gráfico mensal mostra
   janeiro e fevereiro quase vazios.
3. **A fonte do pagamento:** na folha por município, 2025: R$ 457,2 mi da
   parcela de 70% do Fundeb (93,4%) e R$ 32,3 mi de outras fontes; 2026:
   100% na parcela de 70%. O painel diz, com razão, que não é a
   verificação do mínimo de 70%, porque a receita do Fundeb do município
   não está na plataforma. É exatamente a pergunta do conselho: quanto da
   receita do Fundeb foi para a remuneração. Sem a receita, ele não diz o
   percentual nem se os R$ 13,4 mi da adequação cabem.
4. **O CSV da folha por município:** a coluna nova
   `abaixo_piso_diferenca_mensal` de Cuiabá 2026 sai como `1,02744e+06`.
   No Excel em português, vira 1.027.440 (perde R$ 3,81) ou fica como
   texto. Qualquer número com centavos acima de um milhão sai assim (os
   totais em reais são inteiros e escapam).

## O que funciona para ele

- A folha por município (#580) tem o total declarado, o fechamento
  (escolas, Secretaria, fora da lista) e a divisão por fonte: com ela, ele
  monta a resposta ao conselho.
- O aviso de que a divisão por fonte não é a verificação do mínimo legal
  está certo e no lugar.
- O aviso de meses incompletos (setembro e outubro de 2025, junho de 2026)
  aparece no painel.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QE-01 | bloqueia | **O painel da rede mostra só o total da Secretaria e o chama de total da rede.** Para uma escola sem folha própria, o painel da rede soma só o código da Secretaria (sem escola), diz "Os números abaixo são o total da rede" e que "o SIOPE não detalha a folha por escola neste município", mesmo em anos em que detalha. O número que o secretário levaria ao conselho fica muito abaixo do declarado. Pedido: o painel da rede com toda a folha do município (escolas, Secretaria e fora da lista), como o fechamento da base, com a parte da Secretaria dita à parte; o texto do motivo conforme o ano (por escola em todos os meses, em parte ou só na Secretaria). | Cuiabá 2025: painel R$ 17,1 mi e 816 profissionais; declarado R$ 489,5 mi, 12 meses por escola. 2026: painel R$ 295,9 mi; declarado R$ 354,2 mi (jan e fev por escola) | P2, P5, P6 |
| QE-02 | atrapalha | **Sem a receita do Fundeb, não há o percentual dos 70%.** A plataforma divide a folha por fonte, mas não tem a receita do Fundeb do município; a pergunta do conselho (quanto da receita foi para a remuneração dos profissionais) e a do prefeito (a adequação cabe?) ficam sem resposta. Pedido: carregar a receita anual do Fundeb por município de uma fonte oficial (a levantar: FNDE, Tesouro ou os indicadores do SIOPE) e mostrar a parte da folha paga pela parcela de 70% sobre essa receita, com o aviso de que não é a verificação legal (que usa a despesa liquidada e as regras da lei). | Cuiabá 2025: R$ 457,2 mi pela parcela de 70%, receita desconhecida na tela | P2, P5, P6 |
| QE-03 | incomoda | **Números com centavos acima de um milhão saem em notação científica nos CSV.** O formato dos números usa seis dígitos significativos; um valor como 1.027.436,19 vira `1,02744e+06`. Pedido: números não inteiros com as casas decimais fixas (duas para reais), sem notação científica, em todos os CSV que usam o mesmo formato. | `abaixo_piso_diferenca_mensal` de Cuiabá 2026 na folha por município de MT | P2, P4, P6 |

Não é achado: agosto de 2026 tem 8.650 registros, dois terços de um mês
típico, e não é marcado como incompleto (a regra marca abaixo da metade).
Pode ser uma carga feita no meio do mês; ele anotou para conferir na
próxima carga.

## Veredito

**Adotaria, em piloto numa rede** (mantido, com ressalva forte). A
resposta ao conselho sai da folha por município, mas o painel, que é a
tela que ele abriria primeiro, mostra um total errado com o rótulo de
total da rede (QE-01). Se o conselho visse o painel, a confiança na
plataforma acabaria ali.

## Encaminhamento

Achados para o developer decidir se viram issues. Sugestão: QE-01 primeiro
(número errado com rótulo certo), QE-03 junto ou logo depois (pequeno);
QE-02 pede antes levantar a fonte da receita.
