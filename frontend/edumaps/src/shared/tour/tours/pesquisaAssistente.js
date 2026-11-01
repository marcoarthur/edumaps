// src/shared/tour/tours/pesquisaAssistente.js
//
// Tour do assistente de pesquisa (/gestor/pesquisas/nova e /editar). Sem
// login por token (a identidade é a 1ª etapa do próprio assistente). A
// primeira tela varia (seus dados × dados da pesquisa): os alvos são a linha
// de etapas + status de salvamento e o cartão da etapa, comuns a todas as
// variantes. A visão “publicada” (só leitura) não tem a linha de etapas, e
// o tour não abre lá. Textos conferidos com o SurveyWizard (autosave só com
// identidade salva e título ≥ 3 letras; tipos em constants/pesquisas.js).

export default {
  id: "pesquisa-assistente",
  versao: 1,
  titulo: "Montar uma pesquisa",
  rotaInicial: ["/gestor/pesquisas/nova", "/gestor/pesquisas/editar"],
  automatico: true,
  prontoQuando: "pesquisa-etapas",
  passos: [
    {
      alvo: "pesquisa-etapas",
      titulo: "Etapas e salvamento",
      texto:
        "A pesquisa é montada em etapas: seus dados (só na primeira vez), os dados da pesquisa, uma etapa por pergunta e a revisão. " +
        "Ao lado, o status: o rascunho é salvo sozinho depois que seus dados estão salvos e o título tem 3 letras ou mais. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "pesquisa-etapa",
      titulo: "A etapa atual",
      texto:
        "Na primeira vez, seus dados: nome, e-mail e uma senha para ver os resultados depois. " +
        "Em “Dados da pesquisa” vão o título, o convite à comunidade e as perguntas (até 30): escolha única, múltipla escolha, " +
        "lista suspensa ou resposta livre. Na revisão, “Finalizar e publicar” gera o link para a comunidade responder. " +
        "Para rever esta ajuda, use o “?” no menu.",
      lado: "top",
    },
  ],
};
