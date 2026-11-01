// src/shared/tour/tours/analises.js
//
// Tour das análises (clusterização de escolas por geotag). A estrutura da
// página existe desde a montagem (os dados de região e indicadores chegam
// depois, dentro dos mesmos contêineres), então não precisa de
// `prontoQuando`.
//
// Textos conferidos com docs/funcionalidades/analise/clusters.md e com as
// regras da página: recorte exige ao menos a região; preset de IDEB exige o
// ano; K-Means/GMM/Spectral usam nº de grupos (2–10), DBSCAN usa eps/min_pts;
// a tabela mostra os 3 indicadores de maior valor por grupo.

export default {
  id: "analises",
  versao: 1,
  titulo: "Como agrupar escolas",
  rotaInicial: "/cluster/geotag",
  automatico: true,
  passos: [
    {
      alvo: "analises-cabecalho",
      titulo: "Agrupar escolas parecidas",
      texto:
        "Aqui a plataforma forma grupos de escolas com indicadores parecidos e mostra no mapa onde cada uma está. " +
        "São quatro escolhas: onde, quais indicadores, como agrupar e, então, gerar. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
      alinhamento: "start",
    },
    {
      alvo: "analises-recorte",
      titulo: "1. Onde: o recorte",
      texto:
        "Escolha ao menos a região. Para olhar mais de perto, desça para a UF e o município; " +
        "cada lista só abre depois da anterior.",
      lado: "bottom",
    },
    {
      alvo: "analises-indicadores",
      titulo: "2. Quais indicadores",
      texto:
        "Comece por um conjunto pronto (por exemplo, infraestrutura) ou monte sua lista buscando pelo nome. " +
        "Conjuntos com IDEB/SAEB pedem também o ano.",
      lado: "top",
    },
    {
      alvo: "analises-algoritmo",
      titulo: "3. Como agrupar",
      texto:
        "K-Means, GMM e Spectral dividem as escolas no número de grupos que você escolher (de 2 a 10). " +
        "O DBSCAN encontra os grupos sozinho pela proximidade dos valores, e usa os campos eps e min_pts. " +
        "Na dúvida, fique com K-Means e 3 grupos.",
      lado: "bottom",
    },
    {
      alvo: "analises-gerar",
      titulo: "4. Gerar",
      texto:
        "O cálculo roda no servidor de análises e pode levar alguns instantes. " +
        "Se faltar algo (região, indicadores, ano), a página avisa o que completar.",
      lado: "left",
    },
    {
      alvo: "analises-resultado",
      titulo: "O resultado",
      texto:
        "O mapa mostra as escolas coloridas pelo grupo. Abaixo, a tabela resume cada grupo: " +
        "quantas escolas tem e os três indicadores com os valores mais altos. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
