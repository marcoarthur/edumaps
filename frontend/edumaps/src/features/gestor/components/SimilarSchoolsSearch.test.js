// src/features/gestor/components/SimilarSchoolsSearch.test.js
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte";
import { describe, it, expect, vi } from "vitest";
import SimilarSchoolsSearch from "./SimilarSchoolsSearch.svelte";
import { getSchoolSimilares } from "../api/gestorApi.js";

vi.mock("../api/gestorApi.js", () => ({ getSchoolSimilares: vi.fn() }));

vi.mock("@/features/map/components/LeafletMap.svelte", async () => {
  const { default: Stub } = await import("./__tests__/LeafletMapStub.svelte");
  return { default: Stub };
});

const RESULTADO = {
  escola_alvo: {
    id_escola: 11000040,
    nome: "EMEIEF PEQUENOS TALENTOS",
    municipio: "Porto Velho",
    uf: "RO",
    porte_escola: "Entre 201 e 500 matrículas de escolarização",
    localizacao: "Urbana",
    media_inse: 4.86,
    latitude: -8.76,
    longitude: -63.9,
  },
  scope: "municipio",
  limit: 10,
  similares: [
    {
      id_escola: 11048549,
      nome: "EMEIEF KHRYS DAMARIS",
      municipio: "Porto Velho",
      uf: "RO",
      porte_escola: "Entre 51 e 200 matrículas de escolarização",
      localizacao: "Urbana",
      media_inse: null,
      etapas: "Pré-escola",
      latitude: -8.776,
      longitude: -63.901,
      similarity: 0.9921,
    },
    {
      id_escola: 11000660,
      nome: "EMEIEF BOM PRINCIPIO",
      municipio: "Porto Velho",
      uf: "RO",
      porte_escola: "Entre 501 e 1000 matrículas de escolarização",
      localizacao: "Rural",
      media_inse: 4.81,
      etapas: "Pré-escola, Fundamental (Anos Iniciais)",
      latitude: null,
      longitude: null,
      similarity: 0.8461,
    },
  ],
};

describe("SimilarSchoolsSearch", () => {
  it("busca por padrão no município e lista as escolas em ordem", async () => {
    getSchoolSimilares.mockResolvedValue(RESULTADO);
    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    const botao = screen.getByRole("button", { name: /Buscar escolas similares/ });
    await fireEvent.click(botao);

    await waitFor(() => {
      expect(getSchoolSimilares).toHaveBeenCalledWith("11000040", {
        scope: "municipio",
        limit: 10,
      });
    });

    expect(await screen.findByText("EMEIEF KHRYS DAMARIS")).toBeInTheDocument();
    expect(screen.getByText("EMEIEF BOM PRINCIPIO")).toBeInTheDocument();
  });

  it("aplica o escopo selecionado e refaz a busca ao trocar", async () => {
    getSchoolSimilares
      .mockResolvedValueOnce(RESULTADO)
      .mockResolvedValueOnce({ ...RESULTADO, scope: "estado" });

    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    await fireEvent.click(screen.getByRole("button", { name: /Buscar escolas similares/ }));
    await screen.findByText("EMEIEF KHRYS DAMARIS");

    await fireEvent.change(screen.getByLabelText(/Escopo/), { target: { value: "estado" } });

    await waitFor(() => {
      expect(getSchoolSimilares).toHaveBeenCalledWith("11000040", {
        scope: "estado",
        limit: 10,
      });
    });
  });

  it("renderiza dados dos resultados: INSE ausente, porte curto e % de similaridade", async () => {
    getSchoolSimilares.mockResolvedValue(RESULTADO);
    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    await fireEvent.click(screen.getByRole("button", { name: /Buscar escolas similares/ }));

    expect(await screen.findByText("51–200")).toBeInTheDocument();
    expect(screen.getByText("501–1000")).toBeInTheDocument();
    expect(screen.getAllByText("—").length).toBeGreaterThan(0);
    expect(screen.getByText("99%")).toBeInTheDocument();
    expect(screen.getByText("85%")).toBeInTheDocument();
  });

  it("cada escola linka para o painel da escola", async () => {
    getSchoolSimilares.mockResolvedValue(RESULTADO);
    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    await fireEvent.click(screen.getByRole("button", { name: /Buscar escolas similares/ }));

    const link = await screen.findByRole("link", { name: "EMEIEF KHRYS DAMARIS" });
    expect(link).toHaveAttribute("href", "/escola/panel?inep=11048549");
  });

  it("exibe erro da API quando a busca falha", async () => {
    getSchoolSimilares.mockRejectedValue(new Error("boom"));
    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    await fireEvent.click(screen.getByRole("button", { name: /Buscar escolas similares/ }));

    expect(await screen.findByText(/Erro ao buscar escolas similares/)).toBeInTheDocument();
  });

  it("mostra mensagem quando não há escolas similares", async () => {
    getSchoolSimilares.mockResolvedValue({ ...RESULTADO, similares: [] });
    render(SimilarSchoolsSearch, { props: { inep: "11000040" } });

    await fireEvent.click(screen.getByRole("button", { name: /Buscar escolas similares/ }));

    expect(await screen.findByText(/Nenhuma escola semelhante/)).toBeInTheDocument();
  });
});