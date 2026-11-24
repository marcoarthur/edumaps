import { describe, it, expect } from "vitest";
import { reaisCurto, fraseFechamento } from "./fechamentoFolha.js";

describe("fechamento da folha (#554)", () => {
  const UBATUBA = { municipio: "Ubatuba", anos: [{ ano: 2026, fechamento: {
    total: 67696409, escolas_base: 55590647, secretaria: 11838003, fora_total: 267757,
    fora: [{ inep: "35659605", escola: "JOSE LIBORIO - SEU FRANCA EM", valor: 267757 }] } }] };

  it("valores curtos", () => {
    expect(reaisCurto(67696409)).toBe("R$ 67,7 mi");
    expect(reaisCurto(267757)).toBe("R$ 267,8 mil");
    expect(reaisCurto(950)).toBe("R$ 950");
  });

  it("as três partes, com a escola fora da lista", () => {
    expect(fraseFechamento(UBATUBA, 2026, 2025)).toBe(
      "Ubatuba: R$ 67,7 mi declarados em 2026. Nas escolas desta base, R$ 55,6 mi; da Secretaria, sem escola, R$ 11,8 mi; "
      + "em 1 escola fora da lista do Censo 2025 (35659605, JOSE LIBORIO - SEU FRANCA EM), R$ 267,8 mil.");
  });

  it("só a Secretaria", () => {
    const m = { municipio: "Taubaté", anos: [{ ano: 2026, fechamento: { total: 163254335, escolas_base: 0, secretaria: 163254335, fora_total: 0, fora: [] } }] };
    expect(fraseFechamento(m, 2026, 2025)).toBe("Taubaté: R$ 163,3 mi declarados em 2026. Da Secretaria, sem escola, R$ 163,3 mi.");
  });

  it("sem folha no ano: nada", () => {
    expect(fraseFechamento(UBATUBA, 2025, 2025)).toBeNull();
  });
});
