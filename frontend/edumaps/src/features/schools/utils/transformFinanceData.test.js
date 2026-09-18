// src/features/schools/utils/transformFinanceData.test.js
import { describe, it, expect } from "vitest";
import {
  buildCostRows,
  buildProfessionalsRows,
  buildCategoryBuckets,
  buildPeriodOptions,
  summarize,
  formatBRLCompact,
} from "./transformFinanceData.js";

const SERIES = [
  { ano: 2025, mes: "Janeiro", mes_num: 1, total_salario: 1000, total_profissionais: 10 },
  { ano: 2025, mes: "Dezembro", mes_num: 12, total_salario: 2000, total_profissionais: 12 },
];

describe("transformFinanceData", () => {
  it("monta as séries de custo e de profissionais com rótulo de competência", () => {
    expect(buildCostRows(SERIES)).toEqual([
      { group: "Custo total", key: "Jan/2025", value: 1000 },
      { group: "Custo total", key: "Dez/2025", value: 2000 },
    ]);
    expect(buildProfessionalsRows(SERIES)[1]).toEqual({
      group: "Profissionais",
      key: "Dez/2025",
      value: 12,
    });
  });

  it("agrega categorias brutas em buckets curados (ordenado por custo)", () => {
    const buckets = buildCategoryBuckets([
      { categoria: "Docente habilitado em curso de licenciatura plena", total_salario: 700, total_profissionais: 5 },
      { categoria: "Profissionais de secretaria escolar", total_salario: 300, total_profissionais: 2 },
      { categoria: "Função diversa", total_salario: 100, total_profissionais: 1 },
    ]);
    const byId = Object.fromEntries(buckets.map((b) => [b.bucket.id, b]));

    expect(byId.docentes.total_salario).toBe(700);
    expect(byId.administrativo.total_salario).toBe(300);
    expect(byId.outros.total_salario).toBe(100);
    expect(buckets[0].bucket.id).toBe("docentes");
  });

  it("buildPeriodOptions ordena da competência mais recente para a mais antiga", () => {
    expect(buildPeriodOptions(SERIES)).toEqual([
      { value: "12-2025", label: "Dezembro/2025" },
      { value: "01-2025", label: "Janeiro/2025" },
    ]);
  });

  it("summarize soma o custo e usa a última competência", () => {
    const s = summarize(SERIES);
    expect(s.totalCusto).toBe(3000);
    expect(s.mesCount).toBe(2);
    expect(s.lastProfessionals).toBe(12);
    expect(s.lastPeriod).toBe("Dez/2025");
  });

  it("formatBRLCompact usa mil/mi", () => {
    expect(formatBRLCompact(1500)).toMatch(/mil/);
    expect(formatBRLCompact(2_000_000)).toMatch(/mi/);
  });
});
