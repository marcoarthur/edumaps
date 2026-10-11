// src/features/inscricao/api/canaisPublicApi.js
//
// Face pública do contrato congelado (Fase 0, issue #208): sem sessão — o token
// na URL é a capability. Nunca expõe contatos de terceiros.
//   GET  /api/canais/inscricao/:token → 200 {lista_nome, escola_nome, canal, campos, expira_em} · 404/410
//   POST /api/canais/inscricao/:token → 201 {ok:1, duplicado?} · 400 · 410 · 429

import { apiClient } from "@/shared/api/client.js";

const BASE = (token) => `/api/canais/inscricao/${token}`;

/** @returns {Promise<{lista_nome: string, escola_nome: string, canal: string, campos: string[], expira_em: string|null}>} */
export function getInscricaoPublica(token) {
  return apiClient.get(BASE(token));
}

/**
 * @param {string} token
 * @param {{nome: string, telefone: string, consentimento: boolean, _hp?: string}} payload
 * @returns {Promise<{ok: number, duplicado?: number}>}
 */
export function enviarInscricao(token, payload) {
  return apiClient.post(BASE(token), payload);
}
