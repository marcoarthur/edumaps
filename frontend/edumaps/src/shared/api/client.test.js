// src/shared/api/client.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { apiClient, setApiToken, getApiToken } from "./client.js";

describe("apiClient", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
  });

  afterEach(() => setApiToken(null));

  it("anexa o Authorization Bearer quando há token de sessão", async () => {
    setApiToken("token-de-sessao-uuid");
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ ok: true }),
    });

    await apiClient.get("/api/gestor/me");

    const [, options] = fetch.mock.calls[0];
    expect(options.headers).toMatchObject({
      Authorization: "Bearer token-de-sessao-uuid",
    });
  });

  it("não envia header de autorização sem token", async () => {
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ ok: true }),
    });

    await apiClient.get("/api/gestor/pesquisas");

    const [, options] = fetch.mock.calls[0];
    expect(options.headers.Authorization).toBeUndefined();
  });

  it("exposição do token atual", () => {
    setApiToken("abc");
    expect(getApiToken()).toBe("abc");
    setApiToken(null);
    expect(getApiToken()).toBeNull();
  });

  it("monta a URL com query params, ignorando valores vazios", async () => {
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ ok: true }),
    });

    await apiClient.get("/api/school/search", {
      escola: "Paulo",
      municipio: "",
    });

    const [calledUrl] = fetch.mock.calls[0];
    expect(calledUrl).toBe("/api/school/search?escola=Paulo");
  });

  it("lança ApiError com a mensagem retornada pelo backend", async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 404,
      json: async () => ({ error: "Escola não encontrada" }),
    });

    await expect(apiClient.get("/api/school/search")).rejects.toThrow(
      "Escola não encontrada",
    );
  });
});
