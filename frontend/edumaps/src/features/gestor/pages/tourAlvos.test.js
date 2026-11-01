// src/features/gestor/pages/tourAlvos.test.js
//
// Contrato entre os tours dos módulos do gestor (shared/tour/tours) e o
// markup REAL das páginas: com sessão válida (MSW) e o conteúdo pronto, todo
// `alvo` de cada passo — e o `prontoQuando` — precisa existir no DOM.
// Refatorar uma página e perder um `data-tour` quebra este teste, não o tour
// em produção (onde o passo cairia no popover centralizado sem aviso).
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, waitFor } from "@testing-library/svelte";
import { setApiToken } from "@/shared/api/client.js";
import { setSessaoToken } from "../utils/gestorSession.js";
import { SESSION_TOKEN } from "../mocks/fixtures.js";
import { resetCanaisMockState } from "../mocks/canaisHandlers.js";
import { resetEnviosMockState } from "../mocks/enviosHandlers.js";
import { seletorDoAlvo } from "@/shared/tour/tourManager.svelte.js";
import gestorRelatorios from "@/shared/tour/tours/gestorRelatorios.js";
import gestorContatos from "@/shared/tour/tours/gestorContatos.js";
import gestorListas from "@/shared/tour/tours/gestorListas.js";
import gestorEnvios from "@/shared/tour/tours/gestorEnvios.js";
import gestorSegmentos from "@/shared/tour/tours/gestorSegmentos.js";
import RelatoriosPage from "./RelatoriosPage.svelte";
import ContatosPage from "./ContatosPage.svelte";
import ListasPage from "./ListasPage.svelte";
import EnviosPage from "./EnviosPage.svelte";
import SegmentosPage from "./SegmentosPage.svelte";

vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: vi.fn() }));
vi.mock("@carbon/charts-svelte", () => {
  const stub = () => null;
  return { LineChart: stub, DonutChart: stub, BarChartGrouped: stub, BarChartSimple: stub, RadarChart: stub };
});

const CASOS = [
  ["Relatórios", gestorRelatorios, RelatoriosPage],
  ["Contatos", gestorContatos, ContatosPage],
  ["Listas", gestorListas, ListasPage],
  ["Envios", gestorEnvios, EnviosPage],
  ["Listas dinâmicas", gestorSegmentos, SegmentosPage],
];

describe("tours dos módulos do gestor × markup das páginas (logado)", () => {
  beforeEach(() => {
    window.localStorage.clear();
    resetCanaisMockState?.();
    resetEnviosMockState?.();
    setSessaoToken(SESSION_TOKEN);
    setApiToken(SESSION_TOKEN);
    window.history.replaceState({}, "", "/");
  });
  afterEach(() => {
    setApiToken(null);
  });

  it.each(CASOS)("%s: prontoQuando e todos os alvos existem", async (_nome, tour, Pagina) => {
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

  it.each(CASOS)("%s: sem sessão, o prontoQuando NÃO aparece (tour não abre)", async (_nome, tour, Pagina) => {
    setSessaoToken(null);
    setApiToken(null);
    const { container, findAllByText } = render(Pagina);
    // tela de login do gestor (texto "Entre para…" + botão "Entrar")
    expect((await findAllByText(/Entre para/, {}, { timeout: 5000 })).length).toBeGreaterThan(0);
    expect(container.querySelector(seletorDoAlvo(tour.prontoQuando))).toBeNull();
  });
});
