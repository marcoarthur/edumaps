// src/shared/tour/tours/planoDetalhe.js
//
// Tour de um plano de gestão (/gestor/planos/:id, #371). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/planos-gestao.md.

export default {
  id: "plano-detalhe",
  versao: 1,
  titulo: "Acompanhar um plano",
  rotaInicial: "/gestor/planos/:id",
  automatico: true,
  prontoQuando: "plano-resumo",
  passos: [
    {
      alvo: "plano-resumo",
      titulo: "Andamento",
      texto:
        "O andamento é a média das metas que já têm medição — sempre com quantas foram medidas. " +
        "Aqui você põe o plano em vigor, encerra (ou reabre) e liga os alertas de prazo por e-mail. " +
        "O botão Relatório, no topo, gera a versão para imprimir ou salvar em PDF. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "bottom",
    },
    {
      alvo: "plano-objetivos",
      titulo: "Objetivos, metas e ações",
      texto:
        "Cada objetivo tem metas e ações. A meta pode seguir um indicador oficial da escola (IDEB, matrículas, " +
        "infraestrutura), que se atualiza sozinho, ou ser manual: você registra as medições. As ações têm " +
        "responsável, prazo e situação; as vencidas aparecem como atrasadas. Em + Evidência você liga a ata " +
        "de uma reunião, um documento já guardado ou uma nota como prova do que foi feito.",
      lado: "top",
    },
  ],
};
