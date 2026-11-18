---
titulo: "Financeiro e Folha (SIOPE)"
publico: [gestor]
modulo: gestor
nivel: intermediario
status: ativo
relacionadas: [painel-da-escola]
funcionalidade: ../../funcionalidades/analise/financeiro.md
ultima_revisao: 2026-11-18
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
- **Dezembro inclui o 13º salário:** o custo de dezembro é maior que o dos
  outros meses.
- **Como os profissionais são contados:** cada pessoa conta uma vez, pelo CPF
  mascarado **e** pelo nome. O SIOPE publica só seis dígitos do CPF, e
  pessoas diferentes podem ter o mesmo CPF mascarado; contar só por ele
  deixava o total abaixo do real.
- **Agregado da Secretaria ≠ escola.** Em muitos casos os valores são consolidados por rede/município/Secretaria, não por unidade escolar individual (#70/#91).
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
