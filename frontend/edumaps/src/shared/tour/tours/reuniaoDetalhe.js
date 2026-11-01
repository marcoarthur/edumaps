// src/shared/tour/tours/reuniaoDetalhe.js
//
// Tour do detalhe de uma reunião (/gestor/reunioes/:id). Exige login. O
// bloco de ações (realizada/cancelar/editar/excluir) muda com o status e
// fica fora dos alvos. Textos conferidos com o código (anexos até 10 MB; ata
// em texto livre, bloqueada se a reunião foi cancelada).

export default {
  id: "reuniao-detalhe",
  versao: 1,
  titulo: "Acompanhar uma reunião",
  rotaInicial: "/gestor/reunioes/:id",
  automatico: true,
  prontoQuando: "reuniao-detalhe",
  passos: [
    {
      alvo: "reuniao-resumo",
      titulo: "Situação",
      texto:
        "O status (agendada, realizada ou cancelada), a forma de aviso e quantos participantes. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "reuniao-convite",
      titulo: "Convite",
      texto: "O convite pronto para copiar e mandar por WhatsApp ou e-mail. A plataforma não envia por você.",
      lado: "top",
    },
    {
      alvo: "reuniao-anexos",
      titulo: "Pauta e ata em arquivo",
      texto: "Anexe a pauta e a ata (PDF, documento, planilha, imagem ou texto, até 10 MB). Enviar de novo substitui o anterior.",
      lado: "top",
    },
    {
      alvo: "reuniao-ata",
      titulo: "Ata",
      texto:
        "Registre o que foi decidido, quem assume o quê e até quando. Uma reunião cancelada não aceita ata. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
