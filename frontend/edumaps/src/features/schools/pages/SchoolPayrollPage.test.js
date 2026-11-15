// src/features/schools/pages/SchoolPayrollPage.test.js
// #422: escola sem folha (404) é ausência, não erro.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";

const mocks = vi.hoisted(() => ({ getSchoolPayroll: vi.fn() }));
vi.mock("../api/schoolApi.js", () => ({ getSchoolPayroll: mocks.getSchoolPayroll }));

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
});
