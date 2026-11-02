import { describe, it, expect } from "vitest";
import { diaLocal, formatarDia, fusoDoNavegador } from "./dia.js";

describe("dia local do calendário", () => {
  it("usa a data local, não a UTC", () => {
    // 23:30 local de 9/3: em UTC pode já ser 10/3; a chave é a do dia local
    expect(diaLocal(new Date(2001, 2, 9, 23, 30))).toBe("2001-03-09");
    expect(diaLocal(new Date(2001, 2, 10, 0, 0))).toBe("2001-03-10");
  });

  it("formata YYYY-MM-DD sem fuso", () => {
    expect(formatarDia("2026-10-14")).toBe("14/10/2026");
    expect(formatarDia("")).toBe("");
  });

  it("fuso do navegador é uma string IANA", () => {
    expect(typeof fusoDoNavegador()).toBe("string");
  });
});
