import { describe, it, expect } from "vitest";
import { categoryLabel, categoryColor, formatCategory } from "./osm.js";

describe("constants/osm", () => {
  it("traduz as categorias do catálogo curado para PT", () => {
    expect(categoryLabel("amenity=bus_station")).toBe("Terminal de ônibus");
    expect(categoryLabel("highway=bus_stop")).toBe("Ponto de ônibus");
    expect(categoryLabel("leisure=pitch")).toBe("Quadra");
    expect(categoryLabel("amenity=library")).toBe("Biblioteca");
    expect(categoryLabel("healthcare=physiotherapist")).toBe("Serviço de saúde");
    expect(categoryLabel(null)).toBe("Outros");
  });

  it("usa o formato bruto como fallback de categoria desconhecida", () => {
    expect(formatCategory("amenity=some_thing")).toBe("amenity: some thing");
    expect(categoryLabel("amenity=some_thing")).toBe("amenity: some thing");
  });

  it("dá uma cor estável por categoria", () => {
    expect(categoryColor("leisure=pitch")).toBe(categoryColor("leisure=pitch"));
    expect(categoryColor("leisure=pitch")).toMatch(/^#[0-9a-f]{6}$/i);
  });
});
