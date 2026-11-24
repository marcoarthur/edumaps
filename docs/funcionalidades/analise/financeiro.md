---
titulo: Painel financeiro
modulo: analise
status: ativo
audiencia: [gestor, pesquisador, investidor]
relacionadas: [folha-pagamento, rede-municipal, painel-escola]
---

# Painel financeiro

> Módulo: `analise` · Status: 🟢 ativo · Público: gestor, pesquisador, investidor

## Resumo

A plataforma acompanha recursos e gastos da educação, apoiando a leitura de
como o dinheiro chega e é aplicado nas escolas e nos municípios.

## Para quem

Gestores escolares, gestão pública, pesquisadores e investidores.

## O que o sistema permite

- Sistema pode apresentar o resumo financeiro da educação por escola/município
  (custo por competência, total de profissionais distintos e custo por categoria),
  **um ano por vez**, com o período escrito (os meses com folha) e o aviso do
  13º em dezembro.
- Sistema pode **contar cada profissional uma vez**, pela pessoa (CPF mascarado
  e nome), sem juntar pessoas diferentes que o SIOPE publica com o mesmo CPF
  mascarado.
- Quando o SIOPE de um município não detalha a folha por escola, o sistema pode
  apresentar o **agregado da Secretaria municipal**, claramente **escopado como
  rede municipal** (não como se fosse da unidade), com aviso de que os números
  não permitem identificar quem atua na escola. A folha detalhada (nomes) fica
  indisponível nesse caso.
- Quando não há folha para a escola, o sistema diz o motivo (escola fora da
  rede municipal, município ainda sem dados, ou o SIOPE não traz a escola) e
  de quais municípios há folha, com os anos e se o dado é por escola ou só o
  total da Secretaria. O total da Secretaria só é usado para escolas da rede
  municipal, nunca para outra rede.
- Sistema pode **dizer de que fonte saiu a folha do ano**: a parte paga com a
  parcela de 70% do Fundeb, a de 30% e a de outras fontes, como o município
  declara ao SIOPE em cada pagamento, no painel e na base de análise. Avisa
  que não é a verificação do mínimo de 70% exigido em lei, porque a receita
  do Fundeb do município não está na plataforma.
- Sistema pode contextualizar os recursos frente à rede e ao desempenho.
- Sistema pode buscar, sob demanda e em segundo plano, os dados do **SIOPE**
  (remuneração municipal) de um ano que ainda não está disponível — para escolas
  da rede municipal, a partir do painel financeiro, pelo gestor da escola com
  login (o visitante é avisado de que essa busca existe). O progresso é acompanhado em
  tempo real, inclusive quando a busca falha.
- Sistema pode apoiar a prestação de contas e o planejamento orçamentário.

## Valor

Transparência e base objetiva para decisões de alocação de recursos.

## Relacionadas

- [Folha de pagamento](folha-pagamento.md)
- [Comparação de redes](rede-municipal.md)
- [Painel da escola](painel-escola.md)
