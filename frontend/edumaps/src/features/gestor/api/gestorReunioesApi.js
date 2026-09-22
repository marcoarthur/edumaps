// src/features/gestor/api/gestorReunioesApi.js
//
// Espelha EduMaps::Plugin::API::Gestor (módulo Reuniões & Atas).
// Base /api/gestor/:cod_inep — todas as rotas exigem sessão do gestor
// (Authorization: Bearer). Upload de anexos usa multipart via apiClient.upload.

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}`;

// ---------------------------------------------------------------------------
// contatos e grupos (agenda)
// ---------------------------------------------------------------------------

/** @returns {Promise<Array>} [{id, nome, email, telefone, cargo, grupo_id, grupo_nome, updated_at}] */
export function listContatos(inep) {
  return apiClient.get(`${BASE(inep)}/contatos`);
}

/** @param {{nome: string, email?: string|null, telefone?: string|null, cargo?: string|null, grupo_id?: number|null}} contato */
export function createContato(inep, contato) {
  return apiClient.post(`${BASE(inep)}/contatos`, contato);
}

/** @param {number} id */
export function updateContato(inep, id, contato) {
  return apiClient.put(`${BASE(inep)}/contatos/${id}`, contato);
}

export function deleteContato(inep, id) {
  return apiClient.delete(`${BASE(inep)}/contatos/${id}`);
}

/** Importa em lote (colagem de texto normalizada). */
export function importContatos(inep, contatos) {
  return apiClient.post(`${BASE(inep)}/contatos/import`, { contatos });
}

/**
 * Importa os profissionais da folha de pagamento como contatos (nome + cargo),
 * vinculados aos grupos pré-listados da folha. Idempotente.
 * @returns {Promise<{n_inseridos:number, n_grupos:number}>}
 */
export function importarContatosFolha(inep) {
  return apiClient.post(`${BASE(inep)}/contatos/importar-folha`);
}

/** @returns {Promise<Array>} [{id, nome, n_contatos, created_at}] */
export function listGrupos(inep) {
  return apiClient.get(`${BASE(inep)}/grupos`);
}

export function createGrupo(inep, nome) {
  return apiClient.post(`${BASE(inep)}/grupos`, { nome });
}

export function updateGrupo(inep, id, nome) {
  return apiClient.put(`${BASE(inep)}/grupos/${id}`, { nome });
}

export function deleteGrupo(inep, id) {
  return apiClient.delete(`${BASE(inep)}/grupos/${id}`);
}

// ---------------------------------------------------------------------------
// reuniões
// ---------------------------------------------------------------------------

/**
 * Lista reuniões com filtros opcionais.
 * @param {string|number} inep
 * @param {{q?: string, status?: 'agendada'|'realizada'|'cancelada', de?: string, ate?: string}} [filtros]
 * @returns {Promise<Array>} [{id, titulo, quando, duracao_min, aviso_metodo, status, n_participantes, tem_ata}]
 */
export function listReunioes(inep, { q = "", status = "", de = "", ate = "" } = {}) {
  return apiClient.get(`${BASE(inep)}/reunioes`, { q, status, de, ate });
}

/**
 * Cria uma reunião (wizard completo).
 * @param {string|number} inep
 * @param {object} payload ver buildReuniaoPayload
 * @returns {Promise<object>} reunião detalhada
 */
export function createReuniao(inep, payload) {
  return apiClient.post(`${BASE(inep)}/reunioes`, payload);
}

export function getReuniao(inep, id) {
  return apiClient.get(`${BASE(inep)}/reunioes/${id}`);
}

export function updateReuniao(inep, id, payload) {
  return apiClient.put(`${BASE(inep)}/reunioes/${id}`, payload);
}

/** Salva o texto da ata (reunião agendada ou realizada). */
export function salvarAta(inep, id, ataTexto) {
  return apiClient.post(`${BASE(inep)}/reunioes/${id}/ata`, { ata_texto: ataTexto });
}

export function marcarRealizada(inep, id) {
  return apiClient.post(`${BASE(inep)}/reunioes/${id}/marcar-realizada`);
}

export function cancelarReuniao(inep, id) {
  return apiClient.post(`${BASE(inep)}/reunioes/${id}/cancelar`);
}

export function deleteReuniao(inep, id) {
  return apiClient.delete(`${BASE(inep)}/reunioes/${id}`);
}

// ---------------------------------------------------------------------------
// anexos (pauta/ata) — upload multipart e download com sessão
// ---------------------------------------------------------------------------

/**
 * Envia o arquivo pauta/ata (campo "arquivo" do multipart).
 * @param {File} file
 * @returns {Promise<object>} reunião detalhada com os anexos atualizados
 */
export function uploadAnexo(inep, id, tipo, file) {
  const form = new FormData();
  form.append("arquivo", file, file.name);
  form.append("_original_nome", file.name);
  return apiClient.upload(`${BASE(inep)}/reunioes/${id}/anexos/${tipo}`, form);
}

/** Baixa o anexo com a sessão. @returns {Promise<{blob: Blob, filename: string}>} */
export function downloadAnexo(inep, id, tipo) {
  return apiClient.download(`${BASE(inep)}/reunioes/${id}/anexos/${tipo}`);
}