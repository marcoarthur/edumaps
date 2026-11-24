// src/features/schools/pages/SchoolFinancePage.test.js
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";

const mocks = vi.hoisted(() => ({
  getSchoolFinance: vi.fn(),
  requestSchoolSiope: vi.fn(),
  watchJobProgress: vi.fn(),
  fetchMe: vi.fn(),
  addToast: vi.fn(),
  restaurarSessao: vi.fn(),
}));

vi.mock("../api/schoolApi.js", () => ({
  getSchoolFinance: mocks.getSchoolFinance,
  requestSchoolSiope: mocks.requestSchoolSiope,
  watchJobProgress: mocks.watchJobProgress,
}));
vi.mock("@/features/gestor/api/gestorPesquisasApi.js", () => ({ fetchMe: mocks.fetchMe }));
vi.mock("@/features/gestor/utils/gestorAuth.js", () => ({ restaurarSessao: mocks.restaurarSessao }));
vi.mock("@/shared/stores/toastStore.js", () => ({ addToast: mocks.addToast }));

import SchoolFinancePage from "./SchoolFinancePage.svelte";

const INEP = "35051780";

const FINANCE_MUNICIPAL = {
  escola: {
    codigo_inep: INEP,
    nome: "EMEI Teste",
    dependencia_administrativa: "Municipal",
    cod_municipio: "350517",
  },
  total_profissionais: 5,
  origem: "escola",
  series: [
    { ano: 2024, mes: "Outubro", mes_num: 10, total_profissionais: 1, total_salario: 18988.13 },
  ],
  categorias: [],
  siope: {
    habilitado: 1,
    cod_municipio: "350517",
    ano_inicial: 2020,
    ano_atual: 2025,
    anos_presentes: [2023, 2024],
  },
};

describe("SchoolFinancePage — SIOPE", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.restaurarSessao.mockReturnValue(true);
    mocks.fetchMe.mockResolvedValue({ cod_inep: Number(INEP), nome: "Gestor" });
    mocks.getSchoolFinance.mockResolvedValue(FINANCE_MUNICIPAL);
    mocks.requestSchoolSiope.mockResolvedValue({ task: "query_siope", job_id: 42, ano: 2025 });
    mocks.watchJobProgress.mockReturnValue(() => {});
    window.history.replaceState({}, "", `/escola/financeiro?inep=${INEP}`);
  });
  afterEach(() => {
    window.history.replaceState({}, "", "/");
  });

  it("mostra o card e exclui os anos já baixados", async () => {
    render(SchoolFinancePage);

    expect(await screen.findByText(/Dados do SIOPE/)).toBeInTheDocument();
    // 2020..2025 menos 2023/2024
    expect(screen.getByRole("option", { name: "2020" })).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "2025" })).toBeInTheDocument();
    expect(screen.queryByRole("option", { name: "2023" })).toBeNull();
    expect(screen.queryByRole("option", { name: "2024" })).toBeNull();
  });

  it("mostra o total de profissionais distintos, não só a última competência", async () => {
    render(SchoolFinancePage);
    await screen.findByText(/Profissionais \(total\)/);
    // total distinto = 5 (a última competência tem só 1)
    expect(screen.getByText("5")).toBeInTheDocument();
    expect(screen.getByText(/No último mês/)).toBeInTheDocument();
  });

  it("avisa quando os dados vêm do agregado da Secretaria", async () => {
    mocks.getSchoolFinance.mockResolvedValue({
      ...FINANCE_MUNICIPAL,
      origem: "secretaria",
      rotulo_origem:
        "Folha da Secretaria municipal (o SIOPE não detalha por escola neste município)",
    });

    render(SchoolFinancePage);
    expect(
      await screen.findByText(/Painel da rede municipal — não desta escola/),
    ).toBeInTheDocument();
  });

  it("dispara a busca e recarrega ao concluir", async () => {
    mocks.watchJobProgress.mockImplementation((_jobId, { onDone }) => {
      onDone?.();
      return () => {};
    });

    render(SchoolFinancePage);
    await screen.findByText(/Dados do SIOPE/);

    await fireEvent.click(screen.getByRole("button", { name: /Buscar informações via SIOPE/ }));

    await waitFor(() => expect(mocks.requestSchoolSiope).toHaveBeenCalledWith(INEP, 2025));
    await waitFor(() => expect(mocks.getSchoolFinance).toHaveBeenCalledTimes(2));
    expect(mocks.addToast).toHaveBeenCalledWith("Dados do SIOPE atualizados.", "success");
  });

  it("oculta o card em escola não municipal", async () => {
    mocks.getSchoolFinance.mockResolvedValue({
      ...FINANCE_MUNICIPAL,
      escola: { ...FINANCE_MUNICIPAL.escola, dependencia_administrativa: "Estadual" },
      siope: { ...FINANCE_MUNICIPAL.siope, habilitado: 0 },
    });

    render(SchoolFinancePage);
    // painel renderiza (tem série), mas sem o card do SIOPE
    await screen.findByText(/Profissionais \(total\)/);
    expect(screen.queryByText(/Dados do SIOPE/)).toBeNull();
  });

  it("oculta o card quando não há sessão do gestor", async () => {
    mocks.fetchMe.mockRejectedValue(new Error("401"));

    render(SchoolFinancePage);
    await screen.findByText(/Profissionais \(total\)/);
    expect(screen.queryByText(/Dados do SIOPE/)).toBeNull();
  });
});

