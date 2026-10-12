// src/features/gestor/utils/relatorioCapitulos.test.js
import { describe, it, expect } from "vitest";
import { agruparPorCapitulo, ancoraCapitulo } from "./relatorioCapitulos.js";
import { RELATORIO_EDA_FIXTURE, RELATORIO_RESULT_FIXTURE } from "../mocks/relatoriosFixtures.js";

describe("agruparPorCapitulo", () => {
  it("sem capítulos devolve null (relatório por tema)", () => {
    expect(agruparPorCapitulo(RELATORIO_RESULT_FIXTURE)).toBeNull();
    expect(agruparPorCapitulo({ capitulos: [], secoes: [] })).toBeNull();
    expect(agruparPorCapitulo(null)).toBeNull();
  });

  it("agrupa a EDA: resumo antes, capítulos em ordem, leitura depois", () => {
    const g = agruparPorCapitulo(RELATORIO_EDA_FIXTURE);
    expect(g.antes.map((s) => s.id)).toEqual(["resumo"]);
    expect(g.depois.map((s) => s.id)).toEqual(["leitura"]);
    expect(g.capitulos.map((c) => [c.id, c.titulo, c.secoes.map((s) => s.titulo)])).toEqual([
      ["ideb", "IDEB do município", ["Indicadores principais", "IDEB ao longo do tempo"]],
      ["escolas", "Escolas do município pelo IDEB", ["Visão geral das escolas"]],
    ]);
  });

  it("resumo e leitura vão às pontas mesmo fora de ordem; capítulo desconhecido é geral", () => {
    const g = agruparPorCapitulo({
      capitulos: [{ id: "a", titulo: "A" }, { id: "b", titulo: "B" }],
      secoes: [
        { id: "leitura", tipo: "texto" },
        { id: "x", tipo: "texto", capitulo: "a" },
        { id: "resumo", tipo: "texto" },
        { id: "nota", tipo: "texto", capitulo: "zzz" },
      ],
    });
    expect(g.antes.map((s) => s.id)).toEqual(["resumo"]);
    expect(g.depois.map((s) => s.id)).toEqual(["leitura", "nota"]);
    expect(g.capitulos[1].secoes).toEqual([]);
  });

  it("âncora segura para o id", () => {
    expect(ancoraCapitulo("ideb")).toBe("capitulo-ideb");
    expect(ancoraCapitulo("a b/c")).toBe("capitulo-a-b-c");
  });
});
