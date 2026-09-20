// src/shared/api/client.js

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

  const isFormData = typeof FormData !== "undefined" && body instanceof FormData;
  const authHeaders = bearerToken ? { Authorization: `Bearer ${bearerToken}` } : {};
  const requestHeaders = Object.assign(
    isFormData ? {} : { "Content-Type": "application/json" },
    authHeaders,
    headers || {},
  );

  const response = await fetch(url.pathname + url.search, {
    method,
    headers: requestHeaders,
    body: isFormData ? body : body !== undefined ? JSON.stringify(body) : undefined,
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

// Baixa um arquivo com a sessão (ex.: anexos de reunião). O backend devolve
// o blob + filename no Content-Disposition; aqui devolvemos {blob, filename}.
async function download(path, params = {}) {
  const url = new URL(path, window.location.origin);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== "") {
      url.searchParams.set(key, value);
    }
  }

  const authHeaders = bearerToken ? { Authorization: `Bearer ${bearerToken}` } : {};
  const response = await fetch(url.pathname + url.search, {
    method: "GET",
    headers: { ...authHeaders },
  });

  if (!response.ok) {
    let message = `Erro ${response.status}`;
    try {
      const data = await response.json();
      message = data.error || message;
    } catch {
      // corpo não-JSON (arquivo) sem erro tratado
    }
    throw new ApiError(message, { status: response.status, url: url.pathname });
  }

  const cd = response.headers.get("Content-Disposition") ?? "";
  const m = cd.match(/filename="?([^";]+)"?/);
  return { blob: await response.blob(), filename: m ? m[1] : "arquivo" };
}

export const apiClient = {
  get: (path, params) => request(path, { method: "GET", params }),
  post: (path, body) => request(path, { method: "POST", body }),
  put: (path, body) => request(path, { method: "PUT", body }),
  delete: (path) => request(path, { method: "DELETE" }),
  upload: (path, formData) => request(path, { method: "POST", body: formData }),
  download,
};
