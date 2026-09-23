// TEMP: teste de integração do auto-preenchimento do ChatPage sem mocks de API.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/svelte";
import ChatPage from "./ChatPage.svelte";

vi.mock("../api/chatApi.js", () => ({
  askChat: vi.fn(),
  getChatProgress: vi.fn(),
  extractSql: () => null,
  extractResposta: () => null,
  extractResultado: () => null,
  extractOrigem: () => [],
  extractMeta: () => ({ linhas: 0, colunas: 0 }),
}));

describe("ChatPage integração (fetch real mockado)", () => {
  let calls;

  beforeEach(() => {
    calls = [];
    localStorage.setItem("edumaps_gestor_token", "tok-123");
    window.fetch = vi.fn(async (url) => {
      const u = String(url);
      calls.push(u);
      if (u.includes("/api/gestor/me")) {
        return new Response(
          JSON.stringify({ id: 16, cod_inep: 35070212, nome: "Tiago Rovai", email: "rovai@edumaps.dev" }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      if (u.includes("/painel")) {
        return new Response(
          JSON.stringify({ escola: { cod_municipio: 3555406, municipio: "Ubatuba", uf: "SP", nome: "TANCREDO" } }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }
      return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
    });
  });

  afterEach(() => {
    localStorage.clear();
  });

  it("preenche os campos a partir da sessão real", async () => {
    render(ChatPage);
    await waitFor(() => {
      expect(screen.getByDisplayValue("TANCREDO")).toBeInTheDocument();
    });
    expect(calls.some((u) => u.includes("/api/gestor/me"))).toBe(true);
    expect(calls.some((u) => u.includes("/painel"))).toBe(true);
    expect(screen.getByDisplayValue("Ubatuba")).toBeInTheDocument();
    expect(screen.getByDisplayValue("SP")).toBeInTheDocument();
    expect(screen.getByDisplayValue("3555406")).toBeInTheDocument();
    expect(screen.getByDisplayValue("35070212")).toBeInTheDocument();
  });

  it("avisa quando a sessão expirou (401 no /me)", async () => {
    window.fetch = vi.fn(async () =>
      new Response(JSON.stringify({ error: "Faça login como gestor." }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      }),
    );
    render(ChatPage);
    await waitFor(() => {
      expect(screen.getByText(/sua sessão expirou/i)).toBeInTheDocument();
    });
  });
});
