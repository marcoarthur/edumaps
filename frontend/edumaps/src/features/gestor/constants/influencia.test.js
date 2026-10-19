import { describe, it, expect } from "vitest";
import {
  radiusLabel,
  radiusColor,
  radiusPurpose,
  formatCount,
  formatDensity,
  formatAreaKm2,
  formatComputedAt,
  ringCartela,
  entornoLabel,
  INFLUENCIA_RADII,
} from "./influencia.js";

describe("constantes da área de influência", () => {
  it("define os três raios canônicos da metodologia", () => {
    expect(INFLUENCIA_RADII).toEqual([500, 1000, 2000]);
  });

  it("rótulo do raio em m ou km", () => {
    expect(radiusLabel(500)).toBe("500 m");
    expect(radiusLabel(1000)).toBe("1 km");
    expect(radiusLabel(2000)).toBe("2 km");
    expect(radiusLabel(null)).toBe("—");
  });

  it("cor estável por raio, com fallback", () => {
    expect(radiusColor(500)).toBe("#1d4ed8");
    expect(radiusColor(999)).toBe("#64748b");
  });

  it("propósito do raio, com default", () => {
    expect(radiusPurpose(500)).toMatch(/Equipamentos/);
    expect(radiusPurpose(4)).toMatch(/Área de influência/);
  });

  it("formata área em km² no padrão pt-BR", () => {
    expect(formatAreaKm2(0.7854)).toBe("0,7854 km²");
    expect(formatAreaKm2(3.1415)).toBe("3,1415 km²");
    expect(formatAreaKm2(undefined)).toBe("—");
  });

  it("formata o carimbo de cálculo", () => {
    expect(formatComputedAt(null)).toBeNull();
    expect(formatComputedAt("2025-01-02T12:30:00Z")).not.toBeNull();
  });

  it("formata contagem e densidade, degradando sem dado (#154)", () => {
    expect(formatCount(20039)).toBe("20.039");
    expect(formatCount(null)).toBe("—");
    expect(formatCount(undefined)).toBe("—");
    expect(formatDensity(6867.39)).toBe("6.867");
    expect(formatDensity(7.6)).toBe("7,6");
    expect(formatDensity(null)).toBe("—");
  });

  it("monta a leitura do entorno (população · densidade) ou '—'", () => {
    expect(entornoLabel({ pop_total: 20039, densidade_pop_km2: 6416.18 })).toBe(
      "20.039 hab · 6.416 hab/km²",
    );
    expect(entornoLabel({ pop_total: null, densidade_pop_km2: null })).toBe("—");
    expect(entornoLabel({ densidade_pop_km2: 7.6 })).toBe("7,6 hab/km²");
    expect(entornoLabel(null)).toBe("—");
  });

  it("monta a cartela do anel com a leitura do entorno", () => {
    const cartela = ringCartela({
      raio_m: 1000,
      area_km2: 3.1415,
      entorno: { pop_total: 20039, densidade_pop_km2: 6416.18 },
    });
    expect(cartela).toEqual({
      label: "1 km",
      entorno: "20.039 hab · 6.416 hab/km²",
      area: "3,1415 km²",
      color: "#0891b2",
    });
  });

  it("degrada a cartela para raio desconhecido e sem leitura", () => {
    const cartela = ringCartela({});
    expect(cartela.label).toBe("—");
    expect(cartela.entorno).toBe("—");
    expect(cartela.area).toBe("—");
    expect(cartela.color).toBe("#64748b");
  });
});
