// src/features/chat/utils/dia.js
//
// Dias do calendário do histórico em HORA LOCAL. `toISOString()` converte
// para UTC: num fuso a leste de Greenwich a meia-noite local cai no dia
// anterior, e a chave do dia saía errada. O backend conta os dias no fuso do
// navegador (`tz`), então os dois lados falam do mesmo dia.

/** "YYYY-MM-DD" da data em hora local. */
export function diaLocal(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

/** "YYYY-MM-DD" → "DD/MM/YYYY" (sem passar por Date, sem fuso). */
export function formatarDia(ymd) {
  const [y, m, d] = String(ymd ?? "").split("-");
  return y && m && d ? `${d}/${m}/${y}` : "";
}

/** Fuso IANA do navegador (ex.: "America/Sao_Paulo"); undefined se indisponível. */
export function fusoDoNavegador() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || undefined;
  } catch {
    return undefined;
  }
}
