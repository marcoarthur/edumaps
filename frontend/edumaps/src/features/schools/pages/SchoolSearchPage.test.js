// src/features/schools/pages/SchoolSearchPage.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi, beforeEach } from "vitest";
import SchoolSearchPage from "./SchoolSearchPage.svelte";
import { searchSchools } from "../api/schoolApi.js";

vi.mock("../api/schoolApi.js", () => ({
  searchSchools: vi.fn(),
}));

describe("SchoolSearchPage", () => {
  beforeEach(() => vi.clearAllMocks());

  it("busca e lista escolas retornadas pela API", async () => {
    searchSchools.mockResolvedValue([
      {
        escola: "EMEF Paulo Freire",
        codigo_inep: 1,
        municipio: "Ubatuba",
        uf: "SP",
        modalidades: [],
      },
    ]);

    render(SchoolSearchPage);

    await fireEvent.input(screen.getByLabelText(/nome da escola/i), {
      target: { value: "Paulo Freire" },
    });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    await waitFor(() => {
      expect(screen.getByText("EMEF Paulo Freire")).toBeInTheDocument();
    });
    expect(searchSchools).toHaveBeenCalledWith({
      escola: "Paulo Freire",
      municipio: "",
    });
  });

  it("mostra mensagem de erro quando a API falha", async () => {
    searchSchools.mockRejectedValue(new Error("Erro 500"));

    render(SchoolSearchPage);
    await fireEvent.input(screen.getByLabelText(/município/i), {
      target: { value: "Ubatuba" },
    });
    await fireEvent.click(
      screen.getByRole("button", { name: /buscar escolas/i }),
    );

    await waitFor(() => {
      expect(screen.getByText(/erro inesperado/i)).toBeInTheDocument();
    });
  });
});
