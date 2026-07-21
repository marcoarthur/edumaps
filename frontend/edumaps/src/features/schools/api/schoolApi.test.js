// src/features/schools/api/schoolApi.test.js
import { describe, it, expect, vi } from "vitest";
import { apiClient } from "@/shared/api/client.js";
import { searchSchools } from "./schoolApi.js";

vi.mock("@/shared/api/client.js", () => ({
  apiClient: { get: vi.fn() },
}));

describe("searchSchools", () => {
  it("chama /api/school/search repassando os parâmetros recebidos", async () => {
    apiClient.get.mockResolvedValue([]);

    await searchSchools({ escola: "Paulo", municipio: "Ubatuba" });

    expect(apiClient.get).toHaveBeenCalledWith("/api/school/search", {
      escola: "Paulo",
      municipio: "Ubatuba",
      limit: undefined,
    });
  });
});
