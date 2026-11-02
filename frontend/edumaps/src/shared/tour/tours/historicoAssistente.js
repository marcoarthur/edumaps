// src/shared/tour/tours/historicoAssistente.js
//
// Tour do histórico de conversas (/chat/historico). Exige sessão do
// gestor: o `prontoQuando` só é marcado depois da 1ª lista carregada.
// Textos conferidos com o código: o calendário marca os dias, mas não
// filtra a lista; reabrir uma conversa ainda não existe.

export default {
  id: "historico-assistente",
  versao: 1,
  titulo: "Histórico do Assistente",
  rotaInicial: "/chat/historico",
  automatico: true,
  prontoQuando: "historico-conversas",
  passos: [
    {
      alvo: "historico-conversas",
      titulo: "Conversas salvas",
      texto:
        "Aqui ficam só as conversas que você salvou no Assistente do Censo, da mais recente para a mais antiga. " +
        "A busca procura no texto das conversas (digite com acento). " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "left",
    },
    {
      alvo: "historico-calendario",
      titulo: "Calendário",
      texto: "Os dias marcados são os que têm conversas salvas, para você localizar um assunto pelo período.",
      lado: "right",
    },
    {
      alvo: "historico-exportar",
      titulo: "Exportar",
      texto:
        "Baixe todas, as selecionadas ou uma só em Markdown, para citar ou arquivar. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
    },
  ],
};
