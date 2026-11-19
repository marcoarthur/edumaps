---
titulo: "Perfil da escola: diagnóstico e comparação justa"
publico: [gestor]
modulo: gestor
nivel: intermediario
status: ativo
relacionadas: [painel-da-escola, escolas-semelhantes, agrupamentos-de-escolas]
funcionalidade: ../../funcionalidades/analise/perfil-escola.md
ultima_revisao: 2026-11-18
---

# Perfil da escola: diagnóstico e comparação justa

> **Para quem:** Gestor que quer saber onde a escola está bem e onde precisa de atenção  
> **Tempo de leitura:** ~5 min

## Em 30 segundos

O **Perfil da Escola** reúne num só lugar os indicadores da escola lado a lado
com o município, a rede de ensino, o Brasil e o **grupo de referência**: as
30 escolas do município de contexto mais parecido. Ele aponta os **sinais de atenção** — indicadores em que a escola
está entre as mais baixas do seu grupo — e sugere **escolas similares** para
trocar experiências.

## Passo a passo

1. **Onde ir:** no [Painel da Escola](painel-da-escola.md) ou no
   [Painel do Gestor](painel-do-gestor.md), clique em **Perfil analítico**.
   O perfil é público: qualquer pessoa pode abri-lo, sem login.
2. **O que ver:** no topo, o nome da escola, município, UF, código INEP, o ano
   do Censo usado e o grupo de referência ("30 escolas de contexto mais
   parecido no município").
3. **O que fazer:** comece por **Sinais de atenção**; depois confira a linha
   correspondente em **Posição relativa** para ver o valor da escola e das
   referências.
4. **Como saber que deu certo:** as seções aparecem preenchidas; um valor que
   não existe aparece como **–**.

## Entendendo os números

- **Sinais de atenção:** cada sinal tem gravidade **Alta**, **Média** ou
  **Baixa**. Aparece quando a escola está **pior que o seu grupo**: no
  **Q1** quando maior é melhor (ex.: IDEB) ou no **Q4** quando menor é
  melhor (docentes sem especialização, alunos por docente), e abaixo/acima da
  mediana do grupo. Empatar com a mediana não gera sinal. Não é um julgamento
  absoluto: um indicador pode ser baixo no grupo e ainda aceitável no Brasil.
  Sem sinais, a tela diz *"Nenhum indicador pior que o grupo de
  referência"*. O **INSE** aparece na comparação, mas **não gera sinal**: é
  o nível socioeconômico dos alunos, o contexto, e não algo em que a escola
  possa agir.
- **Posição relativa:** tabela com **Escola | Município | Rede | Brasil |
  Grupo | Quartil**. O quartil vai de **Q1** (os 25% mais baixos do grupo)
  a **Q4** (os 25% mais altos). Os indicadores em que menor é melhor trazem
  a nota *"menor é melhor"*. Linhas em atenção ficam destacadas com ⚠.
- **IDEB e nota SAEB na posição relativa:** a linha diz a edição e a etapa
  (ex.: *IDEB observado 2023, anos finais*). Com mais de uma etapa, vale a
  de maior nota da escola. Município, rede, Brasil e grupo são da **mesma
  etapa**, só com as escolas que têm nota nela: a escala do SAEB cresce com
  a série e o IDEB cai (no Brasil, em 2023, 5,7 nos anos iniciais, 4,7 nos
  anos finais e 4,3 no ensino médio). Até 17/11/2026, essas médias
  misturavam as etapas, e uma escola de ensino médio na média nacional
  aparecia cerca de 1 ponto abaixo do "Brasil".
- **IDEB em cada etapa:** a escola com nota em mais de uma etapa vê cada uma
  numa tabela, com o município, a rede e o Brasil da mesma etapa. A linha
  destacada é a usada na posição relativa.
- **Evolução:** IDEB e notas do SAEB (média, matemática e português) **por
  etapa** ao longo das edições, com ▲/▼ para a variação entre a primeira e
  a última edição da série. Série de uma edição só não tem variação. Só
  aparecem anos em que a prova foi aplicada; nada é interpolado nem
  projetado. Até 17/11/2026, as notas do SAEB eram só as dos anos iniciais,
  sem dizer, e as escolas só de anos finais ou de ensino médio ficavam sem
  elas.
- **Distribuição no grupo de referência:** média, p25, p50 (mediana), p75 e
  **N**, o número de escolas do grupo **com aquele dado** (o grupo tem 30;
  o IDEB, por exemplo, só as que têm nota na etapa da escola), para você ver
  onde a escola cai.
- **–** quer dizer *dado não disponível*. Ausência nunca é zero.
- **Fontes:** Censo Escolar (docentes e matrículas), IDEB/SAEB e INSE, na
  edição mais recente.

## Por que comparar com o grupo de referência

Comparar uma escola rural pequena com a média do Brasil costuma ser injusto. O
grupo de referência são as **30 escolas do mesmo município de contexto mais
parecido**, e a comparação dentro dele mostra o que é possível em realidades
semelhantes.

**Como o grupo é formado:** pela distância de Gower, com o mesmo peso para
cinco dimensões de contexto:

- a **rede** (federal, estadual, municipal ou privada);
- a **localização** (urbana ou rural);
- o **porte** (matrículas, em escala logarítmica);
- as **etapas oferecidas** (infantil, anos iniciais, anos finais, médio e
  EJA, que dividem o peso de uma dimensão);
- o **INSE** (quando a escola não tem INSE, ele sai da conta).

O **IDEB, a nota SAEB e os indicadores de docentes não entram**: são o que se
compara com o grupo. Se entrassem, uma escola de IDEB baixo seria posta entre
escolas de IDEB baixo e pareceria normal. Até 18/11/2026 era assim: o grupo
saía de um agrupamento sobre os próprios indicadores comparados.

Município com até 30 outras escolas: o grupo é o município inteiro.

## Limitações conhecidas

- O grupo é sempre do **mesmo município**: num município pequeno, as 30
  escolas mais parecidas podem não ser tão parecidas assim.
- O contexto é o que o Censo e o SAEB dizem; o que eles não medem (a
  violência do bairro, por exemplo) não entra.
- Indicadores sem dado para a escola (por exemplo, sem IDEB na etapa) aparecem
  como **–** e não geram sinal de atenção.
- O perfil é recalculado periodicamente; a data aparece em
  *"Perfil atualizado em…"*.

## Perguntas frequentes

- **Por que o IDEB não forma o grupo?** Porque o grupo serve de régua para o
  IDEB. Uma escola de IDEB baixo comparada só com escolas de IDEB baixo
  nunca apareceria abaixo do grupo.
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
