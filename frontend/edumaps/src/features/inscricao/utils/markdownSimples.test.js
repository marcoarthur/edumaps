// src/features/inscricao/utils/markdownSimples.test.js
import { describe, it, expect } from "vitest";
import { markdownSimples, trechos } from "./markdownSimples.js";

describe("markdownSimples", () => {
  it("separa parágrafos, listas e títulos", () => {
    const blocos = markdownSimples("# Termo\n\nPrimeira linha\ncontinua.\n\n- um\n- **dois**\n\n1. a\n2. b");
    expect(blocos.map((b) => b.tipo)).toEqual(["h", "p", "ul", "ol"]);
    expect(blocos[1].trechos).toEqual([{ texto: "Primeira linha continua.", negrito: false }]);
    expect(blocos[2].itens[1]).toEqual([{ texto: "dois", negrito: true }]);
    expect(blocos[3].itens).toHaveLength(2);
  });

  it("marca negrito no meio do texto", () => {
    expect(trechos("a **b** c")).toEqual([
      { texto: "a ", negrito: false },
      { texto: "b", negrito: true },
      { texto: " c", negrito: false },
    ]);
  });

  it("mantém HTML como texto puro (sem interpretar)", () => {
    const [p] = markdownSimples("<img src=x onerror=alert(1)>");
    expect(p).toEqual({ tipo: "p", trechos: [{ texto: "<img src=x onerror=alert(1)>", negrito: false }] });
  });

  it("aceita texto vazio ou nulo", () => {
    expect(markdownSimples("")).toEqual([]);
    expect(markdownSimples(null)).toEqual([]);
  });
});
