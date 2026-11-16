import { describe, it, expect } from "vitest";
import { rotuloRecorte, tabelaRedes, tabelaEscolas } from "./exportar.js";
import { REDES_FIXTURE, ESCOLAS_FIXTURE } from "../mocks/fixtures.js";

describe("CSVs do ranking com o recorte em toda linha (#448)", () => {
  it("rótulo do recorte vem da resposta", () => {
    expect(rotuloRecorte({ uf: "ES" })).toBe("UF:ES");
    expect(rotuloRecorte({ regiao: { id: "NE", nome: "Nordeste" }, porte: "10_20mil" })).toBe("regiao:NE");
    expect(rotuloRecorte({ nacional: true })).toBe("BR");
  });

  it("redes: recorte, porte filtrado e mínimo no fim de cada linha", () => {
    const r = { ...REDES_FIXTURE, recorte: { regiao: { id: "NE", nome: "Nordeste" }, porte: "10_20mil" }, minimo_escolas: 5 };
    const t = tabelaRedes(r, r.redes);
    expect(t.cabecalho.slice(-3)).toEqual(["recorte", "porte_filtro", "minimo_escolas"]);
    expect(t.linhas).toHaveLength(3);
    for (const l of t.linhas) expect(l.slice(-3)).toEqual(["regiao:NE", "10_20mil", 5]);
  });

  it("redes de uma UF sem porte: porte_filtro vazio", () => {
    const t = tabelaRedes(REDES_FIXTURE, REDES_FIXTURE.redes);
    expect(t.linhas[0].slice(-3)).toEqual(["UF:ES", "", 3]);
  });

  it("escolas: município e rede filtrada em cada linha", () => {
    const t = tabelaEscolas(ESCOLAS_FIXTURE, ESCOLAS_FIXTURE.escolas);
    expect(t.cabecalho.slice(-4)).toEqual(["codigo_ibge", "municipio", "uf", "rede_filtro"]);
    expect(t.linhas[1].slice(-4)).toEqual(["3205309", "Vitória", "ES", "municipal"]);
    expect(tabelaEscolas({ ...ESCOLAS_FIXTURE, rede: null }, ESCOLAS_FIXTURE.escolas).linhas[0].at(-1)).toBe("");
  });
});
