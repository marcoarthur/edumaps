// src/features/gestor/api/gestorApi.test.js
import { describe, it, expect, vi } from "vitest";
import { apiClient } from "@/shared/api/client.js";
import { getGestorPanel, getSchoolSimilares } from "./gestorApi.js";

vi.mock("@/shared/api/client.js", () => ({
  apiClient: { get: vi.fn() },
}));

describe("getGestorPanel", () => {
  it("chama /api/gestor/:inep/painel", async () => {
    apiClient.get.mockResolvedValue({ escola: {} });

    await getGestorPanel("11000040");

    expect(apiClient.get).toHaveBeenCalledWith("/api/gestor/11000040/painel");
  });
});

describe("getSchoolSimilares", () => {
  it("chama /api/gestor/:inep/similares com escopo e limit", async () => {
    apiClient.get.mockResolvedValue({ similares: [] });

    await getSchoolSimilares("11000040", { scope: "estado", limit: 5 });

    expect(apiClient.get).toHaveBeenCalledWith(
      "/api/gestor/11000040/similares",
      { scope: "estado", limit: 5 },
    );
  });

  it("usa defaults (municipio, limit 10)", async () => {
    apiClient.get.mockResolvedValue({ similares: [] });

    await getSchoolSimilares("11000040");

    expect(apiClient.get).toHaveBeenCalledWith(
      "/api/gestor/11000040/similares",
      { scope: "municipio", limit: 10 },
    );
  });
});