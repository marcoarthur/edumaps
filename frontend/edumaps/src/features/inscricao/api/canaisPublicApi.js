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
//
// E-mail e LGPD (issue #214, contrato da onda 1):
//   GET  /api/canais/inscricao/:token → + {campos, obrigatorios, consentimento:{versao, texto}}
//   POST /api/canais/inscricao/:token ← {nome, telefone?, email?, consentimento, consentimento_versao?, _hp?}
//                                      → 201 + exclusao_url · 400 · 409 {error, consentimento} (versão desatualizada)
//   GET  /api/canais/confirmacao/:ref  → estado pendente|parcial|confirmado + contatos {telefone?, email?}
//   POST /api/canais/confirmacao/:ref/email           → 202 {enviado, expira_em} · 404 · 409 · 429 · 502
//   POST /api/canais/confirmacao/:ref/email/verificar → 200 {estado, contatos} · 400 · 410
//   GET  /api/canais/consentimento    → 200 {versao, texto, publicada_em}

import { apiClient } from "@/shared/api/client.js";

const BASE = (token) => `/api/canais/inscricao/${token}`;
const CONFIRMACAO = (ref) => `/api/canais/confirmacao/${ref}`;

/** @returns {Promise<{lista_nome: string, escola_nome: string, canal: string, campos: string[], obrigatorios?: string[], consentimento?: {versao: string, texto: string}, expira_em: string|null}>} */
export function getInscricaoPublica(token) {
  return apiClient.get(BASE(token));
}

/**
 * @param {string} token
 * @param {{nome: string, telefone?: string, email?: string, consentimento: boolean, consentimento_versao?: string, _hp?: string}} payload
 * @returns {Promise<{ok: number, duplicado?: number, exclusao_url?: string, confirmacao?: {ref?: string, estado: string, expira_em?: string, canais?: Array<{canal: string, url?: string}>, contatos?: object}}>}
 */
export function enviarInscricao(token, payload) {
  return apiClient.post(BASE(token), payload);
}

/** @returns {Promise<{estado: "pendente"|"parcial"|"confirmado", canais: Array, expira_em: string, contatos?: object}>} */
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

/** Pede o envio do código de 6 dígitos por e-mail. @returns {Promise<{enviado: number, expira_em: string}>} */
export function enviarCodigoEmail(ref) {
  return apiClient.post(`${CONFIRMACAO(ref)}/email`);
}

/** @returns {Promise<{estado: "pendente"|"parcial"|"confirmado", contatos: object}>} */
export function verificarCodigoEmail(ref, codigo) {
  return apiClient.post(`${CONFIRMACAO(ref)}/email/verificar`, { codigo: String(codigo) });
}

/** Texto de consentimento vigente. @returns {Promise<{versao: string, texto: string, publicada_em: string}>} */
export function consentimentoVigente() {
  return apiClient.get("/api/canais/consentimento");
}

// Exclusão a pedido do titular (issue #214, contrato da onda 2). O token é o da
// `exclusao_url` (32 hex) e funciona mesmo com a autoinscrição desligada.
//   GET  /api/canais/exclusao/:token → 200 {escola_nome, lista_nome, ja_excluido} · 404
//   POST /api/canais/exclusao/:token ← {confirmar:true} → 200 {ok, ja_excluido} · 400 · 404 · 429
//   GET  /api/canais/consentimento   → + retencao {metadados_dias, pendentes_dias, listas_inativas_meses, enabled}
const EXCLUSAO = (token) => `/api/canais/exclusao/${encodeURIComponent(token)}`;

/** @returns {Promise<{escola_nome: string, lista_nome: string, ja_excluido: boolean|number}>} */
export function getExclusao(token) {
  return apiClient.get(EXCLUSAO(token));
}

/** Confirma a exclusão (idempotente). @returns {Promise<{ok: number, ja_excluido: boolean|number}>} */
export function confirmarExclusao(token) {
  return apiClient.post(EXCLUSAO(token), { confirmar: true });
}
