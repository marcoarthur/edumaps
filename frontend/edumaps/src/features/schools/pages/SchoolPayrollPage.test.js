// src/features/schools/pages/SchoolPayrollPage.test.js
// #422: escola sem folha (404) é ausência, não erro.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";

const mocks = vi.hoisted(() => ({ getSchoolPayroll: vi.fn(), getSecretariaPayroll: vi.fn(), getRedePayroll: vi.fn(), getCityRedePayroll: vi.fn() }));
vi.mock("../api/schoolApi.js", () => ({ getSchoolPayroll: mocks.getSchoolPayroll, getSecretariaPayroll: mocks.getSecretariaPayroll, getRedePayroll: mocks.getRedePayroll, getCityRedePayroll: mocks.getCityRedePayroll }));

import SchoolPayrollPage from "./SchoolPayrollPage.svelte";

describe("SchoolPayrollPage (#422)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/escola/payroll?inep=32040164");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("404: mostra ausência com link ao painel financeiro, sem 'Erro'", async () => {
    mocks.getSchoolPayroll.mockRejectedValue(new ApiError("Nenhum registro", { status: 404 }));
    render(SchoolPayrollPage);

    expect(await screen.findByText(/Não há folha de pagamento desta escola/)).toBeInTheDocument();
    expect(screen.queryByText(/Erro ao carregar/)).toBeNull();
    const link = screen.getByRole("link", { name: "painel financeiro" });
    expect(link.getAttribute("href")).toBe("/escola/financeiro?inep=32040164");
  });

  it("outro erro continua aparecendo como erro", async () => {
    mocks.getSchoolPayroll.mockRejectedValue(new ApiError("Falha no servidor", { status: 500 }));
    render(SchoolPayrollPage);
    expect(await screen.findByText(/Erro ao carregar/)).toBeInTheDocument();
  });

  it("nome com letra ilegível do SIOPE: a nota explica o \"?\" (#536)", async () => {
    mocks.getSchoolPayroll.mockResolvedValue([
      { nome_profissional: "MARIA PE?ANHA", escola: "EMEB TESTE", salario_total: 1000 },
      { nome_profissional: "JOÃO GONÇALVES", escola: "EMEB TESTE", salario_total: 1000 },
    ]);
    render(SchoolPayrollPage);
    expect(await screen.findByTestId("nota-nome-ilegivel")).toHaveTextContent(
      'Um nome tem "?" no lugar de uma letra: ela já veio ilegível no arquivo do SIOPE',
    );
  });

  it("sem \"?\" nos nomes, sem a nota (#536)", async () => {
    mocks.getSchoolPayroll.mockResolvedValue([
      { nome_profissional: "JOÃO GONÇALVES", escola: "EMEB TESTE", salario_total: 1000 },
    ]);
    render(SchoolPayrollPage);
    await screen.findByText(/1 profissional/);
    expect(screen.queryByTestId("nota-nome-ilegivel")).toBeNull();
  });
});

// #585 (QE-01 da P2): a folha do total da Secretaria, com filtro e páginas.
describe("SchoolPayrollPage — total da Secretaria (#585)", () => {
  const linha = (i) => ({ nome_profissional: `PESSOA ${i}`, categoria: "Docente", carga_horaria: 30, situacao: "Efetivo",
    salario_base: 3000, salario_total: 4000, mes: "Abril", ano: 2026, escola: "SEC MUN" });
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/escola/payroll?inep=51171805&date=04-2026&secretaria=1");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("usa a rota da Secretaria, avisa e pagina", async () => {
    mocks.getSecretariaPayroll.mockResolvedValue(Array.from({ length: 250 }, (_, i) => linha(i)));
    render(SchoolPayrollPage);
    expect(await screen.findByTestId("aviso-folha-secretaria")).toHaveTextContent("sem escola informada");
    expect(mocks.getSecretariaPayroll).toHaveBeenCalledWith("51171805", "04-2026");
    expect(mocks.getSchoolPayroll).not.toHaveBeenCalled();
    expect(screen.getByTestId("paginacao-folha")).toHaveTextContent("250 registros · página 1 de 3");
  });

  it("sem folha da Secretaria no mês", async () => {
    mocks.getSecretariaPayroll.mockRejectedValue(new ApiError("Sem folha", { status: 404 }));
    render(SchoolPayrollPage);
    expect(await screen.findByText(/Não há folha no total da Secretaria/)).toBeInTheDocument();
  });
});

