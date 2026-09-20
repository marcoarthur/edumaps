// src/features/gestor/utils/convite.js
//
// Monta o "convite copiável" da reunião (sem envio real — decisão da fase 3):
// texto pronto para WhatsApp (wa.me) e assunto+corpo para e-mail.

function formatarDataHora(quando) {
  const d = new Date((quando ?? "").replace(" ", "T"));
  if (Number.isNaN(d.getTime())) return quando ?? "";
  return (
    d.toLocaleDateString("pt-BR", {
      weekday: "long",
      day: "2-digit",
      month: "long",
      year: "numeric",
    }) +
    " às " +
    d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })
  );
}

/** @param {string} tel Ex.: "+5511999990001" -> "5511999990001" */
export function numeroParaWa(tel) {
  const digits = (tel ?? "").replace(/\D/g, "");
  return digits ? `55${digits.replace(/^55/, "")}` : "";
}

/**
 * @param {{titulo: string, quando: string, duracaoMin: number, ondeLabel?: string|null, ondeLink?: string|null}} r
 * @returns {{linhaAssunto: string, textoEmail: string, textoWhatsApp: string}}
 */
export function buildConvite(r) {
  const quando = formatarDataHora(r.quando);
  const duracao = r.duracaoMin ? ` (${r.duracaoMin} min)` : "";
  const onde = r.ondeLabel ? `\nOnde: ${r.ondeLabel}${r.ondeLink ? ` (${r.ondeLink})` : ""}` : "";

  const corpo = [
    `Convite: ${r.titulo}`,
    `Quando: ${quando}${duracao}`,
    onde,
    "",
    "Você está convidado(a). Qualquer dúvida, responda a este canal.",
  ]
    .filter(Boolean)
    .join("\n");

  return {
    linhaAssunto: `Convite — ${r.titulo}`,
    textoEmail: `${corpo}`,
    textoWhatsApp: corpo,
  };
}

/** Link wa.me pré-preenchido com o texto (sem número = escolhe na hora). */
export function waLink(texto, telefone = "") {
  const num = numeroParaWa(telefone);
  const dest = num ? `/${num}` : "";
  return `https://wa.me${dest}?text=${encodeURIComponent(texto)}`;
}