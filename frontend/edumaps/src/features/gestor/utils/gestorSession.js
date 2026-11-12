// src/features/gestor/utils/gestorSession.js
//
// Sessão do gestor no navegador (localStorage): o token bearer do login. A
// escola e a identidade vêm sempre do servidor (/me), nunca do navegador.
const TOKEN_KEY = "edumaps_gestor_token";
// Papel da sessão (gestor | admin | rede), só para o menu escolher o que
// mostrar. A autorização é sempre do servidor; o papel aqui é uma dica de UI.
const PAPEL_KEY = "edumaps_sessao_papel";

// Até 2026-11 o assistente de pesquisas guardava o perfil do gestor (nome,
// e-mail, telefone) em `edumaps_gestor_<INEP>`. Não é mais usado: apaga as
// sobras para não deixar dado pessoal no navegador.
export function limparIdentidadeAntiga() {
  try {
    for (let i = localStorage.length - 1; i >= 0; i -= 1) {
      const k = localStorage.key(i);
      if (k && /^edumaps_gestor_\d{8}$/.test(k)) localStorage.removeItem(k);
    }
  } catch {
    // armazenamento indisponível — nada a limpar
  }
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
  setSessaoPapel(null);
}

/** Papel da sessão para a UI (#394). @returns {string|null} */
export function getSessaoPapel() {
  try {
    return localStorage.getItem(PAPEL_KEY);
  } catch {
    return null;
  }
}

export function setSessaoPapel(papel) {
  try {
    if (papel) localStorage.setItem(PAPEL_KEY, papel);
    else localStorage.removeItem(PAPEL_KEY);
  } catch {
    // armazenamento indisponível — o menu só não mostra o item da rede
  }
}