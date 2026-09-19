// src/features/gestor/utils/gestorSession.js
//
// Sessão do gestor no navegador (localStorage). Duas camadas:
//   - "identidade" por escola (e-mail/upsert em /perfil, fase 1): chave por INEP.
//   - "token de login" (fase 2): bearer temporário, não preso a uma escola —
//     a chave é única e vale para /me, /logout e resultados de qualquer escola
//     cujo gestor tenha aquele login.
const key = (inep) => `edumaps_gestor_${inep}`;
const TOKEN_KEY = "edumaps_gestor_token";

/** @param {string|number} inep @returns {object|null} */
export function getGestorSession(inep) {
  try {
    const raw = localStorage.getItem(key(inep));
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

/** Guarda o gestor autenticado na escola. @param {object} gestor */
export function setGestorSession(inep, gestor) {
  localStorage.setItem(key(inep), JSON.stringify(gestor));
}

/** Permite sair da sessão (trocar de gestor / nova conta). */
export function clearGestorSession(inep) {
  localStorage.removeItem(key(inep));
}

/** Token bearer da sessão do gestor (login de verdade). @returns {string|null} */
export function getSessaoToken() {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setSessaoToken(token) {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  } catch {
    // armazenamento indisponível — segue sem persistência
  }
}

export function clearSessaoToken() {
  setSessaoToken(null);
}