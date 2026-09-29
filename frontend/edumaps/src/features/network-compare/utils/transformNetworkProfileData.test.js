import { describe, it, expect } from "vitest";
import {
  groupClusters,
  transformNetworkProfileData,
  formatNetworkValue,
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
    expect(p.indicadores).toHaveLength(2);
    expect(p.metrics.n_escolas).toBe(30);
  });

  it("normaliza clusters vazios", () => {
    const p = transformNetworkProfileData({ tables: { clusters: [], indicadores: [] }, metadata: {} });
    expect(p.clusters).toEqual([]);
    expect(p.indicadores).toEqual([]);
  });

  it("formatNetworkValue", () => {
    expect(formatNetworkValue("prop_licenciatura", 0.8)).toBe("80.0%");
    expect(formatNetworkValue("ideb_observado", 5.12)).toBe("5.1");
    expect(formatNetworkValue("ideb_observado", null)).toBe("–");
  });
});
