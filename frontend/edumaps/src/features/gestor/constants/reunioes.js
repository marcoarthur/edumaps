// src/features/gestor/constants/reunioes.js
//
// Constantes do módulo "Reuniões & Atas do gestor": status, métodos de aviso,
// tamanhos e rótulos. Espelham validações do backend
// (EduMaps::Controller::Gestor / Roles::Business::Gestor::Reunioes).

export const REUNIAO_STATUS_LABELS = {
  agendada: "Agendada",
  realizada: "Realizada",
  cancelada: "Cancelada",
};

export const REUNIAO_STATUS_BADGE = {
  agendada: "bg-blue-100 text-blue-800",
  realizada: "bg-green-100 text-green-800",
  cancelada: "bg-red-100 text-red-700",
};

export const AVISO_METODOS = [
  { value: "whatsapp", label: "WhatsApp" },
  { value: "email", label: "E-mail" },
  { value: "todos", label: "WhatsApp + e-mail" },
];

export const AVISO_METODO_LABELS = Object.fromEntries(
  AVISO_METODOS.map((m) => [m.value, m.label]),
);

/** Extensões aceitas no upload de pauta/ata (allowlist do backend). */
export const ANEXO_EXTENSOES = [
  "pdf",
  "docx",
  "xlsx",
  "png",
  "jpg",
  "jpeg",
  "txt",
];

export const REUNIAO_LIMITS = {
  TITULO_MIN: 3,
  TITULO_MAX: 120,
  PAUTA_MAX: 5000,
  ATA_MAX: 20000,
  DURACAO_MIN: 15,
  DURACAO_MAX: 480,
  DURACAO_DEFAULT: 60,
  CONVITE_MSG_MAX: 1000,
  MAX_UPLOAD_BYTES: 10 * 1024 * 1024,
  MAX_UPLOAD_LABEL: "10 MB",
  IMPORT_MAX: 200,
};

export const TAMANHO_LABEL = (bytes) => {
  if (!bytes && bytes !== 0) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
};