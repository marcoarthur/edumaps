import { describe, it, expect } from "vitest";
import {
  asArray,
  fraseSinal,
  formatIndicator,
  formatSimilarity,
  formatQuartil,
  idebDiferencaTexto,
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
    expect(p.peersSourceLabel).toBe("contexto, no município inteiro");
    expect(p.escolaIdeb).toBe(4.7);
    expect(p.peersCriterio).toBeNull();
    expect(p.indicadores).toHaveLength(3);
    expect(p.clusterResumo).toHaveLength(3);
    expect(p.peers).toHaveLength(2);
    expect(p.flags).toHaveLength(1);
  });

  it("mapeia frescor (cached/computed_at/cluster_run_id)", () => {
    const p = transformProfileData(PROFILE_FIXTURE);
    expect(p.cached).toBe(false);
    expect(p.computedAt).toBe("2026-09-28 21:00:00");
    expect(p.computedAtLabel).toBeTruthy();
    expect(p.clusterRunId).toBe("run_123");
  });

  it("normaliza tabela serializada como objeto único", () => {
    const p = transformProfileData({
      metadata: {},
      tables: { peers: { co_entidade: "1", no_entidade: "X" }, flags: null },
    });
    expect(p.peers).toHaveLength(1);
    expect(p.flags).toEqual([]);
  });

  it("idebDiferencaTexto: sinal, vírgula e ausência (#495)", () => {
    expect(idebDiferencaTexto(6.1, 4.7)).toBe("+1,4");
    expect(idebDiferencaTexto(4.3, 4.7)).toBe("−0,4");
    expect(idebDiferencaTexto(4.7, 4.7)).toBe("0,0");
    expect(idebDiferencaTexto(null, 4.7)).toBeNull();
    expect(idebDiferencaTexto(5, null)).toBeNull();
  });

  it("perfil em cache antigo mantém o rótulo da fonte antiga", () => {
    const p = transformProfileData({
      ...PROFILE_FIXTURE,
      metadata: { ...PROFILE_FIXTURE.metadata, peers_source: "gower_municipio", peers_criterio: "x" },
    });
    expect(p.peersSourceLabel).toBe("Gower calculado no município");
    expect(p.peersCriterio).toBe("x");
  });
});

describe("fraseSinal (#542)", () => {
  const ind = (o) => [{ indicador: "prop_efetivos", label: "Docentes efetivos (concursados)", direcao: "maior", ...o }];
  const flag = { indicador: "prop_efetivos", mensagem: "motor" };

  it("melhor que um e pior que o outro", () => {
    const f = fraseSinal(flag, ind({ escola: 0.6, municipio: 0.5, brasil: 0.7 }), [{ indicador: "prop_efetivos", p50: 0.8, n: 30 }]);
    expect(f.texto).toBe("60% nesta escola. Nas 30 escolas parecidas do município, metade tem 80% ou mais. A escola está melhor que o município (50%) e pior que o Brasil (70%).");
  });

  it("igual ao município, sem o Brasil", () => {
    const f = fraseSinal(flag, ind({ escola: 0.6, municipio: 0.601, brasil: null }), [{ indicador: "prop_efetivos", p50: 0.8 }], 30);
    expect(f.texto).toBe("60% nesta escola. Nas 30 escolas parecidas do município, metade tem 80% ou mais. A escola está igual ao município (60%).");
  });

  it("sem a mediana do grupo: null (a tela usa a mensagem do motor)", () => {
    expect(fraseSinal(flag, ind({ escola: 0.6 }), [])).toBeNull();
    expect(fraseSinal(flag, [], [{ indicador: "prop_efetivos", p50: 0.8 }])).toBeNull();
  });
});

