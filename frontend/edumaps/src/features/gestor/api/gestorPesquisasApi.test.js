// src/features/gestor/api/gestorPesquisasApi.test.js
import { describe, it, expect, vi } from "vitest";
import { apiClient } from "@/shared/api/client.js";
import {
  upsertGestor,
  listPesquisas,
  createPesquisa,
  getPesquisa,
  updatePesquisa,
  finalizarPesquisa,
  deletePesquisa,
} from "./gestorPesquisasApi.js";

vi.mock("@/shared/api/client.js", () => ({
  apiClient: { post: vi.fn(), get: vi.fn(), put: vi.fn(), delete: vi.fn() },
}));

const BASE = "/api/gestor/pesquisas";

describe("gestorPesquisasApi", () => {
  it("upsertGestor: POST /perfil com os dados do gestor", async () => {
    const perfil = { cod_inep: "11000040", nome: "Marina", email: "m@e.gov.br" };
    apiClient.post.mockResolvedValue({ id: 7 });
    await upsertGestor(perfil);
    expect(apiClient.post).toHaveBeenCalledWith(`${BASE}/perfil`, perfil);
  });

  it("listPesquisas: GET / com ?inep=", async () => {
    apiClient.get.mockResolvedValue([]);
    await listPesquisas("11000040");
    expect(apiClient.get).toHaveBeenCalledWith(BASE, { inep: "11000040" });
  });

  it("createPesquisa: POST / com gestor_id e perguntas", async () => {
    const payload = { gestor_id: 7, titulo: "X", perguntas: [] };
    apiClient.post.mockResolvedValue({ id: 9 });
    await createPesquisa(payload);
    expect(apiClient.post).toHaveBeenCalledWith(BASE, payload);
  });

  it("getPesquisa: GET /:id", async () => {
    apiClient.get.mockResolvedValue({ id: 1 });
    await getPesquisa(1);
    expect(apiClient.get).toHaveBeenCalledWith(`${BASE}/1`);
  });

  it("updatePesquisa: PUT /:id", async () => {
    apiClient.put.mockResolvedValue({ id: 1 });
    await updatePesquisa(1, { titulo: "Novo" });
    expect(apiClient.put).toHaveBeenCalledWith(`${BASE}/1`, { titulo: "Novo" });
  });

  it("finalizarPesquisa: POST /:id/finalizar", async () => {
    apiClient.post.mockResolvedValue({ status: "publicada" });
    await finalizarPesquisa(1);
    expect(apiClient.post).toHaveBeenCalledWith(`${BASE}/1/finalizar`);
  });

  it("deletePesquisa: DELETE /:id", async () => {
    apiClient.delete.mockResolvedValue(null);
    await deletePesquisa(1);
    expect(apiClient.delete).toHaveBeenCalledWith(`${BASE}/1`);
  });
});