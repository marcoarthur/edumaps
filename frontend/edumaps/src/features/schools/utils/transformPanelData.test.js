// src/features/schools/utils/transformPanelData.test.js
import { describe, it, expect } from "vitest";
import { transformPanelData } from "./transformPanelData.js";

const API = {
  escola: {
    id_escola: "1",
    no_entidade: "Escola X",
    municipio: "Ubatuba",
    uf: "SP",
    rede: "Municipal",
    matriculas: 100,
    latitude: null,
    longitude: null,
    etapas: ["fundamental_ii"],
    infraestrutura: ["internet"],
  },
  indicators: {},
  similar_schools: [],
  desempenho: [
    {
      ano: "2021",
      etapa: "fundamental_ii",
      ideb_observado: "5.2",
      nota_media: "6.1",
    },
    {
      ano: "2023",
      etapa: "fundamental_ii",
      ideb_observado: null,
      nota_media: "5.0",
    },
  ],
};

describe("transformPanelData", () => {
  it("normaliza a série de desempenho (ano/ideb como número)", () => {
    const { desempenho } = transformPanelData(API);

    expect(desempenho).toEqual([
      { ano: 2021, etapa: "fundamental_ii", ideb_observado: 5.2 },
      { ano: 2023, etapa: "fundamental_ii", ideb_observado: null },
    ]);
  });

  it("retorna lista vazia quando a API não traz desempenho", () => {
    const { desempenho } = transformPanelData({ ...API, desempenho: undefined });
    expect(desempenho).toEqual([]);
  });
});
