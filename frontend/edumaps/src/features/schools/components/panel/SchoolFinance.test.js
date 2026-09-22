// src/features/schools/components/panel/SchoolFinance.test.js
import { render, screen, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SchoolFinance from "./SchoolFinance.svelte";
import { router } from "@/app/router.svelte.js";

vi.mock("@carbon/charts-svelte", async () => {
  const stub = (
    await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")
  ).default;
  return { LineChart: stub, DonutChart: stub };
});

vi.mock("@/app/router.svelte.js", () => ({ router: { navigate: vi.fn() } }));

const SERIES = [
  { ano: 2025, mes: "Janeiro", mes_num: 1, total_salario: 1000, total_profissionais: 10 },
  { ano: 2025, mes: "Dezembro", mes_num: 12, total_salario: 2000, total_profissionais: 12 },
];
const CATEGORIAS = [
  { categoria: "Docente licenciatura plena", total_salario: 2500, total_profissionais: 8 },
  { categoria: "Secretaria escolar", total_salario: 500, total_profissionais: 2 },
];

function setup() {
  render(SchoolFinance, {
    props: { inep: "12345678", series: SERIES, categorias: CATEGORIAS },
  });
}

describe("SchoolFinance", () => {
  it("renderiza os gráficos (custo, profissionais e categorias)", () => {
    setup();
    const stubs = document.querySelectorAll('[data-testid="carbon-chart-stub"]');
    expect(stubs.length).toBeGreaterThanOrEqual(3);
  });

  it("lista as categorias com ícones", () => {
    setup();
    expect(screen.getByText("Categorias profissionais")).toBeInTheDocument();
    expect(screen.getByText("Docentes")).toBeInTheDocument();
    expect(screen.getByText("Administrativo")).toBeInTheDocument();
    expect(screen.getAllByRole("img").length).toBeGreaterThan(0);
  });

  it("navega para a folha completa na competência mais recente", async () => {
    setup();
    const button = screen.getByRole("button", { name: /ver folha completa/i });
    await fireEvent.click(button);

    expect(router.navigate).toHaveBeenCalledWith(
      "/escola/payroll?inep=12345678&date=12-2025",
    );
  });

  it("escopa como rede municipal quando a origem é a Secretaria", () => {
    render(SchoolFinance, {
      props: {
        inep: "12345678",
        series: SERIES,
        categorias: CATEGORIAS,
        totalProfissionais: 3632,
        origem: "secretaria",
      },
    });

    expect(screen.getByText(/Painel da rede municipal — não desta escola/)).toBeInTheDocument();
    expect(
      screen.getByText((_, el) =>
        el?.tagName === "H2" && /Categorias profissionais/.test(el.textContent) &&
        /rede municipal/.test(el.textContent),
      ),
    ).toBeInTheDocument();
    // a folha detalhada (nomes) fica indisponível no agregado
    expect(screen.getByRole("button", { name: /ver folha completa/i })).toBeDisabled();
  });
});
