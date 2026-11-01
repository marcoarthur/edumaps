// src/shared/tour/tours/painelGestor.js
//
// Tour do painel do gestor (/gestor/painel?inep=...). Os alvos só existem
// depois que os dados da escola carregam, por isso `prontoQuando`: o tour
// automático espera o cabeçalho da escola aparecer (e não abre se o painel
// der erro).
//
// Textos conferidos com docs/funcionalidades/gestor/ (painel, área de
// influência) e busca/similaridade.md. Ausência aparece como "—" (#154).

export default {
  id: "painel-gestor",
  versao: 1,
  titulo: "Conhecer o painel do gestor",
  rotaInicial: "/gestor/painel",
  automatico: true,
  prontoQuando: "gestor-escola",
  passos: [
    {
      alvo: "gestor-escola",
      titulo: "O painel da sua escola",
      texto:
        "Aqui está o raio-x da escola: nome, município, rede e o ano do Censo usado. " +
        "Os botões ao lado abrem o perfil analítico, o painel público e o painel financeiro. " +
        "Use as setas do teclado ou os botões para avançar; Esc fecha.",
      lado: "bottom",
      alinhamento: "start",
    },
    {
      alvo: "gestor-modulos",
      titulo: "Módulos de gestão",
      texto:
        "As ferramentas do dia a dia: pesquisas com a comunidade, reuniões e atas, inventário, " +
        "relações institucionais, documentos e planos, e relatórios.",
      lado: "bottom",
      alinhamento: "end",
    },
    {
      alvo: "gestor-resumo",
      titulo: "Resumo em números",
      texto:
        "Matrículas, docentes, salas de aula e alunos por sala, segundo o Censo Escolar. " +
        "Quando um dado não existe, aparece “—”, nunca zero.",
      lado: "bottom",
    },
    {
      alvo: "gestor-atalhos",
      titulo: "Atalhos",
      texto:
        "Vá direto a cada parte do painel: matrículas, docentes, infraestrutura, equipamentos, " +
        "acessibilidade, escolas similares, equipamentos do entorno e área de influência.",
      lado: "bottom",
    },
    {
      alvo: "gestor-matriculas",
      titulo: "Matrículas",
      texto: "Como os alunos se distribuem por etapa de ensino e por turno.",
      lado: "top",
    },
    {
      alvo: "gestor-infraestrutura",
      titulo: "Infraestrutura",
      texto:
        "Serviços básicos e espaços da escola. O que falta aparece marcado com ×, " +
        "e o contador mostra quantos itens estão presentes.",
      lado: "top",
    },
    {
      alvo: "gestor-similares",
      titulo: "Escolas similares",
      texto:
        "Escolas com porte, localização, condições socioeconômicas (INSE) e etapas parecidas, " +
        "no município, no estado ou na região: um bom ponto de partida para trocar experiências.",
      lado: "top",
    },
    {
      alvo: "gestor-influencia",
      titulo: "Área de influência",
      texto:
        "O entorno da escola usado na leitura do território (índice IVET), com população e densidade por raio. " +
        "Esta informação só aparece para o gestor da escola. Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
