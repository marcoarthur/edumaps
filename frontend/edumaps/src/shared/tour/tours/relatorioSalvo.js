// src/shared/tour/tours/relatorioSalvo.js
//
// Tour de um relatório salvo (/gestor/relatorios/salvos/:id). Exige login;
// `prontoQuando` no aviso de fotografia, que só aparece com o relatório
// carregado (não no "não encontrado").

export default {
  id: "relatorio-salvo",
  versao: 1,
  titulo: "Relatório salvo",
  rotaInicial: "/gestor/relatorios/salvos/:id",
  automatico: true,
  prontoQuando: "salvo-fotografia",
  passos: [
    {
      alvo: "salvo-fotografia",
      titulo: "Fotografia",
      texto:
        "Este relatório mostra os números da data indicada aqui, mesmo que os dados tenham mudado depois. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "salvo-gerar",
      titulo: "Gerar de novo",
      texto:
        "Gera um relatório novo com o mesmo recorte, tema e opções, usando os dados atuais. " +
        "Este salvo continua como está.",
      lado: "bottom",
    },
    {
      alvo: "relatorio-acoes",
      titulo: "Levar para fora",
      texto:
        "Imprima (ou salve em PDF) ou baixe em Markdown para usar em documentos. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
    },
  ],
};
