// src/features/chat/pages/tourAlvos.test.js
//
// Contrato entre o tour do Assistente do Censo e o markup real do ChatPage:
// com sessão de gestor (MSW) e a página pronta, o `prontoQuando` e todos os
// alvos existem; sem sessão, o `prontoQuando` não aparece (o tour não abre
// sobre a tela de login). Mesmo padrão de features/gestor/pages/tourAlvos.test.js.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
import { SESSION_TOKEN } from "@/features/gestor/mocks/fixtures.js";
import { seletorDoAlvo } from "@/shared/tour/tourManager.svelte.js";
import assistenteCenso from "@/shared/tour/tours/assistenteCenso.js";
import ChatPage from "./ChatPage.svelte";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { BarChartSimple: stub, LineChart: stub, PieChart: stub, DonutChart: stub };
});

describe("tour assistente-censo × markup do ChatPage", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => setApiToken(null));

  it("logado: prontoQuando e todos os alvos existem", async () => {
    const { container } = render(ChatPage);
    await waitFor(
      () => expect(container.querySelector(seletorDoAlvo(assistenteCenso.prontoQuando))).not.toBeNull(),
      { timeout: 5000 },
    );
    const faltando = assistenteCenso.passos
      .map((p) => p.alvo)
      .filter((alvo) => document.querySelector(seletorDoAlvo(alvo)) === null);
    expect(faltando).toEqual([]);
  });

  it("sem sessão: prontoQuando não aparece", async () => {
    setSessaoToken(null);
    setApiToken(null);
    const { container, findAllByText } = render(ChatPage);
    expect((await findAllByText(/Entre para usar o Assistente/, {}, { timeout: 5000 })).length).toBeGreaterThan(0);
    expect(container.querySelector(seletorDoAlvo(assistenteCenso.prontoQuando))).toBeNull();
  });
});
