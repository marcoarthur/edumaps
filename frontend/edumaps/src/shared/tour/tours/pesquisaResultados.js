// src/shared/tour/tours/pesquisaResultados.js
//
// Tour dos resultados de uma pesquisa (/gestor/pesquisas/resultados?pesquisa=).
// Exige login. Textos conferidos com o código: opções com contagem e
// percentual; respostas livres listadas uma a uma, com data.

export default {
  id: "pesquisa-resultados",
  versao: 1,
  titulo: "Ler os resultados",
  rotaInicial: "/gestor/pesquisas/resultados",
  automatico: true,
  prontoQuando: "pesq-resultados",
  passos: [
    {
      alvo: "pesq-resultados-total",
      titulo: "Total de respostas",
      texto:
        "Quantas pessoas responderam até agora. Sem respostas ainda? Compartilhe o link da pesquisa. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "pesq-resultados-perguntas",
      titulo: "Por pergunta",
      texto:
        "Nas perguntas de escolha, cada opção mostra quantas respostas teve e o percentual. " +
        "As respostas livres aparecem uma a uma, com a data. Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
