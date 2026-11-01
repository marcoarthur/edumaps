// src/shared/tour/tours/configPainel.js
//
// Tour do Painel de Configuração (/config). Exige gestor com perfil de
// administrador: `prontoQuando` é a grade de categorias + editor, que só
// existe com os dados carregados (não no login nem na tela “restrita”).
// Os painéis extras (bot público do Telegram, retenção, envios) dependem do
// grupo escolhido: ficam no texto, não como alvo.
// Textos conferidos com docs/funcionalidades/plataforma/painel-configuracao.md
// e o código (selo “Em breve” na ConfigArvore; chave secreta nunca exibida no
// ConfigEditor; versões vigente/rascunho/arquivada no consentimento).

export default {
  id: "config-painel",
  versao: 1,
  titulo: "Usar o Painel de Configuração",
  rotaInicial: "/config",
  automatico: true,
  prontoQuando: "config-grade",
  passos: [
    {
      alvo: "config-categorias",
      titulo: "Categorias",
      texto:
        "As configurações da instalação ficam em categorias e grupos. Hoje estão ativas Integrações " +
        "(Assistente do Censo e Bot Telegram) e Canais de comunicação; o que ainda não está disponível leva o selo “Em breve”. " +
        "Use as setas do teclado ou os botões; Esc fecha.",
      lado: "right",
      alinhamento: "start",
    },
    {
      alvo: "config-editor",
      titulo: "Editar um item",
      texto:
        "Escolha um item à esquerda para ver a descrição e um exemplo, mudar o valor e salvar; “Validar” confere o valor antes. " +
        "Chaves secretas nunca são exibidas: ficam cifradas, e deixar o campo em branco mantém a atual. " +
        "Alguns grupos mostram painéis extras, como o status do bot público, a retenção de dados e os limites de envio.",
      lado: "left",
      alinhamento: "start",
    },
    {
      alvo: "config-consentimento",
      titulo: "Versões do consentimento",
      texto:
        "O termo de consentimento apresentado à comunidade é versionado: a versão vigente, rascunhos e as arquivadas. " +
        "Publicar uma nova arquiva a vigente. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
