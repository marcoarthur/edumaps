// src/shared/tour/tours/consentimentoVersoes.js
//
// Tour das versões do consentimento (/config/consentimento). Só admin: o
// `prontoQuando` está na seção de versões, que não existe no login nem na
// tela "restrita".

export default {
  id: "consentimento-versoes",
  versao: 1,
  titulo: "Versões do consentimento",
  rotaInicial: "/config/consentimento",
  automatico: true,
  prontoQuando: "consentimento-versoes",
  passos: [
    {
      alvo: "consentimento-versoes",
      titulo: "Versões",
      texto:
        "O texto que quem se inscreve nas listas das escolas aceita. Há uma versão vigente; " +
        "as anteriores ficam arquivadas, e cada inscrição guarda a versão que aceitou. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "top",
    },
    {
      alvo: "consentimento-nova",
      titulo: "Nova versão",
      texto:
        "Cria um rascunho, que pode ser editado com pré-visualização. Ao publicar (com confirmação), " +
        "ele vira o vigente, o anterior é arquivado e o publicado não pode mais ser alterado. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "left",
    },
  ],
};
