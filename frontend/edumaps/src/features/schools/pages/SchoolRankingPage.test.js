// src/features/schools/pages/SchoolRankingPage.test.js
import { render, screen, waitFor, fireEvent } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import SchoolRankingPage from "./SchoolRankingPage.svelte";
import { getSchoolInfo } from "../api/schoolApi.js";
import { getAvailableIndicators, getSchoolRanking } from "../api/rankingApi.js";
import { router } from "@/app/router.svelte.js";

vi.mock("../api/schoolApi.js", () => ({
  getSchoolInfo: vi.fn(),
}));

vi.mock("../api/rankingApi.js", () => ({
  getAvailableIndicators: vi.fn(),
  getSchoolRanking: vi.fn(),
}));

vi.mock("@/app/router.svelte.js", () => ({
  router: {
    navigate: vi.fn(),
    path: "/escola/ranking",
  },
}));

const mockSchoolData = {
  codigo_inep: 35011162,
  escola: "EE Professor João",
  municipio: "Ubatuba",
  uf: "SP",
  endereco: "Rua das Flores, 100",
  telefone: "123456789",
  tipo: "Estadual",
  modalidades: ["Ensino Médio", "Ensino Fundamental"],
  osm: "https://www.openstreetmap.org/",
};

const mockIndicators = [
  { id: "ideb_anos_finais", label: "IDEB – Anos Finais", available: true },
  { id: "infraestrutura", label: "Infraestrutura", available: true },
];

const mockRanking = {
  indicador: {
    id: "ideb_anos_finais",
    label: "IDEB – Anos Finais",
    valor: 6.8,
  },
  ano: 2023,
  rede: null,
  ranking: {
    municipio: { posicao: 2, total: 40, percentil: 95 },
    estado: { posicao: 15, total: 900, percentil: 85 },
    nacional: null,
  },
};

describe("SchoolRankingPage", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete window.location;
    window.location = new URL("http://localhost/escola/ranking");
  });

  afterEach(() => {
    vi.resetAllMocks();
  });

  it("exibe estado de carregamento enquanto busca a escola", async () => {
    getSchoolInfo.mockImplementation(() => new Promise(() => {}));
    render(SchoolRankingPage);
    expect(
      screen.getByText(/Carregando dados da escola.../i),
    ).toBeInTheDocument();
  });

  it("carrega e exibe as informações da escola e o componente de ranking", async () => {
    getSchoolInfo.mockResolvedValue(mockSchoolData);
    getAvailableIndicators.mockResolvedValue(mockIndicators);
    getSchoolRanking.mockResolvedValue(mockRanking);

    render(SchoolRankingPage);

    await waitFor(() => {
      expect(screen.getByText("EE Professor João")).toBeInTheDocument();
    });

    // Detalhes da escola
    expect(screen.getByText(/Código INEP:/i)).toBeInTheDocument();
    expect(screen.getByText("35011162")).toBeInTheDocument();
    expect(screen.getByText(/Município:/i)).toBeInTheDocument();
    expect(screen.getByText("Ubatuba - SP")).toBeInTheDocument();
    expect(screen.getByText(/Endereço:/i)).toBeInTheDocument();
    expect(screen.getByText("Rua das Flores, 100")).toBeInTheDocument();
    expect(screen.getByText(/Telefone:/i)).toBeInTheDocument();
    expect(screen.getByText("123456789")).toBeInTheDocument();
    expect(screen.getByText("Estadual")).toBeInTheDocument();
    expect(screen.getByText("Ensino Médio")).toBeInTheDocument();
    expect(screen.getByText("Ensino Fundamental")).toBeInTheDocument();

    expect(screen.getByText(/Ver no OpenStreetMap/i)).toHaveAttribute(
      "href",
      mockSchoolData.osm,
    );

    // Verifica o componente de ranking: título "Ranking" e seletor de indicador
    await waitFor(() => {
      // Usa role heading para evitar múltiplos matches
      expect(
        screen.getByRole("heading", { name: "Ranking" }),
      ).toBeInTheDocument();
      expect(screen.getByLabelText(/Indicador:/i)).toBeInTheDocument();
    });
  });

  it("exibe mensagem de erro quando a API falha", async () => {
    const consoleSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    const errorMessage = "Erro ao buscar escola";
    getSchoolInfo.mockRejectedValue(new Error(errorMessage));

    render(SchoolRankingPage);

    await waitFor(() => {
      expect(screen.getByText(/Erro ao carregar escola/i)).toBeInTheDocument();
      expect(screen.getByText(errorMessage)).toBeInTheDocument();
    });
  });

  it("lê o parâmetro `inep` da query string e carrega a escola correspondente", async () => {
    window.location = new URL("http://localhost/escola/ranking?inep=99999999");
    getSchoolInfo.mockResolvedValue({
      ...mockSchoolData,
      codigo_inep: 99999999,
    });

    render(SchoolRankingPage);

    await waitFor(() => {
      expect(getSchoolInfo).toHaveBeenCalledWith(99999999);
    });
    expect(screen.getByText("99999999")).toBeInTheDocument();
  });

  it("navega para a busca quando clica em 'Voltar para busca'", async () => {
    getSchoolInfo.mockResolvedValue(mockSchoolData);
    render(SchoolRankingPage);

    await waitFor(() => {
      expect(screen.getByText("EE Professor João")).toBeInTheDocument();
    });

    const backButton = screen.getByRole("button", {
      name: /Voltar para busca/i,
    });
    await fireEvent.click(backButton);
    expect(router.navigate).toHaveBeenCalledWith("/busca");
  });
});
