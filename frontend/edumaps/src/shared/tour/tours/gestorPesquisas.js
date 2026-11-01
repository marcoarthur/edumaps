// src/shared/tour/tours/gestorPesquisas.js
//
// Tour das pesquisas com a comunidade (/gestor/pesquisas?inep=...). Esta
// lista não exige login (a API é anônima; resultados exigem). O alvo
// `pesq-conteudo` está no estado vazio E na lista — só um existe por vez —,
// então o `prontoQuando` cobre os dois e exclui carregando/erro/sem INEP.
// Textos conferidos com docs/funcionalidades/gestor/pesquisas.md e o código.

export default {
  id: "gestor-pesquisas",
  versao: 1,
  titulo: "Pesquisas com a comunidade",
  rotaInicial: "/gestor/pesquisas",
  automatico: true,
  prontoQuando: "pesq-conteudo",
  passos: [
    {
      alvo: "pesq-conteudo",
      titulo: "Pesquisas da escola",
      texto:
        "Aqui ficam as pesquisas da escola: rascunhos, publicadas e arquivadas. Um rascunho você continua de onde parou; " +
        "uma publicada tem “Copiar link”, para a comunidade responder sem criar conta, e “Resultados”, com contagens e percentuais. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "top",
    },
    {
      alvo: "pesq-nova",
      titulo: "Nova pesquisa",
      texto:
        "A pesquisa é montada em etapas, com perguntas de escolha e de texto, e o rascunho é salvo automaticamente. " +
        "Respostas repetidas do mesmo aparelho são barradas de forma leve. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
