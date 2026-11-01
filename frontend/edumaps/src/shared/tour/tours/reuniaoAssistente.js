// src/shared/tour/tours/reuniaoAssistente.js
//
// Tour do assistente de reunião (/gestor/reunioes/nova e /:id/editar). Exige
// login. Mesma estrutura nos dois modos; a 1ª tela é sempre o passo “Quando”.
// NÃO há salvamento automático: nada é gravado até o botão final. O convite
// é só para copiar (ConviteBox: “sem envio real”). Textos conferidos com o
// código.

export default {
  id: "reuniao-assistente",
  versao: 1,
  titulo: "Agendar uma reunião",
  rotaInicial: ["/gestor/reunioes/nova", "/gestor/reunioes/:id/editar"],
  automatico: true,
  prontoQuando: "reuniao-passos",
  passos: [
    {
      alvo: "reuniao-passos",
      titulo: "Quatro passos",
      texto:
        "Quando, Quem, Aviso e Pauta. Dá para voltar a um passo anterior clicando nele. " +
        "Em “Aviso”, o convite fica pronto para você copiar e mandar por WhatsApp ou e-mail — a plataforma não envia. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "reuniao-etapa",
      titulo: "Quando",
      texto: "Título, data e hora, duração (de 15 a 480 minutos) e onde: o nome do local ou o link da chamada.",
      lado: "top",
    },
    {
      alvo: "reuniao-navegacao",
      titulo: "Avançar e salvar",
      texto:
        "“Continuar” passa ao próximo passo. Atenção: nada é salvo até o último passo, no botão " +
        "“Agendar reunião” (ou “Salvar alterações”, ao editar). Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
