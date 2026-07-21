// src/shared/utils/format.test.js
import { describe, it, expect } from "vitest";
import { formatPhone } from "./format.js";

describe("formatPhone", () => {
  it("formata telefone celular (11 dígitos)", () => {
    expect(formatPhone("12981234567")).toBe("(12) 98123-4567");
  });

  it("formata telefone fixo (10 dígitos)", () => {
    expect(formatPhone("1234567890")).toBe("(12) 3456-7890");
  });

  it("retorna null quando não há telefone", () => {
    expect(formatPhone(null)).toBeNull();
    expect(formatPhone("")).toBeNull();
  });

  it("retorna o valor original se não bater com padrões conhecidos", () => {
    expect(formatPhone("123")).toBe("123");
  });
});
