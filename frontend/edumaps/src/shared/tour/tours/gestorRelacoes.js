// src/shared/tour/tours/gestorRelacoes.js
//
// Tour das relações institucionais (/gestor/relacoes). Exige login. Só a aba
// padrão (“Relações”) é destacada. Interações, documentos e tarefas ficam no
// detalhe da relação (“Abrir”), não nesta página — a ficha sugeria o
// contrário. Textos conferidos com relacoes-institucionais.md e o código.

export default {
  id: "gestor-relacoes",
  versao: 1,
  titulo: "Relações da escola",
  rotaInicial: "/gestor/relacoes",
  automatico: true,
  prontoQuando: "relacoes-abas",
  passos: [
    {
      alvo: "relacoes-abas",
      titulo: "Quatro seções",
      texto:
        "“Relações” com as entidades de fora da escola; “Agenda” com os prazos por mês e os vencidos em destaque; " +
        "“Indicadores” com demandas por grupo e relações sem atividade há 60 dias; “Entidades externas” para cadastrá-las. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "relacoes-filtros",
      titulo: "Filtrar",
      texto: "Busque por assunto ou entidade e filtre por status e prioridade.",
      lado: "bottom",
    },
    {
      alvo: "relacoes-nova",
      titulo: "Nova relação",
      texto:
        "Registre assunto, finalidade, responsável, próxima ação com prazo, status e prioridade. " +
        "A entidade precisa estar cadastrada antes, em “Entidades externas”.",
      lado: "left",
    },
    {
      alvo: "relacoes-lista",
      titulo: "As relações",
      texto:
        "Cada uma mostra o status, a prioridade, a próxima ação e se está vencida. " +
        "“Abrir” leva ao detalhe, com as interações, os documentos e as tarefas. Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
