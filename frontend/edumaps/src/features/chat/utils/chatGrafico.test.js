// src/features/chat/utils/chatGrafico.test.js
import { describe, it, expect } from "vitest";
import { graficoDoChat, linhasGrafico, descricaoGraficoChat } from "./chatGrafico.js";

const layout = { title: { text: "Título" }, xaxis: { title: "rede" }, yaxis: { title: "total" } };

describe("graficoDoChat", () => {
  it("barra", () => {
    const spec = graficoDoChat({ data: [{ x: ["A", "B"], y: [1, 2], type: "bar" }], layout });
    expect(spec).toEqual({
      tipo: "barra",
      titulo: "Título",
      xRotulo: "rede",
      yRotulo: "total",
      pontos: [{ key: "A", value: 1 }, { key: "B", value: 2 }],
    });
    expect(linhasGrafico(spec)).toEqual([
      { group: "total", key: "A", value: 1 },
      { group: "total", key: "B", value: 2 },
    ]);
  });

  it("linha (scatter) com anos numéricos", () => {
    const spec = graficoDoChat({
      data: [{ x: [2021, 2022], y: [5.1, "5.4"], type: "scatter", mode: "lines+markers" }],
      layout,
    });
    expect(spec.tipo).toBe("linha");
    expect(spec.pontos).toEqual([{ key: "2021", value: 5.1 }, { key: "2022", value: 5.4 }]);
  });

  it("pizza: grupo = categoria", () => {
    const spec = graficoDoChat({
      data: [{ labels: ["Urbana", "Rural"], values: [70, 30], type: "pie", hole: 0.3 }],
      layout: { title: { text: "Localização" } },
    });
    expect(spec.tipo).toBe("pizza");
    expect(linhasGrafico(spec)).toEqual([
      { group: "Urbana", key: "Urbana", value: 70 },
      { group: "Rural", key: "Rural", value: 30 },
    ]);
    expect(descricaoGraficoChat(spec)).toBe('Gráfico de pizza "Localização". Urbana: 70; Rural: 30.');
  });

  it("aceita escalares embrulhados pelo Plumber (arrays de 1) e vetor de 1 desembrulhado", () => {
    const spec = graficoDoChat({
      data: [{ x: "Única", y: 7, type: ["bar"] }],
      layout: { title: { text: ["T"] }, xaxis: { title: ["x"] }, yaxis: { title: ["y"] } },
    });
    expect(spec).toMatchObject({ tipo: "barra", titulo: "T", xRotulo: "x", pontos: [{ key: "Única", value: 7 }] });
  });

  it("descarta valores não numéricos", () => {
    const spec = graficoDoChat({ data: [{ x: ["A", "B", "C"], y: [1, null, "x"], type: "bar" }] });
    expect(spec.pontos).toEqual([{ key: "A", value: 1 }]);
    expect(spec.titulo).toBe("");
  });

  it.each([
    ["null", null],
    ["string", "grafico"],
    ["array", [1, 2]],
    ["sem data", { layout }],
    ["tipo desconhecido", { data: [{ type: "heatmap", z: [[1]] }] }],
    ["sem pontos numéricos", { data: [{ x: ["A"], y: [null], type: "bar" }] }],
    ["traço inválido", { data: ["x"] }],
  ])("formato irreconhecível (%s) → null", (_, chart) => {
    expect(graficoDoChat(chart)).toBeNull();
  });
});
