import { describe, it, expect, vi, afterEach } from "vitest";
import { criarEnvio } from "./envio.svelte.js";
import { apiClient } from "@/shared/api/client.js";

const adiado = () => {
  let resolver, rejeitar;
  const promessa = new Promise((res, rej) => {
    resolver = res;
    rejeitar = rej;
  });
  return { promessa, resolver, rejeitar };
};

describe("criarEnvio", () => {
  it("ignora o segundo clique enquanto o primeiro está em curso", async () => {
    const envio = criarEnvio();
    const d = adiado();
    const fn = vi.fn(() => d.promessa);
    const salvar = envio.travar(fn);

    const p1 = salvar("a");
    const p2 = salvar("b");
    expect(envio.ocupado).toBe(true);
    expect(fn).toHaveBeenCalledTimes(1);
    expect(fn).toHaveBeenCalledWith("a");
    expect(await p2).toBeUndefined();

    d.resolver("ok");
    expect(await p1).toBe("ok");
    expect(envio.ocupado).toBe(false);
  });

  it("solta a trava depois de um erro, para tentar de novo", async () => {
    const envio = criarEnvio();
    const falha = vi.fn(() => Promise.reject(new Error("rede")));
    await expect(envio.rodar(falha)).rejects.toThrow("rede");
    expect(envio.ocupado).toBe(false);

    const ok = vi.fn(async () => 1);
    expect(await envio.rodar(ok)).toBe(1);
    expect(ok).toHaveBeenCalledTimes(1);
  });

  it("envios diferentes não se travam", async () => {
    const a = criarEnvio();
    const b = criarEnvio();
    const d = adiado();
    a.rodar(() => d.promessa);
    const fb = vi.fn(async () => 2);
    expect(await b.rodar(fb)).toBe(2);
    d.resolver();
  });

  // #416: chave de idempotência no POST, mantida depois de falha e trocada
  // depois de um envio concluído.
  describe("chave de idempotência", () => {
    const fetchOriginal = global.fetch;
    const resposta = (status) => ({ ok: status < 300, status, json: async () => ({}) });
    const chaves = () => global.fetch.mock.calls.map(([, o]) => o.headers["Idempotency-Key"]);
    afterEach(() => {
      global.fetch = fetchOriginal;
    });

    it("repete a chave depois de erro de rede e de 5xx; troca depois do sucesso", async () => {
      global.fetch = vi.fn()
        .mockRejectedValueOnce(new TypeError("Failed to fetch"))
        .mockResolvedValueOnce(resposta(503))
        .mockResolvedValueOnce(resposta(201))
        .mockResolvedValueOnce(resposta(201));
      const envio = criarEnvio();
      const salvar = envio.travar(() => apiClient.post("/api/x", { a: 1 }));

      await expect(salvar()).rejects.toThrow();
      await expect(salvar()).rejects.toThrow();
      await salvar();
      await salvar();

      const [k1, k2, k3, k4] = chaves();
      expect(k1).toMatch(/^[0-9a-f-]{36}$/);
      expect(k2).toBe(k1);
      expect(k3).toBe(k1);
      expect(k4).not.toBe(k1);
    });

    it("troca a chave depois de um 422 (já usada com outros dados)", async () => {
      global.fetch = vi.fn().mockResolvedValueOnce(resposta(422)).mockResolvedValueOnce(resposta(201));
      const envio = criarEnvio();
      const salvar = envio.travar(() => apiClient.post("/api/x", {}));
      await expect(salvar()).rejects.toThrow();
      await salvar();
      const [k1, k2] = chaves();
      expect(k2).not.toBe(k1);
    });

    it("só o primeiro POST leva a chave; GET e POST fora do envio não", async () => {
      global.fetch = vi.fn().mockResolvedValue(resposta(200));
      const envio = criarEnvio();
      await envio.rodar(() => Promise.all([apiClient.post("/api/a", {}), apiClient.post("/api/b", {})]));
      await envio.rodar(() => apiClient.get("/api/c"));
      await apiClient.post("/api/d", {});
      const [a, b, c, d] = chaves();
      expect(a).toBeTruthy();
      expect(b).toBeUndefined();
      expect(c).toBeUndefined();
      expect(d).toBeUndefined();
    });
  });
});
