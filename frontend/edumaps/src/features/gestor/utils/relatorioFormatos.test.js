// src/features/gestor/utils/relatorioFormatos.test.js
import { describe, it, expect } from "vitest";
import {
  formatarValor,
  ehNumerico,
  regiaoSigla,
  codigoMunicipio,
  valoresOpcao,
} from "./relatorioFormatos.js";
import { dadosGrafico, descricaoGrafico } from "./relatorioGrafico.js";

describe("formatarValor (pt-BR)", () => {
  it.each([
    [12345, "inteiro", "12.345"],
    [1234.6, "inteiro", "1.235"],
    [6.1, "decimal1", "6,1"],
    [6, "decimal1", "6,0"],
    [5.876, "decimal2", "5,88"],
    [1234.5, "decimal2", "1.234,50"],
    [0.934, "percentual", "93,4%"],
    [0.5, "percentual", "50%"],
    ["Municipal", "texto", "Municipal"],
    [2023, "texto", "2023"],
    [1.239, undefined, "1,24"],
  ])("%s em %s → %s", (valor, formato, esperado) => {
    expect(formatarValor(valor, formato).replace(/ /g, " ")).toBe(esperado);
  });

  it("ausente vira travessão", () => {
    expect(formatarValor(null, "inteiro")).toBe("—");
    expect(formatarValor(undefined, "texto")).toBe("—");
    expect(formatarValor("", "decimal1")).toBe("—");
  });

  it("valor não numérico em formato numérico sai como veio", () => {
    expect(formatarValor("n/d", "decimal1")).toBe("n/d");
  });

  it("aceita número em string", () => {
    expect(formatarValor("6.1", "decimal1")).toBe("6,1");
  });

  it("só texto alinha à esquerda", () => {
    expect(ehNumerico("texto")).toBe(false);
    expect(ehNumerico("inteiro")).toBe(true);
  });
});

describe("recorte", () => {
  it("converte co_regiao 1..5 para a sigla do geotag", () => {
    expect([1, 2, 3, 4, 5].map(regiaoSigla)).toEqual(["N", "NE", "SE", "S", "CO"]);
    expect(regiaoSigla("3")).toBe("SE");
    expect(regiaoSigla(9)).toBeNull();
  });

  it("município como string de 7 dígitos", () => {
    expect(codigoMunicipio(1200401)).toBe("1200401");
    expect(codigoMunicipio(120040)).toBe("0120040");
    expect(codigoMunicipio(null)).toBeNull();
  });

  it("valoresOpcao aceita strings e objetos", () => {
    expect(valoresOpcao(["fundamental_i", "Municipal"])).toEqual([
      { valor: "fundamental_i", rotulo: "Ensino fundamental — anos iniciais" },
      { valor: "Municipal", rotulo: "Municipal" },
    ]);
    expect(valoresOpcao([{ id: "x", rotulo: "X" }])).toEqual([{ valor: "x", rotulo: "X" }]);
    expect(valoresOpcao(undefined)).toEqual([]);
  });
});

describe("gráfico", () => {
  const secao = {
    titulo: "IDEB",
    grafico: "barras",
    x: { id: "ano", rotulo: "Ano" },
    series: [
      { id: "a", rotulo: "Cidade" },
      { id: "b", rotulo: "UF" },
    ],
    dados: [
      { ano: 2021, a: 5, b: 5.5 },
      { ano: 2023, a: 5.6, b: null },
    ],
  };

  it("converte para {group, key, value} e descarta ausentes", () => {
    expect(dadosGrafico(secao)).toEqual([
      { group: "Cidade", key: "2021", value: 5 },
      { group: "Cidade", key: "2023", value: 5.6 },
      { group: "UF", key: "2021", value: 5.5 },
    ]);
  });

  it("descreve o gráfico em texto", () => {
    const d = descricaoGrafico(secao, formatarValor);
    expect(d).toContain('Gráfico de barras "IDEB" por Ano');
    expect(d).toContain("Cidade — 2021: 5; 2023: 5,6");
    expect(d).toContain("UF — 2021: 5,5; 2023: —");
    expect(descricaoGrafico({ ...secao, grafico: "linhas" }, formatarValor)).toMatch(/^Gráfico de linhas/);
  });
});
