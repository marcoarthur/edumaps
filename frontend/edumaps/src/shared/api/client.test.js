// src/shared/api/client.test.js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { apiClient } from "./client.js";

describe("apiClient", () => {
  beforeEach(() => {
    global.fetch = vi.fn();
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
