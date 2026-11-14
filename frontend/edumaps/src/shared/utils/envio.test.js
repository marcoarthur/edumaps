import { describe, it, expect, vi } from "vitest";
import { criarEnvio } from "./envio.svelte.js";

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
});
