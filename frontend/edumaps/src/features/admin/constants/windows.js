// src/features/admin/constants/windows.js
// Janelas de tempo aceitas pelo backend (/api/admin/telemetry/overview).
// A ordem é a exibida no seletor; as chaves batem com a whitelist do servidor.
export const TELEMETRY_WINDOWS = [
  { key: "6h", label: "6 h" },
  { key: "12h", label: "12 h" },
  { key: "24h", label: "24 h" },
  { key: "hoje", label: "Hoje" },
  { key: "7d", label: "7 dias" },
  { key: "30d", label: "30 dias" },
];

// Janelas fixas do cartão de logins — "quantos usuários logaram nas últimas
// 6/12/24 h", sempre visíveis independentemente da janela selecionada.
export const LOGIN_CARDS = [
  { key: "6h", label: "Últimas 6 h" },
  { key: "12h", label: "Últimas 12 h" },
  { key: "24h", label: "Últimas 24 h" },
];
