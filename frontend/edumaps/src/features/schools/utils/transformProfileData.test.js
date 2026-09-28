import { describe, it, expect } from "vitest";
import {
  asArray,
  formatIndicator,
  formatSimilarity,
  formatQuartil,
  transformProfileData,
} from "./transformProfileData.js";
import { PROFILE_FIXTURE } from "../mocks/fixtures.js";

describe("transformProfileData", () => {
  it("asArray normaliza objeto único, array e ausente", () => {
    expect(asArray([{ a: 1 }])).toEqual([{ a: 1 }]);
    expect(asArray({ a: 1 })).toEqual([{ a: 1 }]);
    expect(asArray(null)).toEqual([]);
    expect(asArray(undefined)).toEqual([]);
  });

  it("formatIndicator trata proporção como % e null como –", () => {
    expect(formatIndicator("prop_licenciatura", 0.87)).toBe("87.0%");
    expect(formatIndicator("ratio_aluno_docente", 32.1)).toBe("32.1");
    expect(formatIndicator("ideb_observado", 4.7)).toBe("4.7");
    expect(formatIndicator("ideb_observado", null)).toBe("–");
    expect(formatIndicator("ideb_observado", undefined)).toBe("–");
  });

  it("formatSimilarity e formatQuartil", () => {
    expect(formatSimilarity(0.941)).toBe("94%");
    expect(formatQuartil(1)).toBe("Q1");
    expect(formatQuartil(null)).toBe("–");
  });

  it("mapeia metadata, cluster, fontes e tabelas", () => {
    const p = transformProfileData(PROFILE_FIXTURE);

    expect(p.school.nome).toBe("EMEF Exemplo");
    expect(p.school.co_entidade).toBe("35123456");
    expect(p.cluster.source).toBe("fallback_kmeans");
    expect(p.cluster.sourceLabel).toBe("cluster estimado (município)");
    expect(p.peersSourceLabel).toBe("Gower calculado no município");
    expect(p.indicadores).toHaveLength(3);
    expect(p.clusterResumo).toHaveLength(3);
    expect(p.peers).toHaveLength(2);
    expect(p.flags).toHaveLength(1);
  });

  it("normaliza tabela serializada como objeto único", () => {
    const p = transformProfileData({
      metadata: {},
      tables: { peers: { co_entidade: "1", no_entidade: "X" }, flags: null },
    });
    expect(p.peers).toHaveLength(1);
    expect(p.flags).toEqual([]);
  });
});
