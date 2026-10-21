// src/features/schools/api/schoolIvetApi.test.js
import { describe, it, expect } from "vitest";
import { getSchoolIvet, getSchoolIsocrona } from "./schoolIvetApi.js";
import { DEMO_SCHOOL_COD_INEP } from "../mocks/fixtures.js";

describe("schoolIvetApi", () => {
  it("busca o IVET vigente da escola demo", async () => {
    const ivet = await getSchoolIvet(DEMO_SCHOOL_COD_INEP);
    expect(ivet.ivet).toBeCloseTo(0.412);
    expect(ivet.publicavel).toBe(true);
    expect(ivet.blocos.C).toBeCloseTo(0.39);
    expect(ivet.dt_snapshot).toBe("2026-10-20");
  });

  it("rejeita (404) quando a escola não tem medição", async () => {
    await expect(getSchoolIvet("99999992")).rejects.toThrow();
  });

  it("busca a isócrona com as duas faixas", async () => {
    const iso = await getSchoolIsocrona(DEMO_SCHOOL_COD_INEP);
    expect(iso.tempos).toHaveLength(2);
    const [f15, f45] = iso.tempos;
    expect(f15.tempo_minutos).toBe(15);
    expect(f15.resolucao_h3).toBe(9);
    expect(f45.tempo_minutos).toBe(45);
    expect(f45.resolucao_h3).toBe(7);
    expect(f15.celulas[0]).toHaveProperty("grid_id");
  });

  it("rejeita (404) quando a escola está fora da cobertura", async () => {
    await expect(getSchoolIsocrona("99999992")).rejects.toThrow();
  });
});
