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

// #558 (QT-02 da P2): meses em que o município declarou só o total da Secretaria.
describe("SchoolFinance — meses da Secretaria (#558)", () => {
  it("avisa que a folha da escola não aparece nesses meses", () => {
    render(SchoolFinance, { props: { inep: "51171805", series: SERIES, categorias: CATEGORIAS, ano: 2026, mesesSecretaria: [3, 4, 5, 6, 7, 8] } });
    expect(screen.getByTestId("aviso-meses-secretaria")).toHaveTextContent(
      "De março a agosto de 2026, o município declarou a folha só no total da Secretaria, sem separar as escolas: nesses meses a folha desta escola não aparece");
  });
  it("um mês só", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, ano: 2026, mesesSecretaria: [6] } });
    expect(screen.getByTestId("aviso-meses-secretaria")).toHaveTextContent("Em junho de 2026, o município declarou");
    expect(screen.getByTestId("aviso-meses-secretaria")).toHaveTextContent("nesse mês");
  });
  it("no painel da Secretaria, sem o aviso", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, origem: "secretaria", mesesSecretaria: [3] } });
    expect(screen.queryByTestId("aviso-meses-secretaria")).toBeNull();
  });
});

// #567 (P1-FL-01 da P1): os docentes do Censo ao lado da folha.
describe("SchoolFinance — docentes da folha e do Censo (#567)", () => {
  const DOC = { folha_ano: 36, folha_por_mes: 26.5, censo: { docentes: 62, ano: 2025 },
    municipio: { magisterio: 1374, so_secretaria: 658, avisar: true } };
  it("mostra os dois números, o porquê e o aviso da Secretaria", () => {
    render(SchoolFinance, { props: { inep: "35070212", series: SERIES, categorias: CATEGORIAS, ano: 2026, docentes: DOC } });
    const b = screen.getByTestId("docentes-folha-censo");
    expect(b).toHaveTextContent("Docentes na folha: 36 em 2026 (26,5 por mês, em média). No Censo Escolar 2025: 62.");
    expect(b).toHaveTextContent("Os números podem diferir");
    expect(screen.getByTestId("aviso-so-secretaria")).toHaveTextContent(
      "Em 2026, 658 dos 1.374 profissionais do magistério do município aparecem só no total da Secretaria");
  });
  it("sem o aviso abaixo de 10%", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, ano: 2025,
      docentes: { ...DOC, municipio: { magisterio: 3485, so_secretaria: 60, avisar: false } } } });
    expect(screen.getByTestId("docentes-folha-censo")).toBeInTheDocument();
    expect(screen.queryByTestId("aviso-so-secretaria")).toBeNull();
  });
  it("no painel da Secretaria, sem o bloco", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, origem: "secretaria", docentes: DOC } });
    expect(screen.queryByTestId("docentes-folha-censo")).toBeNull();
  });
});

// #568 (P1-FL-02 da P1): meses, não "competências"; a soma das categorias.
describe("SchoolFinance — meses e a soma das categorias (#568)", () => {
  it("fala em meses", () => {
    setup();
    expect(screen.getByText("Meses com folha")).toBeInTheDocument();
    expect(screen.getByText(/No último mês \(dez\/2025\)/)).toBeInTheDocument();
    expect(screen.queryByText(/[Cc]ompetência/)).toBeNull();
  });
  it("explica a soma das categorias quando passa do total", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, totalProfissionais: 9 } });
    expect(screen.getByTestId("nota-soma-categorias")).toHaveTextContent("a soma (10) passa do total de profissionais (9)");
  });
  it("sem nota quando a soma fecha", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, totalProfissionais: 10 } });
    expect(screen.queryByTestId("nota-soma-categorias")).toBeNull();
  });
});

// #571 (QI-01 da P3): o salário do magistério da rede inteira.
describe("SchoolFinance — salário da rede (#571)", () => {
  const S = { pessoas: 2961, total: 6975, base: 2669, carga_comum: 18 };
  it("também no painel da Secretaria", () => {
    render(SchoolFinance, { props: { inep: "1", series: SERIES, categorias: CATEGORIAS, origem: "secretaria", ano: 2026, salarioRede: S } });
    expect(screen.getByTestId("salario-rede")).toHaveTextContent("Magistério na rede municipal em 2026: salário total R$ 6.975 e base R$ 2.669");
    expect(screen.getByTestId("salario-rede")).toHaveTextContent("sem conversão para 40 horas");
  });
  it("sem dado, sem a linha", () => {
    setup();
    expect(screen.queryByTestId("salario-rede")).toBeNull();
  });
});
