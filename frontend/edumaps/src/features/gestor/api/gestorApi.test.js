// src/features/gestor/api/gestorApi.test.js
import { describe, it, expect, vi } from "vitest";
import { apiClient } from "@/shared/api/client.js";
import { getGestorPanel } from "./gestorApi.js";

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
