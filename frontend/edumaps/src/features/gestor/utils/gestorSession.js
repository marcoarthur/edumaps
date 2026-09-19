// src/features/gestor/utils/gestorSession.js
//
// Sessão do gestor no navegador (localStorage). Não há login no EduMaps:
// o e-mail é a identidade e o id do gestor volta a cada upsert em /perfil.
const key = (inep) => `edumaps_gestor_${inep}`;

/** @param {string|number} inep @returns {object|null|null} */
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