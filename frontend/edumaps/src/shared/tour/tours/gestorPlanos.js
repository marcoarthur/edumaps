// src/shared/tour/tours/gestorPlanos.js
//
// Tour da lista de planos de gestão (/gestor/planos, #371). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/planos-gestao.md.

export default {
  id: "gestor-planos",
  versao: 1,
  titulo: "Planos de gestão",
  rotaInicial: "/gestor/planos",
  automatico: true,
  prontoQuando: "planos-acoes",
  passos: [
    {
      alvo: "planos-acoes",
      titulo: "Criar um plano",
      texto:
        "Cadastre o plano de gestão, o plano de ação (PDDE/PDE Escola), o PPP ou outro plano. " +
        "Ele nasce como rascunho; o arquivo do plano continua em Documentos e planos. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "planos-lista",
      titulo: "Seus planos",
      texto: "Cada plano mostra a situação, quantas ações já foram concluídas e quantas estão atrasadas.",
      lado: "top",
    },
  ],
};
