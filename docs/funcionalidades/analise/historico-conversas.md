---
titulo: Histórico de conversas
modulo: analise
status: parcial
audiencia: [gestor, pesquisador]
relacionadas: [assistente-censo, painel-escola]
---

# Histórico de conversas

> Módulo: `analise` · Status: 🟡 parcial · Público: gestor, pesquisador

## Resumo

O gestor guarda as conversas que teve com o Assistente do Censo, relê o que
perguntou antes, reencontra um assunto pelo texto e leva o registro para fora
da plataforma em Markdown.

## Para quem

O gestor que usa o assistente com frequência e quer retomar um raciocínio
anterior, e o pesquisador que precisa citá-lo.

## O que o sistema permite

- Sistema pode salvar automaticamente as conversas do gestor e listá-las por
  data, da mais recente para a mais antiga.
- Sistema pode mostrar em que dias houve conversas, para o gestor localizar
  um assunto pelo período em vez de rolar a lista.
- Sistema pode encontrar conversas pelo conteúdo das respostas, mostrando um
  trecho do texto que casou com a busca.
- Sistema pode filtrar a lista por um dia específico a partir do calendário.
- Sistema pode exportar uma conversa, um conjunto selecionado ou todo o
  histórico em um arquivo Markdown, para leitura, citação ou arquivo.
- Sistema pode permitir que o gestor exclua uma conversa que não queira mais
  manter.

## Valor

Evita refazer perguntas e dá continuidade ao trabalho: quem perguntou "como
ficou a matrícula da rede municipal?" no mês passado encontra a resposta em
segundos, em vez de reconstruir a consulta. O export em Markdown torna o
registro utilizável fora da plataforma — em relatório, em ata, em
documento de trabalho.

## Limitações conhecidas

- **Reabrir não funciona.** As conversas são guardadas e legíveis, mas
  não é possível retomar uma conversa salva dentro do assistente: a
  pergunta começa do zero. O histórico é registro e consulta, não sessão
  retomada.
- **A busca não ignora acentos.** Procurar "matriculas" não encontra
  "Matrículas"; é preciso digitar com acento.
- **A busca devolve a mesma conversa mais de uma vez** quando mais de uma
  mensagem casa com o termo.

## Relacionadas

- [Assistente do Censo](assistente-censo.md)
- [Painel da escola](painel-escola.md)
