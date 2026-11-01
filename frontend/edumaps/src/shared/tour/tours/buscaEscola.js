// src/shared/tour/tours/buscaEscola.js
//
// Tour da busca de escolas. Termina na comparação de redes, numa outra
// página: é o exemplo de tour multi-página.
//
// Cada `alvo` é um `data-tour="..."` no componente correspondente. Mudou o
// conteúdo de forma relevante? Suba `versao` para reapresentar o tour a quem
// já o viu.

export default {
  id: "busca-escola",
  versao: 1,
  titulo: "Como buscar uma escola",
  rotaInicial: "/escola/search",
  automatico: true,
  passos: [
    {
      alvo: "busca-cabecalho",
      titulo: "Busca de escolas",
      texto:
        "Aqui você encontra qualquer escola pública do país pelo nome ou pelo município. " +
        "Use as setas do teclado ou os botões para avançar; Esc fecha a ajuda.",
      lado: "bottom",
      alinhamento: "start",
    },
    {
      alvo: "busca-nome",
      titulo: "Nome da escola",
      texto:
        "Digite pelo menos 3 letras do nome. Sugestões aparecem enquanto você digita.",
      lado: "bottom",
    },
    {
      alvo: "busca-municipio",
      titulo: "Município",
      texto:
        "Você pode buscar só pelo município, ou combinar com o nome da escola para refinar o resultado.",
      lado: "bottom",
    },
    {
      alvo: "busca-enviar",
      titulo: "Buscar",
      texto:
        "O botão fica ativo quando um dos campos tem 3 letras ou mais. “Limpar” apaga os dois campos.",
      lado: "top",
      alinhamento: "start",
    },
    {
      alvo: "busca-resultados",
      titulo: "Resultados",
      texto:
        "Cada escola aparece num cartão com endereço e contato, e atalhos para o ranking e o painel da escola. " +
        "Quando há muitas, a navegação entre páginas fica no fim da lista.",
      lado: "top",
    },
    {
      alvo: "busca-comparar",
      titulo: "Comparar redes do município",
      texto:
        "Escolha um município e use este botão para comparar as redes de ensino que o atendem. Vamos até lá.",
      lado: "top",
      alinhamento: "end",
    },
    {
      rota: "/municipio/compare",
      alvo: "comparar-municipio",
      titulo: "Escolha o município",
      texto:
        "Nesta página você escolhe o município e vê as redes lado a lado. " +
        "Para rever esta ajuda, use o botão “?” no menu, na página de busca.",
      lado: "bottom",
      alinhamento: "start",
    },
  ],
};