describe("SchoolFinancePage — ausência e cobertura (#422)", () => {
  const COBERTURA = {
    municipios: 2,
    lista: [
      { cod_municipio: "510340", municipio: "Cuiabá", uf: "MT", ano_inicial: 2025, ano_final: 2026, escolas: 169 },
      { cod_municipio: "355410", municipio: "Ubatuba", uf: "SP", ano_inicial: 2026, ano_final: 2026, escolas: 0 },
    ],
  };
  const SEM_FOLHA = (motivo, rede = "Municipal") => ({
    ...FINANCE_MUNICIPAL,
    escola: { ...FINANCE_MUNICIPAL.escola, dependencia_administrativa: rede },
    series: [],
    total_profissionais: 0,
    ausencia: motivo,
    cobertura: COBERTURA,
    siope: { ...FINANCE_MUNICIPAL.siope, habilitado: rede === "Municipal" ? 1 : 0 },
  });

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.restaurarSessao.mockReturnValue(false);
    mocks.fetchMe.mockRejectedValue(new Error("sem sessão"));
    window.history.replaceState({}, "", `/escola/financeiro?inep=${INEP}`);
  });

  it("escola estadual: diz que o SIOPE só cobre a rede municipal e lista a cobertura", async () => {
    mocks.getSchoolFinance.mockResolvedValue(SEM_FOLHA("nao_municipal", "Estadual"));
    render(SchoolFinancePage);

    expect(await screen.findByText(/só a remuneração da rede municipal/)).toBeInTheDocument();
    expect(screen.getByText(/Rede desta escola: Estadual/)).toBeInTheDocument();
    expect(screen.getByText(/Hoje há folha de pagamento de 2/)).toBeInTheDocument();
    expect(screen.getByText(/Cuiabá \(MT\), 2025–2026: 169 escola\(s\) com folha própria/)).toBeInTheDocument();
    expect(screen.getByText(/Ubatuba \(SP\), 2026: só o total da Secretaria/)).toBeInTheDocument();
  });

  it("município sem carga, visitante: diz que o gestor pode buscar no SIOPE", async () => {
    mocks.getSchoolFinance.mockResolvedValue(SEM_FOLHA("municipio_sem_carga"));
    render(SchoolFinancePage);

    expect(await screen.findByText(/Ainda não há folha deste município/)).toBeInTheDocument();
    expect(screen.getByText(/O gestor da escola, com login, pode pedir a busca/)).toBeInTheDocument();
    expect(screen.queryByText(/Dados do SIOPE/)).toBeNull();
  });

  it("escola sem folha própria num município com folha", async () => {
    mocks.getSchoolFinance.mockResolvedValue(SEM_FOLHA("escola_sem_folha"));
    render(SchoolFinancePage);
    expect(await screen.findByText(/não traz profissionais desta escola/)).toBeInTheDocument();
  });
});

describe("SchoolFinancePage — ano da folha (#491)", () => {
  const COM_ANOS = {
    ...FINANCE_MUNICIPAL,
    ano: 2025,
    anos: [2026, 2025],
    periodo: { mes_inicial: 1, mes_final: 12, meses: 12 },
    series: [
      { ano: 2025, mes: "Janeiro", mes_num: 1, total_profissionais: 3, total_salario: 1000 },
      { ano: 2025, mes: "Dezembro", mes_num: 12, total_profissionais: 3, total_salario: 2000 },
    ],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.restaurarSessao.mockReturnValue(true);
    mocks.fetchMe.mockRejectedValue(new Error("sem sessão"));
    mocks.getSchoolFinance.mockResolvedValue(COM_ANOS);
    window.history.replaceState({}, "", `/escola/financeiro?inep=${INEP}`);
  });

  it("diz o ano e os meses no total e avisa do 13º", async () => {
    render(SchoolFinancePage);
    expect(await screen.findByText(/Custo total em 2025 \(jan a dez\)/)).toBeInTheDocument();
    expect(screen.getByText(/Profissionais em 2025/)).toBeInTheDocument();
    expect(screen.getByTestId("nota-13")).toHaveTextContent("13º");
  });

  it("trocar o ano busca o painel daquele ano", async () => {
    render(SchoolFinancePage);
    const sel = await screen.findByLabelText("Ano da folha");
    await fireEvent.change(sel, { target: { value: "2026" } });
    await waitFor(() => expect(mocks.getSchoolFinance).toHaveBeenLastCalledWith(INEP, 2026));
  });
});
