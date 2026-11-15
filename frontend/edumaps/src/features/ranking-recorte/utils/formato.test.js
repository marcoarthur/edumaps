import { describe, it, expect } from "vitest";
import { num, variacao, contexto, csv } from "./formato.js";
import { ufDoMunicipio } from "../constants.js";

describe("formato do ranking (#430)", () => {
  it("números, variação e ausência", () => {
    expect(num(7.645)).toBe("7,65");
    expect(num(null)).toBe("–");
    expect(variacao(0.84)).toBe("+0,84");
    expect(variacao(-0.3)).toBe("−0,3");
    expect(variacao(null)).toBe("–");
  });
  it("contexto pelo quinto de INSE", () => {
    expect(contexto({ media: 7, media_quinto_inse: 6 })).toBe("1 acima dos de INSE parecido");
    expect(contexto({ media: 6.02, media_quinto_inse: 6 })).toBe("na média dos de INSE parecido");
    expect(contexto({ media: 6, media_quinto_inse: null })).toBe("–");
  });
  it("CSV com ; BOM, vírgula decimal e aspas", () => {
    const t = csv(["a", "b"], [["x;y", 1.5], [null, 2]]);
    expect(t).toBe('﻿a;b\r\n"x;y";1,5\r\n;2\r\n');
  });
  it("UF pelo código do município", () => {
    expect(ufDoMunicipio("3205309")).toBe("ES");
    expect(ufDoMunicipio("")).toBeNull();
  });
});
