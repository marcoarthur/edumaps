// src/features/schools/api/rankingApi.test.js
import { describe, it, expect } from "vitest";
import { getAvailableIndicators, getSchoolRanking } from "./rankingApi.js";
import { DEMO_SCHOOL_COD_INEP } from "../mocks/fixtures.js";

describe("rankingApi", () => {
  it("lista indicadores disponíveis para a escola", async () => {
    const indicators = await getAvailableIndicators(DEMO_SCHOOL_COD_INEP);
    expect(indicators).toContainEqual(
      expect.objectContaining({ id: "ideb_anos_finais", available: true }),
    );
  });

  it("retorna ranking para um indicador disponível (sem cluster)", async () => {
    const data = await getSchoolRanking(
      DEMO_SCHOOL_COD_INEP,
      "ideb_anos_finais",
    );
    expect(data.ranking.municipio.posicao).toBe(2);
    expect(data.ranking.estado.posicao).toBe(15);
    // O cluster NÃO faz parte do ranking - removemos essa verificação
    expect(data).not.toHaveProperty("cluster");
  });

  it("lança erro para indicador indisponível (cenário 2)", async () => {
    await expect(
      getSchoolRanking(DEMO_SCHOOL_COD_INEP, "ideb_ensino_medio"),
    ).rejects.toThrow(/não está disponível/i);
  });

  it("lança erro para escola sem dados de ranking", async () => {
    await expect(
      getSchoolRanking("00000000", "ideb_anos_finais"),
    ).rejects.toThrow();
  });
});
