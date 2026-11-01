// src/shared/tour/tours/relacaoDetalhe.js
//
// Tour do detalhe de uma relação institucional (/gestor/relacoes/:id). Exige
// login. Interações, tarefas e documentos ficam nesta página (a lista de
// relações é outra). Textos conferidos com relacoes-institucionais.md e o
// código.

export default {
  id: "relacao-detalhe",
  versao: 1,
  titulo: "Acompanhar uma relação",
  rotaInicial: "/gestor/relacoes/:id",
  automatico: true,
  prontoQuando: "relacao-resumo",
  passos: [
    {
      alvo: "relacao-resumo",
      titulo: "Resumo",
      texto:
        "Status, prioridade, finalidade, quem responde por ela na escola, a próxima ação e o prazo. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "relacao-interacoes",
      titulo: "Histórico de interações",
      texto: "Cada contato com a entidade — reunião, ofício, ligação — com assunto, canal e o encaminhamento dado.",
      lado: "top",
    },
    {
      alvo: "relacao-tarefas",
      titulo: "Tarefas",
      texto: "Uma lista do que fazer, com prazo e responsável; marque o que já foi feito.",
      lado: "top",
    },
    {
      alvo: "relacao-documentos",
      titulo: "Documentos",
      texto:
        "Ofícios, protocolos e outros documentos da relação, com tipo, data e número de referência. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
