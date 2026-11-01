// src/features/gestor/pages/tourAlvosSecundarias.test.js
//
// Contrato dos tours das telas secundárias do gestor (assistentes e
// detalhes, com rotas :id/listas) × markup real. Para cada uma: na URL que a
// página espera, com sessão (MSW), o `prontoQuando` e todos os alvos existem.
// E o catálogo resolve a URL concreta para o tour certo (colisão nova × :id).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { seletorDoAlvo } from "@/shared/tour/tourManager.svelte.js";
import { tourManager } from "@/shared/tour";
import pesquisaAssistente from "@/shared/tour/tours/pesquisaAssistente.js";
import pesquisaResultados from "@/shared/tour/tours/pesquisaResultados.js";
import reuniaoAssistente from "@/shared/tour/tours/reuniaoAssistente.js";
import reuniaoDetalhe from "@/shared/tour/tours/reuniaoDetalhe.js";
import relacaoDetalhe from "@/shared/tour/tours/relacaoDetalhe.js";
import GestorPesquisasWizardPage from "./GestorPesquisasWizardPage.svelte";
import GestorPesquisasResultadosPage from "./GestorPesquisasResultadosPage.svelte";
import ReunioesWizardPage from "./ReunioesWizardPage.svelte";
import ReuniaoDetailPage from "./ReuniaoDetailPage.svelte";
import RelacaoDetailPage from "./RelacaoDetailPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));
vi.mock("@carbon/charts-svelte", () => {
  const stub = () => null;
  return { LineChart: stub, DonutChart: stub, BarChartGrouped: stub, BarChartSimple: stub, RadarChart: stub };
});

// [nome, tour, página, URL]
const CASOS = [
  ["assistente de pesquisa (nova)", pesquisaAssistente, GestorPesquisasWizardPage, "/gestor/pesquisas/nova?inep=11000040"],
  ["resultados da pesquisa", pesquisaResultados, GestorPesquisasResultadosPage, "/gestor/pesquisas/resultados?pesquisa=2"],
  ["assistente de reunião (nova)", reuniaoAssistente, ReunioesWizardPage, "/gestor/reunioes/nova"],
  ["assistente de reunião (editar)", reuniaoAssistente, ReunioesWizardPage, "/gestor/reunioes/51/editar"],
  ["detalhe da reunião", reuniaoDetalhe, ReuniaoDetailPage, "/gestor/reunioes/51"],
  ["detalhe da relação", relacaoDetalhe, RelacaoDetailPage, "/gestor/relacoes/1"],
];

describe("tours das telas secundárias × markup (com sessão)", () => {
  beforeEach(() => {
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    window.history.replaceState({}, "", "/");
  });

  it.each(CASOS)("%s: o catálogo escolhe este tour para a URL", (_n, tour, _p, url) => {
    expect(tourManager.tourDaRota(url.split("?")[0])?.id).toBe(tour.id);
  });

  it.each(CASOS)("%s: prontoQuando e todos os alvos existem", async (_n, tour, Pagina, url) => {
    window.history.replaceState({}, "", url);
    const { container } = render(Pagina);
    await waitFor(
      () => expect(container.querySelector(seletorDoAlvo(tour.prontoQuando))).not.toBeNull(),
      { timeout: 5000 },
    );
    const faltando = tour.passos
      .map((p) => p.alvo)
      .filter((alvo) => document.querySelector(seletorDoAlvo(alvo)) === null);
    expect(faltando).toEqual([]);
  });
});
