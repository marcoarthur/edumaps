// src/shared/tour/tours/adminPainel.js
//
// Tour do Painel de Administração (/admin). Exige gestor com perfil de
// administrador: `prontoQuando` é o bloco de logins, que só existe com os
// dados carregados (não na tela de login nem na de “restrita”).
// Textos conferidos com docs/funcionalidades/plataforma/painel-administracao.md
// e o código (atualização a cada 30 s — REFRESH_MS; janelas em
// constants/windows.js).

export default {
  id: "admin-painel",
  versao: 1,
  titulo: "Ler o Painel de Administração",
  rotaInicial: "/admin",
  automatico: true,
  prontoQuando: "admin-logins",
  passos: [
    {
      alvo: "admin-logins",
      titulo: "Logins de gestores",
      texto:
        "Quantos gestores diferentes entraram nas últimas 6, 12 e 24 horas — essas três janelas ficam sempre fixas. " +
        "Tudo neste painel é número agregado, nunca sobre uma pessoa. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "admin-janela",
      titulo: "Janela de tempo",
      texto:
        "Escolha 6 h, 12 h, 24 h, hoje, 7 dias ou 30 dias. A escolha recalcula a atividade abaixo; os logins acima não mudam.",
      lado: "left",
    },
    {
      alvo: "admin-atividade",
      titulo: "Atividade na janela",
      texto:
        "Sessões ativas, separadas entre logadas e anônimas, quantas buscas foram feitas (só a contagem, nunca o texto) e o total de eventos.",
      lado: "bottom",
    },
    {
      alvo: "admin-serie",
      titulo: "Ao longo do tempo",
      texto: "Eventos e sessões por hora (janelas de até um dia) ou por dia (7 e 30 dias).",
      lado: "top",
    },
    {
      alvo: "admin-rotas",
      titulo: "Rotas mais acessadas",
      texto: "As páginas da plataforma mais visitadas na janela, com a participação de cada uma.",
      lado: "top",
    },
    {
      alvo: "admin-tours",
      titulo: "Ajuda guiada",
      texto:
        "Quantas vezes cada roteiro foi aberto, concluído ou fechado antes do fim, e o passo em que mais se desiste — " +
        "bom ponto para revisar um texto. Sem abertura na janela, a taxa aparece como “—”.",
      lado: "top",
    },
    {
      alvo: "admin-atualizar",
      titulo: "Atualização",
      texto:
        "O painel se atualiza sozinho a cada 30 segundos; “Atualizar agora” força na hora. Os dados chegam em lotes, " +
        "então é quase tempo real, não instantâneo. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
