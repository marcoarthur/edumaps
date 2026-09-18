// src/features/gestor/constants/gestor.js
//
// Cores e rótulos do painel do gestor. Os ícones vivem em
// components/icons/icon-data.js (chave = key devolvida pela API).

export const CHART_COLORS = {
  etapa: "#2563eb",
  faixa: "#7c3aed",
  turno: "#0891b2",
  modalidade: "#f59e0b",
  vinculo: "#2563eb",
  disciplina: "#7c3aed",
};

/** Cores fixas por etapa (mantém a leitura estável entre escolas). */
export const ETAPA_COLORS = {
  creche: "#f59e0b",
  pre_escola: "#fbbf24",
  fundamental_ai: "#2563eb",
  fundamental_af: "#1d4ed8",
  ensino_medio: "#7c3aed",
  eja: "#0891b2",
  profissionalizante: "#16a34a",
};

export function etapaColorScale(items = []) {
  return Object.fromEntries(
    items.map((it) => [it.label, ETAPA_COLORS[it.key] ?? "#64748b"]),
  );
}

/** Escopos da busca de escolas similares (mais próximo por padrão). */
export const SCOPE_OPTIONS = [
  { value: "municipio", label: "Município" },
  { value: "estado", label: "Estado" },
  { value: "regiao", label: "Região" },
];
