// src/features/gestor/api/gestorCanaisApi.js
//
// Espelha EduMaps::Plugin::API::Gestor (módulo Listas & QR / canais).
// Base /api/gestor/:cod_inep/canais/listas — todas as rotas exigem sessão do
// gestor (Authorization: Bearer) e a posse do :cod_inep.
//
// Contrato congelado (Fase 0, issue #208):
//   GET    /listas                     listar listas
//   POST   /listas                     criar lista nomeada
//   GET    /listas/:id                 detalhe + contagem
//   DELETE /listas/:id                 excluir/desativar lista
//   POST   /listas/:id/qrcode          gerar/rotacionar QR → {token,url,expira_em}
//   DELETE /listas/:id/qrcode          revogar QR
//   GET    /listas/:id/inscricoes      membros (nome, telefone, quando, validado, conflito)
//
// Confirmação de posse do telefone (issue #212, contrato da onda 1):
//   POST   /listas                     aceita `exige_confirmacao` (default false)
//   PATCH  /listas/:id                 {nome?, descricao?, exige_confirmacao?} → detalhe · 400 · 409 · 404
//   GET    /listas, /listas/:id        + exige_confirmacao, membros_confirmados, membros_pendentes
//   GET    /listas/:id/inscricoes      + estado (nao_exigida|pendente|confirmado), confirmado_via, confirmado_em

import { apiClient } from "@/shared/api/client.js";

const BASE = (inep) => `/api/gestor/${inep}/canais/listas`;

// O backend pode devolver o envelope ou a lista crua; normalizamos para não
// acoplar a UI ao formato exato.
const comoLista = (data) =>
  Array.isArray(data) ? data : (data?.listas ?? data?.itens ?? []);

const comoMembros = (data) =>
  Array.isArray(data) ? data : (data?.membros ?? data?.inscricoes ?? []);

/**
 * @param {string|number} inep
 * @returns {Promise<Array>} [{id, nome, canal, descricao, ativo, n_membros, qrcode}]
 */
export function listListas(inep) {
  return apiClient.get(BASE(inep)).then(comoLista);
}

/**
 * @param {{nome: string, descricao?: string|null, exige_confirmacao?: boolean}} lista
 * @returns {Promise<object>} lista criada
 */
export function createLista(inep, { nome, descricao = null, exige_confirmacao = false }) {
  return apiClient.post(BASE(inep), {
    nome,
    descricao: descricao || null,
    exige_confirmacao: Boolean(exige_confirmacao),
  });
}

/**
 * Altera nome/descrição/exigência de confirmação. Só envia os campos passados.
 * @param {{nome?: string, descricao?: string|null, exige_confirmacao?: boolean}} mudancas
 * @returns {Promise<object>} detalhe da lista atualizada
 */
export function atualizarLista(inep, id, mudancas = {}) {
  const body = {};
  for (const campo of ["nome", "descricao", "exige_confirmacao"]) {
    if (mudancas[campo] !== undefined) body[campo] = mudancas[campo];
  }
  return apiClient.patch(`${BASE(inep)}/${id}`, body);
}

/** @returns {Promise<object>} detalhe da lista (com n_membros) */
export function getLista(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}`);
}

export function deleteLista(inep, id) {
  return apiClient.delete(`${BASE(inep)}/${id}`);
}

/**
 * Gera (ou rotaciona) o QR code da lista.
 * @returns {Promise<{token: string, url: string, expira_em: string|null, usos?: number, max_usos?: number|null, status?: string}>}
 */
export function gerarQrCode(inep, id) {
  return apiClient.post(`${BASE(inep)}/${id}/qrcode`);
}

/** Revoga o QR ativo da lista. */
export function revogarQrCode(inep, id) {
  return apiClient.delete(`${BASE(inep)}/${id}/qrcode`);
}

/**
 * @returns {Promise<Array>} [{id, contato_id, nome, telefone, quando, validado, conflito, origem,
 *   estado, confirmado_via, confirmado_em}]
 */
export function listInscricoes(inep, id) {
  return apiClient.get(`${BASE(inep)}/${id}/inscricoes`).then(comoMembros);
}
