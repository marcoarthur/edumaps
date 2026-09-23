// src/features/gestor/api/gestorDocumentosApi.js
//
// Espelha EduMaps::Plugin::API::Gestor (Documentos e Planos Escolares).
// Base /api/gestor/:cod_inep/documentos — todas as rotas exigem sessão do
// gestor (Authorization: Bearer). Pastas/subpastas, upload versionado
// (sobrescrever = nova versão), tags livres, download de qualquer versão e
// auditoria de todas as mudanças.

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/documentos`;

// ---------------------------------------------------------------------------
// árvore e atividade
// ---------------------------------------------------------------------------

/** @returns {Promise<{pastas:Array, documentos:Array, tags:Array<string>}>} */
export function getDocumentos(inep) {
  return apiClient.get(BASE(inep));
}

/** @returns {Promise<{auditoria:Array}>} feed das últimas ações da escola */
export function getAuditoriaDocumentos(inep, limite = 30) {
  return apiClient.get(`${BASE(inep)}/auditoria`, { limite });
}

// ---------------------------------------------------------------------------
// pastas
// ---------------------------------------------------------------------------

/** @returns {Promise<{id:number, nome:string, pasta_pai_id:number|null}>} */
export function createPasta(inep, { nome, pasta_pai_id }) {
  return apiClient.post(`${BASE(inep)}/pastas`, { nome, pasta_pai_id });
}

/** pasta_pai_id: número da nova pasta mãe ou '' para mover à raiz. */
export function updatePasta(inep, id, { nome, pasta_pai_id }) {
  return apiClient.patch(`${BASE(inep)}/pastas/${id}`, { nome, pasta_pai_id });
}

export function deletePasta(inep, id) {
  return apiClient.delete(`${BASE(inep)}/pastas/${id}`);
}

// ---------------------------------------------------------------------------
// documentos (upload versionado, metadados e download)
// ---------------------------------------------------------------------------

/**
 * Envia um arquivo. Sobrescrever (mesmo nome, mesma pasta) gera nova versão.
 * @returns {Promise<{documento_id:number, versao:number, novo:0|1, nome:string}>}
 */
export function uploadDocumento(inep, { file, pasta_id, tags = [] }) {
  const form = new FormData();
  form.append("arquivo", file, file.name);
  form.append("_original_nome", file.name);
  if (pasta_id !== null && pasta_id !== undefined) form.append("pasta_id", pasta_id);
  for (const t of tags) if (t) form.append("tags", t);
  return apiClient.upload(BASE(inep), form);
}

/** Renomeia e/ou move um documento; pasta_id '' = mover para a raiz. */
export function updateDocumento(inep, id, { nome, pasta_id }) {
  return apiClient.patch(`${BASE(inep)}/${id}`, { nome, pasta_id });
}

export function setDocumentoTags(inep, id, tags) {
  return apiClient.put(`${BASE(inep)}/${id}/tags`, { tags });
}

export function deleteDocumento(inep, id) {
  return apiClient.delete(`${BASE(inep)}/${id}`);
}

export function getDocumentoVersoes(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}/versoes`);
}

export function getDocumentoHistorico(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}/historico`);
}

/** @returns {Promise<{blob: Blob, filename: string}>} */
export function downloadDocumento(inep, id, versao) {
  return apiClient.download(`${BASE(inep)}/${id}/download`, versao ? { versao } : {});
}