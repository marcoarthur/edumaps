// src/features/ranking-recorte/utils/formato.js

/** Número em PT-BR com até 2 casas; "–" quando ausente (#154). */
export function num(v, casas = 2) {
  if (v === null || v === undefined || !Number.isFinite(Number(v))) return "–";
  return Number(v).toLocaleString("pt-BR", { minimumFractionDigits: 0, maximumFractionDigits: casas });
}

/** Variação com sinal: "+0,84" / "−0,3" / "–". */
export function variacao(v) {
  if (v === null || v === undefined || !Number.isFinite(Number(v))) return "–";
  const n = Number(v);
  const s = Math.abs(n).toLocaleString("pt-BR", { maximumFractionDigits: 2 });
  return n > 0 ? `+${s}` : n < 0 ? `−${s}` : "0";
}

/** Leitura do contexto: média da rede frente à média dos municípios de INSE parecido. */
export function contexto(rede) {
  if (rede.media == null || rede.media_quinto_inse == null) return "–";
  const d = rede.media - rede.media_quinto_inse;
  if (Math.abs(d) < 0.05) return "na média dos de INSE parecido";
  return d > 0 ? `${num(d)} acima dos de INSE parecido` : `${num(-d)} abaixo dos de INSE parecido`;
}

/**
 * CSV com ";" e BOM (abre no Excel em PT-BR) e dispara o download.
 * @param {string} nome
 * @param {string[]} cabecalho
 * @param {Array<Array<string|number|null>>} linhas
 */
export function csv(cabecalho, linhas) {
  const q = (v) => {
    if (v === null || v === undefined) return "";
    const s = typeof v === "number" ? String(v).replace(".", ",") : String(v);
    return /[";\n\r]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
  };
  return "﻿" + [cabecalho, ...linhas].map((l) => l.map(q).join(";")).join("\r\n") + "\r\n";
}

export function baixarCsv(nome, conteudo) {
  const blob = new Blob([conteudo], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nome;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
