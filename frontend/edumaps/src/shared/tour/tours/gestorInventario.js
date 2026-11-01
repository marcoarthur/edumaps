// src/shared/tour/tours/gestorInventario.js
//
// Tour do inventário (/gestor/inventario). Exige login. Só a aba padrão
// (“Do Censo”) é destacada: as outras só existem depois de um clique.
// Textos conferidos com docs/funcionalidades/gestor/inventario.md e o código
// (anexos só aparecem ao editar um item já salvo).

export default {
  id: "gestor-inventario",
  versao: 1,
  titulo: "Inventário da escola",
  rotaInicial: "/gestor/inventario",
  automatico: true,
  prontoQuando: "inventario-abas",
  passos: [
    {
      alvo: "inventario-abas",
      titulo: "Quatro seções",
      texto:
        "“Do Censo” mostra o que o Censo Escolar registra; “Recursos” são os bens da escola; " +
        "“Serviços” são os contratos (com valor e periodicidade); “Fornecedores” reúne fornecedores e prestadores. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "inventario-censo",
      titulo: "Do Censo",
      texto: "Os dados do Censo aparecem só para leitura, agrupados como o Censo os registra.",
      lado: "top",
    },
    {
      alvo: "inventario-importar",
      titulo: "Começar pelo Censo",
      texto:
        "“Importar para o inventário” copia esses itens para o seu inventário sem alterar o Censo; importar de novo só traz o que for novo. " +
        "Depois, crie categorias livres e, ao editar um item salvo, acrescente atributos e anexos (fotos, notas fiscais). " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "left",
    },
  ],
};
