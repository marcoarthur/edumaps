// src/features/schools/pages/MunicipioFinanceiroPage.test.js
// #614 (QF-01 da P2): o painel financeiro da rede municipal pelo município.
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { ApiError } from "@/shared/api/client.js";

const mocks = vi.hoisted(() => ({ getCityFinance: vi.fn() }));
vi.mock("../api/schoolApi.js", () => ({ getCityFinance: mocks.getCityFinance }));
vi.mock("@carbon/charts-svelte", async () => {
  const stub = (await import("@/features/network-compare/__tests__/CarbonChartStub.svelte")).default;
  return { LineChart: stub, DonutChart: stub };
});
vi.mock("@/app/router.svelte.js", () => ({ router: { navigate: vi.fn() } }));

import MunicipioFinanceiroPage from "./MunicipioFinanceiroPage.svelte";

const DADOS = (ano) => ({
  origem: "rede", escola: null, municipio: { codigo_ibge: "5103403", nome: "Cuiabá", uf: "MT" },
  municipio_ibge: "5103403", ano, anos: [2026, 2025],
  series: [{ ano, mes: "Janeiro", mes_num: 1, total_salario: 1000, total_profissionais: 10, total_secretaria: 0 }],
  categorias: [{ categoria: "Docente", total_salario: 1000, total_profissionais: 10 }],
  rede: { declaracao: "escola", escolas_com_folha: 167, meses_escola: [1], meses_secretaria: [],
    partes: { escolas: 900, secretaria: 100, fora: 0 } },
  fundeb: null,
});

describe("MunicipioFinanceiroPage (#614)", () => {
  beforeEach(() => vi.clearAllMocks());
  afterEach(() => window.history.replaceState({}, "", "/"));

  it("abre o painel da rede no ano do endereço, com o município e a declaração", async () => {
    window.history.replaceState({}, "", "/municipio/financeiro?codigo_ibge=5103403&ano=2025");
    mocks.getCityFinance.mockResolvedValue(DADOS(2025));
    render(MunicipioFinanceiroPage);
    expect(await screen.findByTestId("municipio-titulo")).toHaveTextContent("Cuiabá (MT) · IBGE 5103403");
    expect(mocks.getCityFinance).toHaveBeenCalledWith("5103403", 2025);
    expect(screen.getByTestId("motivo-rede")).toHaveTextContent(
      "Em 2025, o município declarou a folha por escola em todos os meses (167 escolas). Os números abaixo são de toda a rede municipal: as escolas e o total da Secretaria.");
    expect(screen.queryByText(/não desta escola/)).toBeNull();
    expect(screen.getByRole("link", { name: "← Perfil da rede" })).toHaveAttribute("href", "/municipio/perfil?codigo_ibge=5103403");
  });

  it("trocar o ano põe o ano no endereço", async () => {
    window.history.replaceState({}, "", "/municipio/financeiro?codigo_ibge=5103403");
    mocks.getCityFinance.mockImplementation((_i, a) => Promise.resolve(DADOS(a ?? 2026)));
    render(MunicipioFinanceiroPage);
    const sel = await screen.findByLabelText("Ano da folha");
    expect(window.location.search).toContain("ano=2026");
    await fireEvent.change(sel, { target: { value: "2025" } });
    await waitFor(() => expect(window.location.search).toContain("ano=2025"));
  });

  it("ano sem folha no endereço: abre o mais recente e avisa", async () => {
    window.history.replaceState({}, "", "/municipio/financeiro?codigo_ibge=5103403&ano=2019");
    mocks.getCityFinance.mockImplementation((_i, a) => a === 2019
      ? Promise.reject(new ApiError("Sem folha neste ano", { status: 400 })) : Promise.resolve(DADOS(2026)));
    render(MunicipioFinanceiroPage);
    expect(await screen.findByTestId("aviso-ano")).toHaveTextContent("Não há folha da rede municipal em 2019; abrimos o ano mais recente.");
    expect(window.location.search).toContain("ano=2026");
  });

  it("município sem folha: a mensagem do servidor", async () => {
    window.history.replaceState({}, "", "/municipio/financeiro?codigo_ibge=3550308");
    mocks.getCityFinance.mockRejectedValue(new ApiError("Sem folha do SIOPE carregada para a rede municipal deste município", { status: 404 }));
    render(MunicipioFinanceiroPage);
    expect(await screen.findByRole("alert")).toHaveTextContent("Sem folha do SIOPE carregada");
  });

  it("sem código IBGE válido", async () => {
    window.history.replaceState({}, "", "/municipio/financeiro?codigo_ibge=12");
    render(MunicipioFinanceiroPage);
    expect(await screen.findByRole("alert")).toHaveTextContent("Código IBGE do município não informado");
    expect(mocks.getCityFinance).not.toHaveBeenCalled();
  });
});
