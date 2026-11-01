// src/shared/tour/tours/assistenteCenso.js
//
// Tour do Assistente do Censo (/chat/censo). Exige login de gestor:
// `prontoQuando` é o painel de escopo, que só existe com a sessão carregada.
// Textos conferidos com docs/funcionalidades/analise/assistente-censo.md,
// historico-conversas.md e o código: salvar a conversa é MANUAL (botão +
// título opcional) — a ficha do histórico dizia “automaticamente” e foi
// corrigida junto.

export default {
  id: "assistente-censo",
  versao: 1,
  titulo: "Usar o Assistente do Censo",
  rotaInicial: "/chat/censo",
  automatico: true,
  prontoQuando: "chat-escopo",
  passos: [
    {
      alvo: "chat-escopo",
      titulo: "Escopo da consulta",
      texto:
        "As perguntas valem para a sua escola e o seu município, que vêm da sua conta de gestor e não mudam aqui. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "chat-pergunta",
      titulo: "Pergunte em português",
      texto:
        "Sobre escolas, matrículas, docentes, infraestrutura, indicadores e finanças — por exemplo, " +
        "“quantos alunos tem minha escola?”. Enter envia; Shift+Enter quebra a linha.",
      lado: "top",
    },
    {
      alvo: "chat-conversa",
      titulo: "A resposta",
      texto:
        "Vem com os números e, quando ajuda, um gráfico. Em “Ver SQL executado” e “Ver resultado” você confere a consulta e os dados. " +
        "Só dados públicos são consultados, e informações pessoais são removidas do retorno.",
      lado: "top",
    },
    {
      alvo: "chat-acoes",
      titulo: "Guardar e reencontrar",
      texto:
        "“Salvar conversa” guarda esta conversa, com um título opcional: ela só fica no histórico se você salvar. " +
        "“Buscar conversas anteriores” abre o histórico, com busca, calendário e exportação. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
