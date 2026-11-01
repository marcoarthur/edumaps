// src/shared/tour/tours/gestorContatos.js
//
// Tour da agenda de contatos (/gestor/contatos). Exige login de gestor.
// Textos conferidos com docs/funcionalidades/gestor/contatos-grupos.md e
// com IMPORT_MAX (constants/reunioes.js).

export default {
  id: "gestor-contatos",
  versao: 1,
  titulo: "Organizar os contatos",
  rotaInicial: "/gestor/contatos",
  automatico: true,
  prontoQuando: "contatos-grade",
  passos: [
    {
      alvo: "contatos-importar",
      titulo: "Importar contatos",
      texto:
        "Cole uma pessoa por linha no formato “nome; email; telefone; grupo” (até 200 por vez). " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "right",
      alinhamento: "start",
    },
    {
      alvo: "contatos-folha",
      titulo: "Da folha de pagamento",
      texto:
        "Traz nome e cargo dos profissionais da escola, organizados em grupos da folha, sem repetir quem já está na agenda.",
      lado: "right",
    },
    {
      alvo: "contatos-grupos",
      titulo: "Grupos",
      texto:
        "Crie grupos para organizar a agenda (ex.: conselho escolar). Os grupos que vieram da folha não podem ser apagados.",
      lado: "right",
    },
    {
      alvo: "contatos-lista",
      titulo: "Sua agenda",
      texto:
        "Busque, edite ou exclua contatos, ou crie um novo. Esta agenda é a base das reuniões e das relações institucionais. " +
        "Contatos são dados pessoais: só o gestor da escola tem acesso. Para rever esta ajuda, use o “?” no menu.",
      lado: "left",
      alinhamento: "start",
    },
  ],
};
