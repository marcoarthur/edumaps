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

/**
 * Conteúdo direto de uma pasta (subpastas e arquivos imediatos), a partir da
 * árvore completa que a página já tem em memória (`doc_arvore`). Espelha a
 * regra do backend (`excluir_pasta` recusa pasta com conteúdo, 409).
 * @returns {{ subpastas: number, arquivos: number }}
 */
export function conteudoDaPasta(pastas, documentos, id) {
  const alvo = Number(id);
  return {
    subpastas: (pastas ?? []).filter((p) => p.pasta_pai_id != null && Number(p.pasta_pai_id) === alvo).length,
    arquivos: (documentos ?? []).filter((d) => d.pasta_id != null && Number(d.pasta_id) === alvo).length,
  };
}

const plural = (n, um, varios) => `${n} ${n === 1 ? um : varios}`;

/** Aviso para quem tenta excluir uma pasta com conteúdo. */
export function avisoPastaNaoVazia(nome, { subpastas, arquivos }) {
  const partes = [];
  if (arquivos) partes.push(plural(arquivos, "arquivo", "arquivos"));
  if (subpastas) partes.push(plural(subpastas, "subpasta", "subpastas"));
  return `A pasta "${nome}" não está vazia (${partes.join(" e ")}). Mova ou exclua o conteúdo antes de excluí-la.`;
}
