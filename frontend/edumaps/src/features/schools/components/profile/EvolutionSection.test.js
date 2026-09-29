import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/svelte";
import EvolutionSection from "./EvolutionSection.svelte";
import { transformEvolutionData } from "../../utils/transformEvolutionData.js";
import { EVOLUTION_FIXTURE } from "../../mocks/fixtures.js";

function groups() {
  return transformEvolutionData(EVOLUTION_FIXTURE).groups;
}

describe("EvolutionSection", () => {
  it("renderiza uma série por indicador/etapa com os anos", () => {
    render(EvolutionSection, { groups: groups() });

    expect(screen.getByText("Evolução")).toBeInTheDocument();
    expect(screen.getAllByText("IDEB observado").length).toBeGreaterThan(0);
    expect(screen.getByText("Anos Finais")).toBeInTheDocument();
    expect(screen.getAllByText("2019").length).toBeGreaterThan(0);
    expect(screen.getAllByText("2023").length).toBeGreaterThan(0);
  });

  it("mostra estado vazio quando não há série", () => {
    render(EvolutionSection, { groups: [] });

    expect(
      screen.getByText(/Sem histórico disponível para esta escola/),
    ).toBeInTheDocument();
  });
});
