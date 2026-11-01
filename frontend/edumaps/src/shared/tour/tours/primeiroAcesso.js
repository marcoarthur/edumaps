// src/shared/tour/tours/primeiroAcesso.js
//
// Tour de primeiro acesso: apresenta a plataforma na página inicial e as
// entradas principais do menu. Configurações, Administração e "Sobre o
// Refactor" ficam de fora: são áreas internas, não ponto de partida.
//
// Alvos: `data-tour` na HomePage e nos itens do menu (NAV_LINKS em App.svelte).

export default {
  id: "primeiro-acesso",
  versao: 1,
  titulo: "Conhecer o EduMaps",
  rotaInicial: "/",
  automatico: true,
  passos: [
    {
      alvo: "home-apresentacao",
      titulo: "Bem-vindo ao EduMaps",
      texto:
        "O EduMaps reúne mapas, indicadores e ferramentas de análise das escolas públicas brasileiras. " +
        "Em poucos passos mostramos por onde começar. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "home-atalhos",
      titulo: "Por onde começar",
      texto:
        "Os três caminhos mais comuns: encontrar uma escola, explorar análises, ou entrar como gestor da sua escola.",
      lado: "bottom",
    },
    {
      alvo: "menu-busca",
      titulo: "Busca de escolas",
      texto:
        "Encontre qualquer escola pública pelo nome ou pelo município, e abra o painel e o ranking dela.",
      lado: "bottom",
    },
    {
      alvo: "menu-analises",
      titulo: "Análises",
      texto:
        "Mapas e agrupamentos de escolas parecidas, com a explicação de cada grupo em linguagem simples.",
      lado: "bottom",
    },
    {
      alvo: "menu-assistente",
      titulo: "Assistente do Censo",
      texto:
        "Gestores com conta perguntam em português sobre o Censo Escolar da sua escola e do seu município, " +
        "e recebem os números e, quando ajuda, um gráfico. Exige login.",
      lado: "bottom",
    },
    {
      alvo: "menu-gestor",
      titulo: "Área do gestor",
      texto:
        "Para quem dirige uma escola: pesquisas com a comunidade, reuniões e atas, contatos e relatórios. Exige acesso.",
      lado: "bottom",
    },
    {
      alvo: "menu-ajuda",
      titulo: "Ajuda sempre à mão",
      texto:
        "Nas páginas que têm roteiro, este botão abre a ajuda da página. Aqui, ele repete este tour.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
