// src/shared/tour/tours/gestorDocumentos.js
//
// Tour dos documentos e planos (/gestor/documentos). Exige login.
// Textos conferidos com docs/funcionalidades/gestor/documentos-planos.md e o
// código (limite e tipos aceitos no envio; a interface chama de “Tags”).

export default {
  id: "gestor-documentos",
  versao: 1,
  titulo: "Documentos e planos",
  rotaInicial: "/gestor/documentos",
  automatico: true,
  prontoQuando: "documentos-arquivos",
  passos: [
    {
      alvo: "documentos-arquivos",
      titulo: "Arquivos da escola",
      texto:
        "Pastas e subpastas com os documentos e planos da escola. Enviar um arquivo com o mesmo nome na mesma pasta " +
        "cria uma nova versão; as anteriores continuam em “Versões”. Use as setas do teclado ou os botões; Esc fecha.",
      lado: "top",
    },
    {
      alvo: "documentos-enviar",
      titulo: "Enviar arquivo",
      texto:
        "Vai para a pasta selecionada (a Raiz, se nenhuma estiver). Até 10 MB, em PDF, DOCX, XLSX, PNG, JPG ou TXT.",
      lado: "bottom",
      alinhamento: "end",
    },
    {
      alvo: "documentos-ajuda",
      titulo: "Tags e histórico",
      texto:
        "Tags livres ajudam a achar rápido, por exemplo, o PPP de cada ano. " +
        "Tudo o que muda fica registrado com autor e data.",
      lado: "left",
    },
    {
      alvo: "documentos-atividade",
      titulo: "Atividade recente",
      texto: "As últimas alterações nos documentos, com quem fez e quando. Para rever esta ajuda, use o “?” no menu.",
      lado: "bottom",
      alinhamento: "end",
    },
  ],
};
