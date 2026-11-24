// src/features/schools/pages/SchoolPayrollPage.test.js
// #422: escola sem folha (404) é ausência, não erro.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";

const mocks = vi.hoisted(() => ({ getSchoolPayroll: vi.fn(), getSecretariaPayroll: vi.fn() }));
vi.mock("../api/schoolApi.js", () => ({ getSchoolPayroll: mocks.getSchoolPayroll, getSecretariaPayroll: mocks.getSecretariaPayroll }));

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
