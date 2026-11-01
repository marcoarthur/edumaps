// src/features/admin/pages/tourAlvos.test.js
//
// Contrato entre o tour do Painel de Administração e o markup real:
// administrador com dados → `prontoQuando` e todos os alvos existem;
// gestor sem perfil admin (403/“restrita”) e sem sessão → o `prontoQuando`
// não aparece (o tour não abre). Mesmo padrão dos tourAlvos do gestor/chat.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/svelte";
import { http, HttpResponse } from "msw";
import { server } from "../../../mocks/server.js";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN, SESSION_GESTOR } from "@/features/gestor/mocks/fixtures.js";
import { seletorDoAlvo } from "@/shared/tour/tourManager.svelte.js";
import adminPainel from "@/shared/tour/tours/adminPainel.js";
import AdminTelemetryPage from "./AdminTelemetryPage.svelte";

vi.mock("@carbon/charts-svelte", () => {
  const stub = () => null;
  return { LineChart: stub, DonutChart: stub, BarChartGrouped: stub, RadarChart: stub };
});

const pronto = () => document.querySelector(seletorDoAlvo(adminPainel.prontoQuando));

describe("tour admin-painel × markup do AdminTelemetryPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    vi.restoreAllMocks();
  });

  it("administrador: prontoQuando e todos os alvos existem", async () => {
    render(AdminTelemetryPage);
    await waitFor(() => expect(pronto()).not.toBeNull(), { timeout: 5000 });
    const faltando = adminPainel.passos
      .map((p) => p.alvo)
      .filter((alvo) => document.querySelector(seletorDoAlvo(alvo)) === null);
    expect(faltando).toEqual([]);
  });

  it("gestor sem perfil admin (“restrita”): não abre", async () => {
    server.use(
      http.get("/api/gestor/me", () => HttpResponse.json({ ...SESSION_GESTOR, access_role: "gestor" })),
    );
    render(AdminTelemetryPage);
    await screen.findByText(/restrita a administradores/);
    expect(pronto()).toBeNull();
  });

  it("sem sessão: não abre", async () => {
    window.localStorage.clear();
    setApiToken(null);
    render(AdminTelemetryPage);
    await screen.findByText("Entrar como administrador");
    expect(pronto()).toBeNull();
  });
});
