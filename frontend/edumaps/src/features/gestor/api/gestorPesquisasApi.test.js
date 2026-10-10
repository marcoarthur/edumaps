// src/features/gestor/api/gestorPesquisasApi.test.js
import { describe, it, expect, vi, beforeEach } from "vitest";
import { apiClient, getApiToken } from "@/shared/api/client.js";
import { eventBus } from "@/shared/events";
import { GESTOR_EVENTS } from "../constants/events.js";
import {
  upsertGestor,
  listPesquisas,
  createPesquisa,
  getPesquisa,
  updatePesquisa,
  finalizarPesquisa,
  deletePesquisa,
  loginGestor,
  fetchMe,
  logoutGestor,
  getPesquisaPublica,
  enviarRespostaPublica,
  getResultados,
} from "./gestorPesquisasApi.js";

vi.mock("@/shared/api/client.js", async () => {
  const actual = await vi.importActual("@/shared/api/client.js");
  return {
    ...actual,
    apiClient: {
      post: vi.fn(),
      get: vi.fn(),
      put: vi.fn(),
      delete: vi.fn(),
    },
  };
});

const BASE = "/api/gestor/pesquisas";

describe("gestorPesquisasApi", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

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

  it("loginGestor: POST /api/gestor/login e guarda o token", async () => {
    apiClient.post.mockResolvedValue({ token: "sessao-abc", gestor: { id: 7 } });
    const sessao = await loginGestor({ email: "m@e.gov.br", senha: "senha123" });
    expect(sessao.token).toBe("sessao-abc");
    expect(apiClient.post).toHaveBeenCalledWith("/api/gestor/login", {
      email: "m@e.gov.br",
      senha: "senha123",
    });
    expect(getApiToken()).toBe("sessao-abc");
  });

  it("fetchMe: GET /api/gestor/me", async () => {
    apiClient.get.mockResolvedValue({ id: 7, email: "m@e.gov.br" });
    await fetchMe();
    expect(apiClient.get).toHaveBeenCalledWith("/api/gestor/me");
  });

  it("loginGestor: emite gestor/login com ok=true no sucesso (sem credenciais)", async () => {
    apiClient.post.mockResolvedValue({ token: "t", gestor: { id: 1 } });
    const seen = [];
    const off = eventBus.onAny((_payload, event) => seen.push(event));

    await loginGestor({ email: "m@e.gov.br", senha: "senha123" });
    off();

    expect(seen).toContainEqual(
      expect.objectContaining({ type: GESTOR_EVENTS.LOGIN, payload: { ok: true } }),
    );
    expect(JSON.stringify(seen)).not.toContain("senha123");
  });

  it("loginGestor: emite gestor/login com ok=false quando falha e propaga o erro", async () => {
    apiClient.post.mockRejectedValue(new Error("credenciais invalidas"));
    const seen = [];
    const off = eventBus.onAny((_payload, event) => seen.push(event));

    await expect(loginGestor({ email: "m@e.gov.br", senha: "errada123" })).rejects.toThrow(
      "credenciais invalidas",
    );
    off();

    expect(seen).toContainEqual(
      expect.objectContaining({ type: GESTOR_EVENTS.LOGIN, payload: { ok: false } }),
    );
  });

  it("logoutGestor: emite gestor/logout mesmo quando o servidor falha", async () => {
    apiClient.post.mockRejectedValue(new Error("falha"));
    const seen = [];
    const off = eventBus.onAny((_payload, event) => seen.push(event));

    await expect(logoutGestor()).rejects.toThrow("falha");
    off();

    expect(seen).toContainEqual(expect.objectContaining({ type: GESTOR_EVENTS.LOGOUT }));
  });

  it("logoutGestor: POST /api/gestor/logout e limpa o token mesmo com erro", async () => {
    apiClient.post.mockRejectedValue(new Error("falha"));
    await expect(logoutGestor()).rejects.toThrow("falha");
    expect(getApiToken()).toBeNull();
  });

  it("getPesquisaPublica: GET /publica/:token", async () => {
    apiClient.get.mockResolvedValue({ id: 1, perguntas: [] });
    await getPesquisaPublica("token-uuid");
    expect(apiClient.get).toHaveBeenCalledWith(`${BASE}/publica/token-uuid`);
  });

  it("enviarRespostaPublica: POST /publica/:token/resposta", async () => {
    apiClient.post.mockResolvedValue({ ok: true, id: 9 });
    const payload = { identificador_dispositivo: "u", respostas: [] };
    await enviarRespostaPublica("token-uuid", payload);
    expect(apiClient.post).toHaveBeenCalledWith(
      `${BASE}/publica/token-uuid/resposta`,
      payload,
    );
  });

  it("getResultados: GET /:id/resultados", async () => {
    apiClient.get.mockResolvedValue({ n_respostas: 3, perguntas: [] });
    await getResultados(12);
    expect(apiClient.get).toHaveBeenCalledWith(`${BASE}/12/resultados`);
  });
});