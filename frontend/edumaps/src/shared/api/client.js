// src/shared/api/client.js
const DEFAULT_HEADERS = { "Content-Type": "application/json" };

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

  const response = await fetch(url.pathname + url.search, {
    method,
    headers: { ...DEFAULT_HEADERS, ...headers },
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
};
