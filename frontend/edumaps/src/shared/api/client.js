// src/shared/api/client.js
const DEFAULT_HEADERS = { "Content-Type": "application/json" };

// Token de sessão do gestor (login, fase 2). Toda requisição autenticada leva
// "Authorization: Bearer <token>"; rotas públicas simplesmente o ignoram.
let bearerToken = null;

export function setApiToken(token) {
  bearerToken = token ?? null;
}

export function getApiToken() {
  return bearerToken;
}

export class ApiError extends Error {
  constructor(message, { status, url } = {}) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.url = url;
  }
}

async function request(path, { method = "GET", params, body, headers } = {}) {
  const url = new URL(path, window.location.origin);

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== "") {
        url.searchParams.set(key, value);
      }
    }
  }

  const authHeaders = bearerToken ? { Authorization: `Bearer ${bearerToken}` } : {};

  const response = await fetch(url.pathname + url.search, {
    method,
    headers: { ...DEFAULT_HEADERS, ...authHeaders, ...headers },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    let message = `Erro ${response.status}`;
    try {
      const data = await response.json();
      message = data.error || message;
    } catch {
      // resposta sem corpo JSON (ex: 500 sem handler de erro)
    }
    throw new ApiError(message, { status: response.status, url: url.pathname });
  }

  if (response.status === 204) return null;
  return response.json();
}

export const apiClient = {
  get: (path, params) => request(path, { method: "GET", params }),
  post: (path, body) => request(path, { method: "POST", body }),
  put: (path, body) => request(path, { method: "PUT", body }),
  delete: (path) => request(path, { method: "DELETE" }),
};
