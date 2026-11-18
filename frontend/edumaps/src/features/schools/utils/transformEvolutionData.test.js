import { describe, it, expect } from "vitest";
import {
  groupEvolution,
  transformEvolutionData,
  formatEvolutionValue,
} from "./transformEvolutionData.js";
import { EVOLUTION_FIXTURE } from "../mocks/fixtures.js";

describe("transformEvolutionData", () => {
  it("agrupa por (indicador, etapa) e ordena os pontos por ano", () => {
    const groups = groupEvolution([
      { indicador: "ideb_observado", label: "IDEB", etapa: "fundamental_ii", ano: 2023, valor: 4.9 },
      { indicador: "ideb_observado", label: "IDEB", etapa: "fundamental_ii", ano: 2019, valor: 4.7 },
    ]);

    expect(groups).toHaveLength(1);
    expect(groups[0].pontos.map((p) => p.ano)).toEqual([2019, 2023]);
    expect(groups[0].etapaLabel).toBe("Anos Finais");
  });

  it("transforma o payload e anexa a variação do resumo", () => {
    const evo = transformEvolutionData(EVOLUTION_FIXTURE);

    expect(evo.groups).toHaveLength(2);
    const ideb = evo.groups.find((g) => g.indicador === "ideb_observado");
    expect(ideb.variacao).toBeCloseTo(0.2);
    const saeb = evo.groups.find((g) => g.indicador === "saeb_media");
    expect(saeb.variacao).toBeCloseTo(-0.4);
    expect(saeb.etapaLabel).toBeNull();
  });

  it("normaliza série vazia", () => {
    const evo = transformEvolutionData({ data: [], tables: { resumo: [] }, metadata: {} });
    expect(evo.groups).toEqual([]);
  });

  it("formatEvolutionValue", () => {
    expect(formatEvolutionValue(4.74)).toBe("4.7");
    expect(formatEvolutionValue(null)).toBe("–");
  });
});

describe("evolução: SAEB por etapa e sem variação com uma edição (#485)", () => {
  it("agrupa o SAEB por etapa e deixa a variação nula quando o resumo não a tem", () => {
    const series = [
      { indicador: "saeb_matematica", label: "Matemática (SAEB)", ano: 2021, etapa: "fundamental_ii", valor: 238 },
      { indicador: "saeb_matematica", label: "Matemática (SAEB)", ano: 2023, etapa: "fundamental_ii", valor: 237 },
      { indicador: "saeb_matematica", label: "Matemática (SAEB)", ano: 2023, etapa: "ensino_medio", valor: 242 },
    ];
    const resumo = [
      { indicador: "saeb_matematica", etapa: "fundamental_ii", variacao: -1 },
      { indicador: "saeb_matematica", etapa: "ensino_medio", variacao: null },
    ];
    const g = groupEvolution(series, resumo);
    expect(g.map((x) => x.etapaLabel)).toEqual(["Ensino Médio", "Anos Finais"]);
    expect(g.find((x) => x.etapa === "ensino_medio").variacao).toBeNull();
    expect(g.find((x) => x.etapa === "fundamental_ii").variacao).toBe(-1);
  });
});
