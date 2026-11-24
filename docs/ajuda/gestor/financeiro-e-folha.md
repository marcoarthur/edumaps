---
titulo: "Financeiro e Folha (SIOPE)"
publico: [gestor]
modulo: gestor
nivel: intermediario
status: ativo
relacionadas: [painel-da-escola]
funcionalidade: ../../funcionalidades/analise/financeiro.md
ultima_revisao: 2026-11-24
---

# Financeiro e Folha (SIOPE)

> **Para quem:** Gestor que consulta informações financeiras/orçamentárias  
> **Tempo de leitura:** ~5 min

## Em 30 segundos
O módulo financeiro apresenta informações com base no **SIOPE** (Sistema de Informações sobre Orçamentos Públicos em Educação). É fundamental entender a diferença entre **valor da escola** e **valor agregado da Secretaria/município**.

## Passo a passo
1. **Onde ir:** Painel da Escola → *Financeiro e Folha*
2. **O que ver:** Indicadores disponíveis para o recorte exibido
3. **O que fazer:** Verifique ano, fonte e o **nível de agregação** mostrado
4. **Como saber que deu certo:** Valores aparecem ou "n/d"

## Entendendo os números
- **Um ano por vez.** Em **Ano da folha**, escolha o ano (o padrão é o mais
  recente). O custo total, os profissionais, as categorias e os gráficos são
  desse ano, e o cartão diz os meses ("Custo total em 2025 (jan a dez)"). Um
  ano com poucos meses (ex.: "jan a fev (2 meses)") ainda está chegando.
- **Por fonte de recurso.** O cartão **Por fonte de recurso** divide o custo
  do ano pela origem do dinheiro, como o município declara ao SIOPE em cada
  pagamento: **Fundeb, parcela de 70%**, **Fundeb, parcela de 30%** e
  **Outras fontes** (fora do Fundeb), com o valor e o percentual. As três
  somam o custo total. **Não é a verificação do mínimo de 70% exigido em
  lei:** essa conta divide o gasto com os profissionais pela receita do
  Fundeb do município, e a receita não está na plataforma. Serve para
  conferir a prestação de contas, por exemplo no conselho do Fundeb.
- **Mês com a folha pela metade.** Quando um mês tem bem menos profissionais
  declarados que os outros (menos categorias, ou menos da metade dos
  registros de um mês típico), um aviso acima dos gráficos diz qual mês e os
  números. Nesse mês o custo e os profissionais ficam abaixo do real, e o
  total do ano também. A causa pode ser a declaração do município ao SIOPE
  ou a carga; a plataforma não corrige os números. Para refazer o gasto do
  ano sem esses meses, de todas as escolas de uma vez, a
  [base de análise](../comunidade/base-de-analise.md) traz o gasto só dos
  meses completos.
- **Meses só com o total da Secretaria.** Se o município passou a declarar a
  folha no total da Secretaria, sem separar as escolas, um aviso diz em que
  meses isso aconteceu (ex.: "De março a agosto de 2026"). Nesses meses a
  folha da escola não aparece, e o custo do ano fica abaixo do real.
- **Dezembro inclui o 13º salário:** o custo de dezembro é maior que o dos
  outros meses.
- **Como os profissionais são contados:** cada pessoa conta uma vez, pelo CPF
  mascarado **e** pelo nome. O SIOPE publica só seis dígitos do CPF, e
  pessoas diferentes podem ter o mesmo CPF mascarado; contar só por ele
  deixava o total abaixo do real.
- **Agregado da Secretaria ≠ escola.** Em muitos casos os valores são consolidados por rede/município/Secretaria, não por unidade escolar individual (#70/#91).
  Mesmo onde o SIOPE separa as escolas, parte da folha fica na Secretaria,
  sem escola: somar as escolas não dá o total do município. A
  [base de análise](../comunidade/base-de-analise.md) mostra a conta
  (escolas, Secretaria e escolas fora da lista do Censo).
- **"n/d"** = não disponível. Ausência nunca é zero (#154).
- **Ano de referência** — sempre verifique qual exercício está sendo exibido.

## Limitações conhecidas
- **Cobertura parcial:** nem todas as escolas têm desagregação por unidade no SIOPE.
- **Só a rede municipal:** o SIOPE traz a remuneração da rede municipal. Escola
  estadual, federal ou privada não tem folha aqui, e a tela diz isso.
- **Poucos municípios carregados:** quando não há folha, o painel lista de
  quais municípios há (anos e se o dado é por escola ou só o total da
  Secretaria).
- **Divergências entre recortes** podem ocorrer por forma de consolidação.
- **Atraso na publicação** dos dados oficiais.

## Privacidade
- **Agregados:** sempre que possível são exibidos valores agregados.
- **Sem PII:** não devem ser exibidos dados individuais de servidores em listas públicas.
- **Cuidado com cópias:** evite exportar planilhas com dados sensíveis fora do ambiente autorizado.

## Perguntas frequentes
- **Por que o valor não bate com a escola?** Provavelmente é um valor **agregado** da rede/Secretaria, não desagregado por unidade.
- **Não vejo "Folha" para minha escola?** O painel diz o motivo: a escola não
  é da rede municipal; o município ainda não foi carregado (o gestor da escola,
  com login, pode pedir a busca no SIOPE pelo próprio painel); ou o município
  tem folha, mas o SIOPE não traz profissionais desta escola nem um total da
  Secretaria.

## Veja também
- [Painel da escola](painel-da-escola.md)
- [Glossário](../_glossario.md)
