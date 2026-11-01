// src/shared/tour/tours/gestorSegmentos.js
//
// Tour das listas dinâmicas (/gestor/segmentos). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/listas-autoinscricao.md e
// envios-email.md (não há ficha própria).

export default {
  id: "gestor-segmentos",
  versao: 1,
  titulo: "Listas dinâmicas",
  rotaInicial: "/gestor/segmentos",
  automatico: true,
  prontoQuando: "segmentos-lista",
  passos: [
    {
      alvo: "segmentos-lista",
      titulo: "Listas dinâmicas",
      texto:
        "Uma lista dinâmica é um filtro salvo sobre os inscritos das suas listas: por exemplo, só os confirmados de duas listas. " +
        "Apagar uma lista dinâmica não muda as listas nem os inscritos. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "segmentos-nova",
      titulo: "Criar uma lista dinâmica",
      texto:
        "Escolha as listas e filtre pelo estado do inscrito, pelo e-mail confirmado e pelo período de inscrição. " +
        "A prévia mostra quantas pessoas entram e uma amostra com e-mails parcialmente mascarados.",
      lado: "left",
    },
    {
      alvo: "segmentos-atalhos",
      titulo: "Para que serve",
      texto:
        "Use a lista dinâmica como destinatário em Envios: quem está em várias listas recebe um e-mail só. " +
        "É o jeito de mandar só para os confirmados. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
