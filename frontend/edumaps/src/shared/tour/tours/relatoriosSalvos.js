// src/shared/tour/tours/relatoriosSalvos.js
//
// Tour de "Meus relatórios" (/gestor/relatorios/salvos). Exige login: o
// `prontoQuando` está na tabela e no estado vazio (exclusivos), que só
// existem com a sessão carregada.

export default {
  id: "relatorios-salvos",
  versao: 1,
  titulo: "Meus relatórios",
  rotaInicial: "/gestor/relatorios/salvos",
  automatico: true,
  prontoQuando: "salvos-lista",
  passos: [
    {
      alvo: "salvos-lista",
      titulo: "Relatórios salvos",
      texto:
        "Cada relatório salvo é a fotografia do dia em que foi gerado: os números não mudam depois. " +
        "“Abrir” mostra de novo sem gerar outra vez; “Excluir” pede confirmação. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "top",
    },
    {
      alvo: "salvos-novo",
      titulo: "Novo relatório",
      texto:
        "Para guardar outro, gere um relatório e use “Salvar relatório”. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
    },
  ],
};
