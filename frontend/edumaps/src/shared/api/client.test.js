// src/shared/api/client.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { apiClient, setApiToken, getApiToken } from "./client.js";
import { eventBus, EVENTS } from "@/shared/events";

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

  it("upload multipart não força Content-Type application/json", async () => {
    const form = new FormData();
    const file = new File(["conteudo-pdf"], "pauta.pdf", { type: "application/pdf" });
    form.append("arquivo", file);
    fetch.mockResolvedValue({
      ok: true,
      status: 201,
      json: async () => ({ ok: true }),
    });

    await apiClient.upload("/api/gestor/11000040/reunioes/51/anexos/pauta", form);

    const [, options] = fetch.mock.calls[0];
    expect(options.body).toBeInstanceOf(FormData);
    expect(options.headers["Content-Type"]).toBeUndefined();
  });

  it("upload respeita Authorization Bearer mesmo com FormData", async () => {
    setApiToken("token-de-sessao-uuid");
    const form = new FormData();
    form.append("arquivo", new File(["x"], "pauta.pdf"));
    fetch.mockResolvedValue({
      ok: true,
      status: 201,
      json: async () => ({ ok: true }),
    });

    await apiClient.upload("/api/gestor/11000040/reunioes/51/anexos/ata", form);

    const [, options] = fetch.mock.calls[0];
    expect(options.headers.Authorization).toBe("Bearer token-de-sessao-uuid");
  });

  it("download devolve {blob, filename} do Content-Disposition", async () => {
    setApiToken("token-de-sessao-uuid");
    fetch.mockResolvedValue({
      ok: true,
      status: 200,
      headers: { get: () => 'attachment; filename="pauta.pdf"' },
      blob: async () => new Blob(["content"]),
    });

    const res = await apiClient.download(
      "/api/gestor/11000040/reunioes/51/anexos/pauta",
    );

    const [calledUrl, options] = fetch.mock.calls[0];
    expect(calledUrl).toBe("/api/gestor/11000040/reunioes/51/anexos/pauta");
    expect(options.headers.Authorization).toBe("Bearer token-de-sessao-uuid");
    expect(res.filename).toBe("pauta.pdf");
    expect(res.blob).toBeInstanceOf(Blob);
  });

  it("download lança ApiError quando o backend responde com erro JSON", async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 404,
      headers: { get: () => "" },
      json: async () => ({ error: "Anexo não encontrado" }),
    });

    await expect(
      apiClient.download("/api/gestor/11000040/reunioes/51/anexos/pauta"),
    ).rejects.toThrow("Anexo não encontrado");
  });

  it("emite api:error no eventBus para status >= 500", async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 500,
      json: async () => ({ error: "Boom interno" }),
    });

    const spy = vi.fn();
    const unsubscribe = eventBus.on(EVENTS.API_ERROR, spy);

    await expect(apiClient.get("/api/gestor/me")).rejects.toThrow("Boom interno");
    expect(spy).toHaveBeenCalledOnce();
    const [payload] = spy.mock.calls[0];
    expect(payload.status).toBe(500);
    expect(payload.url).toBe("/api/gestor/me");
    expect(payload.message).toBe("Boom interno");
    expect(payload.error).toBeInstanceOf(Error);
    expect(payload.error.message).toBe("Boom interno");

    unsubscribe();
  });

  it("não emite api:error para 4xx (erro de cliente/negócio)", async () => {
    fetch.mockResolvedValue({
      ok: false,
      status: 422,
      json: async () => ({ error: "Validação" }),
    });

    const spy = vi.fn();
    const unsubscribe = eventBus.on(EVENTS.API_ERROR, spy);

    await expect(apiClient.post("/api/gestor/me/pesquisas", {})).rejects.toThrow(
      "Validação",
    );
    expect(spy).not.toHaveBeenCalled();

    unsubscribe();
  });
});
