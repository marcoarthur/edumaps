// src/features/schools/pages/SchoolSearchPageRx.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { of, throwError } from "rxjs";
import SchoolSearchPage from "@/features/schools/pages/SchoolSearchPageRx.svelte";
import * as schoolApi from "@/features/schools/api/schoolApi.js";

// Mock do módulo da API de escolas
vi.mock("@/features/schools/api/schoolApi.js", () => ({
  searchPaginatedSchools: vi.fn(),
}));

describe("SchoolSearchPage (Integration Test)", () => {
  const mockSchoolsData = [
    {
      escola: "Escola E.E. Brasil",
      codigo_inep: 123,
      endereco: "Rua das Flores, 123",
      telefone: "12981234567",
      municipio: "Ubatuba",
      uf: "SP",
      osm: "https://www.openstreetmap.org/?mlat=1&mlon=2",
      whatsapp: "https://wa.me/5512981234567",
      modalidades: ["Ensino Fundamental", "EJA"],
      tipo: "Municipal",
    },
    {
      escola: "Colégio Anchieta",
      codigo_inep: 456,
      municipio: "Campinas",
      telefone: "12981234567",
      uf: "SP",
      osm: "https://www.openstreetmap.org/?mlat=1&mlon=2",
      whatsapp: "https://wa.me/5512981234567",
      modalidades: ["Ensino Fundamental", "EJA"],
      tipo: "Municipal",
    },
  ];

  const mockMeta = {
    current_page: 1,
    total_pages: 3,
    per_page: 10,
    total_entries: 25,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("deve exibir a mensagem inicial orientando a busca", () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({ data: [], meta: null }),
    );

    render(SchoolSearchPage);

    expect(
      screen.getByRole("heading", { name: /busca de escolas/i }),
    ).toBeInTheDocument();
    expect(
      screen.getByText(/informe um nome de escola ou município para começar/i),
    ).toBeInTheDocument();
  });

  it("deve realizar uma busca com sucesso e renderizar os cards e controles de paginação", async () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({
        data: mockSchoolsData,
        meta: mockMeta,
      }),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, { target: { value: "Brasil" } });
    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText("Escola E.E. Brasil")).toBeInTheDocument();
      expect(screen.getByText("Colégio Anchieta")).toBeInTheDocument();
    });

    expect(screen.getByText(/página 1 de 3/i)).toBeInTheDocument();
  });

  it("deve navegar para a próxima página ao clicar no botão 'Próxima'", async () => {
    schoolApi.searchPaginatedSchools.mockImplementation((params) => {
      return of({
        data: mockSchoolsData,
        meta: { ...mockMeta, current_page: params.page || 1 },
      });
    });

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, { target: { value: "Brasil" } });
    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText(/página 1 de 3/i)).toBeInTheDocument();
    });

    const nextButton = screen.getByRole("button", { name: /próxima/i });
    await fireEvent.click(nextButton);

    await waitFor(() => {
      expect(schoolApi.searchPaginatedSchools).toHaveBeenLastCalledWith(
        expect.objectContaining({
          page: 2,
          escola: "Brasil", // verifica que o filtro é mantido
        }),
      );
      expect(screen.getByText(/página 2 de 3/i)).toBeInTheDocument();
    });
  });

  it("deve tratar estado de erro retornado pela API", async () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      throwError(() => new Error("Servidor fora do ar")),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, { target: { value: "Brasil" } });
    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText(/servidor fora do ar/i)).toBeInTheDocument();
    });
  });

  it("deve limpar a busca e restaurar o estado inicial ao clicar no botão de limpar", async () => {
    schoolApi.searchPaginatedSchools.mockReturnValue(
      of({ data: mockSchoolsData, meta: mockMeta }),
    );

    render(SchoolSearchPage);

    const schoolInput = screen.getByLabelText(/nome da escola/i);
    const searchButton = screen.getByRole("button", {
      name: /buscar escolas/i,
    });

    await fireEvent.input(schoolInput, { target: { value: "Brasil" } });
    await fireEvent.click(searchButton);

    await waitFor(() => {
      expect(screen.getByText("Escola E.E. Brasil")).toBeInTheDocument();
    });

    const clearButton = screen.getByRole("button", { name: /limpar/i });
    await fireEvent.click(clearButton);

    await waitFor(() => {
      expect(
        screen.getByText(
          /informe um nome de escola ou município para começar/i,
        ),
      ).toBeInTheDocument();
      expect(screen.queryByText("Escola E.E. Brasil")).not.toBeInTheDocument();
    });
  });
});
