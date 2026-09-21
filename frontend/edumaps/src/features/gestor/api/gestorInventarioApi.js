// src/features/gestor/api/gestorInventarioApi.js
//
// Espelha EduMaps::Plugin::API::Gestor (Painel de Inventário Escolar).
// Base /api/gestor/:cod_inep/inventario — todas as rotas exigem sessão do
// gestor (Authorization: Bearer). O baseline do Censo é somente leitura e o
// gestor acrescenta categorias, itens (recursos/serviços) e fornecedores.

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/inventario`;

// ---------------------------------------------------------------------------
// visão geral (censo + categorias + fornecedores + itens)
// ---------------------------------------------------------------------------

/** @returns {Promise<{ano:number, censo:object, categorias:Array, fornecedores:Array, itens:Array}>} */
export function getInventario(inep, ano) {
  return apiClient.get(BASE(inep), ano ? { ano } : undefined);
}

export function importarCenso(inep) {
  return apiClient.post(`${BASE(inep)}/importar-censo`);
}

/** @returns {Promise<Array>} itens filtrados por tipo/categoria/texto */
export function listItens(inep, { tipo = "", categoria_id = "", q = "" } = {}) {
  return apiClient.get(`${BASE(inep)}/itens`, { tipo, categoria_id, q });
}

export function getItem(inep, id) {
  return apiClient.get(`${BASE(inep)}/itens/${id}`);
}

// ---------------------------------------------------------------------------
// categorias (taxonomia livre do gestor)
// ---------------------------------------------------------------------------

export function createCategoria(inep, { tipo, nome }) {
  return apiClient.post(`${BASE(inep)}/categorias`, { tipo, nome });
}

export function updateCategoria(inep, id, { tipo, nome }) {
  return apiClient.put(`${BASE(inep)}/categorias/${id}`, { tipo, nome });
}

export function deleteCategoria(inep, id) {
  return apiClient.delete(`${BASE(inep)}/categorias/${id}`);
}

// ---------------------------------------------------------------------------
// fornecedores / prestadores de serviço
// ---------------------------------------------------------------------------

export function createFornecedor(inep, fornecedor) {
  return apiClient.post(`${BASE(inep)}/fornecedores`, fornecedor);
}

export function updateFornecedor(inep, id, fornecedor) {
  return apiClient.put(`${BASE(inep)}/fornecedores/${id}`, fornecedor);
}

export function deleteFornecedor(inep, id) {
  return apiClient.delete(`${BASE(inep)}/fornecedores/${id}`);
}

// ---------------------------------------------------------------------------
// itens (recursos e serviços)
// ---------------------------------------------------------------------------

export function createItem(inep, item) {
  return apiClient.post(`${BASE(inep)}/itens`, item);
}

export function updateItem(inep, id, item) {
  return apiClient.put(`${BASE(inep)}/itens/${id}`, item);
}

export function deleteItem(inep, id) {
  return apiClient.delete(`${BASE(inep)}/itens/${id}`);
}

// ---------------------------------------------------------------------------
// anexos (fotos, notas fiscais) — multipart e download com sessão
// ---------------------------------------------------------------------------

export function uploadAnexo(inep, itemId, file) {
  const form = new FormData();
  form.append("arquivo", file, file.name);
  form.append("_original_nome", file.name);
  return apiClient.upload(`${BASE(inep)}/itens/${itemId}/anexos`, form);
}

/** @returns {Promise<{blob: Blob, filename: string}>} */
export function downloadAnexo(inep, itemId, anexoId) {
  return apiClient.download(`${BASE(inep)}/itens/${itemId}/anexos/${anexoId}`);
}

export function deleteAnexo(inep, itemId, anexoId) {
  return apiClient.delete(`${BASE(inep)}/itens/${itemId}/anexos/${anexoId}`);
}
