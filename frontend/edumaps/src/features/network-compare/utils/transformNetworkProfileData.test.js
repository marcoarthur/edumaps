import { describe, it, expect } from "vitest";
import {
  groupClusters,
  transformNetworkProfileData,
  formatNetworkValue,
  formatNetworkVariacao,
  rotuloIndicadorRede,
} from "./transformNetworkProfileData.js";
import { NETWORK_PROFILE_FIXTURE } from "../mocks/fixtures.js";

describe("transformNetworkProfileData", () => {
  it("agrupa clusters por cluster_id", () => {
    const clusters = groupClusters(NETWORK_PROFILE_FIXTURE.tables.clusters);

    expect(clusters).toHaveLength(2);
    expect(clusters[0].n).toBe(12);
    expect(clusters[0].indicadores).toHaveLength(2);
    expect(clusters[1].cluster_label).toBe("Baixa perfil escolar");
  });

  it("mapeia metadata e indicadores da rede", () => {
    const p = transformNetworkProfileData(NETWORK_PROFILE_FIXTURE);

    expect(p.metadata.municipio).toBe("Sertãozinho");
    expect(p.metadata.uf).toBe("SP");
    expect(p.indicadores).toHaveLength(3);
    expect(p.metrics.n_escolas).toBe(30);
  });

  it("normaliza clusters vazios", () => {
    const p = transformNetworkProfileData({ tables: { clusters: [], indicadores: [] }, metadata: {} });
    expect(p.clusters).toEqual([]);
    expect(p.indicadores).toEqual([]);
  });

  it("formatNetworkVariacao: p.p. nas proporções e sinal explícito (#421)", () => {
    expect(formatNetworkVariacao("prop_sem_especializacao", -0.436)).toBe("-43.6 p.p.");
    expect(formatNetworkVariacao("prop_licenciatura", 0.01)).toBe("+1.0 p.p.");
    expect(formatNetworkVariacao("ratio_aluno_docente", -2.7)).toBe("-2.7");
    expect(formatNetworkVariacao("ideb_observado", 0)).toBe("0.0");
    expect(formatNetworkVariacao("ideb_observado", null)).toBe("–");
  });

  it("formatNetworkValue", () => {
    expect(formatNetworkValue("prop_licenciatura", 0.8)).toBe("80.0%");
    expect(formatNetworkValue("ideb_observado", 5.12)).toBe("5.1");
    expect(formatNetworkValue("ideb_observado", null)).toBe("–");
  });
});

describe("perfil da rede: escolas com dado e rótulos (#479)", () => {
  it("leva n_com_valor dos indicadores e dos grupos", () => {
    const p = transformNetworkProfileData({
      tables: {
        indicadores: [{ indicador: "ideb_observado", label: "IDEB observado", rede: 4.9, brasil: 5, variacao: -0.1, n_com_valor: 406 }],
        clusters: [{ cluster_id: null, cluster_label: "Sem cluster", n: 1432, indicador: "ideb_observado", label: "IDEB observado", media: 4.9, n_com_valor: 406 }],
      },
      metadata: { ano_ideb: 2023, ano_inse: 2023 },
    });
    expect(p.indicadores[0].nComValor).toBe(406);
    expect(p.clusters[0].indicadores[0].nComValor).toBe(406);
    expect(p.metadata.anoIdeb).toBe(2023);
  });

  it("sem n_com_valor (cache antigo), fica null", () => {
    const p = transformNetworkProfileData({ tables: { indicadores: [{ indicador: "inse", rede: 4.5 }], clusters: [] }, metadata: {} });
    expect(p.indicadores[0].nComValor).toBeNull();
  });

  it("usa o rótulo por etapa e marca o IDEB antigo de etapas misturadas (#483)", () => {
    const meta = { anoIdeb: 2023, anoInse: 2023 };
    expect(rotuloIndicadorRede({ indicador: "ideb_observado", label: "IDEB observado" }, meta))
      .toBe("IDEB 2023 (etapas misturadas)");
    expect(rotuloIndicadorRede({ indicador: "ideb_anos_finais", label: "IDEB 2023, anos finais" }, meta))
      .toBe("IDEB 2023, anos finais");
    expect(rotuloIndicadorRede({ indicador: "inse", label: "INSE" }, meta)).toBe("INSE 2023");
    expect(rotuloIndicadorRede({ indicador: "prop_mestrado", label: "Docentes com mestrado" }, meta))
      .toBe("Docentes com mestrado");
  });
});