// #598 (QB-02 da P2): filtro por situação e a marca do piso no ano.
describe("SchoolPayrollPage — situação e piso (#598)", () => {
  const p = (nome, situacao, base, abaixo) => ({ nome_profissional: nome, cpf: `xxx.${nome}-xx`, categoria: "Docente",
    carga_horaria: 30, situacao, salario_base: 3000, salario_total: 4000, mes: "Abril", ano: 2026, escola: "EMEB",
    base_40h_ano: base, abaixo_piso_ano: abaixo });
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/escola/payroll?inep=51171805&date=04-2026");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("conta quem fica abaixo, mostra a coluna e filtra", async () => {
    mocks.getSchoolPayroll.mockResolvedValue([
      p("ANA", "Temporário", 4283.61, true), p("ANA", "Temporário", 4283.61, true),
      p("BIA", "Efetivo", 4000, true), p("CAIO", "Efetivo", 6000, false), p("EVA", "Outros", null, null),
    ]);
    render(SchoolPayrollPage);
    expect(await screen.findByTestId("nota-piso-folha")).toHaveTextContent("2 profissionais do magistério ficam abaixo do piso no ano");
    expect(screen.getByText("Base por 40 h no ano")).toBeInTheDocument();
    expect(screen.getByText("R$ 6.000,00")).toBeInTheDocument();
    expect(screen.getAllByText(/abaixo do piso$/)).toHaveLength(3);
    const { fireEvent } = await import("@testing-library/svelte");
    await fireEvent.click(screen.getByTestId("filtro-abaixo-piso"));
    expect(screen.getByTestId("paginacao-folha")).toHaveTextContent("3 registros");
    await fireEvent.change(screen.getByTestId("filtro-situacao"), { target: { value: "efetivo" } });
    expect(screen.getByTestId("paginacao-folha")).toHaveTextContent("1 registro ·");
    expect(screen.queryByText("CAIO")).toBeNull();
  });

  it("sem a conta (ano sem piso), sem coluna nem nota", async () => {
    mocks.getSchoolPayroll.mockResolvedValue([p("ANA", "Efetivo", null, null)]);
    render(SchoolPayrollPage);
    await screen.findByText("ANA");
    expect(screen.queryByTestId("nota-piso-folha")).toBeNull();
    expect(screen.queryByText("Base por 40 h no ano")).toBeNull();
    expect(screen.queryByTestId("paginacao-folha")).toBeNull();
  });
});

// #602 (QC-02 da P2): ordenar vale para a lista filtrada inteira, não a página.
describe("SchoolPayrollPage — ordenação (#602)", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/escola/payroll?inep=51171805&date=04-2026&secretaria=1");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("a menor base da página 2 sobe para a primeira", async () => {
    const linhas = Array.from({ length: 150 }, (_, i) => ({ nome_profissional: `P${String(i).padStart(3, "0")}`, cpf: `c${i}`,
      categoria: "Docente", carga_horaria: 30, situacao: "Efetivo", salario_base: 5000 - i, salario_total: 6000, mes: "Abril", ano: 2026 }));
    mocks.getSecretariaPayroll.mockResolvedValue(linhas);
    render(SchoolPayrollPage);
    await screen.findByTestId("paginacao-folha");
    expect(screen.queryByText("P149")).toBeNull();
    const { fireEvent } = await import("@testing-library/svelte");
    await fireEvent.click(screen.getByText("Salário Base"));
    expect(screen.getByText("P149")).toBeInTheDocument();
    expect(screen.getByTestId("paginacao-folha")).toHaveTextContent("página 1 de 2");
  });
});

// #610 (QE-01 da P2): a folha de toda a rede municipal no mês, com "Onde".
describe("SchoolPayrollPage — rede municipal (#610)", () => {
  const linha = (i, cod) => ({ nome_profissional: `PESSOA ${i}`, categoria: "Docente", carga_horaria: 30, situacao: "Efetivo",
    salario_base: 3000, salario_total: 4000, mes: "Janeiro", ano: 2026, cod_inep: cod, escola: cod === 99999999 ? "SEC MUN" : "EMEB UM" });
  beforeEach(() => {
    vi.clearAllMocks();
    window.history.replaceState({}, "", "/escola/payroll?inep=51091194&date=01-2026&rede=1");
  });
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("usa a rota da rede, diz onde e filtra pelo lugar", async () => {
    mocks.getRedePayroll.mockResolvedValue([linha(1, 51000001), linha(2, 51000001), linha(3, 99999999)]);
    render(SchoolPayrollPage);
    expect(await screen.findByTestId("aviso-folha-rede")).toHaveTextContent("Neste mês: 2 registros nas escolas e 1 no total da Secretaria.");
    expect(mocks.getRedePayroll).toHaveBeenCalledWith("51091194", "01-2026");
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent("rede municipal (escolas e Secretaria)");
    expect(screen.getByRole("columnheader", { name: /Onde/ })).toBeInTheDocument();
    expect(screen.getByText("Secretaria (sem escola)")).toBeInTheDocument();
    await fireEvent.change(screen.getByTestId("filtro-lugar"), { target: { value: "secretaria" } });
    expect(screen.getByTestId("paginacao-folha")).toHaveTextContent("1 registro · página 1 de 1");
  });
});

// #614 (QF-01 da P2): a folha da rede aberta pelo município
describe("SchoolPayrollPage — rede pelo município (#614)", () => {
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("?codigo_ibge= lista a rede inteira, com o lugar", async () => {
    window.history.replaceState({}, "", "/escola/payroll?codigo_ibge=5103403&date=02-2026");
    mocks.getCityRedePayroll.mockResolvedValue([
      { nome_profissional: "ANA", cod_inep: 51171805, escola: "EMEB A", salario_total: 1000 },
      { nome_profissional: "BIA", cod_inep: 99999999, escola: "SEC MUN", salario_total: 1000 },
    ]);
    render(SchoolPayrollPage);
    expect(await screen.findByText(/Folha de Pagamento – rede municipal/)).toBeInTheDocument();
    expect(mocks.getCityRedePayroll).toHaveBeenCalledWith("5103403", "02-2026");
    expect(screen.getByTestId("aviso-folha-rede")).toBeInTheDocument();
  });

  it("mês sem folha: o link volta ao painel da rede pelo município", async () => {
    window.history.replaceState({}, "", "/escola/payroll?codigo_ibge=5103403&date=11-2026");
    mocks.getCityRedePayroll.mockRejectedValue(new ApiError("Sem folha", { status: 404 }));
    render(SchoolPayrollPage);
    expect(await screen.findByText(/Não há folha da rede municipal neste mês/)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "painel financeiro" })).toHaveAttribute("href", "/municipio/financeiro?codigo_ibge=5103403&ano=2026");
  });
});
