// src/features/config/pages/tourAlvos.test.js
//
// Contrato entre o tour do Painel de Configuração e o markup real:
// administrador → `prontoQuando` e todos os alvos existem; gestor sem perfil
// admin (“restrita”) e sem sessão → o `prontoQuando` não aparece.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN, SESSION_GESTOR } from "@/features/gestor/mocks/fixtures.js";
import { resetConfigMockState } from "../mocks/configHandlers.js";
import { seletorDoAlvo } from "@/shared/tour/tourManager.svelte.js";
import configPainel from "@/shared/tour/tours/configPainel.js";
import ConfigPage from "./ConfigPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));

const pronto = () => document.querySelector(seletorDoAlvo(configPainel.prontoQuando));

describe("tour config-painel × markup do ConfigPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    resetConfigMockState();
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("administrador: prontoQuando e todos os alvos existem", async () => {
    render(ConfigPage);
    await waitFor(() => expect(pronto()).not.toBeNull(), { timeout: 5000 });
    const faltando = configPainel.passos
      .map((p) => p.alvo)
      .filter((alvo) => document.querySelector(seletorDoAlvo(alvo)) === null);
    expect(faltando).toEqual([]);
  });

  it("gestor sem perfil admin (“restrita”): não abre", async () => {
    server.use(
      http.get("/api/gestor/me", () => HttpResponse.json({ ...SESSION_GESTOR, access_role: "gestor" })),
    );
    render(ConfigPage);
    await screen.findByText(/restrita a administradores/);
    expect(pronto()).toBeNull();
  });

  it("sem sessão: não abre", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(ConfigPage);
    await screen.findByText("Entrar como administrador");
    expect(pronto()).toBeNull();
  });
});
