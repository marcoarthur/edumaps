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

  it("redes: as duas posições, com nome (#453)", () => {
    const t = tabelaRedes(REDES_FIXTURE, REDES_FIXTURE.redes);
    expect(t.cabecalho.slice(0, 3)).toEqual(["posicao_valor", "posicao_variacao", "codigo_ibge"]);
    expect(t.linhas[1].slice(0, 3)).toEqual([2, 1, "3203304"]);
    expect(t.linhas[0].slice(0, 2)).toEqual([1, null]);
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

  it("escolas, infraestrutura básica: coluna faltam (#457)", () => {
    const e = { ...ESCOLAS_FIXTURE, indicador: { id: "infraestrutura_basica", label: "Infraestrutura básica", maximo: 4 } };
    const lista = [
      { ...ESCOLAS_FIXTURE.escolas[0], valor: 1, faltam: ["água", "energia", "esgoto"] },
      { ...ESCOLAS_FIXTURE.escolas[1], valor: 4, faltam: [] },
    ];
    const t = tabelaEscolas(e, lista);
    expect(t.cabecalho.slice(4, 7)).toEqual(["infraestrutura_basica_2023", "faltam", "inse"]);
    expect(t.linhas.map((l) => l[5])).toEqual(["água, energia, esgoto", ""]);
    expect(tabelaEscolas(ESCOLAS_FIXTURE, ESCOLAS_FIXTURE.escolas).cabecalho).not.toContain("faltam");
  });

  it("escolas, índice do EduMaps: versao_indice em toda linha (#462)", () => {
    const e = { ...ESCOLAS_FIXTURE, indicador: { id: "diversidade_discente", label: "Diversidade Discente", versao: "indices-v2" } };
    const t = tabelaEscolas(e, ESCOLAS_FIXTURE.escolas);
    expect(t.cabecalho.at(-1)).toBe("versao_indice");
    for (const l of t.linhas) expect(l.at(-1)).toBe("indices-v2");
    expect(tabelaEscolas(ESCOLAS_FIXTURE, ESCOLAS_FIXTURE.escolas).cabecalho).not.toContain("versao_indice");
  });
});
