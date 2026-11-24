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

// #553 (QS-01 da P5): a folha do ano por fonte de recurso.
describe("SchoolFinance — por fonte de recurso (#553)", () => {
  const UBATUBA = { fundeb_70: 63980190, fundeb_30: 208437, outras: 3507782, total: 67696409, nao_informado: 0 };

  it("mostra as três partes, com o percentual e o aviso do mínimo legal", () => {
    render(SchoolFinance, { props: { inep: "35070212", series: SERIES, categorias: CATEGORIAS, porFonte: UBATUBA, ano: 2026 } });
    const card = screen.getByTestId("folha-por-fonte");
    expect(card).toHaveTextContent("Por fonte de recurso em 2026");
    expect(screen.getByTestId("fonte-fundeb_70")).toHaveTextContent("Fundeb, parcela de 70%");
    expect(screen.getByTestId("fonte-fundeb_70")).toHaveTextContent("94,5%");
    expect(screen.getByTestId("fonte-fundeb_30")).toHaveTextContent("0,3%");
    expect(screen.getByTestId("fonte-outras")).toHaveTextContent("5,2%");
    expect(screen.queryByTestId("fonte-nao_informado")).toBeNull();
    expect(screen.getByTestId("aviso-minimo-legal")).toHaveTextContent("Não é a verificação do mínimo de 70% exigido em lei");
  });

  it("no total da Secretaria, diz que é a rede municipal", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, origem: "secretaria", porFonte: { ...UBATUBA } } });
    expect(screen.getByTestId("folha-por-fonte")).toHaveTextContent("rede municipal");
  });

  it("sem a divisão, o cartão não aparece", () => {
    setup();
    expect(screen.queryByTestId("folha-por-fonte")).toBeNull();
  });
});

// #557 (QT-01 da P2): mês com a folha do município pela metade.
describe("SchoolFinance — meses incompletos (#557)", () => {
  const INC = [
    { mes: 9, nome: "setembro", registros: 3269, categorias: 2, registros_habitual: 9680, categorias_habitual: 4 },
    { mes: 10, nome: "outubro", registros: 3253, categorias: 1, registros_habitual: 9680, categorias_habitual: 4 },
  ];
  it("avisa, com os números e sem afirmar a causa", () => {
    const serie = [8, 9, 10].map((m) => ({ ano: 2025, mes: String(m), mes_num: m, total_salario: 1000, total_profissionais: 10 }));
    render(SchoolFinance, { props: { inep: "51171805", series: serie, categorias: CATEGORIAS, ano: 2025, mesesIncompletos: INC } });
    const a = screen.getByTestId("aviso-meses-incompletos");
    expect(a).toHaveTextContent("Setembro e outubro de 2025 têm bem menos profissionais declarados");
    expect(a).toHaveTextContent("setembro: 3.269 registros em 2 categorias, contra 9.680 em 4 num mês típico");
    expect(a).toHaveTextContent("outubro: 3.253 registros em 1 categoria");
    expect(a).toHaveTextContent("Pode ser a declaração do município ao SIOPE ou a carga");
    expect(a).toHaveTextContent("Nesses meses");
  });
  it("mês incompleto fora da série da escola: sem aviso", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, ano: 2026,
      mesesIncompletos: [{ mes: 6, nome: "junho", registros: 2439, categorias: 2, registros_habitual: 12422, categorias_habitual: 5 }] } });
    expect(screen.queryByTestId("aviso-meses-incompletos")).toBeNull();
  });

  it("sem mês incompleto, sem aviso", () => {
    setup();
    expect(screen.queryByTestId("aviso-meses-incompletos")).toBeNull();
  });
});
