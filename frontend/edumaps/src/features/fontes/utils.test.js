import { describe, it, expect } from "vitest";
import { listaMeses, sufixoIncompletos } from "./utils.js";

describe("meses incompletos da folha (#557)", () => {
  const SET = { nome: "setembro" };
  const OUT = { nome: "outubro" };
  it("lista em português", () => {
    expect(listaMeses([SET])).toBe("setembro");
    expect(listaMeses([SET, OUT])).toBe("setembro e outubro");
    expect(listaMeses([{ nome: "maio" }, SET, OUT])).toBe("maio, setembro e outubro");
    expect(listaMeses([])).toBe("");
  });
  it("sufixo da cobertura", () => {
    expect(sufixoIncompletos([SET, OUT])).toBe(" (setembro e outubro incompletos)");
    expect(sufixoIncompletos([SET])).toBe(" (setembro incompleto)");
    expect(sufixoIncompletos(undefined)).toBe("");
  });
});
