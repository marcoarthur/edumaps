// src/features/gestor/utils/qrEstado.js
//
// Estado de exibição de um QR code (issue #214): o backend devolve `status`,
// mas `expirado`/`esgotado` também são deduzidos de `expira_em` e
// `usos >= max_usos`, para a tela não depender do momento da última leitura.

export const QR_ESTADOS = {
  ativo: { rotulo: "Ativo", classe: "bg-green-100 text-green-700" },
  expirado: { rotulo: "Expirado", classe: "bg-gray-200 text-gray-700" },
  esgotado: { rotulo: "Esgotado", classe: "bg-amber-100 text-amber-800" },
  revogado: { rotulo: "Revogado", classe: "bg-red-100 text-red-700" },
};

/**
 * @param {{status?: string, expira_em?: string|null, usos?: number, max_usos?: number|null}|null} qrcode
 * @param {number} [agora]
 * @returns {"ativo"|"expirado"|"esgotado"|"revogado"|null}
 */
export function estadoQr(qrcode, agora = Date.now()) {
  if (!qrcode) return null;
  if (qrcode.status === "revogado") return "revogado";
  if (qrcode.status === "expirado") return "expirado";
  if (qrcode.expira_em && Date.parse(qrcode.expira_em) <= agora) return "expirado";
  if (qrcode.status === "esgotado") return "esgotado";
  if (qrcode.max_usos != null && (qrcode.usos ?? 0) >= qrcode.max_usos) return "esgotado";
  return "ativo";
}

/**
 * Valida as opções do formulário de geração (datetime-local + número) e as
 * converte para o corpo do POST.
 * @param {{validoAte?: string, limite?: string|number}} campos
 * @returns {{erro: string|null, opcoes: {expira_em?: string, max_usos?: number}}}
 */
export function opcoesQr({ validoAte = "", limite = "" } = {}, agora = Date.now()) {
  const opcoes = {};
  if (validoAte) {
    const t = new Date(validoAte).getTime();
    if (Number.isNaN(t)) return { erro: "Data de validade inválida.", opcoes: {} };
    if (t <= agora) return { erro: "A validade precisa ser uma data futura.", opcoes: {} };
    opcoes.expira_em = new Date(t).toISOString();
  }
  if (limite !== "" && limite != null) {
    const n = Number(limite);
    if (!Number.isInteger(n) || n <= 0) {
      return { erro: "O limite de inscrições deve ser um número inteiro maior que zero.", opcoes: {} };
    }
    opcoes.max_usos = n;
  }
  return { erro: null, opcoes };
}
