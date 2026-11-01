// src/shared/tour/tours/gestorEnvios.js
//
// Tour dos envios de e-mail (/gestor/envios). Exige login. `prontoQuando` é
// a LISTA de envios, não o painel de limites: chegando por “Enviar e-mail”
// (?novo=1), a página abre direto no editor e a lista não existe; nesse caso
// o tour não abre (nem marca visto) e fica para a visita à lista.
// Textos conferidos com docs/funcionalidades/gestor/envios-email.md.

export default {
  id: "gestor-envios",
  versao: 1,
  titulo: "Enviar e-mails",
  rotaInicial: "/gestor/envios",
  automatico: true,
  prontoQuando: "envios-lista",
  passos: [
    {
      alvo: "envios-limites",
      titulo: "Limites de hoje",
      texto:
        "Quanto ainda pode ser enviado hoje, dentro da cota diária e do máximo por envio definidos pela administração. " +
        "Se a cota acabar, o envio pausa e continua no dia seguinte. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "envios-lista",
      titulo: "Seus envios",
      texto:
        "Cada envio aparece com o seu estado (rascunho, agendado, enviando, pausado pela cota, concluído…). " +
        "Filtre por estado e abra um envio para ver o resultado. " +
        "Não há rastreio de abertura nem de clique.",
      lado: "top",
    },
    {
      alvo: "envios-novo",
      titulo: "Novo envio",
      texto:
        "Assunto, texto e motivo; os destinatários são uma lista ou uma lista dinâmica. Envie agora ou agende até 90 dias. " +
        "O teste para você mesmo não gasta cota, e todo e-mail leva um link para a pessoa sair. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "left",
    },
  ],
};
