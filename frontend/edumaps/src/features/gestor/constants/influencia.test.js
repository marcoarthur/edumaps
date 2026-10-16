import { describe, it, expect } from "vitest";
import {
  radiusLabel,
  radiusColor,
  radiusPurpose,
  formatAreaKm2,
  formatComputedAt,
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
});
