---
titulo: "Perfil da escola: diagnóstico e comparação justa"
publico: [gestor]
modulo: gestor
nivel: intermediario
status: ativo
relacionadas: [painel-da-escola, escolas-semelhantes, agrupamentos-de-escolas]
funcionalidade: ../../funcionalidades/analise/perfil-escola.md
ultima_revisao: 2026-11-06
---

# Perfil da escola: diagnóstico e comparação justa

> **Para quem:** Gestor que quer saber onde a escola está bem e onde precisa de atenção  
> **Tempo de leitura:** ~5 min

## Em 30 segundos

O **Perfil da Escola** reúne num só lugar os indicadores da escola lado a lado
com o município, a rede de ensino, o Brasil e o **grupo de escolas parecidas**
(o cluster). Ele aponta os **sinais de atenção** — indicadores em que a escola
está entre as mais baixas do seu grupo — e sugere **escolas similares** para
trocar experiências.

## Passo a passo

1. **Onde ir:** no [Painel da Escola](painel-da-escola.md) ou no
   [Painel do Gestor](painel-do-gestor.md), clique em **Perfil analítico**.
   O perfil é público: qualquer pessoa pode abri-lo, sem login.
2. **O que ver:** no topo, o nome da escola, município, UF, código INEP, o ano
   do Censo usado e o nome do grupo de referência (cluster).
3. **O que fazer:** comece por **Sinais de atenção**; depois confira a linha
   correspondente em **Posição relativa** para ver o valor da escola e das
   referências.
4. **Como saber que deu certo:** as seções aparecem preenchidas; um valor que
   não existe aparece como **–**.

## Entendendo os números

- **Sinais de atenção:** cada sinal tem gravidade **Alta**, **Média** ou
  **Baixa**. Aparece quando a escola está no **quartil inferior (Q1)** do seu
  grupo. Não é um julgamento absoluto: um indicador pode ser baixo no grupo e
  ainda aceitável no Brasil. Sem sinais, a tela diz
  *"Nenhum indicador no quartil inferior do cluster"*.
- **Posição relativa:** tabela com **Escola | Município | Rede | Brasil |
  Cluster | Quartil**. O quartil vai de **Q1** (os 25% mais baixos do grupo)
  a **Q4** (os 25% mais altos). Linhas em atenção ficam destacadas com ⚠.
- **Evolução:** IDEB por etapa e notas do SAEB ao longo das edições, com ▲/▼
  para a variação. Só aparecem anos em que a prova foi aplicada; nada é
  interpolado nem projetado.
- **Distribuição no cluster:** média, p25, p50 (mediana), p75 e número de
  escolas (N) do grupo, para você ver onde a escola cai.
- **–** quer dizer *dado não disponível*. Ausência nunca é zero.
- **Fontes:** Censo Escolar (docentes e matrículas), IDEB/SAEB e INSE, na
  edição mais recente.

## Por que comparar com o cluster

Comparar uma escola rural pequena com a média do Brasil costuma ser injusto. O
cluster junta escolas de **contexto parecido** (porte, etapas, nível
socioeconômico, localização), e a comparação dentro dele mostra o que é
possível em realidades semelhantes. Veja
[Agrupamentos de escolas](agrupamentos-de-escolas.md).

## Limitações conhecidas

- Se a escola ainda não tem cluster calculado, o grupo é **estimado no próprio
  município**; a comparação fica mais restrita.
- Indicadores sem dado para a escola (por exemplo, sem IDEB na etapa) aparecem
  como **–** e não geram sinal de atenção.
- O perfil é recalculado periodicamente; a data aparece em
  *"Perfil atualizado em…"*.

## Perguntas frequentes

- **A escola está "em atenção" mas a nota parece boa?** O sinal é relativo ao
  grupo de escolas parecidas, não ao Brasil. Confira a coluna **Brasil** na
  mesma linha.
- **Por que meu IDEB não aparece em um ano?** O IDEB só existe em anos de
  aplicação (ímpares) e só quando há resultado publicado para a escola.

## Veja também

- [Escolas semelhantes](escolas-semelhantes.md)
- [Painel da Escola](painel-da-escola.md)
- [Glossário](../_glossario.md)
- Ficha da funcionalidade: [Perfil da escola](../../funcionalidades/analise/perfil-escola.md)
