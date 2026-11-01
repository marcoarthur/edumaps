// src/shared/tour/tours/gestorListas.js
//
// Tour das listas com autoinscrição por QR (/gestor/listas). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/listas-autoinscricao.md
// e com o formulário de criação (nome, descrição, o que coletar, exigir
// confirmação).

export default {
  id: "gestor-listas",
  versao: 1,
  titulo: "Listas e QR code",
  rotaInicial: "/gestor/listas",
  automatico: true,
  prontoQuando: "listas-suas",
  passos: [
    {
      alvo: "listas-suas",
      titulo: "Suas listas",
      texto:
        "Cada lista vira um QR code ou link para a comunidade se inscrever, sem criar conta. " +
        "Em “Inscrições” você vê quem entrou e o funil (aberturas, inscrições, confirmações). " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "listas-nova",
      titulo: "Criar uma lista",
      texto:
        "Dê um nome, escolha o que coletar (telefone, e-mail, ambos ou qualquer um) e se a inscrição exige confirmação. " +
        "Dá para mudar isso depois, nas inscrições da lista.",
      lado: "left",
    },
    {
      alvo: "listas-exclusoes",
      titulo: "Exclusões",
      texto:
        "Quando alguém pede para apagar seus dados, ou você remove um inscrito, nome, telefone e e-mail somem de todas as listas da escola. " +
        "Aqui fica só o histórico, com datas e quantidades.",
      lado: "top",
    },
    {
      alvo: "listas-atalhos",
      titulo: "Próximos passos",
      texto:
        "Daqui você vai para os envios de e-mail, as listas dinâmicas, os relatórios e os contatos. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
