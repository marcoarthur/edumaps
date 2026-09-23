// src/features/gestor/constants/documentos.js
// Constantes do módulo Documentos e Planos Escolares (pastas, versões, tags).

export const DOCUMENTOS_LIMITS = {
  MAX_TAGS: 20,
  TAG_MAX_LEN: 40,
  MAX_UPLOAD_MB: 10,
};

export const EXT_PERMITIDA = {
  pdf: "application/pdf",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  txt: "text/plain",
};

export const MIME_ROTULO = {
  "application/pdf": "PDF",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "DOCX",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "XLSX",
  "image/png": "PNG",
  "image/jpeg": "JPG",
  "text/plain": "TXT",
};

export const ACAO_ROTULO = {
  criado: "Criado",
  sobrescrito: "Nova versão",
  renomeado: "Renomeado",
  movido: "Movido",
  tags: "Tags atualizadas",
  excluido: "Excluído",
};

/** Formata bytes (1245 -> "1,2 KB"). */
export function formatarTamanho(bytes) {
  const n = Number(bytes) || 0;
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / (1024 * 1024)).toFixed(1)} MB`;
}