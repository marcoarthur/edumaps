// src/features/inscricao/api/canaisPublicApi.js
//
// Face pública do contrato congelado (Fase 0, issue #208): sem sessão — o token
// na URL é a capability. Nunca expõe contatos de terceiros.
//   GET  /api/canais/inscricao/:token → 200 {lista_nome, escola_nome, canal, campos, expira_em} · 404/410
//   POST /api/canais/inscricao/:token → 201 {ok:1, duplicado?, confirmacao?} · 400 · 410 · 429
//
// Confirmação de posse do telefone (issue #212) — a `ref` opaca devolvida em
// `confirmacao.ref` é a capability:
//   GET  /api/canais/confirmacao/:ref                    → 200 {estado, canais, expira_em} · 404
//   POST /api/canais/confirmacao/:ref/whatsapp           → 202 {enviado, expira_em} · 404 · 409 · 429
//   POST /api/canais/confirmacao/:ref/whatsapp/verificar → 200 {estado:"confirmado"} · 400 · 410

import { apiClient } from "@/shared/api/client.js";

const BASE = (token) => `/api/canais/inscricao/${token}`;
const CONFIRMACAO = (ref) => `/api/canais/confirmacao/${ref}`;

/** @returns {Promise<{lista_nome: string, escola_nome: string, canal: string, campos: string[], expira_em: string|null}>} */
export function getInscricaoPublica(token) {
  return apiClient.get(BASE(token));
}

/**
 * @param {string} token
 * @param {{nome: string, telefone: string, consentimento: boolean, _hp?: string}} payload
 * @returns {Promise<{ok: number, duplicado?: number, confirmacao?: {ref?: string, estado: string, expira_em?: string, canais?: Array<{canal: string, url?: string}>}}>}
 */
export function enviarInscricao(token, payload) {
  return apiClient.post(BASE(token), payload);
}

/** @returns {Promise<{estado: "pendente"|"confirmado", canais: Array, expira_em: string}>} */
export function estadoConfirmacao(ref) {
  return apiClient.get(CONFIRMACAO(ref));
}

/** Pede o envio do código de 6 dígitos pelo WhatsApp. @returns {Promise<{enviado: number, expira_em: string}>} */
export function enviarCodigoWhatsapp(ref) {
  return apiClient.post(`${CONFIRMACAO(ref)}/whatsapp`);
}

/** @returns {Promise<{estado: "confirmado"}>} */
export function verificarCodigoWhatsapp(ref, codigo) {
  return apiClient.post(`${CONFIRMACAO(ref)}/whatsapp/verificar`, { codigo: String(codigo) });
}
