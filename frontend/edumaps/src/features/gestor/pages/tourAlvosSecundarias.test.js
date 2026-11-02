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
import relatoriosSalvos from "@/shared/tour/tours/relatoriosSalvos.js";
import relatorioSalvo from "@/shared/tour/tours/relatorioSalvo.js";
import RelatoriosSalvosPage from "./RelatoriosSalvosPage.svelte";
import RelatorioSalvoPage from "./RelatorioSalvoPage.svelte";
import { RELATORIO_RESULT_FIXTURE } from "../mocks/relatoriosFixtures.js";
import { resetRelatoriosMockState, semearSalvosMock } from "../mocks/relatoriosHandlers.js";

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

// Lote B: relatórios salvos (lista e detalhe :id).
describe("tours de relatórios salvos × markup", () => {
  beforeEach(() => {
    resetRelatoriosMockState();
    window.localStorage.clear();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
  });
  afterEach(() => {
    setApiToken(null);
    window.history.replaceState({}, "", "/");
  });

  const alvosFaltando = (tour) =>
    tour.passos.map((p) => p.alvo).filter((alvo) => document.querySelector(seletorDoAlvo(alvo)) === null);

  it("o catálogo distingue a lista do detalhe", () => {
    expect(tourManager.tourDaRota("/gestor/relatorios/salvos")?.id).toBe(relatoriosSalvos.id);
    expect(tourManager.tourDaRota("/gestor/relatorios/salvos/7")?.id).toBe(relatorioSalvo.id);
    expect(tourManager.tourDaRota("/gestor/relatorios")?.id).toBe("gestor-relatorios");
  });

  it("lista vazia: prontoQuando e alvos existem", async () => {
    const { container } = render(RelatoriosSalvosPage);
    await waitFor(() => expect(container.querySelector(seletorDoAlvo("salvos-lista"))).not.toBeNull(), {
      timeout: 5000,
    });
    expect(alvosFaltando(relatoriosSalvos)).toEqual([]);
  });

  it("lista com itens: prontoQuando e alvos existem", async () => {
    semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
    const { container, findByTestId } = render(RelatoriosSalvosPage);
    await findByTestId("salvos-tabela");
    expect(container.querySelector(seletorDoAlvo("salvos-lista"))).not.toBeNull();
    expect(alvosFaltando(relatoriosSalvos)).toEqual([]);
  });

  it("lista sem sessão: não abre", async () => {
    setSessaoToken(null);
    setApiToken(null);
    const { container, findByText } = render(RelatoriosSalvosPage);
    await findByText("Entre para ver os seus relatórios.");
    expect(container.querySelector(seletorDoAlvo("salvos-lista"))).toBeNull();
  });

  it("detalhe: prontoQuando e alvos existem", async () => {
    const [s] = semearSalvosMock([{ relatorio: RELATORIO_RESULT_FIXTURE }]);
    const { container } = render(RelatorioSalvoPage, { props: { id: String(s.id) } });
    await waitFor(() => expect(container.querySelector(seletorDoAlvo(relatorioSalvo.prontoQuando))).not.toBeNull(), {
      timeout: 5000,
    });
    expect(alvosFaltando(relatorioSalvo)).toEqual([]);
  });

  it("detalhe inexistente: não abre", async () => {
    const { container, findByTestId } = render(RelatorioSalvoPage, { props: { id: "999999" } });
    await findByTestId("salvo-nao-encontrado");
    expect(container.querySelector(seletorDoAlvo(relatorioSalvo.prontoQuando))).toBeNull();
  });
});
