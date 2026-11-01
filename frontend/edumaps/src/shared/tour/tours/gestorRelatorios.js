// src/shared/tour/tours/gestorRelatorios.js
//
// Tour do Assistente de Relatório (/gestor/relatorios). Exige login de
// gestor: `prontoQuando` espera o formulário, que só existe com a sessão
// válida e o recorte padrão carregado.
//
// Textos conferidos com docs/funcionalidades/analise/relatorios-territorio.md.

export default {
  id: "gestor-relatorios",
  versao: 1,
  titulo: "Gerar um relatório",
  rotaInicial: "/gestor/relatorios",
  automatico: true,
  prontoQuando: "relatorio-form",
  passos: [
    {
      alvo: "relatorio-form",
      titulo: "Assistente de Relatório",
      texto:
        "Aqui você gera um relatório em texto sobre a sua escola ou o território, a partir de dados públicos. " +
        "Escolha o recorte e o tema e clique em gerar. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "top",
      alinhamento: "start",
    },
    {
      alvo: "relatorio-recorte",
      titulo: "Recorte",
      texto:
        "Sobre o quê: a escola, o município, a UF ou a região. O padrão vem da sua escola; " +
        "em “Escolher outro” você seleciona outro território.",
      lado: "bottom",
    },
    {
      alvo: "relatorio-tema",
      titulo: "Tema",
      texto:
        "O assunto do relatório. Cada nível de recorte só oferece os temas que os dados realmente cobrem. " +
        "No relatório completo do município, os capítulos são fixos e saem juntos, com um resumo geral.",
      lado: "top",
    },
    {
      alvo: "relatorio-gerar",
      titulo: "Gerar",
      texto:
        "O texto é escrito por IA usando só os números mostrados, sem afirmar causas, e cada número cita a fonte e a edição. " +
        "Se a IA estiver indisponível, o relatório sai com um resumo automático.",
      lado: "top",
      alinhamento: "start",
    },
    {
      alvo: "relatorio-salvos",
      titulo: "Meus relatórios",
      texto:
        "Depois de gerar, você pode imprimir (ou salvar em PDF), baixar em Markdown ou salvar em “Meus relatórios”, " +
        "onde só você vê e pode gerar de novo com os dados atuais. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
